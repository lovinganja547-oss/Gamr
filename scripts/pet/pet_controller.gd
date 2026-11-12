class_name PetController
extends Node3D
## Comportement de l'animal : déplacement, autonomie selon besoins et caractère,
## réactions aux interactions, exécution des commandes.

signal arrived
signal action_done(action: String)

var model: PetModel
var pet: Dictionary
var bounds := Rect2(-2.5, -2.0, 5.0, 4.5)
var player_pos := Vector3(0, 0, 2.2)   # position « virtuelle » du joueur (devant la caméra)
var busy := false                      # true pendant une activité : pas d'autonomie
var sleeping := false
var state := "idle"
var speed := 0.0
var _target := Vector3.ZERO
var _move_speed := 1.0
var _on_arrive: Callable
var _idle_t := 2.0
var _act_id := 0
var _yaw_target := 0.0
var _spin := 0.0
var _jump_t := -1.0
var _jump_dur := 0.6
var _jump_h := 0.35
var _tap_count := 0
var _tap_t := 0.0
var _look_cam := true
var _hold_ai := false                  # suspend l'autonomie pendant un jeu spontané
var held: Node3D
var env_meta := {}
var nav: NavGrid
var _path := PackedVector2Array()
var _path_target := Vector3(INF, 0, INF)
var _stuck_t := 0.0
var _unstick_t := 0.0

func setup(p: Dictionary, quality: int) -> void:
	pet = p
	if model:
		model.queue_free()
	model = PetModel.new()
	add_child(model)
	model.setup(p, quality)
	_apply_mood_look()

func refresh_look() -> void:
	if model:
		model.rebuild(pet)
		_apply_mood_look()

func species() -> String:
	return str(GameData.breed(pet.get("breed", "labrador"))["species"])

func voice() -> void:
	var b := GameData.breed(pet.get("breed", "labrador"))
	Audio.play(str(b["voice"]), 0.08)

func happy_sound() -> void:
	if species() == "cat":
		Audio.play("purr", 0.05, -2.0)
	else:
		Audio.play("pant", 0.05, -6.0)

# ================================================================== Mouvement
func walk_to(p: Vector3, spd: float = 1.0, cb: Callable = Callable()) -> void:
	_act_id += 1
	sleeping = false
	GameState.pet_sleeping = false
	_target = Vector3(clampf(p.x, bounds.position.x, bounds.end.x), 0, clampf(p.z, bounds.position.y, bounds.end.y))
	if busy:
		_target = Vector3(p.x, 0, p.z)
	_move_speed = spd
	_on_arrive = cb
	state = "moving"
	model.set_posture("stand", 5.0)
	model.expression = "focus" if spd > 1.5 else "neutral"

## Calcule un chemin contournant les obstacles vers _target (corrigé s'il est inaccessible).
func _plan_path() -> void:
	_path = PackedVector2Array()
	if nav == null:
		_path_target = _target
		return
	var p := nav.find_path(Vector2(position.x, position.z), Vector2(_target.x, _target.z))
	if p.is_empty():
		var f := nav.nearest_free(Vector2(_target.x, _target.z))
		_target = Vector3(f.x, 0, f.y)
	else:
		_path = p
		var last := p[p.size() - 1]
		_target = Vector3(last.x, 0, last.y)
	_path_target = _target

func stop_moving() -> void:
	if state == "moving":
		state = "idle"
	speed = 0.0
	model.move_speed = 0.0

## Interrompt toute action ou coroutine en cours (début d'activité) sans téléporter l'animal.
func interrupt() -> void:
	_act_id += 1
	_on_arrive = Callable()
	_path = PackedVector2Array()
	state = "idle"
	speed = 0.0
	_spin = 0.0
	model.move_speed = 0.0
	model.sniff = 0.0
	model.chew = 0.0
	model.shake = 0.0
	model.tongue_out = 0.0
	model.head_extra = Vector3.ZERO
	var h := drop_held()
	if h and h.name == "Toy":
		h.queue_free()
	_toy_cleanup()
	if sleeping:
		sleeping = false
		GameState.pet_sleeping = false
	model.set_posture("stand", 4.0)
	_apply_mood_look()

