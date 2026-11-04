class_name Panels
extends RefCounted
## Panneaux modaux : besoins, boutique, sac, dressage, activités, concours,
## album, objectifs, succès, déco, animaux, lieux, paramètres.

static var _thumb_cache := {}

static func _t(s: String) -> String:
	return TranslationServer.translate(s)

static func _m() -> Main:
	return Main.inst

static func _row(left: Control, right: Control) -> HBoxContainer:
	var h := UiKit.hbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	h.add_child(right)
	return h

static func _card(color: Color = Color(1, 0.96, 0.9)) -> PanelContainer:
	return UiKit.panel(16, color)

# ================================================================== Besoins
static func needs() -> void:
	var p := GameState.active_pet()
	if p.is_empty():
		return
	var v := UiKit.vbox(14)
	for k in GameData.NEED_KEYS:
		var val: float = p["needs"][k]
		var row := UiKit.need_row(k, val, 44, 26, 26)
		var name_l := UiKit.label(_t(GameData.NEED_NAMES[k]), 26)
		name_l.custom_minimum_size = Vector2(170, 0)
		(row[0] as HBoxContainer).add_child(name_l)
		(row[0] as HBoxContainer).move_child(name_l, 1)
		v.add_child(row[0])
	var worst := GameState.lowest_need(p)
	var tips := {
		"hunger": "Il a faim : donnez-lui un repas.", "thirst": "Il a soif : remplissez sa gamelle d'eau.",
		"clean": "Un bon bain lui ferait du bien.", "energy": "Il est fatigué : laissez-le dormir dans son panier.",
		"affection": "Il a besoin de câlins : caressez-le !", "outside": "Il a besoin de sortir : allez au jardin ou en promenade.", "mood": "Jouez avec lui pour lui remonter le moral.", "health": "Prenez soin de ses besoins et offrez-lui des vitamines.",
	}
	v.add_child(UiKit.spacer(8))
	var tip := _card()
	tip.add_child(UiKit.label("[i:tip] " + (_t(tips[worst]) if p["needs"][worst] < 60.0 else _t("%s est en pleine forme !") % p["name"]), 26))
	v.add_child(tip)
	v.add_child(UiKit.label(_t("Les besoins évoluent même quand le jeu est fermé, mais doucement : votre compagnon ne peut jamais disparaître."), 22, UiKit.C_SUB))
	_m().open_panel(_t("Besoins de %s") % p["name"], UiKit.scroll(v))

# ================================================================== Fiche animal
static func pet_info() -> void:
	var p := GameState.active_pet()
	if p.is_empty():
		return
	var b := GameData.breed(p["breed"])
	var v := UiKit.vbox(12)
	v.add_child(UiKit.label("%s · %s · %s" % [_t(b["name"]), _t("Mâle") if p["sex"] == "m" else _t("Femelle"), _t(GameData.TEMPERAMENTS[p["temperament"]]["name"])], 28))
	var rl := GameState.relation_level(p)
	v.add_child(UiKit.label("[i:relation] " + _t("Relation : niveau %d (%s)") % [rl, _t(GameData.RELATION_NAMES[rl - 1])], 26))
	v.add_child(UiKit.bar(GameState.relation_progress(p) * 100.0, Color(0.95, 0.5, 0.7), 20))
	var days := int((Time.get_unix_time_from_system() - float(p["adopted"])) / 86400.0)
	v.add_child(UiKit.label(_t("Adopté depuis %d jour(s) · %d victoire(s)") % [days, int(p.get("wins", 0))], 24, UiKit.C_SUB))
	v.add_child(UiKit.label(_t("Caractère"), 30))
	var tnames := {"energy": "Énergie", "obedience": "Obéissance", "curiosity": "Curiosité", "affection": "Câlin", "gluttony": "Gourmandise", "independence": "Indépendance"}
	for k in tnames.keys():
		var h := UiKit.hbox(8)
		var l := UiKit.label(_t(tnames[k]), 24, UiKit.C_SUB)
		l.custom_minimum_size = Vector2(220, 0)
		h.add_child(l)
		h.add_child(UiKit.expand(UiKit.bar(float(p["traits"].get(k, 50)), UiKit.C_ACCENT, 18)))
		v.add_child(h)
	v.add_child(UiKit.label(_t("Ordres"), 30))
	for c in GameData.COMMAND_ORDER:
		var s: float = p["skills"][c]
		var h2 := UiKit.hbox(8)
		var l2 := UiKit.label("%s — %s" % [_t(GameData.COMMANDS[c]["name"]), _t(GameData.skill_label(s))], 22, UiKit.C_TEXT)
		l2.custom_minimum_size = Vector2(330, 0)
		h2.add_child(l2)
		h2.add_child(UiKit.expand(UiKit.bar(s, UiKit.C_BLUE, 16)))
		v.add_child(h2)
	var rn := UiKit.hbox(10)
	var le := LineEdit.new()
	le.text = p["name"]
	le.max_length = 16
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rn.add_child(le)
	rn.add_child(UiKit.button(_t("Renommer"), func():
		var t := le.text.strip_edges()
		if t != "":
			p["name"] = t
			GameState.pet_changed.emit()
			GameState.mark_dirty()
			_m().toast(_t("Nouveau nom : %s") % t), UiKit.C_BLUE, 26, 80))
	v.add_child(rn)
	v.add_child(UiKit.button(_t("Personnaliser (collier, accessoire)"), func(): customize(), UiKit.C_ACCENT2, 26, 80))
	_m().open_panel(p["name"], UiKit.scroll(v))

