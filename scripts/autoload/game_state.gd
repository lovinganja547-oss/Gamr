extends Node
## État de la partie : animaux, besoins, économie, progression, sauvegarde.

signal coins_changed(value: int)
signal xp_changed(xp: int, level: int)
signal level_up(level: int)
signal needs_changed
signal pet_changed
signal inventory_changed
signal toast(text: String)
signal achievement_unlocked(id: String)
signal daily_changed
signal relation_up(level: int)
signal pet_level_up(level: int)

const VoiceScript := preload("res://scripts/autoload/voice.gd")
const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak.json"
const TMP_PATH := "user://save.tmp.json"
const AUTOSAVE_INTERVAL := 30.0
const OFFLINE_MAX_HOURS := 48.0
const OFFLINE_FLOOR := 20.0
const HEALTH_FLOOR := 10.0

## Décroissance des besoins en points par heure de jeu active.
const DECAY := {"hunger": 8.0, "thirst": 10.0, "clean": 4.0, "energy": 3.5, "affection": 4.0, "outside": 5.0}

var data: Dictionary = {}
var pet_sleeping := false
var _outdoor := false   # l'animal actif est dehors (jardin, parc, plage…)
var load_status := "new"   # new | ok | backup | corrupt
var offline_report := ""
var _autosave_t := 0.0
var _tick_t := 0.0
var _pet_stroke_budget := 6.0
var _dirty := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()

# ================================================================== Sauvegarde
func default_data() -> Dictionary:
	return {
		"version": GameData.SAVE_VERSION,
		"created": Time.get_unix_time_from_system(),
		"last_time": Time.get_unix_time_from_system(),
		"coins": 150, "coins_earned": 0, "xp": 0, "level": 1,
		"active_pet": "", "pets": [],
		"inventory": {"kibble": 5, "biscuit": 10, "shampoo": 1},
		"owned": ["ball", "collar_red", "collar_blue", "collar_green", "acc_none", "bandana", "bow",
			"rug_round", "bed_basic", "sofa_coral", "wall_cream"],
		"deco": {"wall": "wall_cream", "rug": "rug_round", "sofa": "sofa_coral", "bed": "bed_basic",
			"plant": "", "lamp": "", "frame": "", "box": ""},
		"toy": "ball",
		"envs": ["house", "garden", "center", "shelter"],
		"achievements": [], "stats": {},
		"daily": {"day": "", "list": []},
		"days_played": [],
		"comp": {"obedience": -1, "agility": -1, "search": -1, "tricks": -1},
		"trophies": [], "photos": [], "finds": {},
		"search_level": 0,
		"bowls": {"food": 0.0, "water": 0.0},
		"tutorial": {"done": false},
		"settings": {"master": 0.9, "music": 0.6, "sfx": 0.9, "quality": 1, "voice": false, "vibration": true, "locale": "fr", "text_scale": 0, "reduce_motion": false, "sensitivity": 1.0},
	}

func has_save() -> bool:
	return not data.get("pets", []).is_empty()

func load_game() -> void:
	var d: Variant = _read_save(SAVE_PATH)
	if d is Dictionary:
		load_status = "ok"
	else:
		d = _read_save(BACKUP_PATH)
		if d is Dictionary:
			load_status = "backup"
		elif FileAccess.file_exists(SAVE_PATH):
			load_status = "corrupt"
		else:
			load_status = "new"
	data = sanitize(d if d is Dictionary else {})
	apply_offline()
	ensure_daily()
	_register_day()

func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	# Format : ligne 1 = empreinte SHA-256, reste = JSON
	var nl := txt.find("\n")
	if nl <= 0:
		return null
	var h := txt.substr(0, nl).strip_edges()
	var body := txt.substr(nl + 1)
	if body.sha256_text() != h:
		push_warning("Sauvegarde altérée : %s" % path)
		return null
	var payload: Variant = JSON.parse_string(body)
	if not (payload is Dictionary):
		return null
	return payload

func save_game() -> bool:
	if data.is_empty():
		return false
	data["last_time"] = Time.get_unix_time_from_system()
	var payload := JSON.stringify(data, "", true, true)
	var wrapped := payload.sha256_text() + "\n" + payload
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Impossible d'écrire la sauvegarde")
		return false
	f.store_string(wrapped)
	f.flush()
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if dir.file_exists("save.json"):
		dir.remove("save.bak.json")
		dir.rename("save.json", "save.bak.json")
	var err := dir.rename("save.tmp.json", "save.json")
	_dirty = false
	return err == OK

func reset_game() -> void:
	var settings: Dictionary = data.get("settings", {}).duplicate()
	var photos: Array = data.get("photos", [])
	for p in photos:
		DirAccess.remove_absolute("user://photos/" + str(p))
	data = sanitize({})
	data["settings"] = sanitize({"settings": settings})["settings"]
	ensure_daily()
	_register_day()
	save_game()
	pet_changed.emit()
	coins_changed.emit(coins())
	inventory_changed.emit()