func face(p: Vector3) -> void:
	var d := p - position
	if d.length() > 0.01:
		_yaw_target = atan2(d.x, d.z)

func _process(delta: float) -> void:
	if model == null:
		return
	# Rotation douce
	if _spin > 0.0:
		var step := minf(_spin, delta * TAU * 1.1)
		rotation.y += step
		_spin -= step
		_yaw_target = rotation.y
	else:
		rotation.y = lerp_angle(rotation.y, _yaw_target, minf(1.0, delta * 7.0))
	# Saut
	if _jump_t >= 0.0:
		_jump_t += delta
		var k := _jump_t / _jump_dur
		if k >= 1.0:
			_jump_t = -1.0
			model.jump_y = 0.0
			Audio.play("bounce", 0.1, -6.0)
		else:
			model.jump_y = sin(k * PI) * _jump_h
	# Jamais coincé : si l'animal se retrouve dans la zone d'un meuble (fin d'activité, repas, réveil),
	# il glisse vers l'endroit libre le plus proche au lieu de rester bloqué.
	if nav and not sleeping and state in ["idle", "moving"] and _jump_t < 0.0:
		var here := Vector2(position.x, position.z)
		if nav.is_blocked_point(here, -0.08):
			var out := nav.nearest_free(here)
			position = position.move_toward(Vector3(out.x, 0, out.y), maxf(1.0, speed) * delta)
			_unstick_t += delta
			if _unstick_t > 1.2:
				position = Vector3(out.x, 0, out.y)
				_unstick_t = 0.0
			_path_target = Vector3(INF, 0, INF)
		else:
			_unstick_t = 0.0
	# Déplacement
	if state == "moving":
		if _target != _path_target:
			_plan_path()
		var goal := _target
		if _path.size() > 1:
			goal = Vector3(_path[0].x, 0, _path[0].y)
			if Vector2(position.x, position.z).distance_to(_path[0]) < 0.12:
				_path.remove_at(0)
				goal = Vector3(_path[0].x, 0, _path[0].y) if _path.size() > 1 else _target
		var d := goal - position
		d.y = 0
		var dist := d.length()
		if dist < 0.06:
			speed = 0.0
			state = "idle"
			model.move_speed = 0.0
			arrived.emit()
			if _on_arrive.is_valid():
				var cb := _on_arrive
				_on_arrive = Callable()
				cb.call()
		else:
			var remaining := dist if _path.size() <= 1 else 1.0
			speed = move_toward(speed, _move_speed * minf(1.0, remaining * 2.0 + 0.3), delta * 4.0)
			var before := position
			position += d / dist * minf(speed * delta, dist)
			# Sécurité : jamais à l'intérieur d'un obstacle
			if nav and nav.is_blocked_point(Vector2(position.x, position.z), -0.08) and not nav.is_blocked_point(Vector2(before.x, before.z), -0.08):
				position = before
				_stuck_t += delta
				if _stuck_t > 0.6:
					_stuck_t = 0.0
					_path_target = Vector3(INF, 0, INF)
			else:
				_stuck_t = 0.0
			_yaw_target = atan2(d.x, d.z)
			model.move_speed = speed
			model.tongue_out = 1.0 if speed > 1.6 else 0.0
	# Regard vers le joueur
	if _look_cam and state in ["idle", "action"] and not sleeping:
		var to_p := player_pos - position
		var rel := wrapf(atan2(to_p.x, to_p.z) - rotation.y, -PI, PI)
		model.head_extra.y = clampf(rel, -0.8, 0.8) * 0.8
	elif state == "moving":
		model.head_extra.y = 0.0
	_tap_t = maxf(0.0, _tap_t - delta)
	if _tap_t <= 0.0:
		_tap_count = 0
	if not busy and not _hold_ai and state == "idle":
		_idle_t -= delta
		if _idle_t <= 0.0:
			_autonomy()

# ================================================================== Autonomie
func _apply_mood_look() -> void:
	if pet.is_empty() or model == null:
		return
	var n: Dictionary = pet["needs"]
	model.set_dirt((65.0 - float(n["clean"])) / 65.0 * 0.9)
	model.wag_amp = 0.15 + n["mood"] / 100.0 * 0.45
	model.wag_speed = 6.0 + n["mood"] / 100.0 * 8.0
	if sleeping:
		model.expression = "closed"
	elif n["mood"] < 35.0 or n["health"] < 35.0:
		model.expression = "sad"
	else:
		model.expression = "neutral"