static func customize() -> void:
	var p := GameState.active_pet()
	var v := UiKit.vbox(12)
	for kind in ["collar", "accessory"]:
		v.add_child(UiKit.label(_t("Colliers") if kind == "collar" else _t("Accessoires"), 30))
		var g := HFlowContainer.new()
		g.add_theme_constant_override("h_separation", 10)
		g.add_theme_constant_override("v_separation", 10)
		for id in GameState.data["owned"]:
			var it := GameData.item(id)
			if it.get("cat", "") != kind:
				continue
			var iid: String = id
			var k: String = kind
			var sel: bool = p.get(kind, "") == id
			g.add_child(UiKit.icon_button(it["icon"], _t(it["name"]), func():
				GameState.equip(k, iid)
				_m().close_panel()
				customize(), UiKit.C_GOLD if sel else Color(1, 1, 1, 0.95), 116))
		v.add_child(g)
	v.add_child(UiKit.label(_t("Plus de choix dans la boutique !"), 22, UiKit.C_SUB))
	_m().open_panel(_t("Personnaliser"), UiKit.scroll(v))

# ================================================================== Choix de nourriture
static func food_picker(cat: String, cb: Callable) -> void:
	var v := UiKit.vbox(12)
	var g := HFlowContainer.new()
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	var any := false
	for id in GameData.ITEMS.keys():
		var it: Dictionary = GameData.ITEMS[id]
		if it["cat"] != cat or GameState.item_count(id) <= 0:
			continue
		any = true
		var iid: String = id
		g.add_child(UiKit.icon_button(it["icon"], "%s ×%d" % [_t(it["name"]), GameState.item_count(id)], func():
			_m().close_panel()
			cb.call(iid), Color(1, 0.96, 0.9), 150))
	v.add_child(g)
	if not any:
		v.add_child(UiKit.label(_t("Votre sac est vide ! Passez à la boutique."), 28))
		v.add_child(UiKit.button(_t("Aller à la boutique"), func():
			_m().close_panel()
			shop("food" if cat == "food" else "treat"), UiKit.C_ACCENT))
	_m().open_panel(_t("Que lui donner ?"), UiKit.scroll(v))

# ================================================================== Boutique
static func shop(tab: String = "food") -> void:
	var v := UiKit.vbox(12)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	for t in GameData.SHOP_TABS:
		var tt: String = t
		var b := UiKit.button(_t(GameData.SHOP_TAB_NAMES[t]), func():
			_m().close_panel()
			shop(tt), UiKit.C_ACCENT if t == tab else UiKit.C_DISABLED, 22, 60)
		tabs.add_child(b)
	v.add_child(tabs)
	var coins := UiKit.label("[i:coin] " + _t("Vos pièces : %d") % GameState.coins(), 26, UiKit.C_SUB)
	v.add_child(coins)
	var list := UiKit.vbox(10)
	if tab == "env":
		for id in GameData.ENV_ORDER:
			var e: Dictionary = GameData.ENVIRONMENTS[id]
			if int(e["price"]) <= 0:
				continue
			var iid: String = id
			var owned := GameState.env_unlocked(id)
			var c := _card()
			var info := UiKit.vbox(2)
			info.add_child(UiKit.label("[i:%s] %s" % [e["icon"], _t(e["name"])], 30))
			info.add_child(UiKit.label(_t("Nouveau lieu de promenade et de jeu · niveau %d") % int(e["level"]), 22, UiKit.C_SUB))
			var btn := UiKit.button(_t("Débloqué") if owned else "[i:coin] %d" % int(e["price"]), func():
				var err := GameState.buy_env(iid)
				if err == "":
					Audio.play("coin")
					_m().toast(_t("%s débloqué !") % _t(e["name"]))
					_m().close_panel()
					shop("env")
				else:
					Audio.play("buzz")
					_m().toast(err), UiKit.C_ACCENT2, 26, 80)
			btn.disabled = owned
			btn.custom_minimum_size = Vector2(190, 80)
			c.add_child(_row(info, btn))
			list.add_child(c)
	else:
		for id in GameData.ITEMS.keys():
			var it: Dictionary = GameData.ITEMS[id]
			if it["cat"] != tab or (int(it["price"]) == 0 and not GameState.CONSUMABLE_CAT(it)):
				continue
			var iid: String = id
			var consumable := GameState.CONSUMABLE_CAT(it)
			var owned: bool = not consumable and GameState.data["owned"].has(id)
			var c := _card()
			var info := UiKit.vbox(2)
			var title: String = "[i:%s] %s" % [it["icon"], _t(it["name"])]
			if consumable:
				title += "  (×%d)" % GameState.item_count(id)
			info.add_child(UiKit.label(title, 28))
			var desc := _t(it["desc"])
			if it.has("fx"):
				var parts: Array[String] = []
				for k in it["fx"].keys():
					parts.append("%s+%d" % [GameData.NEED_ICONS.get(k, ""), int(it["fx"][k])])
				desc += "  " + " ".join(parts)
			if int(it.get("level", 1)) > GameState.level():
				desc += "  · " + _t("verrouillé, niveau %d") % int(it["level"])
			info.add_child(UiKit.label(desc, 21, UiKit.C_SUB))
			var btn := UiKit.button(_t("Possédé") if owned else "[i:coin] %d" % int(it["price"]), func():
				var err := GameState.buy(iid)
				if err == "":
					Audio.play("coin")
					_m().toast(_t("Acheté : %s") % _t(it["name"]))
					_m().close_panel()
					shop(tab)
				else:
					Audio.play("buzz")
					_m().toast(err), UiKit.C_ACCENT2, 26, 80)
			btn.disabled = owned
			btn.custom_minimum_size = Vector2(170, 80)
			c.add_child(_row(info, btn))
			list.add_child(c)
	v.add_child(list)
	_m().open_panel("[i:shop] " + _t("Boutique"), UiKit.scroll(v))