## Valide et complète des données chargées (types, bornes, clés manquantes).
func sanitize(src: Dictionary) -> Dictionary:
	var d := default_data()
	for k in d.keys():
		if src.has(k) and typeof(src[k]) == typeof(d[k]):
			d[k] = src[k]
		elif src.has(k) and typeof(d[k]) == TYPE_INT and typeof(src[k]) == TYPE_FLOAT:
			d[k] = int(src[k])
		elif src.has(k) and typeof(d[k]) == TYPE_FLOAT and typeof(src[k]) == TYPE_INT:
			d[k] = float(src[k])
	d["coins"] = maxi(0, int(d["coins"]))
	d["coins_earned"] = maxi(0, int(d["coins_earned"]))
	d["xp"] = maxi(0, int(d["xp"]))
	d["level"] = clampi(int(d["level"]), 1, GameData.MAX_PLAYER_LEVEL)
	d["search_level"] = clampi(int(d["search_level"]), 0, GameData.SEARCH_LEVELS.size() - 1)
	var defs := default_data()
	for sk in defs["settings"].keys():
		if not d["settings"].has(sk) or typeof(d["settings"][sk]) != typeof(defs["settings"][sk]):
			if d["settings"].has(sk) and typeof(defs["settings"][sk]) == TYPE_INT and typeof(d["settings"][sk]) == TYPE_FLOAT:
				d["settings"][sk] = int(d["settings"][sk])
			elif d["settings"].has(sk) and typeof(defs["settings"][sk]) == TYPE_FLOAT and typeof(d["settings"][sk]) == TYPE_INT:
				d["settings"][sk] = float(d["settings"][sk])
			else:
				d["settings"][sk] = defs["settings"][sk]
	for sk in ["master", "music", "sfx"]:
		d["settings"][sk] = clampf(float(d["settings"][sk]), 0.0, 1.0)
	d["settings"]["quality"] = clampi(int(d["settings"]["quality"]), 0, 2)
	d["settings"]["text_scale"] = clampi(int(d["settings"]["text_scale"]), 0, 2)
	d["settings"]["sensitivity"] = clampf(float(d["settings"]["sensitivity"]), 0.4, 2.0)
	for sk in defs["deco"].keys():
		if not d["deco"].has(sk) or typeof(d["deco"][sk]) != TYPE_STRING:
			d["deco"][sk] = defs["deco"][sk]
	for ck in defs["comp"].keys():
		d["comp"][ck] = clampi(int(d["comp"].get(ck, -1)), -1, GameData.COMP_LEVELS.size() - 1)
	for bk in ["food", "water"]:
		d["bowls"][bk] = clampf(float(d["bowls"].get(bk, 0.0)), 0.0, 1.0)
	var inv := {}
	for k in d["inventory"].keys():
		if GameData.ITEMS.has(k):
			var c := int(d["inventory"][k])
			if c > 0:
				inv[k] = mini(c, 999)
	d["inventory"] = inv
	var owned: Array = []
	for k in d["owned"]:
		if GameData.ITEMS.has(str(k)) and not owned.has(str(k)):
			owned.append(str(k))
	for k in defs["owned"]:
		if not owned.has(k):
			owned.append(k)
	d["owned"] = owned
	var envs: Array = []
	for e in d["envs"]:
		if GameData.ENVIRONMENTS.has(str(e)) and not envs.has(str(e)):
			envs.append(str(e))
	for e in defs["envs"]:
		if not envs.has(e):
			envs.append(e)
	d["envs"] = envs
	var stats := {}
	for k in d["stats"].keys():
		stats[str(k)] = maxi(0, int(d["stats"][k]))
	d["stats"] = stats
	var src_version := int(src.get("version", 1)) if not src.is_empty() else GameData.SAVE_VERSION
	if src_version < 2:
		# v1 -> v2 : niveau par animal déduit de la relation, besoin « sortir » ajouté
		for p in d["pets"]:
			if p is Dictionary and not p.has("level"):
				var rx := int(p.get("relation_xp", 0))
				var lv := 1
				for i in GameData.RELATION_XP.size():
					if rx >= GameData.RELATION_XP[i]:
						lv = i + 1
				p["level"] = lv
				p["xp"] = 0
	d["version"] = GameData.SAVE_VERSION
	var pets: Array = []
	for p in d["pets"]:
		if p is Dictionary:
			var sp := sanitize_pet(p)
			if not sp.is_empty():
				pets.append(sp)
	d["pets"] = pets
	var found_active := false
	for p in pets:
		if p["id"] == d["active_pet"]:
			found_active = true
	if not found_active:
		d["active_pet"] = pets[0]["id"] if not pets.is_empty() else ""
	if not GameData.ITEMS.has(d["toy"]) or not owned.has(d["toy"]):
		d["toy"] = "ball"
	var ph: Array = []
	for p in d["photos"]:
		if FileAccess.file_exists("user://photos/" + str(p)):
			ph.append(str(p))
	d["photos"] = ph
	return d

