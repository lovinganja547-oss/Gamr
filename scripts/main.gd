class_name Main
extends Node
## Point d'entrée : monde 3D, caméra, écrans, panneaux, entrées tactiles, photos.

static var inst: Main

var world: Node3D
var env_root: Node3D
var env_id := ""
var lighting: Node3D
var nav: NavGrid
var cam_rig: CameraRig
var pet_ctrl: PetController
var extra_pets: Array[PetController] = []
var ui_layer: CanvasLayer
var ui_root: Control
var safe: MarginContainer
var screen: Control
var screen_name := ""
var panel_stack: Array[Control] = []
var toast_box: VBoxContainer
var activity: Node = null
var quality := 1
var input_enabled := true

# Entrées tactiles
var _touches := {}
var _press_pos := Vector2.ZERO
var _press_t := 0
var _drag_kind := ""
var _drag_part := ""
var _stroke_acc := 0.0
var _pinch_d := 0.0
var _moved := 0.0

func _ready() -> void:
	inst = self
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	TranslationServer.set_locale(str(GameState.setting("locale")))
	quality = int(GameState.setting("quality"))
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	cam_rig = CameraRig.new()
	world.add_child(cam_rig)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.theme = UiKit.theme()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)
	safe = MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(safe)
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_box.position = Vector2(-330, 170)
	toast_box.custom_minimum_size = Vector2(660, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(toast_box)
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()
	GameState.toast.connect(toast)
	GameState.level_up.connect(func(_l): Audio.play("levelup"))
	GameState.achievement_unlocked.connect(func(_id): Audio.play("success", 0.0, -2.0))
	GameState.pet_changed.connect(_on_pet_changed)
	apply_quality(quality)
	Audio.apply_volumes()
	change_env("shelter")
	show_screen("title")

func _update_safe_area() -> void:
	var vp := get_viewport().get_visible_rect().size
	var win := DisplayServer.window_get_size()
	var sa := DisplayServer.get_display_safe_area()
	var top := 0.0
	var bottom := 0.0
	var left := 0.0
	var right := 0.0
	if OS.has_feature("mobile") and win.x > 0 and win.y > 0:
		var k := vp.y / float(win.y)
		top = maxf(0.0, sa.position.y) * k
		bottom = maxf(0.0, win.y - sa.end.y) * k
		left = maxf(0.0, sa.position.x) * k
		right = maxf(0.0, win.x - sa.end.x) * k
	safe.add_theme_constant_override("margin_top", int(top) + 12)
	safe.add_theme_constant_override("margin_bottom", int(bottom) + 12)
	safe.add_theme_constant_override("margin_left", int(left) + 12)
	safe.add_theme_constant_override("margin_right", int(right) + 12)

# ================================================================== Qualité graphique
func apply_quality(q: int) -> void:
	quality = clampi(q, 0, 2)
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	vp.scaling_3d_scale = [0.75, 0.9, 1.0][quality]
	Engine.max_fps = [30, 45, 60][quality]
	if env_id != "":
		var e := env_id
		env_id = ""
		change_env(e)

# ================================================================== Monde
func change_env(id: String, keep_pet_pos: bool = false) -> void:
	if id == env_id:
		return
	env_id = id
	if env_root:
		env_root.queue_free()
	if lighting:
		lighting.queue_free()
	env_root = WorldBuilder.build(id, quality)
	world.add_child(env_root)
	nav = WorldBuilder.make_nav(env_root)
	lighting = WorldBuilder.make_lighting(env_root, quality)
	world.add_child(lighting)
	var e: Dictionary = GameData.ENVIRONMENTS.get(id, {})
	Audio.ambience(str(e.get("amb", "")))
	GameState._outdoor = not env_root.get_meta("indoor", false) and id != "shelter"
	_clear_extra_pets()
	if id != "shelter":
		spawn_pet(keep_pet_pos)
	elif pet_ctrl:
		pet_ctrl.visible = false
	cam_rig.reset_view(3.2, -0.32, 0.0)
	cam_rig.bounds_box = env_root.get_meta("cam_box", AABB())
	cam_rig.obstacles = env_root.get_meta("obstacles", []).filter(func(o): return o.has("c") and float(o["r"]) >= 0.6 and bool(o.get("cam", true)))
	cam_rig.follow = true
	cam_rig.focus_offset = Vector3(0, 0.3, 0)
	if pet_ctrl and pet_ctrl.visible:
		cam_rig.frame_pet(pet_ctrl, pet_ctrl.model.top_height(), pet_ctrl.model.body_length(), 0.22, -0.3)
		cam_rig.distance = maxf(cam_rig.distance, 2.4)
	cam_rig.snap()

func rebuild_env() -> void:
	var e := env_id
	env_id = ""
	change_env(e, true)

func spawn_pet(keep_pos: bool = false) -> void:
	var p := GameState.active_pet()
	if p.is_empty():
		if pet_ctrl:
			pet_ctrl.visible = false
		return
	var old_pos := Vector3.ZERO
	if pet_ctrl and keep_pos:
		old_pos = pet_ctrl.position
	if pet_ctrl == null or pet_ctrl.pet.get("id", "") != p["id"] or pet_ctrl.model.quality != quality:
		if pet_ctrl:
			pet_ctrl.queue_free()
		pet_ctrl = PetController.new()
		pet_ctrl.name = "Pet"
		world.add_child(pet_ctrl)
		pet_ctrl.setup(p, quality)
	pet_ctrl.pet = p
	pet_ctrl.visible = true
	pet_ctrl.busy = false
	pet_ctrl.bounds = env_root.get_meta("bounds", Rect2(-2.5, -2, 5, 4.5))
	pet_ctrl.env_meta = {}
	for k in ["bed", "bowl_food", "bowl_water", "fountain"]:
		if env_root.has_meta(k):
			pet_ctrl.env_meta[k] = env_root.get_meta(k)
	pet_ctrl.nav = nav
	pet_ctrl.position = old_pos if keep_pos else Vector3(0, 0, 0.2)
	var fp := nav.nearest_free(Vector2(pet_ctrl.position.x, pet_ctrl.position.z))
	pet_ctrl.position = Vector3(fp.x, 0, fp.y)
	pet_ctrl.rotation.y = 0.0
	pet_ctrl._yaw_target = 0.0
	pet_ctrl.state = "idle"
	pet_ctrl.sleeping = false
	GameState.pet_sleeping = false
	pet_ctrl.player_pos = Vector3(0, 0, 2.2)
	cam_rig.target = pet_ctrl

func _on_pet_changed() -> void:
	var p := GameState.active_pet()
	if p.is_empty() or env_id == "shelter":
		return
	if pet_ctrl and pet_ctrl.pet.get("id", "") == p["id"]:
		pet_ctrl.pet = p
		pet_ctrl.refresh_look()
	else:
		spawn_pet(false)

## Recentre la caméra sur l'animal actif, distance adaptée à sa taille (transition douce).
func recenter_camera(shift: float = 0.0) -> void:
	if pet_ctrl == null or not pet_ctrl.visible:
		return
	var m := pet_ctrl.model
	cam_rig.frame_pet(pet_ctrl, m.top_height(), m.body_length(), shift, clampf(cam_rig.pitch, -0.6, -0.15))
	Audio.play("click", 0.05, -8.0)

func _clear_extra_pets() -> void:
	for c in extra_pets:
		if is_instance_valid(c):
			c.queue_free()
	extra_pets.clear()

func add_extra_pet(p: Dictionary, pos: Vector3) -> PetController:
	var c := PetController.new()
	world.add_child(c)
	c.setup(p if p.has("needs") and p.has("traits") else GameState.sanitize_pet(p), quality)
	c.position = pos
	c.bounds = Rect2(pos.x - 0.6, pos.z - 0.5, 1.2, 1.0)
	extra_pets.append(c)
	return c

var _fit_t := 0.0

func _process(delta: float) -> void:
	if pet_ctrl and pet_ctrl.visible and cam_rig.cam:
		pet_ctrl.player_pos = cam_rig.player_ground_pos()
	_fit_t -= delta
	if _fit_t <= 0.0:
		_fit_t = 0.25
		_fit_ui()

## Garantit que chaque interface tient à l'écran : si son contenu est plus large ou plus haut que
## l'écran (nom très long, grande taille de texte, écran étroit), elle est réduite d'un bloc.
func _fit_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	_fit_one(safe, vp)
	if activity and is_instance_valid(activity) and activity.has_method("fit"):
		var sc := safe.scale.x
		activity.fit(vp.x / maxf(sc, 0.01) - float(safe.get_theme_constant("margin_left") + safe.get_theme_constant("margin_right")))
		var sub_a: Variant = activity.get("sub")
		if sub_a is Activity and is_instance_valid(sub_a):
			(sub_a as Activity).fit(vp.x / maxf(sc, 0.01) - float(safe.get_theme_constant("margin_left") + safe.get_theme_constant("margin_right")))
	for ov in panel_stack:
		if is_instance_valid(ov) and ov.get_child_count() > 0:
			_fit_one(ov.get_child(0) as Control, vp)

func _fit_one(c: Control, vp: Vector2) -> void:
	if c == null:
		return
	var need := c.get_combined_minimum_size()
	var k := minf(1.0, minf(vp.x / maxf(need.x, 1.0), vp.y / maxf(need.y, 1.0)))
	if k < 0.999:
		c.set_anchors_preset(Control.PRESET_TOP_LEFT)
		c.scale = Vector2(k, k)
		c.position = Vector2.ZERO
		c.size = vp / k
	elif c.scale.x < 0.999:
		c.scale = Vector2.ONE
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# ================================================================== Écrans et panneaux
func show_screen(nm: String, args: Dictionary = {}) -> void:
	close_all_panels()
	if screen:
		screen.queue_free()
		screen = null
	screen_name = nm
	var s: Control
	match nm:
		"title": s = TitleScreen.new()
		"adopt": s = AdoptScreen.new()
		"home": s = HomeHud.new()
		_: s = HomeHud.new()
	s.set_meta("args", args)
	safe.add_child(s)
	screen = s

func open_panel(title: String, content: Control, on_close: Callable = Callable()) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.15, 0.08, 0.02, 0.35)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(overlay)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, safe.get_theme_constant(k) + 6)
	m.add_theme_constant_override("margin_top", safe.get_theme_constant("margin_top") + 110)
	m.add_theme_constant_override("margin_bottom", safe.get_theme_constant("margin_bottom") + 6)
	overlay.add_child(m)
	var pnl := UiKit.panel(26)
	m.add_child(pnl)
	var v := UiKit.vbox(16)
	pnl.add_child(v)
	var head := UiKit.hbox()
	var t := UiKit.label(title, 40, UiKit.C_TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := UiKit.button("[i:close]", func(): close_panel(), UiKit.C_DANGER, 34, 80)
	close.custom_minimum_size = Vector2(80, 80)
	head.add_child(close)
	v.add_child(head)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(content)
	overlay.set_meta("on_close", on_close)
	panel_stack.append(overlay)
	if not UiKit.reduce_motion():
		pnl.pivot_offset = Vector2(330, 600)
		pnl.scale = Vector2(0.92, 0.92)
		pnl.modulate.a = 0.0
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pnl, "scale", Vector2.ONE, 0.22)
		tw.tween_property(pnl, "modulate:a", 1.0, 0.15)
	return overlay