# ================================================================== Sac
static func inventory() -> void:
	var v := UiKit.vbox(12)
	v.add_child(UiKit.label(_t("Consommables"), 30))
	var g := HFlowContainer.new()
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	for id in GameData.ITEMS.keys():
		var it: Dictionary = GameData.ITEMS[id]
		if not GameState.CONSUMABLE_CAT(it) or GameState.item_count(id) <= 0:
			continue
		var iid: String = id
		g.add_child(UiKit.icon_button(it["icon"], "%s ×%d" % [_t(it["name"]), GameState.item_count(id)], func(): _use_item(iid), Color(1, 0.96, 0.9), 132))
	if g.get_child_count() == 0:
		v.add_child(UiKit.label(_t("Rien pour l'instant."), 24, UiKit.C_SUB))
	v.add_child(g)
	v.add_child(UiKit.label(_t("Jouet actif"), 30))
	var tg := HFlowContainer.new()
	tg.add_theme_constant_override("h_separation", 10)
	tg.add_theme_constant_override("v_separation", 10)
	for id in GameState.data["owned"]:
		var it2 := GameData.item(id)
		if it2.get("cat", "") != "toy":
			continue
		var iid2: String = id
		tg.add_child(UiKit.icon_button(it2["icon"], _t(it2["name"]), func():
			GameState.set_toy(iid2)
			_m().close_panel()
			inventory(), UiKit.C_GOLD if GameState.data["toy"] == id else Color(1, 1, 1, 0.95), 132))
	v.add_child(tg)
	v.add_child(UiKit.button(_t("Colliers et accessoires"), func(): customize(), UiKit.C_ACCENT2, 26, 80))
	v.add_child(UiKit.button(_t("Décorer la maison"), func(): deco(), UiKit.C_BLUE, 26, 80))
	var fd: Dictionary = GameState.data["finds"]
	if not fd.is_empty():
		v.add_child(UiKit.label(_t("Trouvailles de promenade"), 30))
		var keys: Array = fd.keys()
		keys.sort()
		var txt := ""
		for k in keys:
			txt += "%s ×%d   " % [k, int(fd[k])]
		v.add_child(UiKit.label(txt, 24, UiKit.C_SUB))
	_m().open_panel("[i:inventory] " + _t("Sac"), UiKit.scroll(v))

static func _use_item(iid: String) -> void:
	_m().close_panel()
	var it := GameData.item(iid)
	var hud: Node = _m().screen
	match str(it.get("cat", "")):
		"food":
			if hud and hud.has_method("feed"):
				hud.feed(iid)
		"treat":
			if hud and hud.has_method("give_treat"):
				hud.give_treat(iid)
		"care":
			if GameState.use_care(iid):
				Audio.play("chime")
				_m().toast(_t("%s utilisé !") % _t(it["name"]))
				if _m().pet_ctrl:
					_m().pet_ctrl.model.emote("emo_sparkle")

# ================================================================== Déco
static func deco() -> void:
	var v := UiKit.vbox(12)
	for slot in GameData.DECO_SLOTS:
		v.add_child(UiKit.label(_t(GameData.DECO_SLOT_NAMES[slot]), 28))
		var g := HFlowContainer.new()
		g.add_theme_constant_override("h_separation", 10)
		g.add_theme_constant_override("v_separation", 10)
		var cur: String = GameState.data["deco"].get(slot, "")
		var sl: String = slot
		if slot in ["plant", "lamp", "frame", "box"]:
			g.add_child(UiKit.icon_button("acc_none", _t("Aucun"), func():
				GameState.set_deco(sl, "")
				_after_deco(), UiKit.C_GOLD if cur == "" else Color(1, 1, 1, 0.95), 140))
		var count := 0
		for id in GameState.data["owned"]:
			var it := GameData.item(id)
			if it.get("slot", "") != slot:
				continue
			count += 1
			var iid: String = id
			g.add_child(UiKit.icon_button(it["icon"], _t(it["name"]), func():
				GameState.set_deco(sl, iid)
				_after_deco(), UiKit.C_GOLD if cur == id else Color(1, 1, 1, 0.95), 140))
		v.add_child(g)
	v.add_child(UiKit.button(_t("Acheter des décorations"), func():
		_m().close_panel()
		shop("deco"), UiKit.C_ACCENT, 26, 80))
	_m().open_panel("[i:house] " + _t("Décorer"), UiKit.scroll(v))