func _autonomy() -> void:
	_apply_mood_look()
	var n: Dictionary = pet["needs"]
	var tr_: Dictionary = pet["traits"]
	var rng := randf()
	_idle_t = randf_range(3.0, 7.0) * (1.4 - float(tr_.get("energy", 50)) / 100.0 * 0.7)
	if sleeping:
		if n["energy"] >= 98.0:
			wake_up()
		else:
			_idle_t = 3.0
			if randf() < 0.3:
				model.emote("emo_zzz", 1.6)
		return
	if n["energy"] < 12.0:
		go_sleep()
		return
	if n["hunger"] < 30.0 and randf() < 0.4:
		model.emote("emo_food")
		Audio.play("whine", 0.05, -6.0)
		do_posture("sad", 2.0)
		return
	if n["thirst"] < 30.0 and randf() < 0.4:
		model.emote("emo_drop")
		do_posture("sad", 2.0)
		return
	if n["clean"] < 25.0 and randf() < 0.3:
		model.emote("emo_bug")
		shake_off()
		return
	if n["mood"] < 35.0:
		do_posture("lie", 4.0)
		model.expression = "sad"
		return
	var curious := float(tr_.get("curiosity", 50)) / 100.0
	var energetic := float(tr_.get("energy", 50)) / 100.0
	if rng < 0.28:
		var p := Vector3(randf_range(bounds.position.x, bounds.end.x), 0, randf_range(bounds.position.y, bounds.end.y))
		walk_to(p, 0.55 + energetic * 0.5)
	elif rng < 0.28 + curious * 0.25:
		var p2 := position + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
		walk_to(p2, 0.45, sniff_ground)
	elif rng < 0.62:
		do_posture("sit", randf_range(2.5, 5.0))
	elif rng < 0.72:
		do_posture("lie", randf_range(3.0, 6.0))
	elif rng < 0.8:
		stretch()
	elif rng < 0.88 and energetic > 0.5 and n["mood"] > 60.0:
		play_bow()
	else:
		look_at_player()

# ================================================================== Actions de base
func _begin(nm: String) -> int:
	_act_id += 1
	state = "action"
	sleeping = false
	GameState.pet_sleeping = false
	model.move_speed = 0.0
	model.sniff = 0.0
	model.chew = 0.0
	model.shake = 0.0
	speed = 0.0
	set_meta("action", nm)
	return _act_id

func _wait(t: float, id: int) -> bool:
	await get_tree().create_timer(t, false).timeout
	return id == _act_id

func _end(id: int, nm: String) -> void:
	if id != _act_id:
		return
	state = "idle"
	model.set_posture("stand")
	model.sniff = 0.0
	model.chew = 0.0
	_apply_mood_look()
	action_done.emit(nm)

func do_posture(p: String, dur: float) -> void:
	var id := _begin(p)
	model.set_posture(p)
	if await _wait(dur, id):
		_end(id, p)

func sniff_ground() -> void:
	var id := _begin("sniff")
	model.set_posture("sniff")
	model.sniff = 1.0
	Audio.play("sniff", 0.1, -4.0)
	if await _wait(1.8, id):
		model.sniff = 0.0
		_end(id, "sniff")

func stretch() -> void:
	var id := _begin("stretch")
	model.set_posture("stretch", 2.5)
	model.expression = "closed"
	model.tongue_out = 1.0
	if await _wait(1.6, id):
		model.tongue_out = 0.0
		_end(id, "stretch")

func play_bow() -> void:
	var id := _begin("bow")
	model.set_posture("bow", 6.0)
	model.wag_amp = 0.8
	model.wag_speed = 16.0
	model.expression = "happy"
	voice()
	if await _wait(1.4, id):
		_end(id, "bow")

func shake_off() -> void:
	var id := _begin("shake")
	model.set_posture("stand")
	model.shake = 1.0
	Audio.play("whoosh", 0.1, -4.0)
	if await _wait(0.9, id):
		model.shake = 0.0
		_end(id, "shake")

