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
	GameState.pet_level_up.connect(func(_l):
		Audio.play("levelup")
		_update_top()
		_update_cmds())
	GameState.inventory_changed.connect(_update_top)
	Voice.heard.connect(_on_voice)
	Voice.unrecognized.connect(_on_voice_miss)
	Voice.level.connect(_on_voice_level)
	Voice.state_changed.connect(func(_on): refresh())
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
	nv.add_theme_constant_override("separation", 2)
	for k in GameData.NEED_KEYS:
		var row := UiKit.need_row(k, 50.0, 30, 14, 19, 92)
		need_bars[k] = [row[1], row[2]]
		nv.add_child(row[0])
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
	side.add_child(UiKit.icon_button("menu", tr("Menu"), func(): Panels.more(), Color(1, 1, 1, 0.92), 96))
	side.add_child(UiKit.icon_button("camera", tr("Photo"), func(): Main.inst.start_activity(PhotoMode.new()), Color(1, 1, 1, 0.92), 96))
	side.add_child(UiKit.icon_button("map", tr("Lieux"), func(): Panels.places(), Color(1, 1, 1, 0.92), 96))
	side.add_child(UiKit.icon_button("paw", tr("Animaux"), func(): Panels.pets(), Color(1, 1, 1, 0.92), 96))
	side.add_child(UiKit.icon_button("recenter", tr("Centrer"), func(): Main.inst.recenter_camera(0.22), Color(1, 1, 1, 0.92), 96))
	side.add_child(UiKit.icon_button("call", tr("Appeler"), _call, Color(1, 1, 1, 0.92), 96))
	mic_btn = UiKit.icon_button("mic", tr("Voix"), _toggle_mic, Color(1, 1, 1, 0.92), 96)
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
	row1.add_child(UiKit.icon_button("feed", tr("Nourrir"), func(): Panels.food_picker("food", feed), Color(1, 0.93, 0.85), 108))
	row1.add_child(UiKit.icon_button("water", tr("Eau"), give_water, Color(0.88, 0.95, 1), 108))
	row1.add_child(UiKit.icon_button("wash", tr("Laver"), func(): Main.inst.start_activity(BathActivity.new()), Color(0.88, 0.97, 1), 108))
	row1.add_child(UiKit.icon_button("brush", tr("Brosser"), func(): Main.inst.start_activity(BrushActivity.new()), Color(0.98, 0.93, 0.85), 108))
	row1.add_child(UiKit.icon_button("treat", tr("Friandise"), func(): Panels.food_picker("treat", give_treat), Color(1, 0.95, 0.88), 108))
	row1.add_child(UiKit.icon_button("cuddle", tr("Câlin"), func(): Main.inst.start_activity(CuddleActivity.new()), Color(1, 0.92, 0.95), 108))
	root.add_child(row1)
	var row2 := UiKit.hbox(8)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_child(UiKit.icon_button("throw", tr("Jouer"), func(): Panels.play(self), Color(0.95, 1, 0.88), 108))
	row2.add_child(UiKit.icon_button("training", tr("Dressage"), func(): Panels.training(), Color(0.98, 0.85, 0.75), 108))
	row2.add_child(UiKit.icon_button("activities", tr("Activités"), func(): Panels.activities(), Color(0.85, 0.95, 0.85), 108))
	row2.add_child(UiKit.icon_button("trophy", tr("Concours"), func(): Panels.competitions(), Color(1, 0.93, 0.7), 108))
	row2.add_child(UiKit.icon_button("shop", tr("Boutique"), func(): Panels.shop(), Color(0.9, 0.88, 1), 108))
	row2.add_child(UiKit.icon_button("inventory", tr("Sac"), func(): Panels.inventory(), Color(0.95, 0.9, 0.85), 108))
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
	UiKit.set_label(place_l, "[i:%s] %s" % [e.get("icon", "house"), tr(e.get("name", ""))])
	mic_btn.visible = bool(GameState.setting("voice")) or Voice.trained_count() > 0
	mic_btn.modulate = Color(1, 0.6, 0.6) if Voice.listening else Color.WHITE

