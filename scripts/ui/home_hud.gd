class_name HomeHud
extends Control
## Vue principale du compagnon : besoins, monnaie, actions de soin, menus, ordres rapides.

var need_bars := {}
var coins_l: Label
var level_l: Label
var xp_bar: ProgressBar
var name_l: Label
var rel_bar: ProgressBar
var rel_l: Label
var cmd_bar: HFlowContainer
var mic_btn: Button
var place_l: Label
var _last_cmd := {}
var _temp_bowl: Node3D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Audio.music("music_home")
	_build()
	GameState.needs_changed.connect(_update_needs)
	GameState.coins_changed.connect(func(_c): _update_top())
	GameState.xp_changed.connect(func(_x, _l): _update_top())
	GameState.pet_changed.connect(refresh)
	GameState.inventory_changed.connect(_update_top)
	Voice.heard.connect(_on_voice)
	refresh()
	var args: Dictionary = get_meta("args", {})
	if args.get("welcome", false) and not GameState.data["tutorial"].get("done", false):
		_tutorial()

func _build() -> void:
	var root := UiKit.vbox(8)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# --- Barre du haut
	var top := UiKit.hbox(10)
	var pp := UiKit.panel(12)
	pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pv := UiKit.vbox(2)
	name_l = UiKit.label("", 32)
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_l.clip_text = true
	pv.add_child(name_l)
	var rh := UiKit.hbox(6)
	rel_l = UiKit.label("", 20, UiKit.C_SUB)
	rel_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	rh.add_child(rel_l)
	rel_bar = UiKit.bar(0, Color(0.95, 0.5, 0.7), 14)
	rel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rel_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rh.add_child(rel_bar)
	pv.add_child(rh)
	pp.add_child(pv)
	pp.gui_input.connect(_on_pet_panel_input)
	top.add_child(pp)
	var cp := UiKit.panel(12)
	var cv := UiKit.vbox(2)
	coins_l = UiKit.label("", 30)
	coins_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cv.add_child(coins_l)
	var lh := UiKit.hbox(6)
	level_l = UiKit.label("", 20, UiKit.C_SUB)
	lh.add_child(level_l)
	xp_bar = UiKit.bar(0, UiKit.C_GOLD, 14)
	xp_bar.custom_minimum_size = Vector2(110, 14)
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lh.add_child(xp_bar)
	cv.add_child(lh)
	cp.add_child(cv)
	cp.custom_minimum_size = Vector2(230, 0)
	top.add_child(cp)
	root.add_child(top)
	# --- Milieu : besoins (gauche) + raccourcis (droite)
	var mid := UiKit.hbox(8)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var np := UiKit.panel(10, Color(1, 0.99, 0.96, 0.85))
	np.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var nv := UiKit.vbox(4)
	for k in GameData.NEED_KEYS:
		var h := UiKit.hbox(4)
		var il := UiKit.label(GameData.NEED_ICONS[k], 22, UiKit.C_TEXT)
		il.autowrap_mode = TextServer.AUTOWRAP_OFF
		il.custom_minimum_size = Vector2(32, 0)
		h.add_child(il)
		var b := UiKit.bar(50, GameData.NEED_COLORS[k], 16)
		b.custom_minimum_size = Vector2(110, 16)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
		need_bars[k] = b
		nv.add_child(h)
	np.add_child(nv)
	np.gui_input.connect(_on_needs_input)
	mid.add_child(np)
	place_l = UiKit.label("", 22, Color.WHITE)
	place_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	place_l.add_theme_constant_override("outline_size", 8)
	place_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	place_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(place_l)
	var side := UiKit.vbox(10)
	side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side.add_child(UiKit.icon_button("📷", tr("Photo"), func(): Main.inst.take_photo(), Color(1, 1, 1, 0.92), 96))
	side.add_child(UiKit.icon_button("🗺️", tr("Lieux"), func(): Panels.places(), Color(1, 1, 1, 0.92), 96))
	side.add_child(UiKit.icon_button("🐾", tr("Animaux"), func(): Panels.pets(), Color(1, 1, 1, 0.92), 96))
	mic_btn = UiKit.icon_button("🎤", tr("Voix"), _toggle_mic, Color(1, 1, 1, 0.92), 96)
	side.add_child(mic_btn)
	mid.add_child(side)
	root.add_child(mid)
	# --- Ordres rapides
	var cpnl := UiKit.panel(10, Color(1, 0.99, 0.96, 0.85))
	var cvb := UiKit.vbox(6)
	cmd_bar = HFlowContainer.new()
	cmd_bar.add_theme_constant_override("h_separation", 8)
	cmd_bar.add_theme_constant_override("v_separation", 8)
	cvb.add_child(cmd_bar)
	cpnl.add_child(cvb)
	root.add_child(cpnl)
	# --- Actions
	var row1 := UiKit.hbox(8)
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_child(UiKit.icon_button("🍖", tr("Nourrir"), func(): Panels.food_picker("food", feed), Color(1, 0.93, 0.85), 108))
	row1.add_child(UiKit.icon_button("💧", tr("Eau"), give_water, Color(0.88, 0.95, 1), 108))
	row1.add_child(UiKit.icon_button("🛁", tr("Laver"), func(): Main.inst.start_activity(BathActivity.new()), Color(0.88, 0.97, 1), 108))
	row1.add_child(UiKit.icon_button("🦴", tr("Friandise"), func(): Panels.food_picker("treat", give_treat), Color(1, 0.95, 0.88), 108))
	row1.add_child(UiKit.icon_button("🎾", tr("Lancer"), _throw, Color(0.95, 1, 0.88), 108))
	row1.add_child(UiKit.icon_button("📣", tr("Appeler"), _call, Color(1, 0.92, 0.95), 108))
	root.add_child(row1)
	var row2 := UiKit.hbox(8)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_child(UiKit.icon_button("🎓", tr("Dressage"), func(): Panels.training(), Color(0.98, 0.85, 0.75), 108))
	row2.add_child(UiKit.icon_button("🎯", tr("Activités"), func(): Panels.activities(), Color(0.85, 0.95, 0.85), 108))
	row2.add_child(UiKit.icon_button("🏆", tr("Concours"), func(): Panels.competitions(), Color(1, 0.93, 0.7), 108))
	row2.add_child(UiKit.icon_button("🛍️", tr("Boutique"), func(): Panels.shop(), Color(0.9, 0.88, 1), 108))
	row2.add_child(UiKit.icon_button("🎒", tr("Sac"), func(): Panels.inventory(), Color(0.95, 0.9, 0.85), 108))
	row2.add_child(UiKit.icon_button("☰", tr("Plus"), func(): Panels.more(), Color(0.92, 0.92, 0.92), 108))
	root.add_child(row2)

