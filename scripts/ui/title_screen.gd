class_name TitleScreen
extends Control
## Écran titre / menu principal.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var main := Main.inst
	Audio.music("music_title")
	if GameState.has_save():
		main.change_env("garden")
		main.cam_rig.reset_view(3.0, -0.25, 0.4)
	else:
		main.change_env("garden")
		var i := 0
		for b in ["labrador", "cat", "shiba"]:
			var c := main.add_extra_pet({"breed": b, "palette": 0, "eyes": i, "collar": "collar_blue", "accessory": "acc_none"}, Vector3(-0.62 + i * 0.62, 0, 0.0))
			c.bounds = Rect2(-2, -1.5, 4, 2.5)
			i += 1
		main.cam_rig.target = null
		main.cam_rig.focus = Vector3(0, 0.3, 0)
		main.cam_rig.reset_view(4.3, -0.22, 0.0)
	var v := UiKit.vbox(18)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	v.add_child(UiKit.spacer(30))
	var title := TextureRect.new()
	title.texture = load("res://assets/ui/logo.png")
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.custom_minimum_size = Vector2(0, 360)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)
	var sub := UiKit.label(tr("Des compagnons à aimer, soigner et dresser"), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_color_override("font_outline_color", Color(0.4, 0.25, 0.15, 0.8))
	sub.add_theme_constant_override("outline_size", 10)
	v.add_child(sub)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var box := UiKit.vbox(18)
	box.custom_minimum_size = Vector2(460, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(box)
	if GameState.load_status == "backup":
		box.add_child(_note(tr("La dernière sauvegarde était endommagée : la copie de secours a été chargée.")))
	elif GameState.load_status == "corrupt":
		box.add_child(_note(tr("Sauvegarde illisible : une nouvelle partie va commencer.")))
	if GameState.has_save():
		var p := GameState.active_pet()
		box.add_child(UiKit.button(tr("Continuer") + "  ·  " + str(p.get("name", "")), _continue, UiKit.C_ACCENT, 36, 104))
	else:
		box.add_child(UiKit.button(tr("Nouvelle partie"), _new_game, UiKit.C_ACCENT, 36, 104))
	box.add_child(UiKit.button(tr("Paramètres"), func(): Panels.settings(), UiKit.C_BLUE, 32, 92))
	if not OS.has_feature("mobile"):
		box.add_child(UiKit.button(tr("Quitter"), func():
			GameState.save_game()
			get_tree().quit(), UiKit.C_DISABLED, 30, 84))
	v.add_child(UiKit.spacer(40))
	var ver := UiKit.label("v" + str(ProjectSettings.get_setting("application/config/version", "1.0")), 20, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(ver)
	title.pivot_offset = Vector2(360, 60)
	var tw := title.create_tween().set_loops()
	tw.tween_property(title, "scale", Vector2(1.04, 1.04), 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)

func _note(t: String) -> Control:
	var p := UiKit.panel(14, Color(1, 0.95, 0.85, 0.95))
	p.add_child(UiKit.label(t, 24, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	return p

func _continue() -> void:
	var main := Main.inst
	main._clear_extra_pets()
	main.change_env("house")
	main.show_screen("home")
	if GameState.offline_report != "":
		main.toast(GameState.offline_report)
		GameState.offline_report = ""

func _new_game() -> void:
	var main := Main.inst
	main._clear_extra_pets()
	main.show_screen("adopt", {"first": true})