static func _after_deco() -> void:
	Audio.play("pop")
	_m().close_panel()
	if _m().env_id == "house":
		_m().rebuild_env()
	else:
		_m().toast(_t("Changement appliqué à la maison."))
	deco()

# ================================================================== Lieux
static func places() -> void:
	var v := UiKit.vbox(12)
	for id in GameData.ENV_ORDER:
		var e: Dictionary = GameData.ENVIRONMENTS[id]
		var iid: String = id
		var unlocked := GameState.env_unlocked(id)
		var c := _card(Color(1, 0.97, 0.9) if _m().env_id != id else Color(0.9, 0.97, 0.9))
		var info := UiKit.vbox(2)
		info.add_child(UiKit.label("[i:%s] %s" % [e["icon"], _t(e["name"])], 30))
		var sub := ""
		match id:
			"house": sub = _t("Repos, repas, décoration")
			"garden": sub = _t("Jeux de balle, promenade, sieste dans la niche")
			"park": sub = _t("Grand espace, rencontres, fontaine")
			"beach": sub = _t("Sable, vagues et coquillages")
			"center": sub = _t("Agilité et concours")
			"shelter": sub = _t("Adopter un nouveau compagnon")
		if not unlocked:
			sub += "  · " + _t("à débloquer : Boutique › Lieux")
		info.add_child(UiKit.label(sub, 21, UiKit.C_SUB))
		var btn := UiKit.button(_t("Ici") if _m().env_id == id else _t("Y aller"), func():
			_m().close_panel()
			go_to(iid), UiKit.C_BLUE, 26, 80)
		btn.disabled = not unlocked or _m().env_id == id
		btn.custom_minimum_size = Vector2(160, 80)
		c.add_child(_row(info, btn))
		v.add_child(c)
	_m().open_panel("[i:map] " + _t("Lieux"), UiKit.scroll(v))

static func go_to(id: String) -> void:
	if id == "shelter":
		_m().show_screen("adopt", {"first": false})
		return
	_m().change_env(id)
	if _m().screen and _m().screen.has_method("refresh"):
		_m().screen.refresh()

# ================================================================== Animaux
static func pets() -> void:
	var v := UiKit.vbox(12)
	for p in GameState.data["pets"]:
		var b := GameData.breed(p["breed"])
		var pid: String = p["id"]
		var active: bool = p["id"] == GameState.data["active_pet"]
		var c := _card(Color(0.9, 0.97, 0.9) if active else Color(1, 0.97, 0.9))
		var info := UiKit.vbox(2)
		info.add_child(UiKit.label("%s  (%s)" % [p["name"], _t(b["name"])], 28))
		info.add_child(UiKit.label("[i:relation] " + _t("Relation %d · Niv. %d · Faim %d %% · Bonheur %d %%") % [GameState.relation_level(p), int(p.get("level", 1)), int(p["needs"]["hunger"]), int(p["needs"]["mood"])], 22, UiKit.C_SUB))
		var btn := UiKit.button(_t("Actif") if active else _t("Choisir"), func():
			GameState.set_active_pet(pid)
			_m().close_panel()
			if _m().screen and _m().screen.has_method("refresh"):
				_m().screen.refresh(), UiKit.C_ACCENT2, 26, 80)
		btn.disabled = active
		btn.custom_minimum_size = Vector2(160, 80)
		c.add_child(_row(info, btn))
		v.add_child(c)
	v.add_child(UiKit.label(_t("Adoption : %d pièces, niveau 2 minimum, 6 animaux maximum.") % GameData.ADOPT_PRICE, 22, UiKit.C_SUB))
	v.add_child(UiKit.button("[i:shelter] " + _t("Aller au refuge"), func():
		_m().close_panel()
		go_to("shelter"), UiKit.C_ACCENT))
	_m().open_panel("[i:paw] " + _t("Mes animaux"), UiKit.scroll(v))

# ================================================================== Jouer
static func play(hud: Node) -> void:
	var v := UiKit.vbox(12)
	var entries := [
		["throw", "Lancer la balle", "Glissez vers le haut pour lancer, il vous la rapporte.", "fetch", func(): hud.throw_free()],
		["tug", "Tir à la corde", "Tirez par petits coups, il tire aussi !", "tug", func(): _m().start_activity(TugActivity.new())],
		["ball", "Jouer avec son jouet", "Il s'amuse tout seul avec son jouet préféré.", "fetch", func():
			if _m().pet_ctrl:
				_m().pet_ctrl.play_with_toy()],
		["search", "Cache-cache", "Cachez des objets et laissez parler son flair.", "search", func(): _choose_place("search")],
		["training", "Jeux d'obéissance", "Révisez ses ordres et faites-le progresser.", "fetch", func(): training()],
	]
	for e in entries:
		var cb: Callable = e[4]
		var key: String = e[3]
		var c := _card()
		var info := UiKit.vbox(2)
		info.add_child(UiKit.label("[i:%s] %s" % [e[0], _t(e[1])], 28))
		info.add_child(UiKit.label(_t(e[2]), 21, UiKit.C_SUB))
		var btn := UiKit.button(_t("Jouer"), func():
			_m().close_panel()
			cb.call(), UiKit.C_ACCENT2, 26, 80)
		btn.custom_minimum_size = Vector2(150, 80)
		if not GameState.activity_unlocked(key):
			btn.disabled = true
			btn.text = _t("Niv. %d") % int(GameData.ACTIVITY_LEVELS[key])
		c.add_child(_row(info, btn))
		v.add_child(c)
	_m().open_panel("[i:throw] " + _t("Jouer"), UiKit.scroll(v))

