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
	# Voix : FFT, caractéristiques, détection, qualité, reconnaissance
	_voice_tests()
	# Nettoyage
	GS.reset_game()
	print("TESTS: %d OK, %d ECHECS" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)

# ------------------------------------------------------------------ voix (signaux synthétiques)
func _syn(segs: Array, amp: float = 0.3, stretch: float = 1.0, noise: float = 0.0, pad: float = 0.4, seed_v: int = 1) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var sr := Voice.SR
	var out := PackedFloat32Array()
	var npad := int(pad * sr)
	for i in npad:
		out.append(rng.randfn(0.0, 0.0015 + noise))
	for seg in segs:
		var freqs: Array = seg[0]
		var n := int(float(seg[1]) * stretch * sr)
		for i in n:
			var t := float(i) / sr
			var env := minf(1.0, minf(float(i) / (0.02 * sr), float(n - i) / (0.02 * sr)))
			var v := 0.0
			var k := 1.0
			for f in freqs:
				v += sin(TAU * float(f) * t) * k
				k *= 0.6
			out.append(v * amp * env + rng.randfn(0.0, noise))
	for i in npad + int(0.1 * sr):
		out.append(rng.randfn(0.0, 0.0015 + noise))
	return out

const WORD_A := [[[220.0, 1100.0, 2600.0], 0.18], [[300.0, 700.0, 2300.0], 0.22]]       # type « assis »
const WORD_B := [[[180.0, 900.0, 2100.0], 0.12], [[260.0, 1800.0, 3200.0], 0.14], [[200.0, 600.0, 1500.0], 0.2]]   # type « couché »
const WORD_C := [[[320.0, 2200.0, 3600.0], 0.3]]                                        # type « viens »
const WORD_D := [[[140.0, 500.0, 900.0], 0.15], [[240.0, 1300.0, 2800.0], 0.15], [[400.0, 2000.0, 2500.0], 0.15]]  # inconnu

var _utt: Dictionary = {}
func _on_utt(r: Dictionary) -> void:
	_utt = r

func _capture(samples: PackedFloat32Array) -> Dictionary:
	_utt = {}
	Voice.record_utterance(5.0)
	Voice.feed(samples)
	return _utt