func look_at_player() -> void:
	var id := _begin("look")
	face(player_pos)
	model.set_posture("alert")
	model.head_extra.z = 0.35 * (1.0 if randf() < 0.5 else -1.0)
	if await _wait(1.5, id):
		model.head_extra.z = 0.0
		_end(id, "look")

func head_tilt() -> void:
	var id := _begin("tilt")
	model.set_posture("alert")
	model.head_extra.z = 0.45 * (1.0 if randf() < 0.5 else -1.0)
	model.emote("emo_question")
	if await _wait(1.3, id):
		model.head_extra.z = 0.0
		_end(id, "tilt")

func go_sleep() -> void:
	var id := _begin("sleep")
	var bed: Variant = env_meta.get("bed")
	if bed is Vector3 and not busy:
		walk_to(bed, 0.5, func(): _sleep_now())
		return
	_sleep_now()
	if id != _act_id:
		return

func _sleep_now() -> void:
	var id := _begin("sleep")
	sleeping = true
	GameState.pet_sleeping = true
	state = "idle"
	_idle_t = 4.0
	model.set_posture("sleep", 1.5)
	model.expression = "closed"
	model.wag_amp = 0.0
	model.emote("emo_zzz", 2.0)
	if id != _act_id:
		return

func wake_up() -> void:
	sleeping = false
	GameState.pet_sleeping = false
	_act_id += 1
	state = "idle"
	model.set_posture("stand", 2.0)
	_apply_mood_look()
	stretch()

func eat(kind: String, dur: float = 2.5) -> void:
	var id := _begin("eat")
	model.set_posture("eat")
	model.chew = 1.0
	Audio.play("crunch" if kind == "food" else "lap", 0.05, -2.0)
	if await _wait(dur * 0.5, id):
		Audio.play("crunch" if kind == "food" else "lap", 0.05, -2.0)
		if await _wait(dur * 0.5, id):
			model.chew = 0.0
			model.emote("emo_yum")
			_end(id, "eat")

## Repas complet : approche par un côté libre, tête au-dessus de la gamelle, mastication,
## nourriture qui diminue (on_tick reçoit la part consommée 0..1), puis retour à l'état normal.
func eat_from(bowl: Node3D, kind: String, dur: float, on_tick: Callable, on_done: Callable) -> void:
	var bp := Vector3(bowl.global_position.x, 0, bowl.global_position.z)
	var reach := model.head_reach() * 0.82 + 0.1
	var spot := bp + Vector3(0, 0, reach)
	if nav:
		var best := Vector2(spot.x, spot.z)
		var best_d := INF
		for a in [0.0, -0.6, 0.6, -1.2, 1.2, PI * 0.5, -PI * 0.5, PI]:
			var c := Vector2(bp.x, bp.z) + Vector2(sin(a), cos(a)) * reach
			if not nav.is_blocked_point(c):
				var d := c.distance_to(Vector2(position.x, position.z)) + absf(a) * 0.3
				if d < best_d:
					best_d = d
					best = c
		spot = Vector3(best.x, 0, best.y)
	var id_before := _act_id + 1
	walk_to(spot, 1.2, func(): _eat_now(bp, kind, dur, on_tick, on_done))
	# Sécurité : chemin bloqué -> on mange là où on est arrivé, sans téléportation
	await get_tree().create_timer(9.0, false).timeout
	if _act_id == id_before and state == "moving":
		stop_moving()
		_eat_now(bp, kind, dur, on_tick, on_done)

func _eat_now(bp: Vector3, kind: String, dur: float, on_tick: Callable, on_done: Callable) -> void:
	var id := _begin("eat")
	face(bp)
	await get_tree().create_timer(0.25, false).timeout
	if id != _act_id:
		on_done.call(false)
		return
	model.set_posture("eat", 3.5)
	model.chew = 1.0
	var steps := 6
	for i in steps:
		Audio.play("crunch" if kind == "food" else "lap", 0.08, -4.0)
		await get_tree().create_timer(dur / steps, false).timeout
		if id != _act_id:
			model.chew = 0.0
			on_done.call(false)
			return
		if on_tick.is_valid():
			on_tick.call(float(i + 1) / steps)
	model.chew = 0.0
	model.set_posture("stand", 3.0)
	model.emote("emo_yum" if kind == "food" else "emo_drop")
	model.tongue_out = 1.0
	await get_tree().create_timer(0.6, false).timeout
	model.tongue_out = 0.0
	_end(id, "eat")
	on_done.call(true)