func sanitize_pet(p: Dictionary) -> Dictionary:
	var breed := str(p.get("breed", ""))
	if not GameData.BREEDS.has(breed):
		return {}
	var b: Dictionary = GameData.BREEDS[breed]
	var out := {
		"id": str(p.get("id", "pet_%d" % randi())),
		"name": str(p.get("name", b["name"])).substr(0, 16),
		"breed": breed,
		"sex": "f" if str(p.get("sex", "m")) == "f" else "m",
		"palette": clampi(int(p.get("palette", 0)), 0, b["palettes"].size() - 1),
		"eyes": clampi(int(p.get("eyes", 0)), 0, GameData.EYE_COLORS.size() - 1),
		"collar": str(p.get("collar", "collar_red")),
		"accessory": str(p.get("accessory", "acc_none")),
		"temperament": str(p.get("temperament", "joueur")),
		"relation_xp": maxi(0, int(p.get("relation_xp", 0))),
		"adopted": float(p.get("adopted", Time.get_unix_time_from_system())),
		"needs": {}, "skills": {}, "traits": {},
		"train_day": str(p.get("train_day", "")), "train_reps": maxi(0, int(p.get("train_reps", 0))),
		"wins": maxi(0, int(p.get("wins", 0))),
		"xp": maxi(0, int(p.get("xp", 0))),
		"level": clampi(int(p.get("level", 1)), 1, GameData.MAX_PET_LEVEL),
		"last_bath": float(p.get("last_bath", 0.0)),
		"records": {},
		"voice": VoiceScript.sanitize_voice(p.get("voice")),
		"cooldowns": p.get("cooldowns", {}) if p.get("cooldowns") is Dictionary else {},
	}
	if out["name"].strip_edges() == "":
		out["name"] = b["name"]
	out["temperament"] = GameData.TEMPERAMENT_MIGRATION.get(out["temperament"], out["temperament"])
	if not GameData.TEMPERAMENTS.has(out["temperament"]):
		out["temperament"] = "joueur"
	if GameData.item(out["collar"]).get("cat", "") != "collar":
		out["collar"] = "collar_red"
	if GameData.item(out["accessory"]).get("cat", "") != "accessory":
		out["accessory"] = "acc_none"
	var needs: Dictionary = p.get("needs", {}) if p.get("needs") is Dictionary else {}
	for k in GameData.NEED_KEYS:
		out["needs"][k] = clampf(float(needs.get(k, 80.0)), 0.0, 100.0)
	out["needs"]["health"] = maxf(out["needs"]["health"], HEALTH_FLOOR)
	var skills: Dictionary = p.get("skills", {}) if p.get("skills") is Dictionary else {}
	for c in GameData.COMMAND_ORDER:
		out["skills"][c] = clampf(float(skills.get(c, 0.0)), 0.0, 100.0)
	var traits: Dictionary = p.get("traits", {}) if p.get("traits") is Dictionary else {}
	for t in b["traits"].keys():
		out["traits"][t] = clampf(float(traits.get(t, b["traits"][t])), 0.0, 100.0)
	var recs: Dictionary = p.get("records", {}) if p.get("records") is Dictionary else {}
	for k in recs.keys():
		if typeof(recs[k]) == TYPE_FLOAT or typeof(recs[k]) == TYPE_INT:
			out["records"][str(k)] = float(recs[k])
	return out

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if has_save():
			save_game()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		apply_offline()
		ensure_daily()

func mark_dirty() -> void:
	_dirty = true

# ================================================================== Temps / besoins
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_tick_t += delta
	_autosave_t += delta
	_pet_stroke_budget = minf(_pet_stroke_budget + delta * 2.0, 12.0)
	if _tick_t >= 1.0:
		var dt := _tick_t
		_tick_t = 0.0
		for p in data.get("pets", []):
			_decay_pet(p, dt / 3600.0, p["id"] == data["active_pet"] and pet_sleeping, false)
		needs_changed.emit()
	if _autosave_t >= AUTOSAVE_INTERVAL:
		_autosave_t = 0.0
		if has_save():
			save_game()

func _decay_pet(p: Dictionary, hours: float, sleeping: bool, offline: bool) -> void:
	var n: Dictionary = p["needs"]
	var tr_: Dictionary = p["traits"]
	var mult := 0.5 if offline else 1.0
	var floor_v := OFFLINE_FLOOR if offline else 0.0
	var gl := 0.7 + float(tr_.get("gluttony", 50)) / 100.0 * 0.6
	var en := 0.7 + float(tr_.get("energy", 50)) / 100.0 * 0.6
	_dec(n, "hunger", DECAY["hunger"] * gl * hours * mult, floor_v)
	_dec(n, "thirst", DECAY["thirst"] * hours * mult, floor_v)
	_dec(n, "clean", DECAY["clean"] * hours * mult, floor_v)
	_dec(n, "affection", DECAY["affection"] * (0.6 + float(tr_.get("affection", 50)) / 100.0 * 0.8) * hours * mult, floor_v)
	var out_k := 1.4 if p.get("temperament", "") == "energique" else (0.8 if p.get("temperament", "") == "calme" else 1.0)
	if not offline and p["id"] == data.get("active_pet", "") and _outdoor:
		n["outside"] = minf(100.0, n["outside"] + 6.0 * hours)   # dehors : le besoin de sortir se comble doucement
	else:
		_dec(n, "outside", DECAY["outside"] * out_k * hours * mult, floor_v)
	if sleeping or offline:
		var bonus := 1.0 + float(GameData.item(data["deco"].get("bed", "")).get("bonus", 0)) / 100.0
		n["energy"] = minf(100.0, n["energy"] + 30.0 * bonus * hours)
	else:
		_dec(n, "energy", DECAY["energy"] * en * hours * (0.8 if p.get("temperament", "") == "calme" else 1.0), floor_v)
	var low: bool = n["hunger"] < 20.0 or n["thirst"] < 20.0 or n["clean"] < 15.0
	if low:
		_dec(n, "health", 3.0 * hours * mult, maxf(HEALTH_FLOOR, 40.0 if offline else HEALTH_FLOOR))
	else:
		n["health"] = minf(100.0, n["health"] + 4.0 * hours)
	var target := mood_target(p)
	var k := clampf(12.0 * hours, 0.0, 1.0)
	n["mood"] = clampf(lerpf(n["mood"], target, k), 0.0, 100.0)

