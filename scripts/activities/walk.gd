class_name WalkActivity
extends Activity
## Promenade : on guide l'animal (joystick virtuel ou toucher au sol),
## on ramasse des trouvailles, on renifle des pistes et on rencontre d'autres animaux.

const DURATION := 150.0

var area := Rect2(-6, -6, 12, 10)
var items: Array[Dictionary] = []
var npcs: Array[PetController] = []
var met: Array[int] = []
var time_left := DURATION
var collected := 0
var coins := 0
var joy_base := Vector2.ZERO
var joy_vec := Vector2.ZERO
var joy_active := false
var joy_ui: Control
var joy_knob: Control
var _drink_cd := 0.0

func _start() -> void:
	area = main.env_root.get_meta("walk_area", Rect2(-6, -6, 12, 10))
	make_top("🚶 " + tr("Promenade · %s") % tr(GameData.ENVIRONMENTS[main.env_id]["name"]))
	var bb := bottom_bar()
	bb.add_child(UiKit.button("🏠 " + tr("Rentrer"), quit, UiKit.C_ACCENT2, 28, 90))
	joy_ui = Control.new()
	joy_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_ui.visible = false
	ui.add_child(joy_ui)
	var base := Panel.new()
	base.add_theme_stylebox_override("panel", UiKit.sb(Color(1, 1, 1, 0.3), 90, 4, Color(1, 1, 1, 0.7), false, 0))
	base.size = Vector2(180, 180)
	base.position = Vector2(-90, -90)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_ui.add_child(base)
	joy_knob = Panel.new()
	joy_knob.add_theme_stylebox_override("panel", UiKit.sb(Color(1, 1, 1, 0.85), 40, 0, Color.TRANSPARENT, true, 0))
	joy_knob.size = Vector2(80, 80)
	joy_knob.position = Vector2(-40, -40)
	joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_ui.add_child(joy_knob)
	pet.bounds = area
	pet.position = Vector3(area.get_center().x, 0, area.end.y - 1.0)
	pet.state = "idle"
	main.cam_rig.target = pet
	main.cam_rig.follow = true
	main.cam_rig.reset_view(4.2, -0.5, 0.0)
	# Trouvailles
	var finds: Array = GameData.WALK_FINDS.get(main.env_id, GameData.WALK_FINDS["park"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 9:
		var p := Vector3(rng.randf_range(area.position.x + 0.5, area.end.x - 0.5), 0, rng.randf_range(area.position.y + 0.5, area.end.y - 0.5))
		var kind := "find" if i < 6 else "scent"
		var f: Array = finds[rng.randi() % finds.size()]
		items.append({"pos": p, "kind": kind, "icon": f[0], "name": f[1], "node": _make_item(p, kind, f[0]), "taken": false})
	# Autres animaux
	for i in 2:
		var breed: String = GameData.BREED_ORDER[rng.randi() % GameData.BREED_ORDER.size()]
		var bd := GameData.breed(breed)
		var np := GameState.sanitize_pet({"breed": breed, "palette": rng.randi() % bd["palettes"].size(), "eyes": rng.randi() % 5,
			"collar": ["collar_blue", "collar_green", "collar_red"][i % 3], "name": GameData.RIVAL_NAMES[rng.randi() % GameData.RIVAL_NAMES.size()]})
		var p2 := Vector3(rng.randf_range(area.position.x + 1, area.end.x - 1), 0, rng.randf_range(area.position.y + 1, area.get_center().y))
		var c := main.add_extra_pet(np, p2)
		c.bounds = Rect2(p2.x - 2, p2.z - 2, 4, 4)
		npcs.append(c)
	GameState.change_need("mood", 5.0)

func _make_item(p: Vector3, kind: String, icon: String) -> Node3D:
	var n := Node3D.new()
	n.position = p
	main.world.add_child(n)
	var l := Label3D.new()
	l.text = icon if kind == "find" else "✨"
	l.font = UiKit.emoji_font()
	l.font_size = 96
	l.pixel_size = 0.003
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 0.35, 0)
	l.outline_size = 0
	n.add_child(l)
	var ring := WorldBuilder.torus(n, 0.18, 0.24, Vector3(0, 0.02, 0), Color(1, 0.9, 0.4) if kind == "find" else Color(0.8, 0.9, 1.0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "position:y", 0.45, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "position:y", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	return n

func handle_input(event: InputEvent) -> bool:
	if finished:
		return false
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			joy_active = true
			joy_base = event.position
			joy_vec = Vector2.ZERO
			joy_ui.position = joy_base
			joy_ui.visible = true
			joy_knob.position = Vector2(-40, -40)
		else:
			joy_active = false
			joy_ui.visible = false
			if joy_vec.length() < 0.15:
				var gp: Variant = main.ground_point(event.position)
				if gp is Vector3:
					pet.walk_to(gp, 1.1)
			else:
				pet.stop_moving()
			joy_vec = Vector2.ZERO
		return true
	if event is InputEventScreenDrag and event.index == 0 and joy_active:
		var d: Vector2 = event.position - joy_base
		joy_vec = d.limit_length(90.0) / 90.0
		joy_knob.position = joy_vec * 90.0 - Vector2(40, 40)
		return true
	return false

func _process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	_drink_cd = maxf(0.0, _drink_cd - delta)
	info_label.text = tr("⏱ %d s · Trouvailles : %d · 🪙 %d") % [int(time_left), collected, coins]
	if joy_active and joy_vec.length() > 0.15:
		var basis := main.cam_rig.cam.global_transform.basis
		var fwd := -basis.z
		fwd.y = 0
		var right := basis.x
		right.y = 0
		var dir := (right.normalized() * joy_vec.x - fwd.normalized() * joy_vec.y)
		var spd := 0.6 + joy_vec.length() * 1.6
		pet.walk_to(pet.position + dir.normalized() * 0.6, spd)
	# Ramassage
	for it in items:
		if it["taken"]:
			continue
		if pet.position.distance_to(it["pos"]) < 0.45:
			it["taken"] = true
			_collect(it)
	# Rencontres
	for i in npcs.size():
		var c := npcs[i]
		if not met.has(i) and pet.position.distance_to(c.position) < 0.8:
			met.append(i)
			_meet(c)
	# Fontaine
	var f: Variant = main.env_root.get_meta("fountain", null)
	if f is Vector3 and _drink_cd <= 0.0 and pet.position.distance_to(f) < 0.8:
		_drink_cd = 30.0
		GameState.change_need("thirst", 40.0)
		pet.model.emote("💧")
		Audio.play("lap")
		main.toast(tr("%s se désaltère à la fontaine.") % pet_name())
	if time_left <= 0.0:
		_finish()

func _collect(it: Dictionary) -> void:
	var n: Node3D = it["node"]
	if it["kind"] == "find":
		collected += 1
		coins += 6
		GameState.add_find(it["icon"], it["name"])
		Audio.play("coin", 0.05, -4.0)
		main.toast("%s %s !" % [it["icon"], tr(it["name"])])
	else:
		pet.stop_moving()
		pet.sniff_ground()
		coins += 4
		GameState.change_need("mood", 3.0)
		Audio.play("sniff")
	if is_instance_valid(n):
		var tw := n.create_tween()
		tw.tween_property(n, "scale", Vector3.ZERO, 0.25)
		tw.tween_callback(n.queue_free)

func _meet(c: PetController) -> void:
	pet.stop_moving()
	pet.face(c.position)
	c.stop_moving()
	c.face(pet.position)
	c.play_bow()
	pet.play_bow()
	c.voice()
	pet.model.emote("❤️")
	c.model.emote("❤️")
	coins += 10
	GameState.change_need("mood", 8.0)
	GameState.change_need("affection", 4.0)
	main.toast(tr("%s a rencontré %s ! Ils jouent ensemble.") % [pet_name(), c.pet.get("name", "?")])

func _finish() -> void:
	if finished:
		return
	finished = true
	pet.stop_moving()
	GameState.inc_stat("walk", 1)
	GameState.change_need("energy", -15.0)
	GameState.change_need("hunger", -8.0)
	GameState.change_need("thirst", -10.0)
	GameState.change_need("clean", -12.0 if main.env_id in ["beach", "garden"] else -6.0)
	GameState.change_need("mood", 10.0)
	GameState.add_relation(15)
	show_results("🚶 " + tr("Belle promenade !"), [
		tr("Trouvailles : %d") % collected, tr("Rencontres : %d") % met.size(),
		tr("%s est ravi, mais un peu sale…") % pet_name()], coins + 10, 25 + collected * 3)

func quit() -> void:
	if not finished:
		_finish()
	else:
		main.end_activity()

func _exit_tree() -> void:
	super._exit_tree()
	for it in items:
		var n: Variant = it["node"]
		if is_instance_valid(n):
			(n as Node).queue_free()
	if main:
		main._clear_extra_pets()