func _update_top() -> void:
	var p := GameState.active_pet()
	if p.is_empty():
		return
	UiKit.set_label(name_l, "[i:%s] %s" % ["male" if p["sex"] == "m" else "female", p["name"]])
	var lv := GameState.relation_level(p)
	UiKit.set_label(rel_l, "[i:relation] %d · %s" % [lv, tr(GameData.RELATION_NAMES[lv - 1])])
	rel_bar.value = GameState.relation_progress(p) * 100.0
	UiKit.set_label(coins_l, "[i:coin] %d" % GameState.coins())
	level_l.text = tr("Niv. %d") % GameState.pet_level(p)
	xp_bar.value = GameState.pet_xp_progress(p) * 100.0

func _update_needs() -> void:
	var p := GameState.active_pet()
	if p.is_empty():
		return
	for k in need_bars.keys():
		UiKit.set_need(need_bars[k][0], need_bars[k][1], float(p["needs"][k]))
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
		var hl := UiKit.label("[i:training] " + tr("Apprenez des ordres dans « Dressage »"), 22, UiKit.C_SUB)
		hl.custom_minimum_size = Vector2(640, 0)
		cmd_bar.add_child(hl)
	cmd_bar.add_child(UiKit.button("[i:check] " + tr("Bravo"), praise, UiKit.C_ACCENT2, 22, 60))
	cmd_bar.add_child(UiKit.button("[i:stop] " + tr("Non"), scold, UiKit.C_DANGER, 22, 60))

# ================================================================== Soins
func _pet() -> PetController:
	return Main.inst.pet_ctrl

## Gamelle du lieu (maison) ou gamelle temporaire posée sur un point libre près de l'animal.
func _bowl_node(kind: String) -> Node3D:
	var env := Main.inst.env_root
	var n: Node3D = env.get_node_or_null("Bowl_" + kind)
	if n:
		return n
	if _temp_bowl and is_instance_valid(_temp_bowl):
		_temp_bowl.queue_free()
	var p := _pet().position + Vector3(0.45, 0, 0.55)
	if Main.inst.nav:
		var f := Main.inst.nav.nearest_free(Vector2(p.x, p.z))
		p = Vector3(f.x, 0, f.y)
	_temp_bowl = WorldBuilder.make_bowl(Main.inst.world, p, Color(0.95, 0.45, 0.45) if kind == "food" else Color(0.45, 0.65, 0.95), kind)
	return _temp_bowl

func _fill(bowl: Node3D, amount: float) -> void:
	var f: Node3D = bowl.get_node_or_null("Fill")
	if f == null:
		return
	f.visible = amount > 0.02
	var k := 0.45 + 0.55 * clampf(amount, 0.0, 1.0)
	f.scale = Vector3(k, 1.0, k)
	f.position.y = 0.05 + 0.025 * amount

func feed(item_id: String) -> void:
	var pet := _pet()
	if pet == null or pet.state == "action" and pet.get_meta("action", "") == "eat":
		return
	var fx := GameState.feed_start(item_id)
	if fx.is_empty():
		Main.inst.toast(tr("Plus de nourriture de ce type."))
		return
	var bowl := _bowl_node("food")
	_fill(bowl, 1.0)
	GameState.data["bowls"]["food"] = 1.0
	Audio.play("pop")
	var given := {"k": 0.0}
	pet.eat_from(bowl, "food", 3.2, func(frac: float):
		# besoins mis à jour au fil du repas
		for key in fx.keys():
			if GameData.NEED_KEYS.has(key):
				GameState.change_need(key, float(fx[key]) * (frac - given["k"]))
		given["k"] = frac
		_fill(bowl, 1.0 - frac), func(_ok: bool):
		if given["k"] < 1.0:   # repas interrompu : il finira la gamelle plus tard, effets restants appliqués
			for key in fx.keys():
				if GameData.NEED_KEYS.has(key):
					GameState.change_need(key, float(fx[key]) * (1.0 - given["k"]))
		GameState.data["bowls"]["food"] = 0.0
		_fill(bowl, 0.0)
		_cleanup_bowl())