func _dec(n: Dictionary, key: String, amount: float, floor_v: float) -> void:
	var v: float = n[key]
	if v <= floor_v:
		return
	n[key] = maxf(floor_v, v - amount)

func mood_target(p: Dictionary) -> float:
	var n: Dictionary = p["needs"]
	return clampf((n["hunger"] + n["thirst"] + n["clean"] * 0.6 + n["energy"] * 0.7 + n["affection"] * 1.2 + n["health"] + n.get("outside", 80.0) * 0.8) / 6.3, 0.0, 100.0)

func apply_offline() -> void:
	if data.is_empty():
		return
	var now := Time.get_unix_time_from_system()
	var last := float(data.get("last_time", now))
	var hours := clampf((now - last) / 3600.0, 0.0, OFFLINE_MAX_HOURS)
	data["last_time"] = now
	offline_report = ""
	if hours < 0.05 or data["pets"].is_empty():
		return
	var steps := maxi(1, int(ceil(hours)))
	for q in data["pets"]:
		for i in steps:
			_decay_pet(q, hours / steps, false, true)
	var p := active_pet()
	if not p.is_empty():
		var h := int(hours)
		var when := ("%d h" % h) if h >= 1 else ("%d min" % int(hours * 60.0))
		var worst := lowest_need(p)
		offline_report = tr("Vous êtes parti %s. %s vous a attendu !") % [when, p["name"]]
		if p["needs"][worst] < 40.0:
			offline_report += " " + tr("Pensez à : %s.") % tr(GameData.NEED_NAMES[worst])
	if p.size() > 0 and data["deco"].get("box", "") == "toybox" and hours > 6.0:
		p["needs"]["mood"] = minf(100.0, p["needs"]["mood"] + 5.0)
	needs_changed.emit()

func lowest_need(p: Dictionary) -> String:
	var worst := "hunger"
	for k in ["hunger", "thirst", "clean", "energy", "affection", "health", "outside"]:
		if p["needs"][k] < p["needs"][worst]:
			worst = k
	return worst

func _register_day() -> void:
	var day := today()
	var days: Array = data["days_played"]
	if not days.has(day):
		days.append(day)
		if days.size() > 60:
			days.pop_front()
		inc_stat("days", 1)

func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]

# ================================================================== Animaux
func active_pet() -> Dictionary:
	for p in data.get("pets", []):
		if p["id"] == data.get("active_pet", ""):
			return p
	return {}

func set_active_pet(id: String) -> void:
	for p in data["pets"]:
		if p["id"] == id:
			data["active_pet"] = id
			pet_sleeping = false
			pet_changed.emit()
			needs_changed.emit()
			mark_dirty()
			return

func create_pet(breed: String, pet_name: String, sex: String, palette: int, eyes: int, collar: String, accessory: String, temperament: String) -> Dictionary:
	var b: Dictionary = GameData.breed(breed)
	var traits: Dictionary = b["traits"].duplicate()
	var mods: Dictionary = GameData.TEMPERAMENTS.get(temperament, {}).get("mod", {})
	for k in mods.keys():
		traits[k] = clampf(float(traits.get(k, 50)) + float(mods[k]), 0.0, 100.0)
	var p := sanitize_pet({
		"id": "pet_%d_%d" % [Time.get_ticks_msec(), randi() % 100000],
		"name": pet_name, "breed": breed, "sex": sex, "palette": palette, "eyes": eyes,
		"collar": collar, "accessory": accessory, "temperament": temperament, "traits": traits,
		"needs": {"hunger": 70, "thirst": 70, "clean": 85, "energy": 90, "mood": 70, "health": 100, "affection": 40},
	})
	data["pets"].append(p)
	data["active_pet"] = p["id"]
	inc_stat("adopted", 1)
	add_xp(30)
	pet_changed.emit()
	save_game()
	return p

func random_temperament(breed: String) -> String:
	var keys: Array = GameData.TEMPERAMENTS.keys()
	var h := absi(hash(breed + str(Time.get_ticks_usec())))
	return keys[h % keys.size()]

func relation_level(p: Dictionary) -> int:
	var xp := int(p.get("relation_xp", 0))
	var lv := 1
	for i in GameData.RELATION_XP.size():
		if xp >= GameData.RELATION_XP[i]:
			lv = i + 1
	return lv

func relation_progress(p: Dictionary) -> float:
	var lv := relation_level(p)
	if lv >= GameData.RELATION_XP.size():
		return 1.0
	var a: int = GameData.RELATION_XP[lv - 1]
	var b: int = GameData.RELATION_XP[lv]
	return clampf(float(int(p["relation_xp"]) - a) / float(b - a), 0.0, 1.0)

func add_relation(amount: int) -> void:
	var p := active_pet()
	if p.is_empty() or amount <= 0:
		return
	var before := relation_level(p)
	p["relation_xp"] = int(p["relation_xp"]) + amount
	var after := relation_level(p)
	if after > before:
		relation_up.emit(after)
		toast.emit(tr("Relation avec %s : %s !") % [p["name"], tr(GameData.RELATION_NAMES[after - 1])])
		var best := 0
		for q in data["pets"]:
			best = maxi(best, relation_level(q))
		set_stat_max("relation_max", best)
	mark_dirty()

func change_need(key: String, amount: float) -> void:
	var p := active_pet()
	if p.is_empty():
		return
	var v: float = p["needs"][key]
	if amount > 0.0 and v < 30.0:
		amount *= 1.5   # récupération facilitée d'un animal négligé
	p["needs"][key] = clampf(v + amount, HEALTH_FLOOR if key == "health" else 0.0, 100.0)
	needs_changed.emit()
	mark_dirty()

