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
var held: Node3D
var env_meta := {}
var nav: NavGrid
var _path := PackedVector2Array()
var _path_target := Vector3(INF, 0, INF)
var _stuck_t := 0.0

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
			if nav and nav.is_blocked_point(Vector2(position.x, position.z), -0.08):
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
	if not busy and state == "idle":
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
				model.emote("💤", 1.6)
		return
	if n["energy"] < 12.0:
		go_sleep()
		return
	if n["hunger"] < 30.0 and randf() < 0.4:
		model.emote("🍖")
		Audio.play("whine", 0.05, -6.0)
		do_posture("sad", 2.0)
		return
	if n["thirst"] < 30.0 and randf() < 0.4:
		model.emote("💧")
		do_posture("sad", 2.0)
		return
	if n["clean"] < 25.0 and randf() < 0.3:
		model.emote("🦟")
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
	model.emote("❓")
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
	model.emote("💤", 2.0)
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
			model.emote("😋")
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
	model.emote("😋" if kind == "food" else "💦")
	model.tongue_out = 1.0
	await get_tree().create_timer(0.6, false).timeout
	model.tongue_out = 0.0
	_end(id, "eat")
	on_done.call(true)

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
	model.expression = "happy"
	model.wag_amp = 0.9
	model.wag_speed = 15.0
	model.head_extra.z = 0.25 if part == "head" else 0.0
	if part == "body" and pet["needs"]["energy"] < 50.0 and randf() < 0.01:
		model.set_posture("lie")
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
		model.emote("😪")
		return
	_tap_count += 1
	_tap_t = 1.5
	if _tap_count >= 5 and float(pet["traits"].get("independence", 50)) > 50.0:
		model.emote("💢")
		_tap_count = 0
		do_posture("sit", 1.0)
		face(position + Vector3(randf_range(-1, 1), 0, -1))
		return
	if part == "head":
		voice()
		head_tilt()
	else:
		model.emote("❤️" if pet["needs"]["affection"] > 50.0 else "❔")
		play_bow()

func call_name() -> void:
	if sleeping:
		wake_up()
	model.emote("❗")
	voice()
	walk_to(player_pos + Vector3(randf_range(-0.2, 0.2), 0, -0.5), 1.6, func():
		face(player_pos)
		do_posture("sit", 2.0))

func praise() -> void:
	var id := _begin("praise")
	model.expression = "happy"
	model.wag_amp = 1.0
	model.wag_speed = 18.0
	model.emote("💖")
	happy_sound()
	model.set_posture("bow", 6.0)
	if await _wait(1.2, id):
		_end(id, "praise")

func scold() -> void:
	var id := _begin("scold")
	model.expression = "sad"
	model.set_posture("sad")
	model.wag_amp = 0.05
	model.emote("😔")
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
