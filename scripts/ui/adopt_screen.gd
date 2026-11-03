class_name AdoptScreen
extends Control
## Refuge : choix de l'animal puis personnalisation (nom, sexe, couleurs, collier, accessoire).

const NAMES_M := ["Filou", "Oscar", "Pistache", "Gaston", "Biscuit", "Moka", "Plume", "Toby", "Nougat", "Hercule"]
const NAMES_F := ["Lola", "Praline", "Noisette", "Perle", "Câline", "Vanille", "Nala", "Fripouille", "Mimi", "Olive"]

var idx := 0
var candidates: Array[PetController] = []
var temps: Array[String] = []
var step := "choose"
var info_box: VBoxContainer
var custom := {}
var first := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var args: Dictionary = get_meta("args", {})
	first = bool(args.get("first", false)) or not GameState.has_save()
	var main := Main.inst
	main.change_env("shelter")
	Audio.music("music_home")
	var i := 0
	for b in GameData.BREED_ORDER:
		var p := {"breed": b, "palette": 0, "eyes": 0, "collar": "collar_red", "accessory": "acc_none",
			"needs": {"mood": 80.0, "energy": 90.0, "hunger": 80.0, "thirst": 80.0, "clean": 80.0, "health": 100.0, "affection": 50.0}}
		var c := main.add_extra_pet(GameState.sanitize_pet(p), Vector3(-3.75 + i * 1.5, 0, -2.6))
		c.rotation.y = 0.0
		c.player_pos = Vector3(-3.75 + i * 1.5, 0, 1.0)
		candidates.append(c)
		temps.append(GameState.random_temperament(b + str(i)))
		i += 1
	main.cam_rig.target = null
	_build_choose()
	_focus()

func _exit_tree() -> void:
	if Main.inst:
		Main.inst._clear_extra_pets()

func _focus(detail: String = "body", greet: bool = true) -> void:
	var main := Main.inst
	var c := candidates[idx]
	main.cam_rig.follow = false
	main.cam_rig.target = null
	var top := c.model.top_height()
	if detail == "head":
		main.cam_rig.focus = c.model.head_pivot.global_position + Vector3(0, top * 0.05, 0)
		main.cam_rig.reset_view(0.75 + top * 0.9, -0.15, 0.4)
		main.cam_rig.screen_shift = 0.42
	elif detail == "neck":
		main.cam_rig.focus = c.model.acc_root.global_position
		main.cam_rig.reset_view(0.75 + top * 0.9, -0.1, 0.95)
		main.cam_rig.screen_shift = 0.42
	elif step == "choose":
		main.cam_rig.focus = c.position + Vector3(0, top * 0.45, 0)
		main.cam_rig.reset_view(1.1 + top * 1.6, -0.2, 0.0)
		main.cam_rig.screen_shift = 0.32
	else:
		main.cam_rig.focus = c.position + Vector3(0, top * 0.45, 0)
		main.cam_rig.reset_view(1.2 + top * 1.9, -0.2, 0.45)
		main.cam_rig.screen_shift = 0.4
	for k in candidates.size():
		candidates[k].busy = true
		candidates[k].player_pos = Vector3(candidates[k].position.x, 0, 1.0)
	if greet:
		c.model.emote("emo_heart")
		c.voice()
		c.play_bow()

func _clear() -> void:
	for ch in get_children():
		ch.queue_free()

