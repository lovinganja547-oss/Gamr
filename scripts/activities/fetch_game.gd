class_name FetchGame
extends Activity
## Lancer de balle. Mode libre (jeu) ou mode score (5 lancers, cibles au sol).

const THROWS := 5
const GRAVITY := 9.0

var free_mode := true
var toy: Node3D
var toy_id := "ball"
var vel := Vector3.ZERO
var flying := false
var _swipe_start := Vector2.ZERO
var _swipe_t := 0
var _swiping := false
var throws_done := 0
var score := 0
var targets: Array[Dictionary] = []
var target_nodes: Array[Node3D] = []
var player_spot := Vector3(0, 0, 2.0)
var _throw_t := 0.0
var _land_pos := Vector3.ZERO
var _landed := false
var _phase := "ready"   # ready, flying, chasing, returning, playing
var aim_line: Line2D
var call_btn: Button
var throw_area := Rect2(-4, -9, 8, 9)

func _init(is_free: bool = true) -> void:
	free_mode = is_free

func _start() -> void:
	toy_id = str(GameState.data.get("toy", "ball"))
	throw_area = main.env_root.get_meta("throw_area", Rect2(-3.5, -3.0, 7.0, 4.5))
	make_top(("🎾 " + tr("Jeu de balle")) if free_mode else ("🎾 " + tr("Lancer de balle")))
	_update_info()
	var bb := bottom_bar()
	call_btn = UiKit.button("📣 " + tr("Rapporte !"), _call_back, UiKit.C_BLUE, 28, 90)
	call_btn.visible = false
	bb.add_child(call_btn)
	aim_line = Line2D.new()
	aim_line.width = 14.0
	aim_line.default_color = Color(1, 1, 1, 0.8)
	aim_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	aim_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	ui.add_child(aim_line)
	player_spot = Vector3(0, 0, throw_area.end.y + 0.3)
	pet.bounds = Rect2(throw_area.position.x - 1, throw_area.position.y - 1, throw_area.size.x + 2, throw_area.size.y + 3)
	pet.position = player_spot + Vector3(0.5, 0, -0.4)
	pet.player_pos = player_spot
	pet.face(player_spot + Vector3(0, 0, -3))
	pet.model.set_posture("sit")
	pet.state = "action"
	main.cam_rig.follow = false
	main.cam_rig.target = null
	main.cam_rig.focus = Vector3(0, 0.3, (throw_area.position.y + throw_area.end.y) * 0.5)
	main.cam_rig.reset_view(throw_area.size.y * 0.5 + 3.2, -0.42, 0.0)
	toy = PetController.make_toy(toy_id)
	main.world.add_child(toy)
	_reset_toy()
	if not free_mode:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in 3:
			var z := lerpf(throw_area.end.y - 1.5, throw_area.position.y + 0.8, (i + 0.5) / 3.0)
			var x := rng.randf_range(throw_area.position.x + 0.8, throw_area.end.x - 0.8)
			var pts: int = [50, 80, 120][i]
			targets.append({"pos": Vector3(x, 0, z), "pts": pts})
			var n := Node3D.new()
			n.position = Vector3(x, 0.02, z)
			main.world.add_child(n)
			WorldBuilder.torus(n, 0.85, 1.0, Vector3.ZERO, Color(1, 0.9, 0.3))
			WorldBuilder.torus(n, 0.4, 0.55, Vector3.ZERO, Color(1, 0.5, 0.35))
			var lbl := Label3D.new()
			lbl.text = "%d" % pts
			lbl.font_size = 96
			lbl.pixel_size = 0.004
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position = Vector3(0, 0.45, 0)
			lbl.modulate = Color(1, 1, 1)
			lbl.outline_size = 12
			n.add_child(lbl)
			target_nodes.append(n)
		big_hint(tr("Glissez vers le haut pour lancer !"), 1.4)
	else:
		big_hint(tr("Glissez vers le haut pour lancer !"), 1.4)