func _on_pet_panel_input(e: InputEvent) -> void:
	if _is_tap(e):
		Panels.pet_info()

func _on_needs_input(e: InputEvent) -> void:
	if _is_tap(e):
		Panels.needs()

func _is_tap(e: InputEvent) -> bool:
	return e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT

func refresh() -> void:
	_update_top()
	_update_needs()
	_update_cmds()
	var e: Dictionary = GameData.ENVIRONMENTS.get(Main.inst.env_id, {})
	place_l.text = "%s %s" % [e.get("icon", ""), tr(e.get("name", ""))]
	mic_btn.visible = bool(GameState.setting("voice"))
	mic_btn.modulate = Color(1, 0.6, 0.6) if Voice.listening else Color.WHITE

func _update_top() -> void:
	var p := GameState.active_pet()
	if p.is_empty():
		return
	var sex := "♂" if p["sex"] == "m" else "♀"
	name_l.text = "%s %s" % [p["name"], sex]
	var lv := GameState.relation_level(p)
	rel_l.text = "💞 %d · %s" % [lv, tr(GameData.RELATION_NAMES[lv - 1])]
	rel_bar.value = GameState.relation_progress(p) * 100.0
	coins_l.text = "🪙 %d" % GameState.coins()
	level_l.text = "⭐ %d" % GameState.level()
	xp_bar.value = float(GameState.data["xp"]) / float(GameData.xp_for_level(GameState.level())) * 100.0

