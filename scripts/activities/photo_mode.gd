class_name PhotoMode
extends Activity
## Mode photo : cadrage libre (glisser = tourner, pincer = zoomer), choix de la pose,
## de l'expression, d'un accessoire et d'un décor, interface masquable, sauvegarde dans l'album.

const POSES := [["stand", "Debout"], ["sit", "Assis"], ["lie", "Couché"], ["beg", "Fais le beau"], ["paw", "La patte"], ["bow", "Joueur"], ["sleep", "Dodo"]]
const EXPRS := [["happy", "Content"], ["neutral", "Calme"], ["closed", "Yeux fermés"], ["tongue", "Langue"]]
const DECOS := [["none", "Aucun"], ["hearts", "Cœurs"], ["stars", "Étoiles"], ["polaroid", "Polaroïd"]]

var deco_layer: CanvasLayer
var deco_root: Control
var panel_box: Control
var hide_btn: Button
var _touches := {}
var _pinch := 0.0
var deco := "none"

func _start() -> void:
	make_top("[i:camera] " + tr("Mode photo"))
	info_label.text = tr("Glissez pour tourner, pincez pour zoomer.")
	deco_layer = CanvasLayer.new()
	deco_layer.layer = 0
	add_child(deco_layer)
	deco_root = Control.new()
	deco_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deco_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco_layer.add_child(deco_root)
	var bb := bottom_bar()
	var pv := UiKit.panel(12)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box = pv
	var v := UiKit.vbox(6)
	v.add_child(_chips(tr("Pose"), POSES, func(k): _pose(k)))
	v.add_child(_chips(tr("Expression"), EXPRS, func(k): _expr(k)))
	v.add_child(_chips(tr("Décor"), DECOS, func(k): _deco(k)))
	var acc := HFlowContainer.new()
	acc.add_theme_constant_override("h_separation", 6)
	for id in GameState.data["owned"]:
		var it := GameData.item(id)
		if it.get("cat", "") == "accessory":
			var iid: String = id
			var b := UiKit.icon_button(it["icon"], tr(it["name"]), func(): GameState.equip("accessory", iid), Color(1, 1, 1, 0.95), 74)
			acc.add_child(b)
	v.add_child(acc)
	var h := UiKit.hbox(10)
	hide_btn = UiKit.button("[i:motion] " + tr("Masquer"), _toggle_ui, UiKit.C_BLUE, 24, 80)
	h.add_child(UiKit.expand(hide_btn))
	h.add_child(UiKit.expand(UiKit.button("[i:camera] " + tr("Photo !"), _shoot, UiKit.C_ACCENT, 28, 80)))
	v.add_child(h)
	pv.add_child(v)
	bb.add_child(pv)
	pet.stop_moving()
	pet.state = "action"
	main.recenter_camera(0.35)
	pet.face(main.cam_rig.player_ground_pos())

func can_recenter() -> bool:
	return true

func recenter() -> void:
	main.recenter_camera(0.35)

func _chips(title: String, list: Array, cb: Callable) -> Control:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	var l := UiKit.label(title, 20, UiKit.C_SUB)
	l.custom_minimum_size = Vector2(110, 0)
	f.add_child(l)
	for e in list:
		var k: String = e[0]
		f.add_child(UiKit.button(tr(e[1]), func(): cb.call(k), UiKit.C_ACCENT2, 18, 52))
	return f

func _pose(k: String) -> void:
	pet.model.set_posture(k, 4.0)
	pet.model.expression = "closed" if k == "sleep" else pet.model.expression

func _expr(k: String) -> void:
	pet.model.tongue_out = 1.0 if k == "tongue" else 0.0
	pet.model.expression = "happy" if k == "tongue" else k

func _deco(k: String) -> void:
	deco = k
	for c in deco_root.get_children():
		c.queue_free()
	var vp := main.get_viewport().get_visible_rect().size
	match k:
		"hearts", "stars":
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 14:
				var edge := rng.randi() % 4
				var p := Vector2(rng.randf() * vp.x, rng.randf() * vp.y)
				match edge:
					0: p.y = rng.randf_range(10, 120)
					1: p.y = vp.y - rng.randf_range(60, 160)
					2: p.x = rng.randf_range(10, 90)
					3: p.x = vp.x - rng.randf_range(60, 140)
				var r := UiKit.icon_rect("heart" if k == "hearts" else "star", rng.randi_range(40, 80))
				r.position = p
				r.rotation = rng.randf_range(-0.4, 0.4)
				r.modulate.a = 0.85
				deco_root.add_child(r)
		"polaroid":
			var fr := Panel.new()
			fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0, 0, 0, 0)
			st.border_color = Color(1, 1, 1)
			st.set_border_width_all(30)
			st.border_width_bottom = 170
			fr.add_theme_stylebox_override("panel", st)
			fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			deco_root.add_child(fr)
			var l := UiKit.label("%s · %s" % [pet_name(), GameState.today()], 40, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
			l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			l.offset_top = -130
			l.offset_bottom = -60
			deco_root.add_child(l)

func _toggle_ui() -> void:
	ui.visible = not ui.visible
	if not ui.visible:
		main.toast(tr("Touchez l'écran pour réafficher l'interface."))

func _shoot() -> void:
	ui.visible = false
	main.take_photo(func(_nm):
		ui.visible = true
		main.toast(tr("Photo ajoutée à l'album !")))

func handle_input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if not ui.visible and _touches.size() == 1:
				ui.visible = true
		else:
			_touches.erase(event.index)
		if _touches.size() == 2:
			var ps: Array = _touches.values()
			_pinch = (ps[0] as Vector2).distance_to(ps[1])
		return true
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var ps2: Array = _touches.values()
			var nd := (ps2[0] as Vector2).distance_to(ps2[1])
			if _pinch > 10.0:
				main.cam_rig.zoom(_pinch / maxf(nd, 1.0))
			_pinch = nd
		elif event.index == 0:
			main.cam_rig.orbit(event.relative.x, event.relative.y)
		return true
	return false

func _exit_tree() -> void:
	super._exit_tree()
	if pet:
		pet.model.tongue_out = 0.0