func _update_info() -> void:
	if free_mode:
		info_label.text = tr("Lancers : %d · Énergie : %d") % [throws_done, int(GameState.active_pet()["needs"]["energy"])]
	else:
		info_label.text = tr("Lancer %d/%d · Score : %d") % [mini(throws_done + 1, THROWS), THROWS, score]

func _reset_toy() -> void:
	if toy.get_parent() != main.world:
		if toy.get_parent():
			toy.get_parent().remove_child(toy)
		main.world.add_child(toy)
	toy.position = player_spot + Vector3(0, 0.9, 0)
	toy.visible = true
	_phase = "ready"

func handle_input(event: InputEvent) -> bool:
	if finished:
		return false
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed and _phase == "ready":
			_swiping = true
			_swipe_start = event.position
			_swipe_t = Time.get_ticks_msec()
			aim_line.points = PackedVector2Array([event.position, event.position])
		elif not event.pressed and _swiping:
			_swiping = false
			aim_line.points = PackedVector2Array()
			_throw(event.position - _swipe_start)
		return true
	if event is InputEventScreenDrag and event.index == 0 and _swiping:
		aim_line.points = PackedVector2Array([_swipe_start, event.position])
		return true
	return false

func _throw(swipe: Vector2) -> void:
	if swipe.y > -60.0:
		return
	var vp := main.get_viewport().get_visible_rect().size
	var power := clampf(swipe.length() / (vp.y * 0.55), 0.15, 1.0)
	var cam_basis := main.cam_rig.cam.global_transform.basis
	var fwd := -cam_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := cam_basis.x
	right.y = 0
	right = right.normalized()
	var dir2 := Vector2(swipe.x, -swipe.y).normalized()
	var dir := (fwd * dir2.y + right * dir2.x).normalized()
	var bonus := 1.0 + float(GameData.item(toy_id).get("bonus", 0)) / 100.0 * (0.5 if GameData.item(toy_id).get("toy", "") != "disc" else 1.0)
	var horiz := lerpf(2.5, 9.0, power) * minf(bonus, 1.15)
	vel = dir * horiz + Vector3(0, lerpf(3.0, 5.0, power), 0)
	toy.position = player_spot + Vector3(0, 0.9, 0)
	flying = true
	_landed = false
	_phase = "flying"
	_throw_t = 0.0
	Audio.play("whoosh")
	GameState.inc_stat("throw", 1)
	pet.model.expression = "focus"
	pet.model.set_posture("alert")
	pet.voice()

func _process(delta: float) -> void:
	if finished:
		return
	_throw_t += delta
	if flying:
		var drag := 0.25 if GameData.item(toy_id).get("toy", "") == "disc" else 0.0
		vel.y -= GRAVITY * (1.0 - drag) * delta
		toy.position += vel * delta
		toy.rotation.x += delta * 8.0
		if toy.position.y <= 0.06:
			toy.position.y = 0.06
			if not _landed:
				_landed = true
				_land_pos = toy.position
				if _phase == "flying":
					_send_pet()
			if absf(vel.y) > 1.2:
				vel.y = -vel.y * 0.45
				vel.x *= 0.6
				vel.z *= 0.6
				Audio.play("bounce", 0.1, -4.0)
			else:
				vel = Vector3.ZERO
				flying = false
		var a := throw_area.grow(2.0)
		if toy.position.x < a.position.x or toy.position.x > a.end.x or toy.position.z < a.position.y or toy.position.z > a.end.y:
			toy.position.x = clampf(toy.position.x, a.position.x, a.end.x)
			toy.position.z = clampf(toy.position.z, a.position.y, a.end.y)
			vel.x = -vel.x * 0.3
			vel.z = -vel.z * 0.3

func _send_pet() -> void:
	_phase = "chasing"
	var p := GameState.active_pet()
	var b := GameData.breed(p["breed"])
	var spd := (1.6 + float(b["stats"]["agility"]) / 100.0 * 1.6) * lerpf(0.55, 1.0, p["needs"]["energy"] / 100.0)
	_chase(spd)

