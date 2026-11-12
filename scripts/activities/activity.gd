class_name Activity
extends Node
## Base des activités : interface dédiée, sortie, écran de résultats.

var ui: Control
var top_label: Label
var info_label: Label
var main: Main
var pet: PetController
var finished := false
var on_done: Callable = Callable()   # utilisé par les concours : on_done.call(score)
var _fit_boxes: Array = []            # [conteneur, ancré en bas ?] : réduits s'ils dépassent de l'écran

## Réduit les barres de l'activité plus larges que l'écran (texte long, grande taille de police).
func fit(avail: float) -> void:
	for fb in _fit_boxes:
		var c: Control = fb[0]
		if not is_instance_valid(c):
			continue
		var need := c.get_combined_minimum_size().x
		var k := minf(1.0, avail / maxf(need, 1.0))
		c.pivot_offset = Vector2(0, c.size.y if fb[1] else 0.0)
		c.scale = Vector2(k, k)

func _ready() -> void:
	main = Main.inst
	pet = main.pet_ctrl
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.safe.add_child(ui)
	if pet:
		pet.interrupt()
		pet.busy = true
	_start()

func _exit_tree() -> void:
	if ui and is_instance_valid(ui):
		ui.queue_free()

func _start() -> void:
	pass

## L'activité autorise-t-elle le bouton de recentrage caméra ?
func can_recenter() -> bool:
	return false

func recenter() -> void:
	main.recenter_camera()

func handle_input(_event: InputEvent) -> bool:
	return false

## Barre du haut : titre + infos + bouton quitter.
func make_top(title: String, show_quit: bool = true) -> VBoxContainer:
	var v := UiKit.vbox(8)
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UiKit.hbox(10)
	var p := UiKit.panel(14)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pv := UiKit.vbox(2)
	top_label = UiKit.label(title, 32)
	top_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	top_label.clip_text = true
	top_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pv.add_child(top_label)
	info_label = UiKit.label("", 24, UiKit.C_SUB)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # textes longs : retour à la ligne, jamais hors écran
	pv.add_child(info_label)
	p.add_child(pv)
	h.add_child(p)
	if can_recenter():
		var rc := UiKit.button("[i:recenter]", func(): recenter(), UiKit.C_BLUE, 34, 90)
		rc.custom_minimum_size = Vector2(90, 90)
		rc.tooltip_text = tr("Recentrer la caméra")
		h.add_child(rc)
	if show_quit:
		var q := UiKit.button("[i:close]", quit, UiKit.C_DANGER, 34, 90)
		q.custom_minimum_size = Vector2(90, 90)
		h.add_child(q)
	v.add_child(h)
	ui.add_child(v)
	_fit_boxes.append([v, false])
	return v

func bottom_bar() -> HBoxContainer:
	var h := UiKit.hbox(10)
	h.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	h.grow_vertical = Control.GROW_DIRECTION_BEGIN
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	ui.add_child(h)
	_fit_boxes.append([h, true])
	return h

func big_hint(text: String, dur: float = 1.6, color: Color = Color.WHITE) -> void:
	var l := UiKit.label(text, 64, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0.3, 0.15, 0.05, 0.8))
	l.add_theme_constant_override("outline_size", 16)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.custom_minimum_size = Vector2(680, 0)
	l.position = Vector2(-340, -260)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(l)
	l.pivot_offset = Vector2(340, 40)
	var tw := l.create_tween()
	if not UiKit.reduce_motion():
		l.scale = Vector2(0.5, 0.5)
		tw.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)

func quit() -> void:
	if finished:
		main.end_activity()
		return
	finished = true
	_on_quit()
	if on_done.is_valid():
		on_done.call(0.0)
		return
	main.end_activity()

func _on_quit() -> void:
	pass

## Écran de résultats avec récompenses.
func show_results(title: String, lines: Array, coins: int, xp: int) -> void:
	finished = true
	if coins > 0:
		GameState.add_coins(coins)
		Audio.play("coin")
	if xp > 0:
		GameState.add_xp(xp)
	var v := UiKit.vbox(14)
	for l in lines:
		v.add_child(UiKit.label(str(l), 30))
	if coins > 0 or xp > 0:
		v.add_child(UiKit.label("[i:coin] +%d " % coins + tr("pièces") + "   ·   +%d " % xp + tr("pts d'expérience"), 36, UiKit.C_ACCENT))
	v.add_child(UiKit.button(tr("Continuer"), func():
		main.close_panel(), UiKit.C_ACCENT2, 32, 96))
	main.open_panel(title, v, func(): main.end_activity())
	GameState.save_game()

func pet_name() -> String:
	return str(GameState.active_pet().get("name", ""))

# ================================================================== Soins (bain, brossage)
## Caméra de soin : un doigt sur l'animal = frotter, un doigt à côté = tourner autour,
## deux doigts = zoom. Les boutons de zone placent la caméra face à la partie choisie.
var _care_mode := ""
var _care_touches := {}
var _care_pinch := 0.0
var _care_saved_offset := Vector3.ZERO
var _care_zone_btns := {}