func _build_choose() -> void:
	_clear()
	step = "choose"
	var v := UiKit.vbox(10)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var top := UiKit.panel(16)
	var tl := UiKit.label(tr("Bienvenue au refuge ! Choisissez votre compagnon.") if first else tr("Adopter un nouveau compagnon"), 30, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(tl)
	v.add_child(top)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var nav := UiKit.hbox(12)
	nav.add_child(UiKit.button("[i:left]", func(): _move(-1), UiKit.C_BLUE, 40, 96))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_child(sp2)
	nav.add_child(UiKit.button("[i:right]", func(): _move(1), UiKit.C_BLUE, 40, 96))
	for b in nav.get_children():
		if b is Button:
			b.custom_minimum_size = Vector2(110, 96)
	v.add_child(nav)
	var pnl := UiKit.panel(22)
	info_box = UiKit.vbox(10)
	pnl.add_child(info_box)
	v.add_child(pnl)
	_fill_info()

func _fill_info() -> void:
	for ch in info_box.get_children():
		ch.queue_free()
	var b := GameData.breed(GameData.BREED_ORDER[idx])
	var t: Dictionary = GameData.TEMPERAMENTS[temps[idx]]
	info_box.add_child(UiKit.label("%s  ·  %s" % [tr(b["name"]), tr(t["name"])], 38))
	info_box.add_child(UiKit.label(tr(b["desc"]) + " " + tr(t["desc"]), 25, UiKit.C_SUB))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 20)
	var names := {"agility": "Agilité", "nose": "Flair", "intelligence": "Intelligence", "stamina": "Endurance"}
	for k in ["agility", "nose", "intelligence", "stamina"]:
		var h := UiKit.hbox(8)
		var l := UiKit.label(tr(names[k]), 22, UiKit.C_SUB)
		l.custom_minimum_size = Vector2(140, 0)
		h.add_child(l)
		h.add_child(UiKit.expand(UiKit.bar(float(b["stats"][k]), UiKit.C_ACCENT2, 18)))
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(h)
	info_box.add_child(g)
	var price := 0 if first else GameData.ADOPT_PRICE
	var txt := tr("Adopter") if price == 0 else "[i:coin] " + tr("Adopter (%d pièces)") % price
	var btn := UiKit.button(txt, _adopt, UiKit.C_ACCENT, 34, 96)
	info_box.add_child(btn)
	if not first:
		info_box.add_child(UiKit.button(tr("Retour à la maison"), func():
			Main.inst.change_env("house")
			Main.inst.show_screen("home"), UiKit.C_DISABLED, 28, 76))

func _move(d: int) -> void:
	idx = wrapi(idx + d, 0, candidates.size())
	_fill_info()
	_focus()

func _adopt() -> void:
	if not first:
		if GameState.level() < 2:
			Main.inst.toast(tr("Atteignez le niveau 2 pour adopter un autre animal."))
			return
		if GameState.coins() < GameData.ADOPT_PRICE:
			Main.inst.toast(tr("Pas assez de pièces"))
			return
		if GameState.data["pets"].size() >= 6:
			Main.inst.toast(tr("Votre maison est pleine (6 animaux maximum)."))
			return
	var b := GameData.BREED_ORDER[idx]
	var sex := "m" if randf() < 0.5 else "f"
	custom = {"breed": b, "palette": 0, "eyes": 0, "collar": "collar_red", "accessory": "acc_none", "sex": sex,
		"name": (NAMES_M if sex == "m" else NAMES_F)[randi() % 10]}
	_build_custom(true)

func _preview() -> void:
	var c := candidates[idx]
	var p := c.pet.duplicate(true)
	for k in custom.keys():
		p[k] = custom[k]
	c.pet = GameState.sanitize_pet(p)
	c.refresh_look()