func _chase(spd: float) -> void:
	if finished:
		return
	var tp := Vector3(toy.position.x, 0, toy.position.z)
	pet.walk_to(tp, spd, func():
		if flying and toy.position.distance_to(pet.position + Vector3(0, 0.06, 0)) > 0.35:
			_chase(spd)
			return
		flying = false
		pet.grab(toy)
		Audio.play("pop")
		_decide_return(spd))

func _decide_return(spd: float) -> void:
	var p := GameState.active_pet()
	var fetch_skill := GameState.skill("fetch") / 100.0
	var chance := 0.35 + fetch_skill * 0.55 + float(GameState.relation_level(p)) * 0.02 - float(p["traits"].get("independence", 50)) / 100.0 * 0.2
	if randf() < chance:
		_return(spd)
	else:
		_phase = "playing"
		pet.model.set_posture("lie")
		pet.model.chew = 1.0
		pet.model.emote("😜")
		call_btn.visible = true

func _call_back() -> void:
	if _phase != "playing":
		return
	call_btn.visible = false
	pet.model.chew = 0.0
	pet.model.emote("❗")
	_return(1.4)

func _return(spd: float) -> void:
	_phase = "returning"
	pet.walk_to(player_spot + Vector3(0, 0, -0.45), spd * 0.85, func():
		pet.face(player_spot)
		pet.drop_held()
		pet.model.set_posture("sit")
		pet.model.expression = "happy"
		pet.model.wag_amp = 0.9
		_round_done())

func _round_done() -> void:
	throws_done += 1
	GameState.change_need("energy", -3.0)
	GameState.change_need("mood", 3.0)
	GameState.change_need("thirst", -2.0)
	GameState.add_relation(2)
	var msg := ""
	if not free_mode:
		var best := 0.0
		for t in targets:
			var d: float = Vector2(_land_pos.x, _land_pos.z).distance_to(Vector2(t["pos"].x, t["pos"].z))
			var pts := 0.0
			if d < 0.5:
				pts = float(t["pts"])
			elif d < 1.0:
				pts = float(t["pts"]) * 0.5
			elif d < 1.8:
				pts = float(t["pts"]) * 0.15
			best = maxf(best, pts)
		var time_bonus := maxf(0.0, 9.0 - _throw_t) * 6.0
		var mult := 1.0 + float(GameData.item(toy_id).get("bonus", 0)) / 100.0
		var pts_total := int(round((best + time_bonus) * mult))
		score += pts_total
		msg = "+%d" % pts_total
		big_hint(msg, 0.8, UiKit.C_GOLD)
	_update_info()
	await get_tree().create_timer(0.6, false).timeout
	if finished:
		return
	if not free_mode and throws_done >= THROWS:
		_finish()
		return
	if free_mode and GameState.active_pet()["needs"]["energy"] < 12.0:
		big_hint(tr("%s est épuisé !") % pet_name(), 1.2)
		await get_tree().create_timer(1.2, false).timeout
		quit()
		return
	pet.drop_held()
	_reset_toy()

func _finish() -> void:
	var coins := int(score / 12.0)
	var xp := 20 + int(score / 20.0)
	Audio.play("success")
	if on_done.is_valid():
		finished = true
		on_done.call(clampf(score / 7.0, 0.0, 100.0))
		return
	show_results("🎾 " + tr("Fin de partie"), [tr("Score : %d points") % score], coins, xp)

func _on_quit() -> void:
	if free_mode and throws_done > 0:
		GameState.add_xp(throws_done * 2)

func _exit_tree() -> void:
	super._exit_tree()
	if toy and is_instance_valid(toy):
		if pet and pet.held == toy:
			pet.held = null
		toy.queue_free()
	for n in target_nodes:
		if is_instance_valid(n):
			n.queue_free()
