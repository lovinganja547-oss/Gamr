extends Node
## Tests unitaires de la logique de jeu (exécuter : tests/run_unit.sh).
var fails := 0
var passes := 0

func ok(cond: bool, name: String) -> void:
	if cond:
		passes += 1
	else:
		fails += 1
		print("ECHEC: ", name)

func _ready() -> void:
	var GS := GameState
	GS.reset_game()
	ok(not GS.has_save(), "nouvelle partie vide")
	var p := GS.create_pet("beagle", "Rex", "m", 1, 2, "collar_blue", "bow", "calin")
	ok(GS.has_save() and GS.active_pet()["name"] == "Rex", "création animal")
	ok(GS.get_stat("adopted") == 1 and GS.data["achievements"].has("first_pet"), "succès premier animal")
	# Besoins : décroissance en ligne
	p["needs"]["hunger"] = 80.0
	GS._decay_pet(p, 1.0, false, false)
	ok(p["needs"]["hunger"] < 80.0, "faim diminue")
	# Hors ligne : plancher
	for k in ["hunger", "thirst", "clean", "affection"]:
		p["needs"][k] = 50.0
	GS.data["last_time"] = Time.get_unix_time_from_system() - 3600.0 * 200.0
	GS.apply_offline()
	ok(p["needs"]["hunger"] >= GS.OFFLINE_FLOOR - 0.01, "plancher hors ligne faim")
	ok(p["needs"]["health"] >= GS.HEALTH_FLOOR, "santé jamais nulle")
	ok(p["needs"]["energy"] > 90.0, "énergie récupérée hors ligne")
	ok(GS.offline_report != "", "rapport d'absence")
	# Récupération facilitée
	p["needs"]["hunger"] = 10.0
	GS.change_need("hunger", 20.0)
	ok(p["needs"]["hunger"] >= 39.9, "bonus récupération animal négligé")
	# Économie
	var c0 := GS.coins()
	ok(GS.buy("tennis") == "" and GS.coins() == c0 - 40, "achat jouet")
	ok(GS.buy("tennis") != "", "pas d'achat en double")
	GS.data["coins"] = 0
	ok(GS.buy("kibble") != "", "achat refusé sans pièces")
	GS.add_coins(500)
	var n0 := GS.item_count("kibble")
	ok(GS.buy("kibble") == "" and GS.item_count("kibble") == n0 + 1, "achat consommable")
	ok(GS.feed("kibble") and GS.item_count("kibble") == n0, "nourrir consomme")
	ok(GS.buy("crown") != "", "niveau requis couronne")
	ok(GS.buy_env("park") != "" or GS.level() >= 2, "parc verrouillé niveau 1")
	# XP / niveau
	var lv := GS.level()
	GS.add_xp(GameData.xp_for_level(lv) + 1)
	ok(GS.level() == lv + 1, "passage de niveau")
	# Dressage
	var s0 := GS.skill("sit")
	for i in 5:
		GS.training_feedback("sit", true, true, true)
	ok(GS.skill("sit") > s0 + 15.0, "dressage progresse")
	var s1 := GS.skill("sit")
	GS.training_feedback("sit", false, true, false)
	ok(GS.skill("sit") < s1, "récompenser une erreur pénalise")
	ok(GS.success_chance("sit") > GS.success_chance("beg"), "chance selon compétence")
	# Concours
	GS.add_coins(1000)
	ok(GS.comp_requirements("obedience", 1) != "", "niveau 2 verrouillé")
	var r := GS.comp_result("obedience", 0, 99.0, 42)
	ok(r["ranking"].size() == 8 and r["place"] >= 1 and r["place"] <= 8, "classement 8")
	# Objectifs du jour
	GS.ensure_daily()
	ok(GS.data["daily"]["list"].size() == 3, "3 objectifs")
	var e: Dictionary = GS.data["daily"]["list"][0]
	var d := GS.daily_def(e["id"])
	GS.inc_stat(d["stat"], int(d["target"]))
	var cc := GS.coins()
	ok(GS.claim_daily(0) and GS.coins() > cc, "récompense objectif")
	ok(not GS.claim_daily(0), "pas de double réclamation")
	# Sauvegarde / chargement
	ok(GS.save_game(), "sauvegarde")
	GS.save_game()
	var coins_saved := GS.coins()
	GS.data["coins"] = 1
	GS.load_game()
	ok(GS.load_status == "ok" and GS.coins() == coins_saved, "rechargement")
	ok(GS.active_pet()["name"] == "Rex" and GS.skill("sit") > 10.0, "animal rechargé")
	# Corruption -> secours
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	f.store_string("{corrompu")
	f.close()
	GS.load_game()
	ok(GS.load_status == "backup" and GS.has_save(), "sauvegarde de secours")
	# Validation données hostiles
	var bad := GS.sanitize({"coins": -50, "level": 999, "pets": [{"breed": "dragon"}, {"breed": "cat", "needs": {"hunger": 999}, "name": ""}], "inventory": {"kibble": 99999, "x": 3}})
	ok(bad["coins"] == 0 and bad["level"] == GameData.MAX_PLAYER_LEVEL, "bornes")
	ok(bad["pets"].size() == 1 and bad["pets"][0]["needs"]["hunger"] == 100.0 and bad["pets"][0]["name"] != "", "animal validé")
	ok(bad["inventory"].get("kibble", 0) == 999 and not bad["inventory"].has("x"), "inventaire validé")
	# Gestes
	ok(GestureRecognizer.classify(_line([Vector2(0, 0), Vector2(0, 300)])) == "D", "geste bas")
	ok(GestureRecognizer.classify(_line([Vector2(0, 0), Vector2(0, 200), Vector2(200, 200)])) == "DR", "geste bas-droite")
	ok(GestureRecognizer.classify(_line([Vector2(0, 300), Vector2(0, 0)])) == "U", "geste haut")
	ok(GestureRecognizer.classify(_line([Vector2(0, 0), Vector2(0, 200), Vector2(0, 0), Vector2(0, 200)])) == "DUD", "geste zigzag")
	var gr := GestureRecognizer.new()
	gr.begin(Vector2(200, 100))
	for i in 41:
		var a := -PI / 2 + TAU * i / 40.0
		gr.add(Vector2(200, 200) + Vector2(cos(a), sin(a)) * 100.0)
	ok(gr.finish() == "O", "geste cercle")
	gr.begin(Vector2(10, 10)); ok(gr.finish() == "T", "tape")
	gr.begin(Vector2(10, 10)); ok(gr.finish() == "TT", "double tape")
	for cmd in GameData.COMMANDS.keys():
		var g: String = GameData.COMMANDS[cmd]["gesture"]
		var dup := 0
		for c2 in GameData.COMMANDS.keys():
			if GameData.COMMANDS[c2]["gesture"] == g: dup += 1
		ok(dup == 1, "geste unique " + cmd)
	# Voix : DTW
	var a1: Array = []
	var b1: Array = []
	for i in 30:
		a1.append(PackedFloat32Array([sin(i * 0.3), cos(i * 0.2), i * 0.1, 0, 1, 0]))
		b1.append(PackedFloat32Array([cos(i * 0.5), sin(i * 0.7), -i * 0.1, 1, 0, 1]))
	var na := Voice.normalize(a1)
	var nb := Voice.normalize(b1)
	ok(Voice.dtw(na, na) < 0.01, "dtw identique")
	ok(Voice.dtw(na, nb) > Voice.dtw(na, na) + 0.2, "dtw différent")
	Voice.templates = {"sit": [na], "down": [nb]}
	ok(Voice.recognize(na)[0] == "sit", "reconnaissance vocale")
	Voice.templates = {}
	# Nettoyage
	GS.reset_game()
	print("TESTS: %d OK, %d ECHECS" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)

func _line(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var n := int(a.distance_to(b) / 8.0)
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	out.append(pts[pts.size() - 1])
	return out