func apply_fx(fx: Dictionary) -> void:
	for k in fx.keys():
		if GameData.NEED_KEYS.has(k):
			change_need(k, float(fx[k]))

# ================================================================== Économie
## Anti-abus : true si la récompense « key » peut être donnée (une fois par période), et la consomme.
func reward_ok(key: String, hours: float, p: Dictionary = {}) -> bool:
	if p.is_empty():
		p = active_pet()
	if p.is_empty():
		return false
	var cd: Dictionary = p.get("cooldowns", {})
	var now := Time.get_unix_time_from_system()
	if now - float(cd.get(key, 0.0)) < hours * 3600.0:
		return false
	cd[key] = now
	p["cooldowns"] = cd
	mark_dirty()
	return true

func coins() -> int:
	return int(data.get("coins", 0))

func add_coins(n: int) -> void:
	if n <= 0:
		return
	data["coins"] = coins() + n
	data["coins_earned"] = int(data["coins_earned"]) + n
	set_stat_max("coins_earned", int(data["coins_earned"]))
	coins_changed.emit(coins())
	mark_dirty()

func spend(n: int) -> bool:
	if n < 0 or coins() < n:
		return false
	data["coins"] = coins() - n
	coins_changed.emit(coins())
	mark_dirty()
	return true

func level() -> int:
	return int(data.get("level", 1))

func pet_level(p: Dictionary = {}) -> int:
	if p.is_empty():
		p = active_pet()
	return int(p.get("level", 1))

## Expérience de l'animal (progression individuelle) ; récompense à chaque niveau.
func add_pet_xp(n: int, p: Dictionary = {}) -> void:
	if p.is_empty():
		p = active_pet()
	if p.is_empty() or n <= 0:
		return
	p["xp"] = int(p.get("xp", 0)) + n
	while int(p["level"]) < GameData.MAX_PET_LEVEL and int(p["xp"]) >= GameData.pet_xp_for_level(int(p["level"])):
		p["xp"] = int(p["xp"]) - GameData.pet_xp_for_level(int(p["level"]))
		p["level"] = int(p["level"]) + 1
		var lv := int(p["level"])
		var reward := 25 * lv
		add_coins(reward)
		var msg := tr("%s passe au niveau %d ! +%d pièces") % [p["name"], lv, reward]
		for a in GameData.ACTIVITY_LEVELS.keys():
			if int(GameData.ACTIVITY_LEVELS[a]) == lv:
				msg += "\n" + tr("Nouveau : %s") % tr(GameData.ACTIVITY_NAMES[a])
		toast.emit(msg)
		pet_level_up.emit(lv)
	mark_dirty()

func pet_xp_progress(p: Dictionary = {}) -> float:
	if p.is_empty():
		p = active_pet()
	if p.is_empty():
		return 0.0
	return clampf(float(p.get("xp", 0)) / float(GameData.pet_xp_for_level(int(p.get("level", 1)))), 0.0, 1.0)

## Coût d'énergie d'une activité, modulé par l'endurance, le niveau et le caractère.
func spend_energy(kind: String, mult: float = 1.0) -> void:
	var p := active_pet()
	if p.is_empty():
		return
	var base := float(GameData.ENERGY_COST.get(kind, 1.0)) * mult
	var stam := float(GameData.breed(p["breed"])["stats"]["stamina"]) / 100.0
	var k := (1.25 - stam * 0.5) * (1.0 - minf(float(p.get("level", 1)), 20.0) * 0.012)
	if p.get("temperament", "") == "energique":
		k *= 0.8
	elif p.get("temperament", "") == "calme":
		k *= 0.9
	change_need("energy", -base * k)

func add_xp(n: int) -> void:
	if n <= 0:
		return
	add_pet_xp(n)
	data["xp"] = int(data["xp"]) + n
	while level() < GameData.MAX_PLAYER_LEVEL and int(data["xp"]) >= GameData.xp_for_level(level()):
		data["xp"] = int(data["xp"]) - GameData.xp_for_level(level())
		data["level"] = level() + 1
		var reward := 40 * level()
		add_coins(reward)
		level_up.emit(level())
		toast.emit(tr("Niveau %d ! +%d pièces") % [level(), reward])
		set_stat_max("level", level())
	xp_changed.emit(int(data["xp"]), level())
	mark_dirty()

func item_count(id: String) -> int:
	return int(data["inventory"].get(id, 0))

func owns(id: String) -> bool:
	var it := GameData.item(id)
	if CONSUMABLE_CAT(it):
		return item_count(id) > 0
	return data["owned"].has(id)

static func CONSUMABLE_CAT(it: Dictionary) -> bool:
	return GameData.CONSUMABLE_CATS.has(str(it.get("cat", "")))

func consume(id: String, n: int = 1) -> bool:
	if item_count(id) < n:
		return false
	data["inventory"][id] = item_count(id) - n
	if data["inventory"][id] <= 0:
		data["inventory"].erase(id)
	inventory_changed.emit()
	mark_dirty()
	return true