func _build_custom(refocus: bool = false, detail: String = "") -> void:
	_clear()
	step = "custom"
	_preview()
	if refocus:
		_focus("body", true)
	elif detail != "":
		_focus(detail, false)
	var v := UiKit.vbox(10)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.custom_minimum_size = Vector2(0, 480)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var pnl := UiKit.panel(20)
	pnl.custom_minimum_size = Vector2(0, 540)
	v.add_child(pnl)
	var inner := UiKit.vbox(14)
	pnl.add_child(UiKit.scroll(inner))
	var b := GameData.breed(custom["breed"])
	# Nom
	inner.add_child(UiKit.label(tr("Nom"), 26, UiKit.C_SUB))
	var nh := UiKit.hbox(10)
	var le := LineEdit.new()
	le.text = custom["name"]
	le.max_length = 16
	le.custom_minimum_size = Vector2(0, 84)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(t): custom["name"] = t)
	nh.add_child(le)
	var dice := UiKit.button("[i:dice]", func():
		custom["name"] = (NAMES_M if custom["sex"] == "m" else NAMES_F)[randi() % 10]
		le.text = custom["name"], UiKit.C_BLUE, 34, 84)
	dice.custom_minimum_size = Vector2(90, 84)
	nh.add_child(dice)
	inner.add_child(nh)
	# Sexe
	var sh := UiKit.hbox(10)
	for s in [["m", "[i:male] " + tr("Mâle")], ["f", "[i:female] " + tr("Femelle")]]:
		var sel: bool = custom["sex"] == s[0]
		var bt := UiKit.button(s[1], func():
			custom["sex"] = s[0]
			_build_custom(false, "body"), UiKit.C_ACCENT if sel else UiKit.C_DISABLED, 28, 76)
		sh.add_child(UiKit.expand(bt))
	inner.add_child(sh)
	# Pelage
	inner.add_child(UiKit.label(tr("Pelage : %s") % tr(b["palettes"][custom["palette"]]["name"]), 26, UiKit.C_SUB))
	var ph := HFlowContainer.new()
	ph.add_theme_constant_override("h_separation", 12)
	for i in b["palettes"].size():
		var ii: int = i
		ph.add_child(UiKit.swatch(b["palettes"][i]["main"], i == custom["palette"], func():
			custom["palette"] = ii
			_build_custom(false, "body")))
	inner.add_child(ph)
	# Yeux
	inner.add_child(UiKit.label(tr("Yeux : %s") % tr(GameData.EYE_NAMES[custom["eyes"]]), 26, UiKit.C_SUB))
	var eh := HFlowContainer.new()
	eh.add_theme_constant_override("h_separation", 12)
	for i in GameData.EYE_COLORS.size():
		var ii: int = i
		eh.add_child(UiKit.swatch(GameData.EYE_COLORS[i], i == custom["eyes"], func():
			custom["eyes"] = ii
			_build_custom(false, "head"), 64))
	inner.add_child(eh)
	# Collier
	inner.add_child(UiKit.label(tr("Collier"), 26, UiKit.C_SUB))
	var ch := HFlowContainer.new()
	ch.add_theme_constant_override("h_separation", 12)
	for id in GameState.data["owned"]:
		var it := GameData.item(id)
		if it.get("cat", "") == "collar":
			var iid: String = id
			ch.add_child(UiKit.swatch(it["color"], custom["collar"] == id, func():
				custom["collar"] = iid
				_build_custom(false, "neck"), 64))
	inner.add_child(ch)
	# Accessoire
	inner.add_child(UiKit.label(tr("Accessoire"), 26, UiKit.C_SUB))
	var ah := HFlowContainer.new()
	ah.add_theme_constant_override("h_separation", 10)
	ah.add_theme_constant_override("v_separation", 10)
	for id in GameState.data["owned"]:
		var it := GameData.item(id)
		if it.get("cat", "") == "accessory":
			var iid: String = id
			var bt := UiKit.icon_button(it["icon"], tr(it["name"]), func():
				custom["accessory"] = iid
				_build_custom(false, "neck" if iid in ["bandana", "scarf"] else "head"), UiKit.C_GOLD if custom["accessory"] == id else Color(1, 1, 1, 0.95), 104)
			ah.add_child(bt)
	inner.add_child(ah)
	var bh := UiKit.hbox(12)
	bh.add_child(UiKit.expand(UiKit.button(tr("Retour"), func():
		candidates[idx].pet = GameState.sanitize_pet({"breed": custom["breed"]})
		candidates[idx].refresh_look()
		_build_choose()
		_focus(), UiKit.C_DISABLED, 30, 92)))
	bh.add_child(UiKit.expand(UiKit.button(tr("C'est parti !"), _confirm, UiKit.C_ACCENT2, 32, 92)))
	v.add_child(bh)

func _confirm() -> void:
	var nm := str(custom["name"]).strip_edges()
	if nm == "":
		Main.inst.toast(tr("Donnez un nom à votre compagnon."))
		return
	if not first:
		if not GameState.spend(GameData.ADOPT_PRICE):
			Main.inst.toast(tr("Pas assez de pièces"))
			return
	var p := GameState.create_pet(custom["breed"], nm, custom["sex"], custom["palette"], custom["eyes"], custom["collar"], custom["accessory"], temps[idx])
	Audio.play("success")
	var main := Main.inst
	main.change_env("house")
	main.show_screen("home", {"welcome": first})
	main.toast(tr("%s rejoint votre famille !") % p["name"])