# ================================================================== Dressage
static func training() -> void:
	var v := UiKit.vbox(10)
	var p := GameState.active_pet()
	v.add_child(UiKit.label(_t("Motivation de %s : %d %%") % [p["name"], int(GameState.motivation(p) * 100.0)], 26, UiKit.C_SUB))
	for cmd in GameData.COMMAND_ORDER:
		var d: Dictionary = GameData.COMMANDS[cmd]
		var s := GameState.skill(cmd)
		var avail := GameState.command_available(cmd)
		var cc: String = cmd
		var c := _card()
		var info := UiKit.vbox(4)
		info.add_child(UiKit.label("%s  ·  %s" % [_t(d["name"]), _t(GameData.skill_label(s))], 28))
		info.add_child(UiKit.bar(s, UiKit.C_BLUE, 16))
		var sub := _t("Geste : %s") % _t(d["hint"])
		var nv := Voice.template_count(p, cmd)
		if nv > 0:
			sub += "  ·  " + _t("voix « %s » (%s)") % [Voice.word(p, cmd), Voice.reliability_label(Voice.reliability(p, cmd))]
		if not avail:
			sub = "[i:lock] " + _t("Niveau %d du compagnon") % int(d["level"])
		info.add_child(UiKit.label(sub, 21, UiKit.C_SUB))
		var btn := UiKit.button(_t("Entraîner"), func():
			_m().close_panel()
			_m().start_activity(TrainingActivity.new(cc)), UiKit.C_BLUE, 26, 80)
		btn.disabled = not avail
		btn.custom_minimum_size = Vector2(170, 80)
		c.add_child(_row(info, btn))
		v.add_child(c)
	v.add_child(UiKit.label(_t("Astuce : de courtes séances régulières sont plus efficaces. Récompensez uniquement les réussites ! Pendant une séance, associez votre propre mot à chaque ordre (micro)."), 22, UiKit.C_SUB))
	_m().open_panel("[i:training] " + _t("Dressage"), UiKit.scroll(v))

# ================================================================== Activités
static func activities() -> void:
	var v := UiKit.vbox(12)
	var lvl: Dictionary = GameData.SEARCH_LEVELS[int(GameState.data["search_level"])]
	var entries := [
		["throw", "Lancer de balle", "Visez avec le doigt : la distance du geste règle la puissance.", "fetch"],
		["agility", "Parcours d'agilité", "Haies, tunnels, slaloms, passerelles : touchez le gros bouton au bon moment ! 5 niveaux, médailles et records.", "agility"],
		["search", "Jeu de recherche", _t("Niveau %d : %d cachettes, %d essais.") % [int(GameState.data["search_level"]) + 1, int(lvl["spots"]), int(lvl["tries"])], "search"],
		["walk", "Promenade", "Explorez, ramassez des trouvailles et faites des rencontres.", "walk"],
	]
	for e in entries:
		var kind: String = e[3]
		var c := _card()
		var info := UiKit.vbox(2)
		info.add_child(UiKit.label("%s %s" % [e[0], _t(e[1])], 30))
		info.add_child(UiKit.label(_t(e[2]), 21, UiKit.C_SUB))
		var btn := UiKit.button(_t("Jouer"), func():
			_m().close_panel()
			if kind == "agility":
				agility_levels()
			else:
				_choose_place(kind), UiKit.C_ACCENT2, 26, 80)
		btn.custom_minimum_size = Vector2(150, 80)
		if not GameState.activity_unlocked(kind):
			btn.disabled = true
			btn.text = _t("Niv. %d") % int(GameData.ACTIVITY_LEVELS[kind])
			info.add_child(UiKit.label("[i:lock] " + _t("Débloqué au niveau %d de votre compagnon") % int(GameData.ACTIVITY_LEVELS[kind]), 21, UiKit.C_DANGER))
		c.add_child(_row(info, btn))
		v.add_child(c)
	var p := GameState.active_pet()
	if p["needs"]["energy"] < 20.0:
		v.add_child(UiKit.label("[i:warning] " + _t("%s est fatigué : il jouera moins bien.") % p["name"], 24, UiKit.C_DANGER))
	_m().open_panel("[i:activities] " + _t("Activités"), UiKit.scroll(v))

static func _choose_place(kind: String) -> void:
	var allowed: Array = []
	match kind:
		"fetch": allowed = ["garden", "park", "beach"]
		"walk": allowed = ["garden", "park", "beach"]
		"search": allowed = ["house", "garden", "park", "beach"]
		"agility": allowed = ["center"]
	var unlocked: Array = allowed.filter(func(e): return GameState.env_unlocked(e))
	if unlocked.size() == 1 or (unlocked.has(_m().env_id) and kind != "walk"):
		_launch(kind, _m().env_id if unlocked.has(_m().env_id) else unlocked[0])
		return
	var v := UiKit.vbox(12)
	for e in unlocked:
		var ee: String = e
		var d: Dictionary = GameData.ENVIRONMENTS[e]
		v.add_child(UiKit.button("[i:%s] %s" % [d["icon"], _t(d["name"])], func():
			_m().close_panel()
			_launch(kind, ee), UiKit.C_BLUE, 30, 96))
	for e in allowed:
		if not unlocked.has(e):
			var d2: Dictionary = GameData.ENVIRONMENTS[e]
			var b := UiKit.button("[i:lock] %s" % _t(d2["name"]), Callable(), UiKit.C_DISABLED, 28, 88)
			b.disabled = true
			v.add_child(b)
	_m().open_panel(_t("Où jouer ?"), UiKit.scroll(v))