## Jeu spontané avec le jouet actif : bond, attrape, secoue, lance et rattrape.
## Robuste aux interruptions : le jouet est toujours retiré, l'IA autonome est suspendue pendant le jeu.
var _toy_node: Node3D = null

func _toy_cleanup() -> void:
	_hold_ai = false
	if _toy_node and is_instance_valid(_toy_node):
		if held == _toy_node:
			held = null
		_toy_node.queue_free()
	_toy_node = null

## Court vers un point (sans annuler l'action en cours). Vrai si arrivé avant le délai.
func _run_to(dest: Vector3, spd: float, id: int, timeout: float) -> bool:
	_on_arrive = Callable()
	_path = PackedVector2Array()
	_path_target = Vector3(INF, 0, INF)
	_target = Vector3(dest.x, 0, dest.z)
	_move_speed = spd
	model.set_posture("stand", 8.0)
	state = "moving"
	var t := 0.0
	while t < timeout:
		await get_tree().process_frame
		if id != _act_id:
			return false
		t += get_process_delta_time()
		if state != "moving":
			state = "action"
			return true
	stop_moving()
	state = "action"
	return true

func play_with_toy() -> void:
	if _toy_node and is_instance_valid(_toy_node):
		return
	var id := _begin("toy")
	_hold_ai = true
	var toy := make_toy(GameState.data.get("toy", "ball"))
	_toy_node = toy
	get_parent().add_child(toy)
	var p := position + Vector3(sin(rotation.y), 0, cos(rotation.y)) * 0.8
	if nav:
		var f := nav.nearest_free(Vector2(p.x, p.z))
		p = Vector3(f.x, 0, f.y)
	toy.position = p + Vector3(0, 0.06, 0)
	Audio.play("bounce")
	face(p)
	model.set_posture("bow", 6.0)
	model.expression = "happy"
	model.wag_amp = 1.0
	model.wag_speed = 18.0
	model.emote("emo_playful")
	if not await _wait(0.9, id):
		_toy_cleanup()
		return
	for round_i in 2:
		if not is_instance_valid(toy):
			_toy_cleanup()
			return
		# s'arrête la gueule sur le jouet (et non le corps dessus)
		var tp := Vector3(toy.position.x, 0, toy.position.z)
		var dir := tp - position
		dir.y = 0
		var reach := model.body_length() * 0.45
		var dest := tp - dir.normalized() * reach if dir.length() > reach else position
		if not await _run_to(dest, 1.6, id, 4.0):
			_toy_cleanup()
			return
		face(tp)
		grab(toy)
		model.set_posture("stand", 6.0)
		model.shake = 0.6
		Audio.play("crunch", 0.2, -8.0)
		if not await _wait(0.8, id):
			_toy_cleanup()
			return
		model.shake = 0.0
		# lance le jouet un peu plus loin
		var thrown := drop_held()
		if thrown:
			var to := position + Vector3(randf_range(-0.9, 0.9), 0, randf_range(-0.9, 0.9))
			if nav:
				var f2 := nav.nearest_free(Vector2(to.x, to.z))
				to = Vector3(f2.x, 0, f2.y)
			var tw := thrown.create_tween()
			tw.tween_property(thrown, "position", Vector3(to.x, 0.35, to.z), 0.25).set_ease(Tween.EASE_OUT)
			tw.tween_property(thrown, "position", Vector3(to.x, 0.06, to.z), 0.25).set_ease(Tween.EASE_IN)
			Audio.play("bounce", 0.1, -6.0)
		model.set_posture("bow", 6.0)
		if not await _wait(0.6, id):
			_toy_cleanup()
			return
	if is_instance_valid(toy):
		var tp2 := Vector3(toy.position.x, 0, toy.position.z)
		var d2 := tp2 - position
		d2.y = 0
		var r2 := model.body_length() * 0.45
		if d2.length() > r2 and not await _run_to(tp2 - d2.normalized() * r2, 1.2, id, 3.0):
			_toy_cleanup()
			return
		grab(toy)
	model.set_posture("lie", 3.0)
	model.chew = 1.0
	GameState.change_need("mood", 8.0)
	GameState.spend_energy("calm")
	if not await _wait(2.0, id):
		model.chew = 0.0
		_toy_cleanup()
		return
	model.chew = 0.0
	_toy_cleanup()
	GameState.inc_stat("toy_play", 1)
	if GameState.reward_ok("toy_play", 0.5):
		GameState.add_xp(3)
	_end(id, "toy")