## Place l'animal dans un endroit dégagé pour que la caméra puisse tourner tout autour.
func care_setup() -> void:
	if pet == null:
		return
	var b: Rect2 = pet.bounds
	var c := b.get_center()
	var want := Vector2(lerpf(pet.position.x, c.x, 0.7), lerpf(pet.position.z, c.y, 0.7))
	if main.nav:
		want = main.nav.nearest_free(want)
	pet.position = Vector3(want.x, 0, want.y)
	pet.model.set_leg_hit(true)
	_care_saved_offset = main.cam_rig.focus_offset

func care_teardown() -> void:
	if pet and is_instance_valid(pet) and pet.model:
		pet.model.set_leg_hit(false)

## Panneau des zones : bouton (vue de la zone) + barre de progression. Renvoie {zone: ProgressBar}.
func care_zone_panel(zones: Dictionary, col: Color) -> Dictionary:
	var bars := {}
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for z in zones.keys():
		var cell := UiKit.vbox(4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var zz: String = z
		var btn := UiKit.button("[i:recenter] " + tr(zones[z]), func(): care_view(zz), UiKit.C_BLUE, 22, 62)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_care_zone_btns[z] = btn
		cell.add_child(btn)
		var bar := UiKit.bar(0, col, 16)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(bar)
		bars[z] = bar
		grid.add_child(cell)
	var box := UiKit.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	return {"grid": box, "bars": bars}

## Oriente la caméra pour bien voir une zone du corps.
func care_view(zone: String) -> void:
	var r := main.cam_rig
	var m := pet.model
	var fy := pet.rotation.y
	var top := m.top_height()
	r.fixed_transform = null
	r.follow = true
	r.screen_shift = 0.22
	match zone:
		"head":
			r.yaw = fy + 0.45
			r.pitch = -0.22
			r.focus_offset = Vector3(0, top * 0.62, 0) + Vector3(sin(fy), 0, cos(fy)) * m.body_length() * 0.3
		"back":
			r.yaw = fy + PI * 0.5 + 0.2
			r.pitch = -0.95
			r.focus_offset = Vector3(0, top * 0.45, 0)
		"legs":
			r.yaw = fy + PI * 0.5 - 0.15
			r.pitch = -0.08
			r.focus_offset = Vector3(0, top * 0.22, 0)
		"tail":
			r.yaw = fy + PI - 0.45
			r.pitch = -0.32
			r.focus_offset = Vector3(0, top * 0.4, 0) - Vector3(sin(fy), 0, cos(fy)) * m.body_length() * 0.3
	# assez de recul pour laisser de la place autour de l'animal (glisser à côté = tourner)
	r.distance = clampf(r.fit_distance(top, m.body_length() * 0.9, 0.48), r.min_dist, r.max_dist)
	Audio.play("click", 0.05, -8.0)

## Tourne la caméra d'un huitième de tour autour de l'animal.
func care_rotate(dir: float) -> void:
	main.cam_rig.yaw += dir * PI * 0.25
	Audio.play("click", 0.05, -10.0)

## Gère les gestes de soin. on_rub(event, hit) est appelé pour chaque glissement sur l'animal.
func care_input(event: InputEvent, on_rub: Callable) -> bool:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_care_touches[e.index] = e.position
			if _care_touches.size() >= 2:
				var ps: Array = _care_touches.values()
				_care_pinch = (ps[0] as Vector2).distance_to(ps[1])
				_care_mode = "pinch"
				return true
			if e.index == 0:
				var hit := main.raycast(e.position, 2)
				_care_mode = "rub" if not hit.is_empty() else "orbit"
		else:
			_care_touches.erase(e.index)
			if _care_touches.is_empty():
				_care_mode = ""
		return true
	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_care_touches[d.index] = d.position
		match _care_mode:
			"pinch":
				if _care_touches.size() >= 2:
					var ps2: Array = _care_touches.values()
					var nd := (ps2[0] as Vector2).distance_to(ps2[1])
					if _care_pinch > 10.0:
						main.cam_rig.zoom(_care_pinch / maxf(nd, 1.0))
					_care_pinch = nd
			"orbit":
				if d.index == 0:
					var k := float(GameState.setting("sensitivity")) if GameState.data.has("settings") else 1.0
					main.cam_rig.yaw -= d.relative.x * 0.006 * k
					main.cam_rig.pitch = clampf(main.cam_rig.pitch - d.relative.y * 0.004 * k, -1.2, -0.03)
			"rub":
				if d.index == 0:
					var hit2 := main.raycast(d.position, 2)
					if not hit2.is_empty():
						on_rub.call(d, hit2)
		return true
	return false

## Zone du corps touchée (tête, dos, pattes et ventre, queue).
func care_zone(hit: Dictionary) -> String:
	var col: Object = hit.get("collider")
	if col and col.has_meta("zone"):
		return str(col.get_meta("zone"))
	if main.hit_part(hit) == "head":
		return "head"
	var lp: Vector3 = pet.model.to_local(hit["position"])
	if lp.z < -pet.model.bz * 0.36:
		return "tail"
	if lp.y < pet.model.L + pet.model.hy * 0.3 + pet.model.by * 0.15:
		return "legs"
	return "back"