static func _launch(kind: String, env: String) -> void:
	if _m().env_id != env:
		_m().change_env(env)
		if _m().screen and _m().screen.has_method("refresh"):
			_m().screen.refresh()
	match kind:
		"fetch": _m().start_activity(FetchGame.new(false))
		"agility": agility_levels()
		"search": _m().start_activity(SearchGame.new({}))
		"walk": _m().start_activity(WalkActivity.new())

# ================================================================== Agilité : niveaux
static func agility_levels() -> void:
	var v := UiKit.vbox(12)
	var p := GameState.active_pet()
	v.add_child(UiKit.label(_t("Touchez le gros bouton d'action quand la jauge est dans la zone verte. Or : 85, argent : 65, bronze : 45."), 22, UiKit.C_SUB))
	for lv in GameData.AGILITY_LEVELS.size():
		var L: Dictionary = GameData.AGILITY_LEVELS[lv]
		var req := GameState.agility_requirements(lv)
		var best := GameState.record("agility_%d" % lv)
		var best_t := GameState.record("agility_time_%d" % lv)
		var c := _card(Color(1, 0.97, 0.9) if req == "" else Color(0.95, 0.94, 0.92))
		var info := UiKit.vbox(3)
		var title := "%s · %d %s" % [_t(L["name"]), int(L["obstacles"]), _t("obstacles")]
		if best >= 0.0:
			var medal := GameData.medal_for(best)
			title = ("[i:medal_%s] " % medal if medal != "" else "") + title
		info.add_child(UiKit.label(title, 28))
		var names: Array[String] = []
		for k in L["kinds"]:
			names.append(_t(GameData.AGILITY_OBSTACLES[k]["name"]).to_lower())
		info.add_child(UiKit.label(", ".join(names), 20, UiKit.C_SUB))
		if best >= 0.0:
			info.add_child(UiKit.label("[i:star] " + _t("Record de %s : %d / 100 · %.1f s") % [p["name"], int(best), best_t], 21, UiKit.C_ACCENT))
		if req != "":
			info.add_child(UiKit.label("[i:lock] " + req, 21, UiKit.C_DANGER))
		else:
			info.add_child(UiKit.label("[i:coin] " + _t("Jusqu'à %d pièces · énergie requise : %d %%") % [int(L["coins"]), int(L["energy"])], 20, UiKit.C_SUB))
		var ll := lv
		var btn := UiKit.button(_t("Jouer"), func():
			_m().close_panel()
			if _m().env_id != "center":
				_m().change_env("center")
				if _m().screen and _m().screen.has_method("refresh"):
					_m().screen.refresh()
			_m().start_activity(AgilityGame.new({"level": ll})), UiKit.C_ACCENT2, 26, 80)
		btn.disabled = req != ""
		btn.custom_minimum_size = Vector2(150, 80)
		c.add_child(_row(info, btn))
		v.add_child(c)
	_m().open_panel("[i:agility] " + _t("Parcours d'agilité"), UiKit.scroll(v))

# ================================================================== Concours
static func competitions() -> void:
	var v := UiKit.vbox(12)
	v.add_child(UiKit.label(_t("Inscrivez votre compagnon et affrontez 7 concurrents. Le podium rapporte des pièces et un trophée !"), 22, UiKit.C_SUB))
	for cat in GameData.COMP_ORDER:
		var cd: Dictionary = GameData.COMP_CATS[cat]
		var c := _card()
		var inner := UiKit.vbox(8)
		inner.add_child(UiKit.label("[i:%s] %s" % [cd["icon"], _t(cd["name"])], 32))
		inner.add_child(UiKit.label(_t(cd["desc"]), 21, UiKit.C_SUB))
		var best := int(GameState.data["comp"].get(cat, -1))
		var g := GridContainer.new()
		g.columns = 2
		for lv in GameData.COMP_LEVELS.size():
			var L: Dictionary = GameData.COMP_LEVELS[lv]
			var req := GameState.comp_requirements(cat, lv)
			var won := best >= lv
			var cc: String = cat
			var ll: int = lv
			var txt := ("[i:medal_gold] " if won else "") + _t(L["name"])
			var b := UiKit.button(txt, func():
				var r := GameState.comp_requirements(cc, ll)
				if r != "":
					Audio.play("buzz")
					_m().toast(r)
					return
				_m().confirm(_t("Inscription en %s (%s) : %d pièces. Récompense jusqu'à %d pièces.") % [_t(GameData.COMP_CATS[cc]["name"]), _t(GameData.COMP_LEVELS[ll]["name"]), int(GameData.COMP_LEVELS[ll]["fee"]), int(GameData.COMP_LEVELS[ll]["prize"])], func():
					if GameState.spend(int(GameData.COMP_LEVELS[ll]["fee"])):
						_m().close_all_panels()
						_m().change_env("center")
						_m().start_activity(Competition.new(cc, ll)), "S'inscrire"), UiKit.C_ACCENT if req == "" else UiKit.C_DISABLED, 24, 70)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(b)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(g)
		c.add_child(inner)
		v.add_child(c)
	_m().open_panel("[i:trophy] " + _t("Concours"), UiKit.scroll(v))