# ================================================================== Interactions joueur
func on_stroke(part: String) -> void:
	if state == "moving":
		return
	if sleeping:
		if randf() < 0.05:
			wake_up()
		return
	if state != "action" or get_meta("action", "") != "petted":
		_begin("petted")
		state = "action"
	var temper: String = pet.get("temperament", "joueur")
	var mood: float = pet["needs"]["mood"]
	var shy := temper == "timide" and GameState.relation_level(pet) < 3
	if shy and randf() < 0.35:
		# timide : se laisse caresser, mais reste un peu sur la réserve
		model.expression = "focus"
		model.wag_amp = 0.25
		model.head_extra.z = 0.0
		model.set_posture("sit", 3.0)
	else:
		model.expression = "happy" if mood > 35.0 else "closed"
		model.wag_amp = lerpf(0.3, 1.0, mood / 100.0)
		model.wag_speed = lerpf(8.0, 16.0, mood / 100.0)
		model.head_extra.z = 0.25 if part == "head" else 0.0
		if part == "body" and (temper == "calme" or pet["needs"]["energy"] < 45.0) and randf() < 0.04:
			model.set_posture("lie", 2.0)   # se détend sous la main
		elif temper == "affectueux" and randf() < 0.05:
			model.set_posture("lie", 2.0)
			model.head_extra.z = 0.45
	model.hearts(1)
	set_meta("petted_until", Time.get_ticks_msec() + 900)
	_petted_release(_act_id)

func _petted_release(id: int) -> void:
	await get_tree().create_timer(1.0, false).timeout
	if id != _act_id:
		return
	if Time.get_ticks_msec() >= int(get_meta("petted_until", 0)):
		model.head_extra.z = 0.0
		if randf() < 0.5:
			happy_sound()
		_end(id, "petted")

func on_tap(part: String) -> void:
	if sleeping:
		wake_up()
		model.emote("emo_sleepy")
		return
	_tap_count += 1
	_tap_t = 1.5
	if _tap_count >= 5 and float(pet["traits"].get("independence", 50)) > 50.0:
		model.emote("emo_angry")
		_tap_count = 0
		do_posture("sit", 1.0)
		face(position + Vector3(randf_range(-1, 1), 0, -1))
		return
	var temper: String = pet.get("temperament", "joueur")
	if temper == "timide" and GameState.relation_level(pet) < 3 and _tap_count >= 2:
		# timide : recule doucement si on insiste
		model.emote("emo_question")
		walk_to(position + (position - player_pos).normalized() * 0.4, 0.8, func(): do_posture("sit", 1.5))
		return
	if pet["needs"]["mood"] < 30.0:
		model.emote("emo_sad")
		do_posture("sad", 1.5)
		return
	if part == "head":
		voice()
		head_tilt()
	else:
		match temper:
			"energique":
				model.emote("emo_star")
				perform("spin")
			"curieux":
				face(player_pos)
				sniff_ground()
			"calme":
				model.emote("emo_heart")
				do_posture("sit", 1.5)
			_:
				model.emote("emo_heart" if pet["needs"]["affection"] > 50.0 else "emo_playful")
				play_bow()