func give_water() -> void:
	var pet := _pet()
	if pet == null or pet.state == "action" and pet.get_meta("action", "") == "eat":
		return
	var bowl := _bowl_node("water")
	_fill(bowl, 1.0)
	Audio.play("splash", 0.1, -6.0)
	GameState.give_water(false)
	var given := {"k": 0.0}
	pet.eat_from(bowl, "water", 2.6, func(frac: float):
		GameState.change_need("thirst", 60.0 * (frac - given["k"]))
		given["k"] = frac
		_fill(bowl, 1.0 - frac), func(_ok: bool):
		if given["k"] < 1.0:
			GameState.change_need("thirst", 60.0 * (1.0 - given["k"]))
		_fill(bowl, 0.0)
		_cleanup_bowl())

func _cleanup_bowl() -> void:
	if _temp_bowl and is_instance_valid(_temp_bowl):
		var b := _temp_bowl
		_temp_bowl = null
		await get_tree().create_timer(1.5, false).timeout
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
			pet.model.emote("emo_heart"))

func _call() -> void:
	if _pet():
		_pet().call_name()
		GameState.add_relation(1)

func throw_free() -> void:
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
			Main.inst.toast(tr("Associez d'abord un mot à un ordre dans « Dressage »."))
			return
		if not Voice.start_listening():
			Main.inst.toast(tr("Autorisez le micro puis réessayez.") if not Voice.has_permission() else tr("Aucun micro disponible."))
	refresh()

func _on_voice_level(v: float) -> void:
	if mic_btn and Voice.listening:
		mic_btn.modulate = Color(1, 0.6 + 0.4 * v, 0.6 + 0.4 * v)

func _on_voice(cmd: String, _conf: float) -> void:
	if not is_visible_in_tree() or Main.inst.activity or Main.inst.has_panel():
		return
	var p := GameState.active_pet()
	Voice.record_use(p, cmd, true)
	Main.inst.toast("[i:mic] " + tr("Entendu : « %s »") % Voice.word(p, cmd))
	if GameState.skill(cmd) < 20.0 or not GameState.command_available(cmd):
		_pet().head_tilt()
		return
	order(cmd)

func _on_voice_miss(_best: String, _d: float) -> void:
	if not is_visible_in_tree() or Main.inst.activity or Main.inst.has_panel():
		return
	if _pet() and not _pet().sleeping:
		_pet().head_tilt()

func _tutorial() -> void:
	GameState.data["tutorial"]["done"] = true
	var v := UiKit.vbox(14)
	var p := GameState.active_pet()
	for t in [
		tr("Bienvenue à la maison, %s !") % p.get("name", ""),
		"[i:finger] " + tr("Glissez le doigt sur votre compagnon pour le caresser, tapotez-le pour jouer."),
		"[i:feed] " + tr("Surveillez ses besoins à gauche : nourrissez-le, donnez-lui à boire et lavez-le."),
		"[i:training] " + tr("Apprenez-lui des ordres dans « Dressage » puis récompensez-le avec « Bravo »."),
		"[i:activities] " + tr("Gagnez des pièces avec les activités, les concours et les objectifs du jour."),
		"[i:map] " + tr("Touchez le sol pour l'appeler, faites glisser pour tourner la caméra."),
	]:
		v.add_child(UiKit.label(t, 28))
	v.add_child(UiKit.button(tr("Compris !"), func(): Main.inst.close_panel(), UiKit.C_ACCENT2))
	Main.inst.open_panel(tr("Premiers pas"), UiKit.scroll(v))