func _update_needs() -> void:
	var p := GameState.active_pet()
	if p.is_empty():
		return
	for k in need_bars.keys():
		var b: ProgressBar = need_bars[k]
		b.value = p["needs"][k]
		b.modulate = Color(1, 0.75, 0.75) if p["needs"][k] < 25.0 else Color.WHITE
	if Main.inst.pet_ctrl:
		Main.inst.pet_ctrl._apply_mood_look()

func _update_cmds() -> void:
	for c in cmd_bar.get_children():
		c.queue_free()
	var any := false
	for cmd in GameData.COMMAND_ORDER:
		if GameState.skill(cmd) >= 20.0 and GameState.command_available(cmd):
			any = true
			var cc: String = cmd
			var b := UiKit.button(tr(GameData.COMMANDS[cmd]["name"]), func(): order(cc), UiKit.C_BLUE, 22, 60)
			cmd_bar.add_child(b)
	if not any:
		cmd_bar.add_child(UiKit.label(tr("Apprenez des ordres dans « Dressage » 🎓"), 22, UiKit.C_SUB))
	cmd_bar.add_child(UiKit.button("👍 " + tr("Bravo"), praise, UiKit.C_ACCENT2, 22, 60))
	cmd_bar.add_child(UiKit.button("✋ " + tr("Non"), scold, UiKit.C_DANGER, 22, 60))

# ================================================================== Soins
func _pet() -> PetController:
	return Main.inst.pet_ctrl

func _bowl_pos(kind: String) -> Vector3:
	var env := Main.inst.env_root
	var key := "bowl_" + kind
	if env.has_meta(key):
		return env.get_meta(key)
	if _temp_bowl and is_instance_valid(_temp_bowl):
		_temp_bowl.queue_free()
	var p := _pet().position + Vector3(0.4, 0, 0.5)
	_temp_bowl = WorldBuilder.make_bowl(Main.inst.world, p, Color(0.95, 0.45, 0.45) if kind == "food" else Color(0.45, 0.65, 0.95), kind)
	return p

func _set_bowl(kind: String, full: bool) -> void:
	var env := Main.inst.env_root
	var n: Node = env.get_node_or_null("Bowl_" + kind)
	if n == null and _temp_bowl and is_instance_valid(_temp_bowl):
		n = _temp_bowl
	if n:
		var f: Node3D = n.get_node_or_null("Fill")
		if f:
			f.visible = full
	GameState.data["bowls"][kind] = 1.0 if full else 0.0

func feed(item_id: String) -> void:
	var pet := _pet()
	if pet == null:
		return
	var bp := _bowl_pos("food")
	_set_bowl("food", true)
	Audio.play("pop")
	pet.walk_to(bp + Vector3(0, 0, 0.32), 1.2, func():
		pet.face(bp)
		pet.eat("food", 2.6)
		await get_tree().create_timer(2.6, false).timeout
		if GameState.feed(item_id):
			pet.model.emote("😋")
		_set_bowl("food", false)
		_cleanup_bowl())

func give_water() -> void:
	var pet := _pet()
	if pet == null:
		return
	var bp := _bowl_pos("water")
	_set_bowl("water", true)
	Audio.play("splash", 0.1, -6.0)
	pet.walk_to(bp + Vector3(0, 0, 0.32), 1.2, func():
		pet.face(bp)
		pet.eat("water", 2.2)
		await get_tree().create_timer(2.2, false).timeout
		GameState.give_water()
		_set_bowl("water", false)
		_cleanup_bowl())

func _cleanup_bowl() -> void:
	if _temp_bowl and is_instance_valid(_temp_bowl):
		var b := _temp_bowl
		_temp_bowl = null
		await get_tree().create_timer(1.0, false).timeout
		if is_instance_valid(b):
			b.queue_free()