## Appel par le joueur : interrompt tout et ramène l'animal devant lui, quoi qu'il arrive.
## S'il est coincé (dans un meuble, hors de la pièce, sans chemin possible), il est replacé directement.
func call_name() -> void:
	interrupt()
	model.emote("emo_exclaim")
	voice()
	var dest := player_pos + Vector3(randf_range(-0.2, 0.2), 0, -0.5)
	dest.x = clampf(dest.x, bounds.position.x + 0.3, bounds.end.x - 0.3)
	dest.z = clampf(dest.z, bounds.position.y + 0.3, bounds.end.y - 0.3)
	var here := Vector2(position.x, position.z)
	var stuck := not bounds.grow(0.3).has_point(here) or absf(position.y) > 0.05
	if nav != null:
		var f := nav.nearest_free(Vector2(dest.x, dest.z))
		dest = Vector3(f.x, 0, f.y)
		if nav.is_blocked_point(here):
			stuck = true
		elif here.distance_to(f) > 0.4 and not nav.clear_line(here, f) and nav.find_path(here, f).is_empty():
			stuck = true
	var arrive := func():
		face(player_pos)
		do_posture("sit", 2.0)
	if stuck:
		_place_at(dest)
		arrive.call()
		return
	walk_to(dest, 1.6, arrive)
	_call_watch(_act_id, dest, arrive)

func _place_at(dest: Vector3) -> void:
	position = Vector3(dest.x, 0, dest.z)
	_path = PackedVector2Array()
	_on_arrive = Callable()
	state = "idle"
	speed = 0.0
	model.move_speed = 0.0

## Filet de sécurité : si l'animal n'avance plus vers le joueur, il est replacé.
func _call_watch(id: int, dest: Vector3, arrive: Callable) -> void:
	var last := position
	var still := 0
	for i in 16:
		await get_tree().create_timer(0.5, false).timeout
		if id != _act_id or state != "moving":
			return
		if position.distance_to(dest) < 0.35:
			return
		still = still + 1 if position.distance_to(last) < 0.08 else 0
		last = position
		if still >= 2:
			break
	if id == _act_id and position.distance_to(dest) >= 0.35:
		_place_at(dest)
		arrive.call()

func praise() -> void:
	var id := _begin("praise")
	model.expression = "happy"
	model.wag_amp = 1.0
	model.wag_speed = 18.0
	model.hearts(3)
	happy_sound()
	Audio.play("heart", 0.1, -12.0)
	model.set_posture("bow", 6.0)
	if await _wait(1.2, id):
		_end(id, "praise")

func scold() -> void:
	var id := _begin("scold")
	model.expression = "sad"
	model.set_posture("sad")
	model.wag_amp = 0.05
	model.emote("emo_sad")
	Audio.play("whine", 0.05, -6.0)
	if await _wait(1.5, id):
		_end(id, "scold")

# ================================================================== Commandes (dressage)
## Exécute la commande ; retourne la durée de l'animation.
func perform(cmd: String) -> float:
	var id := _begin("cmd_" + cmd)
	face(player_pos)
	model.expression = "focus"
	match cmd:
		"sit":
			model.set_posture("sit", 5.0)
			_finish_after(1.6, id, cmd)
			return 1.6
		"down":
			model.set_posture("lie", 4.0)
			_finish_after(1.8, id, cmd)
			return 1.8
		"stand":
			model.set_posture("stand_up", 4.0)
			_finish_after(1.6, id, cmd)
			return 1.6
		"paw":
			model.set_posture("paw", 4.0)
			_finish_after(1.7, id, cmd)
			return 1.7
		"beg":
			model.set_posture("beg", 3.5)
			model.tongue_out = 1.0
			_finish_after(1.9, id, cmd)
			return 1.9
		"spin":
			model.set_posture("stand", 6.0)
			_spin = TAU
			model.move_speed = 0.7
			_finish_after(1.4, id, cmd)
			return 1.4
		"jump":
			model.set_posture("jump", 8.0)
			_jump_t = 0.0
			_jump_dur = 0.65
			_jump_h = 0.4
			_finish_after(0.9, id, cmd)
			return 0.9
		"stay":
			# reste en place et garde le contact visuel pendant que le joueur s'éloigne
			model.set_posture("sit", 5.0)
			model.wag_amp = 0.2
			_finish_after(2.6, id, cmd)
			return 2.6
		"come":
			var start := position
			var dest := player_pos + Vector3(0, 0, -0.55)
			if start.distance_to(dest) < 0.4:
				start = dest + Vector3(0, 0, -1.2)
				position = start
			state = "moving"
			_target = dest
			_move_speed = 1.6
			_on_arrive = func():
				face(player_pos)
				model.set_posture("sit")
				_finish_after(0.8, _act_id, cmd)
			return 2.2
		"fetch":
			_fetch_demo(id)
			return 3.4
	return 1.0