## Retourne "" si l'achat a réussi, sinon la raison de l'échec.
func buy(id: String) -> String:
	var it := GameData.item(id)
	if it.is_empty():
		return tr("Objet inconnu")
	if level() < int(it.get("level", 1)):
		return tr("Niveau %d requis") % int(it.get("level", 1))
	if not CONSUMABLE_CAT(it) and data["owned"].has(id):
		return tr("Déjà possédé")
	if CONSUMABLE_CAT(it) and item_count(id) >= 999:
		return tr("Inventaire plein")
	if not spend(int(it["price"])):
		return tr("Pas assez de pièces")
	if CONSUMABLE_CAT(it):
		data["inventory"][id] = item_count(id) + 1
	else:
		data["owned"].append(id)
		if it["cat"] == "deco":
			var n := 0
			for o in data["owned"]:
				if GameData.item(o).get("cat", "") == "deco":
					n += 1
			set_stat_max("decos", n)
	inventory_changed.emit()
	mark_dirty()
	return ""

func buy_env(id: String) -> String:
	var e: Dictionary = GameData.ENVIRONMENTS.get(id, {})
	if e.is_empty():
		return tr("Lieu inconnu")
	if data["envs"].has(id):
		return tr("Déjà débloqué")
	if level() < int(e["level"]):
		return tr("Niveau %d requis") % int(e["level"])
	if not spend(int(e["price"])):
		return tr("Pas assez de pièces")
	data["envs"].append(id)
	inventory_changed.emit()
	mark_dirty()
	return ""

func env_unlocked(id: String) -> bool:
	return data["envs"].has(id)

func set_deco(slot: String, id: String) -> void:
	if id != "" and (not data["owned"].has(id) or GameData.item(id).get("slot", "") != slot):
		return
	data["deco"][slot] = id
	inventory_changed.emit()
	mark_dirty()

func equip(kind: String, id: String) -> void:
	var p := active_pet()
	if p.is_empty() or not data["owned"].has(id):
		return
	if GameData.item(id).get("cat", "") != kind:
		return
	p[kind] = id
	pet_changed.emit()
	mark_dirty()

func set_toy(id: String) -> void:
	if data["owned"].has(id) and GameData.item(id).get("cat", "") == "toy":
		data["toy"] = id
		inventory_changed.emit()
		mark_dirty()

# ================================================================== Soins
func feed(id: String) -> bool:
	var fx := feed_start(id)
	if fx.is_empty():
		return false
	apply_fx(fx)
	return true

## Consomme un repas et compte la progression ; renvoie les effets à appliquer
## progressivement pendant que l'animal mange ({} si impossible).
func feed_start(id: String) -> Dictionary:
	var it := GameData.item(id)
	if it.get("cat", "") != "food" or not consume(id):
		return {}
	add_relation(3)
	inc_stat("feed", 1)
	add_xp(5)
	return it["fx"]

func give_treat(id: String) -> bool:
	var it := GameData.item(id)
	if it.get("cat", "") != "treat" or not consume(id):
		return false
	apply_fx(it["fx"])
	add_relation(2)
	inc_stat("treat", 1)
	add_xp(2)
	return true

func give_water(apply: bool = true) -> void:
	if apply:
		change_need("thirst", 60.0)
	add_relation(1)
	add_xp(2)

func use_care(id: String) -> bool:
	var it := GameData.item(id)
	if it.get("cat", "") != "care" or not consume(id):
		return false
	apply_fx(it["fx"])
	return true

func bath_done(quality: float) -> void:
	change_need("clean", 55.0 * clampf(quality, 0.2, 1.0) + 10.0)
	change_need("mood", 4.0)
	add_relation(4)
	inc_stat("bath", 1)

## Caresse : limitée par un budget pour éviter l'abus. Retourne true si comptée.
func stroke() -> bool:
	if _pet_stroke_budget < 1.0:
		return false
	_pet_stroke_budget -= 1.0
	var p := active_pet()
	var k := 1.0
	if p.get("temperament", "") == "affectueux":
		k = 1.4
	elif p.get("temperament", "") == "timide" and relation_level(p) < 3:
		k = 0.6
	change_need("affection", 2.5 * k)
	change_need("mood", 1.0)
	add_relation(1)
	inc_stat("pet", 1)
	if get_stat("pet") % 10 == 0:
		add_xp(2)
	return true

# ================================================================== Dressage
func skill(cmd: String) -> float:
	var p := active_pet()
	if p.is_empty():
		return 0.0
	return float(p["skills"].get(cmd, 0.0))

func command_available(cmd: String) -> bool:
	return pet_level() >= int(GameData.COMMANDS[cmd]["level"])

func activity_unlocked(a: String) -> bool:
	return pet_level() >= int(GameData.ACTIVITY_LEVELS.get(a, 1))

## Motivation de 0 à 1 : faim, humeur, énergie, relation, fatigue de la séance.
func motivation(p: Dictionary) -> float:
	var n: Dictionary = p["needs"]
	var m: float = 0.35 + n["mood"] / 100.0 * 0.3 + n["energy"] / 100.0 * 0.2 + float(relation_level(p)) / 10.0 * 0.15
	if n["hunger"] < 25.0 or n["energy"] < 15.0:
		m -= 0.25
	if p["train_day"] == today():
		m -= maxf(0.0, float(p["train_reps"]) - 25.0) * 0.015
	return clampf(m, 0.05, 1.0)

func success_chance(cmd: String) -> float:
	var p := active_pet()
	if p.is_empty():
		return 0.0
	var s := skill(cmd) / 100.0
	var obed := float(p["traits"].get("obedience", 50)) / 100.0
	var c := 0.25 + s * 0.68 + (obed - 0.5) * 0.15
	c *= lerpf(0.55, 1.08, motivation(p))
	return clampf(c, 0.05, 0.98)