# ================================================================== Plus
static func more() -> void:
	var g := GridContainer.new()
	g.columns = 3
	var items := [
		["calendar", "Objectifs", func(): daily()],
		["medal", "Succès", func(): achievements()],
		["album", "Album", func(): album()],
		["house", "Décorer", func(): deco()],
		["style", "Style", func(): customize()],
		["paw", "Animaux", func(): pets()],
		["map", "Lieux", func(): places()],
		["gear", "Réglages", func(): settings()],
		["save", "Sauver", func(): _save_now()],
	]
	for it in items:
		var cb: Callable = it[2]
		var b := UiKit.icon_button(it[0], _t(it[1]), cb, Color(1, 0.97, 0.92), 196)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(b)
	_m().open_panel(_t("Menu"), UiKit.scroll(g))

static func _save_now() -> void:
	if GameState.save_game():
		_m().toast(_t("Partie sauvegardée."))

static func daily() -> void:
	GameState.ensure_daily()
	var v := UiKit.vbox(12)
	var list: Array = GameState.data["daily"]["list"]
	for i in list.size():
		var e: Dictionary = list[i]
		var d := GameState.daily_def(e["id"])
		var c := _card()
		var info := UiKit.vbox(4)
		info.add_child(UiKit.label(_t(d["text"]), 26))
		info.add_child(UiKit.bar(float(e["progress"]) / float(d["target"]) * 100.0, UiKit.C_ACCENT2, 16))
		info.add_child(UiKit.label("[i:coin] " + "%d / %d   ·   +%d" % [int(e["progress"]), int(d["target"]), int(d["reward"])], 21, UiKit.C_SUB))
		var ii := i
		var done := int(e["progress"]) >= int(d["target"])
		var btn := UiKit.button(_t("Reçu") if e["claimed"] else _t("Récupérer"), func():
			if GameState.claim_daily(ii):
				Audio.play("coin")
				_m().close_panel()
				daily(), UiKit.C_GOLD, 24, 76)
		btn.disabled = e["claimed"] or not done
		btn.custom_minimum_size = Vector2(170, 76)
		c.add_child(_row(info, btn))
		v.add_child(c)
	v.add_child(UiKit.label(_t("Nouveaux objectifs chaque jour."), 22, UiKit.C_SUB))
	_m().open_panel("[i:calendar] " + _t("Objectifs du jour"), UiKit.scroll(v))

static func achievements() -> void:
	var v := UiKit.vbox(10)
	var got: Array = GameState.data["achievements"]
	v.add_child(UiKit.label(_t("%d / %d débloqués") % [got.size(), GameData.ACHIEVEMENTS.size()], 26, UiKit.C_SUB))
	for id in GameData.ACHIEVEMENTS.keys():
		var a: Dictionary = GameData.ACHIEVEMENTS[id]
		var ok := got.has(id)
		var c := _card(Color(1, 0.95, 0.75) if ok else Color(0.95, 0.94, 0.92))
		var info := UiKit.vbox(2)
		info.add_child(UiKit.label(("[i:medal] " if ok else "[i:lock] ") + _t(a["name"]), 26))
		var prog := mini(GameState.get_stat(a["stat"]), int(a["value"]))
		info.add_child(UiKit.label("%s  (%d/%d)  ·  +%d " % [_t(a["desc"]), prog, int(a["value"]), int(a["reward"])] + _t("pièces"), 20, UiKit.C_SUB))
		c.add_child(info)
		v.add_child(c)
	_m().open_panel("[i:medal] " + _t("Succès"), UiKit.scroll(v))

# ================================================================== Album
static func _thumb(nm: String) -> Texture2D:
	if _thumb_cache.has(nm):
		return _thumb_cache[nm]
	var img := Image.load_from_file("user://photos/" + nm)
	if img == null or img.is_empty():
		return null
	var w := 220
	img.resize(w, int(img.get_height() * float(w) / img.get_width()), Image.INTERPOLATE_BILINEAR)
	var t := ImageTexture.create_from_image(img)
	_thumb_cache[nm] = t
	return t

static func album() -> void:
	var v := UiKit.vbox(12)
	var photos: Array = GameState.data["photos"]
	if photos.is_empty():
		v.add_child(UiKit.label(_t("Aucune photo. Touchez « Photo » pour immortaliser votre compagnon !"), 28))
	var g := GridContainer.new()
	g.columns = 3
	for i in range(photos.size() - 1, -1, -1):
		var nm: String = photos[i]
		var t := _thumb(nm)
		if t == null:
			continue
		var b := TextureButton.new()
		b.texture_normal = t
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(205, 300)
		b.pressed.connect(func(): _photo_view(nm))
		g.add_child(b)
	v.add_child(g)
	_m().open_panel("[i:album] " + _t("Album photo"), UiKit.scroll(v))