func close_panel() -> void:
	if panel_stack.is_empty():
		return
	var o: Control = panel_stack.pop_back()
	var cb: Callable = o.get_meta("on_close", Callable())
	o.queue_free()
	if cb.is_valid():
		cb.call()

func close_all_panels() -> void:
	while not panel_stack.is_empty():
		close_panel()

func has_panel() -> bool:
	return not panel_stack.is_empty()

func confirm(text: String, yes_cb: Callable, yes_txt: String = "Oui") -> void:
	var v := UiKit.vbox(20)
	v.add_child(UiKit.label(text, 32))
	var h := UiKit.hbox(16)
	h.add_child(UiKit.expand(UiKit.button(tr("Annuler"), func(): close_panel(), UiKit.C_DISABLED)))
	h.add_child(UiKit.expand(UiKit.button(tr(yes_txt), func():
		close_panel()
		yes_cb.call(), UiKit.C_ACCENT)))
	v.add_child(h)
	open_panel(tr("Confirmation"), v)

func toast(text: String) -> void:
	var p := UiKit.panel(14, Color(0.3, 0.22, 0.18, 0.92))
	var l := UiKit.label(text, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

# ================================================================== Activités
func start_activity(a: Node) -> void:
	if activity:
		end_activity()
	activity = a
	close_all_panels()
	if screen:
		screen.visible = false
	add_child(a)

func end_activity() -> void:
	if activity:
		var a := activity
		activity = null
		if is_instance_valid(a):
			a.queue_free()
	if pet_ctrl:
		pet_ctrl.busy = false
		pet_ctrl.drop_held()
	cam_rig.follow = true
	cam_rig.fixed_transform = null
	if screen:
		screen.visible = true
		if screen.has_method("refresh"):
			screen.refresh()
	GameState.save_game()

# ================================================================== Entrées
func raycast(screen_pos: Vector2, mask: int = 7) -> Dictionary:
	var c := cam_rig.cam
	if c == null:
		return {}
	var from := c.project_ray_origin(screen_pos)
	var to := from + c.project_ray_normal(screen_pos) * 60.0
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return world.get_world_3d().direct_space_state.intersect_ray(q)

## Point au sol (y = 0) sous un point de l'écran.
func ground_point(screen_pos: Vector2) -> Variant:
	var c := cam_rig.cam
	var from := c.project_ray_origin(screen_pos)
	var dir := c.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	return from + dir * t

func hit_part(hit: Dictionary) -> String:
	if hit.is_empty():
		return ""
	var col: Object = hit.get("collider")
	if col and col.has_meta("part"):
		return str(col.get_meta("part"))
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if activity and activity.has_method("handle_input"):
		if activity.handle_input(event):
			get_viewport().set_input_as_handled()
			return
	if screen_name == "adopt" and not has_panel() and event is InputEventScreenDrag:
		cam_rig.orbit(event.relative.x, 0.0)   # tourner autour de l'animal pour voir les détails
		return
	if screen_name != "home" or has_panel() or activity:
		return
	_home_input(event)

func _home_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 2:
				var ps: Array = _touches.values()
				_pinch_d = (ps[0] as Vector2).distance_to(ps[1])
				_drag_kind = "pinch"
				return
			if e.index != 0:
				return
			_press_pos = e.position
			_press_t = Time.get_ticks_msec()
			_moved = 0.0
			_stroke_acc = 0.0
			var hit := raycast(e.position, 2 | 4)
			var part := hit_part(hit)
			if part == "head" or part == "body":
				_drag_kind = "pet"
				_drag_part = part
			elif part != "":
				_drag_kind = "obj"
				_drag_part = part
			else:
				_drag_kind = "cam"
		else:
			_touches.erase(e.index)
			if e.index != 0 or _drag_kind == "pinch":
				if _touches.is_empty():
					_drag_kind = ""
				return
			var short := Time.get_ticks_msec() - _press_t < 350 and _moved < 24.0
			if short:
				_on_tap(e.position)
			_drag_kind = ""
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touches[d.index] = d.position
		if _drag_kind == "pinch" and _touches.size() >= 2:
			var ps2: Array = _touches.values()
			var nd := (ps2[0] as Vector2).distance_to(ps2[1])
			if _pinch_d > 10.0:
				cam_rig.zoom(_pinch_d / maxf(nd, 1.0))
			_pinch_d = nd
			return
		if d.index != 0:
			return
		_moved += d.relative.length()
		if _drag_kind == "pet":
			var hit := raycast(d.position, 2)
			var part := hit_part(hit)
			if part == "head" or part == "body":
				_stroke_acc += d.relative.length()
				if _stroke_acc > 70.0:
					_stroke_acc = 0.0
					var counted := GameState.stroke()
					pet_ctrl.on_stroke(part)
					if counted and randf() < 0.3:
						Audio.play("heart", 0.12, -14.0)
					Audio.vibrate(8)
		elif _drag_kind == "cam":
			cam_rig.orbit(d.relative.x, d.relative.y)

func _on_tap(pos: Vector2) -> void:
	var hit := raycast(pos, 2 | 4)
	var part := hit_part(hit)
	if part == "head" or part == "body":
		pet_ctrl.on_tap(part)
		return
	if part != "" and screen and screen.has_method("on_object_tapped"):
		screen.on_object_tapped(part)
		return
	var gp: Variant = ground_point(pos)
	if gp is Vector3 and pet_ctrl and pet_ctrl.visible:
		pet_ctrl.walk_to(gp, 1.0, func(): pet_ctrl.do_posture("sit", 2.0))
		_tap_marker(gp)

func _tap_marker(p: Vector3) -> void:
	var r := WorldBuilder.torus(world, 0.1, 0.14, p + Vector3(0, 0.02, 0), Color(1, 1, 1))
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tw := r.create_tween()
	tw.tween_property(r, "scale", Vector3(2.2, 1, 2.2), 0.4)
	tw.tween_callback(r.queue_free)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		GameState.save_game()
		get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		get_tree().paused = false
		if GameState.offline_report != "" and screen_name == "home":
			toast(GameState.offline_report)
			GameState.offline_report = ""

func _on_back() -> void:
	if has_panel():
		close_panel()
	elif activity and activity.has_method("quit"):
		activity.quit()
	elif screen_name == "home" or screen_name == "adopt":
		if screen_name == "adopt" and GameState.has_save():
			change_env("house")
			show_screen("home")
		else:
			show_screen("title")
	else:
		GameState.save_game()
		get_tree().quit()

# ================================================================== Photo
func take_photo(cb: Callable = Callable()) -> void:
	ui_layer.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	ui_layer.visible = true
	DirAccess.make_dir_recursive_absolute("user://photos")
	var nm := "photo_%d.png" % int(Time.get_unix_time_from_system() * 1000.0)
	var w := img.get_width()
	var h := img.get_height()
	if w > 1080:
		img.resize(1080, int(h * 1080.0 / w), Image.INTERPOLATE_BILINEAR)
	img.save_png("user://photos/" + nm)
	GameState.data["photos"].append(nm)
	while GameState.data["photos"].size() > 60:
		var old: String = GameState.data["photos"].pop_front()
		DirAccess.remove_absolute("user://photos/" + old)
	GameState.inc_stat("photo", 1)
	GameState.add_xp(3)
	Audio.play("camera", 0.0)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)
	if cb.is_valid():
		cb.call(nm)