## Résultat d'une séquence de dressage. rewarded = friandise/félicitation, scolded = « Non » doux.
func training_feedback(cmd: String, success: bool, rewarded: bool, treat: bool) -> float:
	var p := active_pet()
	if p.is_empty():
		return 0.0
	if p["train_day"] != today():
		p["train_day"] = today()
		p["train_reps"] = 0
	p["train_reps"] = int(p["train_reps"]) + 1
	var b: Dictionary = GameData.breed(p["breed"])
	var learn := (0.6 + float(b["stats"]["intelligence"]) / 100.0 * 0.8) / float(GameData.COMMANDS[cmd]["difficulty"])
	var cur := skill(cmd)
	var repeat_factor := 1.0 / (1.0 + maxf(0.0, float(p["train_reps"]) - 15.0) * 0.08)  # séances trop longues = moins efficaces
	var gain := 0.0
	if success and rewarded:
		gain = (7.0 + (100.0 - cur) * 0.07) * learn * repeat_factor
		if treat:
			gain *= 1.0 + float(p["traits"].get("gluttony", 50)) / 200.0
		change_need("mood", 2.0)
		add_relation(3)
		inc_stat("train_ok", 1)
		add_xp(4)
	elif success and not rewarded:
		gain = -1.0
		change_need("mood", -3.0)
	elif not success and rewarded:
		gain = -2.0   # récompenser une erreur embrouille l'animal
	else:
		gain = 1.0 * learn * repeat_factor   # correction douce : il comprend un peu
		change_need("mood", -1.0)
	spend_energy("train_rep")
	var before := cur
	var after := clampf(cur + gain, 0.0, 100.0)
	p["skills"][cmd] = after
	if before < GameData.SKILL_MASTERED and after >= GameData.SKILL_MASTERED:
		toast.emit(tr("%s maîtrise « %s » !") % [p["name"], tr(GameData.COMMANDS[cmd]["name"])])
		_update_mastered()
	elif before < GameData.SKILL_LEARNED and after >= GameData.SKILL_LEARNED:
		toast.emit(tr("%s connaît « %s » !") % [p["name"], tr(GameData.COMMANDS[cmd]["name"])])
	mark_dirty()
	return after - before

func _update_mastered() -> void:
	var best := 0
	for p in data["pets"]:
		var n := 0
		for c in GameData.COMMAND_ORDER:
			if float(p["skills"].get(c, 0.0)) >= GameData.SKILL_MASTERED:
				n += 1
		best = maxi(best, n)
	set_stat_max("mastered", best)

# ================================================================== Compétitions
## Retourne "" si l'inscription est possible, sinon la raison.
func comp_requirements(cat: String, lv: int) -> String:
	var p := active_pet()
	if p.is_empty():
		return tr("Aucun animal")
	var L: Dictionary = GameData.COMP_LEVELS[lv]
	if lv > 0 and int(data["comp"].get(cat, -1)) < lv - 1:
		return tr("Gagnez d'abord le niveau %s") % tr(GameData.COMP_LEVELS[lv - 1]["name"])
	if pet_level() < int(L["player_level"]) + 3:
		return tr("%s doit être niveau %d") % [p["name"], int(L["player_level"]) + 3]
	if relation_level(p) < int(L["relation"]):
		return tr("Relation niveau %d requise") % int(L["relation"])
	for c in GameData.COMP_CATS[cat]["skills"]:
		if skill(c) < float(L["skill"]):
			return tr("« %s » à %d %% requis") % [tr(GameData.COMMANDS[c]["name"]), int(L["skill"])]
	if p["needs"]["energy"] < 25.0:
		return tr("%s est trop fatigué") % p["name"]
	if coins() < int(L["fee"]):
		return tr("Inscription : %d pièces") % int(L["fee"])
	return ""

## Classe le joueur parmi 7 rivaux. Retourne {place, ranking, prize, xp}.
func comp_result(cat: String, lv: int, score: float, seed_v: int) -> Dictionary:
	var L: Dictionary = GameData.COMP_LEVELS[lv]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var p := active_pet()
	var ranking: Array = [{"name": p.get("name", "?"), "score": score, "player": true}]
	var names := GameData.RIVAL_NAMES.duplicate()
	names.erase(str(p.get("name", "")))
	for i in 7:
		var idx := rng.randi_range(0, names.size() - 1)
		var nm: String = names[idx]
		names.remove_at(idx)
		var s := clampf(rng.randfn(float(L["rivals"]), 9.0), 5.0, 100.0)
		ranking.append({"name": nm, "score": snappedf(s, 0.1), "player": false})
	ranking.sort_custom(func(a, b): return a["score"] > b["score"])
	var place := 1
	for i in ranking.size():
		if ranking[i]["player"]:
			place = i + 1
	var prize := 0
	var xp := int(L["xp"]) / 3
	if place == 1:
		prize = int(L["prize"]); xp = int(L["xp"])
	elif place == 2:
		prize = int(L["prize"]) / 2; xp = int(L["xp"]) * 2 / 3
	elif place == 3:
		prize = int(L["prize"]) / 4; xp = int(L["xp"]) / 2
	inc_stat("comp", 1)
	add_coins(prize)
	add_xp(xp)
	add_relation(10)
	spend_energy("competition")
	change_need("hunger", -5.0)
	if place <= 3:
		data["trophies"].append({"cat": cat, "level": lv, "place": place, "pet": p.get("name", "?"), "day": today()})
	if place == 1:
		inc_stat("comp_win", 1)
		p["wins"] = int(p.get("wins", 0)) + 1
		if int(data["comp"].get(cat, -1)) < lv:
			data["comp"][cat] = lv
			toast.emit(tr("Niveau suivant débloqué en %s !") % tr(GameData.COMP_CATS[cat]["name"]))
	save_game()
	return {"place": place, "ranking": ranking, "prize": prize, "xp": xp}

