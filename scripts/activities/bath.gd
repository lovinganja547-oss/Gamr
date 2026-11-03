class_name BathActivity
extends Activity
## Bain : frotter l'animal pour faire mousser, puis rincer.

var tub: Node3D
var progress := 0.0
var bar: ProgressBar
var rinse_btn: Button
var shampoo_btn: Button
var bubbles: Array[Node3D] = []
var _rubbing := false
var _acc := 0.0
var shampoo := false
var _rinsing := false

func _start() -> void:
	make_top("🛁 " + tr("Bain de %s") % pet_name())
	info_label.text = tr("Frottez votre compagnon du bout du doigt pour faire mousser !")
	var bb := bottom_bar()
	var pv := UiKit.panel(14)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vv := UiKit.vbox(8)
	bar = UiKit.bar(0, Color(0.55, 0.85, 0.95), 30)
	vv.add_child(UiKit.label(tr("Mousse"), 24, UiKit.C_SUB))
	vv.add_child(bar)
	var h := UiKit.hbox(10)
	shampoo_btn = UiKit.button("🧴 " + tr("Shampooing (×%d)") % GameState.item_count("shampoo"), _use_shampoo, UiKit.C_BLUE, 24, 80)
	shampoo_btn.disabled = GameState.item_count("shampoo") <= 0
	h.add_child(UiKit.expand(shampoo_btn))
	rinse_btn = UiKit.button("🚿 " + tr("Rincer"), _rinse, UiKit.C_ACCENT2, 26, 80)
	rinse_btn.disabled = true
	h.add_child(UiKit.expand(rinse_btn))
	vv.add_child(h)
	pv.add_child(vv)
	bb.add_child(pv)
	# Baquet autour de l'animal
	tub = Node3D.new()
	tub.position = pet.position
	main.world.add_child(tub)
	WorldBuilder.cyl(tub, 0.62, 0.7, 0.32, Vector3(0, 0.16, 0), Color(0.6, 0.78, 0.95), 24)
	var water := WorldBuilder.cyl(tub, 0.6, 0.6, 0.02, Vector3(0, 0.25, 0), Color(0.75, 0.9, 1.0), 24)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WorldBuilder.torus(tub, 0.6, 0.7, Vector3(0, 0.32, 0), Color(0.95, 0.95, 1.0))
	pet.face(pet.player_pos)
	pet.model.set_posture("sit", 3.0)
	pet.state = "action"
	pet.model.expression = "neutral"
	main.cam_rig.reset_view(2.0, -0.35, main.cam_rig.yaw)
	Audio.play("splash")

func handle_input(event: InputEvent) -> bool:
	if finished or _rinsing:
		return false
	if event is InputEventScreenTouch and event.index == 0:
		_rubbing = event.pressed
		return true
	if event is InputEventScreenDrag and event.index == 0 and _rubbing:
		var hit := main.raycast(event.position, 2)
		if not hit.is_empty():
			_acc += event.relative.length()
			if _acc > 45.0:
				_acc = 0.0
				_add_bubble(hit["position"])
				var gain := 2.2 * (1.5 if shampoo else 1.0)
				progress = minf(100.0, progress + gain)
				bar.value = progress
				if randf() < 0.25:
					Audio.play("bubble", 0.1, -8.0)
				if randf() < 0.1:
					pet.model.expression = "happy"
					pet.model.wag_amp = 0.6
				if progress >= 60.0:
					rinse_btn.disabled = false
		return true
	return false

func _add_bubble(p: Vector3) -> void:
	if bubbles.size() > 70:
		return
	var b := WorldBuilder.ball(main.world, randf_range(0.04, 0.08), p + Vector3(randf_range(-0.04, 0.04), 0.02, randf_range(-0.04, 0.04)), Color(1, 1, 1), Vector3.ONE, 8)
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.scale = Vector3.ONE * 0.2
	b.create_tween().tween_property(b, "scale", Vector3.ONE * randf_range(0.8, 1.3), 0.15)
	bubbles.append(b)

func _use_shampoo() -> void:
	if shampoo or not GameState.consume("shampoo"):
		return
	shampoo = true
	shampoo_btn.disabled = true
	shampoo_btn.text = "🧴 " + tr("Shampooing actif")
	Audio.play("chime")

func _rinse() -> void:
	_rinsing = true
	rinse_btn.disabled = true
	Audio.play("splash")
	var tw := create_tween()
	for b in bubbles:
		if is_instance_valid(b):
			tw.parallel().tween_property(b, "scale", Vector3.ZERO, 0.6)
	await tw.finished
	for b in bubbles:
		if is_instance_valid(b):
			b.queue_free()
	bubbles.clear()
	pet.state = "idle"
	pet.shake_off()
	await get_tree().create_timer(1.0, false).timeout
	var q := progress / 100.0
	GameState.bath_done(q)
	if shampoo:
		GameState.change_need("clean", 20.0)
	pet.model.emote("✨")
	show_results("🛁 " + tr("Tout propre !"), [tr("%s sent bon la rose.") % pet_name(), tr("Propreté : %d") % int(GameState.active_pet()["needs"]["clean"])], 5, 0)

func _exit_tree() -> void:
	super._exit_tree()
	for b in bubbles:
		if is_instance_valid(b):
			b.queue_free()
	if tub and is_instance_valid(tub):
		tub.queue_free()