func _voice_tests() -> void:
	Voice.test_mode = true
	# FFT : une sinusoïde à 1000 Hz tombe dans la case 32 (1000 * 512 / 16000)
	var x := PackedFloat32Array()
	for i in Voice.FRAME:
		x.append(sin(TAU * 1000.0 * i / float(Voice.SR)))
	var pw := Voice.power_spectrum(x)
	var peak := 0
	for k in pw.size():
		if pw[k] > pw[peak]:
			peak = k
	ok(peak == 32, "fft pic à 1000 Hz (case %d)" % peak)
	ok(pw.size() == Voice.FRAME / 2 + 1, "taille du spectre")
	# Caractéristiques : 13 dimensions, identiques pour un même cadre, différentes sinon
	var fa := Voice.frame_features(x)
	var y := PackedFloat32Array()
	for i in Voice.FRAME:
		y.append(0.5 * sin(TAU * 300.0 * i / float(Voice.SR)) + 0.3 * sin(TAU * 2500.0 * i / float(Voice.SR)))
	var fb := Voice.frame_features(y)
	ok(fa.size() == Voice.DIMS and fb.size() == Voice.DIMS, "13 caractéristiques par cadre")
	var dd := 0.0
	for d in Voice.DIMS:
		dd += absf(fa[d] - fb[d])
	ok(dd > 1.0, "caractéristiques discriminantes")
	ok(Voice.frame_features(x) == fa, "caractéristiques déterministes")
	# Détection de parole et contrôle qualité via la chaîne complète
	Voice.utterance_ready.connect(_on_utt)
	var r := _capture(_syn(WORD_A))
	ok(bool(r.get("ok", false)), "mot détecté : " + str(r.get("reason", "")))
	ok(int(r.get("frames", 0)) >= 15 and int(r.get("frames", 0)) <= 32, "durée du mot plausible (%d cadres)" % int(r.get("frames", 0)))
	ok(r.has("samples") and (r["samples"] as PackedFloat32Array).size() > 5000, "échantillons conservés pour la réécoute")
	r = _capture(_syn([[[500.0, 1500.0], 0.1]]))
	ok(not bool(r.get("ok", true)) and r.get("reason", "") == "too_short", "trop court détecté : %s %d" % [r.get("reason", "?"), r.get("frames", -1)])
	r = _capture(_syn(WORD_A, 1.6))
	ok(not bool(r.get("ok", true)) and r.get("reason", "") == "saturated", "saturation détectée")
	r = _capture(_syn(WORD_A, 0.3, 1.0, 0.07))
	ok(not bool(r.get("ok", true)) and r.get("reason", "") == "noisy", "bruit de fond détecté : " + str(r.get("reason", "")))
	r = _capture(_syn([[[300.0, 1200.0], 3.0]]))
	ok(not bool(r.get("ok", true)) and r.get("reason", "") == "too_long", "mot trop long détecté")
	var q := Voice.analyze([], PackedFloat32Array(), 0.01, 0.0, false)
	ok(q["reason"] == "too_short", "analyse vide")
	# Reconnaissance : modèles par animal, marge, inconnu refusé
	var p := GameState.active_pet()
	Voice.clear_all(p)
	var fa1: Dictionary = _capture(_syn(WORD_A, 0.3, 1.0, 0.004, 0.4, 2))
	var fa2: Dictionary = _capture(_syn(WORD_A, 0.25, 0.88, 0.004, 0.4, 3))
	var fb1: Dictionary = _capture(_syn(WORD_B, 0.3, 1.0, 0.004, 0.4, 4))
	var fc1: Dictionary = _capture(_syn(WORD_C, 0.3, 1.0, 0.004, 0.4, 5))
	ok(Voice.add_template(p, "sit", fa1["feats"], "assis") == 1, "ajout modèle 1")
	ok(Voice.add_template(p, "sit", fa2["feats"], "") == 2, "ajout modèle 2")
	Voice.add_template(p, "down", fb1["feats"], "couché")
	Voice.add_template(p, "come", fc1["feats"], "viens")
	ok(Voice.trained_count(p) == 3 and Voice.word(p, "sit") == "assis", "modèles stockés par animal")
	var qa: Dictionary = _capture(_syn(WORD_A, 0.35, 1.15, 0.006, 0.4, 6))
	var ra := Voice.recognize(qa["feats"], p)
	ok(ra["cmd"] == "sit", "reconnaît « assis » (meilleur : %s, d=%.2f, second=%.2f)" % [ra["best"], ra["d"], ra["second"]])
	var qb: Dictionary = _capture(_syn(WORD_B, 0.28, 0.9, 0.006, 0.4, 7))
	var rb := Voice.recognize(qb["feats"], p)
	ok(rb["cmd"] == "down", "reconnaît « couché » (meilleur : %s, d=%.2f, second=%.2f)" % [rb["best"], rb["d"], rb["second"]])
	var qd: Dictionary = _capture(_syn(WORD_D, 0.3, 1.0, 0.006, 0.4, 8))
	var rd := Voice.recognize(qd["feats"], p)
	ok(rd["cmd"] == "", "mot inconnu refusé (meilleur : %s, d=%.2f)" % [rd["best"], rd["d"]])
	ok(Voice.recognize(qa["feats"], {"id": "x", "voice": {}}).get("cmd", "x") == "", "sans modèle : rien")
	ok(Voice.reliability(p, "sit") > Voice.reliability(p, "down"), "fiabilité croît avec les modèles")
	ok(Voice.reliability(p, "paw") == 0.0 and Voice.reliability_label(0.0) != "", "fiabilité nulle sans modèle")
	Voice.record_use(p, "sit", true)
	ok(int(p["voice"]["sit"]["uses"]) == 1 and int(p["voice"]["sit"]["hits"]) == 1, "statistiques d'usage")
	# Sauvegarde : validation de la structure
	var packed := Voice.pack_feats(fa1["feats"])
	ok(Voice.unpack_feats(packed).size() == fa1["feats"].size(), "compactage des modèles")
	var sv := Voice.sanitize_voice({"sit": {"word": "x", "tpl": [packed, [[1, 2]], "zut"]}, "dragon": {"tpl": [packed]}, "down": 5})
	ok(sv.size() == 1 and sv["sit"]["tpl"].size() == 1 and sv["sit"]["word"] == "x", "validation des modèles vocaux")
	ok(Voice.sanitize_voice(null).is_empty(), "voix absente tolérée")
	GameState.save_game()
	GameState.load_game()
	ok(Voice.template_count(GameState.active_pet(), "sit") == 2, "modèles vocaux rechargés")
	ok(Voice.recognize(qa["feats"], GameState.active_pet())["cmd"] == "sit", "reconnaissance après rechargement")
	Voice.utterance_ready.disconnect(_on_utt)
	Voice.stop_listening()
	Voice.test_mode = false

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