func _finish_after(t: float, id: int, cmd: String) -> void:
	if await _wait(t, id):
		model.move_speed = 0.0
		model.tongue_out = 0.0
		_end(id, "cmd_" + cmd)

func _fetch_demo(id: int) -> void:
	var toy := make_toy(GameState.data.get("toy", "ball"))
	get_parent().add_child(toy)
	var dest := position + Vector3(randf_range(-0.6, 0.6), 0, -1.4)
	dest.x = clampf(dest.x, bounds.position.x, bounds.end.x)
	dest.z = clampf(dest.z, bounds.position.y - 1.0, bounds.end.y)
	toy.position = dest + Vector3(0, 0.06, 0)
	state = "moving"
	_target = dest
	_move_speed = 1.8
	_on_arrive = func():
		if id != _act_id:
			toy.queue_free()
			return
		grab(toy)
		state = "moving"
		_target = player_pos + Vector3(0, 0, -0.55)
		_move_speed = 1.6
		_on_arrive = func():
			face(player_pos)
			drop_held()
			model.set_posture("sit")
			_finish_after(0.5, id, "fetch")

## Mauvaise réaction quand la commande échoue.
func fail_behaviour(cmd: String) -> float:
	var r := randi() % 4
	if cmd == "stay" and r < 3:
		# ne reste pas : suit le joueur
		model.emote("emo_question")
		walk_to(player_pos + Vector3(randf_range(-0.3, 0.3), 0, -0.5), 0.9, func(): do_posture("sit", 1.0))
		return 2.6
	match r:
		0:
			head_tilt()
			return 1.3
		1:
			var wrong: Array = ["sit", "down", "spin", "paw"].filter(func(c): return c != cmd)
			perform(wrong[randi() % wrong.size()])
			return 1.7
		2:
			var p := position + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.6, 0.2))
			walk_to(p, 0.6, sniff_ground)
			return 2.4
		_:
			shake_off()
			return 1.0

# ================================================================== Jouets
static func make_toy(id: String) -> Node3D:
	var it := GameData.item(id)
	var c: Color = it.get("color", Color.RED)
	var n := Node3D.new()
	n.name = "Toy"
	match str(it.get("toy", "ball")):
		"disc":
			WorldBuilder.cyl(n, 0.11, 0.11, 0.03, Vector3.ZERO, c, 16)
		"rope":
			WorldBuilder.cyl(n, 0.025, 0.025, 0.28, Vector3.ZERO, c, 8, Vector3(0, 0, PI / 2))
			WorldBuilder.ball(n, 0.045, Vector3(0.14, 0, 0), c.darkened(0.2))
			WorldBuilder.ball(n, 0.045, Vector3(-0.14, 0, 0), c.darkened(0.2))
		"plush":
			WorldBuilder.ball(n, 0.07, Vector3.ZERO, c)
			WorldBuilder.ball(n, 0.045, Vector3(0, 0.07, 0.04), c)
			WorldBuilder.ball(n, 0.025, Vector3(0, 0.07, 0.09), Color(1, 0.55, 0.2), Vector3(1, 0.5, 1.2))
		_:
			WorldBuilder.ball(n, 0.06, Vector3.ZERO, c, Vector3.ONE, 12)
	return n

func grab(n: Node3D) -> void:
	drop_held()
	held = n
	if n.get_parent():
		n.get_parent().remove_child(n)
	model.held_anchor.add_child(n)
	n.position = Vector3.ZERO
	n.rotation = Vector3.ZERO

func drop_held() -> Node3D:
	if held == null or not is_instance_valid(held):
		held = null
		return null
	var n := held
	held = null
	var gp := n.global_position
	n.get_parent().remove_child(n)
	get_parent().add_child(n)
	n.global_position = Vector3(gp.x, 0.06, gp.z)
	return n