# ================================================================== Agilité / records
## Retourne "" si le niveau d'agilité est accessible, sinon la raison.
func agility_requirements(lv: int) -> String:
	var p := active_pet()
	if p.is_empty():
		return tr("Aucun animal")
	var L: Dictionary = GameData.AGILITY_LEVELS[clampi(lv, 0, GameData.AGILITY_LEVELS.size() - 1)]
	if pet_level() < int(L["pet_level"]):
		return tr("%s doit être niveau %d") % [p["name"], int(L["pet_level"])]
	for c in L["cmds"].keys():
		if skill(c) < float(L["cmds"][c]):
			return tr("« %s » à %d %% requis") % [tr(GameData.COMMANDS[c]["name"]), int(L["cmds"][c])]
	if float(p["needs"]["energy"]) < float(L["energy"]):
		return tr("Énergie insuffisante (%d %% requis)") % int(L["energy"])
	return ""

## Record personnel de l'animal actif ; -1 si aucun.
func record(key: String, p: Dictionary = {}) -> float:
	if p.is_empty():
		p = active_pet()
	if p.is_empty():
		return -1.0
	var r: Dictionary = p.get("records", {})
	return float(r.get(key, -1.0))

## Enregistre un record si meilleur (plus grand, ou plus petit si higher_better = false). Retourne true si nouveau record.
func set_record(key: String, value: float, higher_better: bool = true, p: Dictionary = {}) -> bool:
	if p.is_empty():
		p = active_pet()
	if p.is_empty():
		return false
	if not (p.get("records") is Dictionary):
		p["records"] = {}
	var r: Dictionary = p["records"]
	var old := float(r.get(key, -1.0))
	var better := old < 0.0 or (value > old if higher_better else value < old)
	if better:
		r[key] = snappedf(value, 0.01)
		mark_dirty()
	return better

# ================================================================== Statistiques / succès / objectifs
func get_stat(key: String) -> int:
	return int(data["stats"].get(key, 0))

func inc_stat(key: String, n: int) -> void:
	data["stats"][key] = get_stat(key) + n
	_progress_daily(key, n)
	_check_achievements(key)
	mark_dirty()

func set_stat_max(key: String, v: int) -> void:
	if v > get_stat(key):
		data["stats"][key] = v
		_check_achievements(key)

func _check_achievements(key: String) -> void:
	for id in GameData.ACHIEVEMENTS.keys():
		var a: Dictionary = GameData.ACHIEVEMENTS[id]
		if a["stat"] != key or data["achievements"].has(id):
			continue
		if get_stat(key) >= int(a["value"]):
			data["achievements"].append(id)
			achievement_unlocked.emit(id)
			toast.emit(tr("[i:trophy] Succès : %s (+%d)") % [tr(a["name"]), int(a["reward"])])
			add_coins(int(a["reward"]))

func ensure_daily() -> void:
	if data.is_empty():
		return
	var day := today()
	if data["daily"].get("day", "") == day and data["daily"].get("list", []).size() == 3:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day)
	var pool := range(GameData.DAILY_POOL.size())
	var list: Array = []
	for i in 3:
		var j := rng.randi_range(0, pool.size() - 1)
		var d: Dictionary = GameData.DAILY_POOL[pool[j]]
		pool.remove_at(j)
		list.append({"id": d["id"], "progress": 0, "claimed": false})
	data["daily"] = {"day": day, "list": list}
	daily_changed.emit()

func daily_def(id: String) -> Dictionary:
	for d in GameData.DAILY_POOL:
		if d["id"] == id:
			return d
	return {}

func _progress_daily(stat: String, n: int) -> void:
	for e in data["daily"].get("list", []):
		var d := daily_def(e["id"])
		if d.get("stat", "") == stat and not e["claimed"]:
			var before := int(e["progress"])
			e["progress"] = mini(int(d["target"]), before + n)
			if before < int(d["target"]) and int(e["progress"]) >= int(d["target"]):
				toast.emit(tr("Objectif du jour terminé ! Récupérez la récompense."))
			daily_changed.emit()

func claim_daily(idx: int) -> bool:
	var list: Array = data["daily"].get("list", [])
	if idx < 0 or idx >= list.size():
		return false
	var e: Dictionary = list[idx]
	var d := daily_def(e["id"])
	if e["claimed"] or int(e["progress"]) < int(d.get("target", 1)):
		return false
	e["claimed"] = true
	add_coins(int(d["reward"]))
	add_xp(20)
	daily_changed.emit()
	return true

func add_find(icon: String, find_name: String) -> void:
	var f: Dictionary = data["finds"]
	var key := icon + " " + find_name
	f[key] = int(f.get(key, 0)) + 1
	inc_stat("collect", 1)

# ================================================================== Paramètres
func setting(key: String) -> Variant:
	return data["settings"].get(key)

func set_setting(key: String, v: Variant) -> void:
	data["settings"][key] = v
	mark_dirty()