func give_treat(item_id: String) -> void:
	var pet := _pet()
	if pet == null:
		return
	pet.walk_to(pet.player_pos + Vector3(0, 0, -0.5), 1.5, func():
		pet.face(pet.player_pos)
		pet.do_posture("sit", 0.6)
		await get_tree().create_timer(0.6, false).timeout
		if GameState.give_treat(item_id):
			pet.eat("food", 1.2)
			pet.model.emote("💖"))

func _call() -> void:
	if _pet():
		_pet().call_name()
		GameState.add_relation(1)

func _throw() -> void:
	if Main.inst.env_root.get_meta("indoor", false):
		Main.inst.toast(tr("Pas de lancer à l'intérieur ! Allez au jardin ou au parc."))
		return
	Main.inst.start_activity(FetchGame.new(true))

func on_object_tapped(part: String) -> void:
	match part:
		"bowl_food":
			Panels.food_picker("food", feed)
		"bowl_water":
			give_water()
		"bed":
			if _pet():
				if _pet().sleeping:
					_pet().wake_up()
				else:
					_pet().go_sleep()
					Main.inst.toast(tr("%s fait une sieste…") % _pet().pet["name"])

# ================================================================== Ordres
func order(cmd: String) -> void:
	var pet := _pet()
	if pet == null or pet.state == "moving":
		return
	var ok := randf() < GameState.success_chance(cmd)
	if pet.sleeping:
		pet.wake_up()
		ok = false
	if ok:
		pet.perform(cmd)
	else:
		pet.fail_behaviour(cmd)
	_last_cmd = {"cmd": cmd, "ok": ok, "t": Time.get_ticks_msec()}

func praise() -> void:
	var pet := _pet()
	if pet == null:
		return
	if not _last_cmd.is_empty() and Time.get_ticks_msec() - int(_last_cmd["t"]) < 6000:
		GameState.training_feedback(_last_cmd["cmd"], _last_cmd["ok"], true, false)
		_last_cmd = {}
		_update_cmds()
	pet.praise()
	GameState.change_need("mood", 2.0)

func scold() -> void:
	var pet := _pet()
	if pet == null:
		return
	if not _last_cmd.is_empty() and Time.get_ticks_msec() - int(_last_cmd["t"]) < 6000:
		GameState.training_feedback(_last_cmd["cmd"], _last_cmd["ok"], false, false)
		_last_cmd = {}
	pet.scold()

func _toggle_mic() -> void:
	if Voice.listening:
		Voice.stop_listening()
	else:
		if Voice.trained_count() == 0:
			Main.inst.toast(tr("Enregistrez d'abord votre voix dans Paramètres › Commandes vocales."))
			return
		if not Voice.start_listening():
			Main.inst.toast(tr("Autorisez le micro puis réessayez."))
	refresh()

func _on_voice(cmd: String, _conf: float) -> void:
	if not is_visible_in_tree() or Main.inst.activity:
		return
	if GameState.skill(cmd) < 20.0:
		_pet().head_tilt()
		return
	order(cmd)

func _tutorial() -> void:
	GameState.data["tutorial"]["done"] = true
	var v := UiKit.vbox(14)
	var p := GameState.active_pet()
	for t in [
		tr("Bienvenue à la maison, %s !") % p.get("name", ""),
		"👆 " + tr("Glissez le doigt sur votre compagnon pour le caresser, tapotez-le pour jouer."),
		"🍖 " + tr("Surveillez ses besoins à gauche : nourrissez-le, donnez-lui à boire et lavez-le."),
		"🎓 " + tr("Apprenez-lui des ordres dans « Dressage » puis récompensez-le avec 👍 Bravo."),
		"🎯 " + tr("Gagnez des pièces avec les activités, les concours et les objectifs du jour."),
		"🗺️ " + tr("Touchez le sol pour l'appeler, faites glisser pour tourner la caméra."),
	]:
		v.add_child(UiKit.label(t, 28))
	v.add_child(UiKit.button(tr("Compris !"), func(): Main.inst.close_panel(), UiKit.C_ACCENT2))
	Main.inst.open_panel(tr("Premiers pas"), UiKit.scroll(v))