static func _photo_view(nm: String) -> void:
	var v := UiKit.vbox(12)
	var img := Image.load_from_file("user://photos/" + nm)
	if img:
		var tr_ := TextureRect.new()
		tr_.texture = ImageTexture.create_from_image(img)
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr_.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tr_.custom_minimum_size = Vector2(0, 700)
		v.add_child(tr_)
	v.add_child(UiKit.button("[i:trash] " + _t("Supprimer"), func():
		GameState.data["photos"].erase(nm)
		DirAccess.remove_absolute("user://photos/" + nm)
		_thumb_cache.erase(nm)
		GameState.mark_dirty()
		_m().close_panel()
		_m().close_panel()
		album(), UiKit.C_DANGER, 26, 80))
	_m().open_panel(_t("Photo"), v)

# ================================================================== Paramètres
static func settings() -> void:
	var v := UiKit.vbox(14)
	for k in [["master", "Volume général"], ["music", "Musique"], ["sfx", "Effets sonores"]]:
		var key: String = k[0]
		v.add_child(UiKit.label(_t(k[1]), 26))
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(GameState.setting(key))
		s.custom_minimum_size = Vector2(0, 56)
		s.value_changed.connect(func(val):
			GameState.set_setting(key, float(val))
			Audio.apply_volumes())
		v.add_child(s)
	v.add_child(UiKit.label(_t("Qualité graphique"), 26))
	var qh := UiKit.hbox(10)
	var cur := int(GameState.setting("quality"))
	for i in 3:
		var qi := i
		qh.add_child(UiKit.expand(UiKit.button([_t("Faible"), _t("Moyen"), _t("Élevé")][i], func():
			GameState.set_setting("quality", qi)
			_m().apply_quality(qi)
			_m().close_panel()
			settings(), UiKit.C_ACCENT if cur == i else UiKit.C_DISABLED, 26, 76)))
	v.add_child(qh)
	v.add_child(_toggle(_t("Vibrations"), "vibration"))
	v.add_child(UiKit.label("[i:text_size] " + _t("Taille du texte"), 26))
	var th := UiKit.hbox(10)
	var cur_t := int(GameState.setting("text_scale"))
	for i in 3:
		var ti := i
		th.add_child(UiKit.expand(UiKit.button([_t("Normal"), _t("Grand"), _t("Très grand")][i], func():
			GameState.set_setting("text_scale", ti)
			_m().close_all_panels()
			_m().show_screen(_m().screen_name if _m().screen_name != "" else "title")
			settings(), UiKit.C_ACCENT if cur_t == i else UiKit.C_DISABLED, 24, 72)))
	v.add_child(th)
	v.add_child(_toggle(_t("Réduire les animations"), "reduce_motion"))
	v.add_child(UiKit.label("[i:speed] " + _t("Sensibilité de la caméra"), 26))
	var sens := HSlider.new()
	sens.min_value = 0.4
	sens.max_value = 2.0
	sens.step = 0.1
	sens.value = float(GameState.setting("sensitivity"))
	sens.custom_minimum_size = Vector2(0, 56)
	sens.value_changed.connect(func(val): GameState.set_setting("sensitivity", float(val)))
	v.add_child(sens)
	v.add_child(_toggle(_t("Commandes vocales (micro)"), "voice"))
	v.add_child(UiKit.label(_t("Sans Internet : pendant le dressage, vous associez votre propre mot à chaque ordre ; le jeu compare ensuite votre voix à ces enregistrements, propres à chaque compagnon. Tous les ordres restent disponibles au toucher."), 20, UiKit.C_SUB))
	v.add_child(UiKit.label(_t("Langue : Français"), 24, UiKit.C_SUB))
	v.add_child(UiKit.button("[i:save] " + _t("Sauvegarder maintenant"), func():
		if GameState.save_game():
			_m().toast(_t("Partie sauvegardée.")), UiKit.C_ACCENT2, 26, 80))
	v.add_child(UiKit.button("[i:reload] " + _t("Recharger la sauvegarde"), func():
		GameState.load_game()
		_m().close_all_panels()
		_m().show_screen("title"), UiKit.C_BLUE, 26, 80))
	v.add_child(UiKit.button("[i:warning] " + _t("Recommencer une partie"), func():
		_m().confirm(_t("Tout effacer et recommencer ? Vos animaux, pièces et objets seront perdus."), func():
			GameState.reset_game()
			Voice.invalidate_cache()
			_m().close_all_panels()
			_m().env_id = ""
			_m().change_env("shelter")
			_m().show_screen("title"), "Effacer"), UiKit.C_DANGER, 26, 80))
	v.add_child(UiKit.label(_t("Truffe & Co v%s — graphismes, sons et musiques originaux générés procéduralement.") % str(ProjectSettings.get_setting("application/config/version", "1.0")), 20, UiKit.C_SUB))
	_m().open_panel("[i:gear] " + _t("Paramètres"), UiKit.scroll(v))

static func _toggle(txt: String, key: String) -> Control:
	var on := bool(GameState.setting(key))
	var b := UiKit.button(("[i:check] " if on else "[i:acc_none] ") + txt, func():
		GameState.set_setting(key, not bool(GameState.setting(key)))
		if key == "voice":
			if GameState.setting("voice"):
				Voice.request_permission()
			else:
				Voice.stop_listening()
		_m().close_panel()
		settings()
		if _m().screen and _m().screen.has_method("refresh"):
			_m().screen.refresh(), UiKit.C_ACCENT2 if on else UiKit.C_DISABLED, 26, 80)
	return b
