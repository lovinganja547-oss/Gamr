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
	GS.inc_stat(d["stat"], GS.daily_target(e))
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
	# Phase 8 : missions adaptées, connexion, classements, déblocages, vente, migration
	GS.data["daily"] = {"day": "", "list": []}
	GS.active_pet()["level"] = 9
	GS.ensure_daily()
	var tiers_ok := true
	for x in GS.data["daily"]["list"]:
		if int(x["tier"]) != 2:
			tiers_ok = false
	ok(tiers_ok and GS.data["daily"]["list"].size() == 3, "missions au palier 2")
	ok(GS.daily_target({"id": "d_pet", "tier": 2}) == 40 and GS.daily_target({"id": "d_pet", "tier": 0}) == 20, "cible selon palier")
	ok(GS.daily_text({"id": "d_pet", "tier": 1}).find("30") >= 0, "texte de mission")
	for k in 3:
		var ee: Dictionary = GS.data["daily"]["list"][k]
		GS.inc_stat(GS.daily_def(ee["id"])["stat"], GS.daily_target(ee))
	var c_before := GS.coins()
	GS.claim_daily(0); GS.claim_daily(1); GS.claim_daily(2)
	ok(GS.data["daily"]["bonus"] == true and GS.coins() > c_before + 40, "bonus 3 missions")
	GS.data["login"] = {"last": "", "streak": 0, "claimed": ""}
	ok(GS.login_check() == 0, "connexion jour 1")
	var lc := GS.coins()
	ok(not GS.login_claim().is_empty() and GS.coins() == lc + 30, "récompense jour 1")
	ok(GS.login_check() == -1 and GS.login_claim().is_empty(), "pas de double récompense")
	var y := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	GS.data["login"] = {"last": y, "streak": 3, "claimed": y}
	ok(GS.login_check() == 3 and int(GS.data["login"]["streak"]) == 4, "série de connexion")
	GS.data["login"] = {"last": "2000-01-01", "streak": 5, "claimed": "2000-01-01"}
	ok(GS.login_check() == 0, "série remise à zéro")
	for sc in [50.0, 80.0, 65.0]:
		GS.board_add("test_board", sc)
	ok(GS.data["boards"]["test_board"][0]["score"] == 80.0 and GS.data["boards"]["test_board"].size() == 3, "classement local trié")
	ok(GS.breed_unlocked("shepherd") and GS.unlock_level() == 9, "races débloquées par niveau")
	GS.active_pet()["level"] = 1
	ok(not GS.breed_unlocked("poodle") and GS.breed_unlocked("cat"), "race verrouillée")
	GS.add_item("gem", 2)
	var cg := GS.coins()
	ok(GS.sell("gem", 1) == 60 and GS.coins() == cg + 60 and GS.item_count("gem") == 1, "vente objet de collection")
	ok(GS.data["collection_seen"].has("gem"), "collection découverte")
	var mig := GS.sanitize({"version": 2, "finds": {"shell Coquillage": 3}, "pets": []})
	ok(int(mig["inventory"].get("shell", 0)) == 3 and int(mig["version"]) == GameData.SAVE_VERSION, "migration v2 -> v3 des trouvailles")
	ok(GameData.COMP_ORDER.has("walk") and GameData.route("park_pond")["length"] == 300, "défi de promenade et itinéraires")
	# Carte de promenade
	ok(GameData.walk_endurance(1) < GameData.walk_endurance(10), "endurance de promenade croissante avec le niveau")
	for we in GameData.WALK_EDGES:
		ok(GameData.WALK_NODES.has(we[0]) and GameData.WALK_NODES.has(we[1]), "rue %s-%s valide" % [we[0], we[1]])
	ok(GameData.walk_neighbors("home") == ["lane"], "la maison donne sur la rue des Lilas")
	var wm := WalkMap.new()
	wm.endurance = 2000.0
	wm.route.assign(["home", "lane", "fountain", "shop"])
	ok(wm.auto_return() and wm.is_complete() and wm.route[wm.route.size() - 1] == "home", "retour automatique à la maison")
	wm.route.assign(["home", "lane", "fountain", "shop"])
	wm.endurance = wm.used() + 10.0
	ok(not wm.auto_return(), "retour refusé sans assez d'endurance")
	wm.free()
	ok(GameData.WALK_NODES.size() >= 20, "au moins 20 lieux sur la carte")
	var reach := {"home": true}
	var todo: Array = ["home"]
	while not todo.is_empty():
		var cur: String = todo.pop_back()
		for nb in GameData.walk_neighbors(cur):
			if not reach.has(nb):
				reach[nb] = true
				todo.append(nb)
	ok(reach.size() == GameData.WALK_NODES.size(), "tous les lieux sont reliés à la maison")
	ok(GS.walk_daily_take("test_x") and not GS.walk_daily_take("test_x") and GS.walk_daily_done("test_x"), "action de promenade une fois par jour")
	# Sauvegarde : clés futures conservées, copie du jour
	var fut := GS.sanitize({"version": 99, "nouvelle_option": 3, "pets": []})
	ok(fut.has("nouvelle_option"), "clés d'une version plus récente conservées")
	GS.save_game()
	ok(DirAccess.dir_exists_absolute(GS.SNAP_DIR) and DirAccess.get_files_at(GS.SNAP_DIR).size() >= 1, "copie de sauvegarde du jour")
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

func _capture(samples: PackedFloat32Array, quiet_noise: float = 0.0015) -> Dictionary:
	_utt = {}
	Voice.stop_listening()
	Voice.record_utterance(3.0)
	Voice.feed(samples)
	if _utt.is_empty():
		# le joueur ne dit plus rien : le délai de début de parole s'écoule (horloge audio)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var quiet := PackedFloat32Array()
		for i in int(3.5 * Voice.SR):
			quiet.append(rng.randfn(0.0, quiet_noise))
		Voice.feed(quiet)
	if Voice.is_recording():
		Voice.cancel_record()
	return _utt

## Flux tel que livré par le moteur : stéréo, taux de mixage donné, sinusoïde pure.
func _raw_tone(freq: float, rate: float, dur: float, amp: float = 0.3) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in int(dur * rate):
		var v := amp * sin(TAU * freq * i / rate)
		out.append(Vector2(v, v))
	return out

var _states: Array = []
func _on_cap_state(st: String) -> void:
	_states.append(st)

var _raw_out := PackedFloat32Array()

## Sortie du rééchantillonneur seul (16 kHz) pour un flux brut.
func _resampled(raw: PackedVector2Array, rate: float) -> PackedFloat32Array:
	Voice.stop_listening()
	Voice.start_listening()
	Voice.resample_probe = PackedFloat32Array()
	Voice.resample_probe_on = true
	var i := 0
	while i < raw.size():
		Voice.feed_raw(raw.slice(i, mini(raw.size(), i + 800)), rate)
		i += 800
	Voice.resample_probe_on = false
	Voice.stop_listening()
	return Voice.resample_probe

func _peak_bin(x: PackedFloat32Array) -> int:
	var pw := Voice.power_spectrum(x.slice(2000, 2000 + Voice.FRAME))
	var peak := 0
	for k in pw.size():
		if pw[k] > pw[peak]:
			peak = k
	return peak

func _rms(x: PackedFloat32Array, from: int = 2000) -> float:
	var e := 0.0
	for i in range(from, x.size()):
		e += x[i] * x[i]
	return sqrt(e / maxf(1.0, float(x.size() - from)))

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
	ok(int(r.get("frames", 0)) >= 18 and int(r.get("frames", 0)) <= 28, "durée du mot plausible (%d cadres)" % int(r.get("frames", 0)))
	ok(r.has("samples") and (r["samples"] as PackedFloat32Array).size() > 5000, "échantillons conservés pour la réécoute")
	r = _capture(_syn([[[500.0, 1500.0], 0.1]]))
	ok(not bool(r.get("ok", true)) and r.get("reason", "") == "too_short", "trop court détecté : %s %d" % [r.get("reason", "?"), r.get("frames", -1)])
	r = _capture(_syn(WORD_A, 1.6))
	ok(not bool(r.get("ok", true)) and r.get("reason", "") == "saturated", "saturation détectée")
	r = _capture(_syn(WORD_A, 0.3, 1.0, 0.07), 0.0715)
	ok(not bool(r.get("ok", true)) and r.get("reason", "") == "noisy", "bruit de fond détecté : " + str(r.get("reason", "")))
	r = _capture(_syn([[[300.0, 1200.0], 3.0]]))
	ok(not bool(r.get("ok", true)) and r.get("reason", "") == "too_long", "mot trop long détecté")
	var q := Voice.analyze([], PackedFloat32Array(), 0.01, 0.0, false)
	ok(q["reason"] == "too_short", "analyse vide")
	# Rééchantillonnage : 44,1 et 48 kHz stéréo -> 16 kHz, fréquence conservée, pas de repliement
	for rate in [44100.0, 48000.0]:
		var rs := _resampled(_raw_tone(1000.0, rate, 0.5), rate)
		ok(absi(rs.size() - 8000) < 40, "rééchantillonnage %d Hz : durée conservée (%d échantillons)" % [int(rate), rs.size()])
		ok(_peak_bin(rs) == 32 and absf(_rms(rs) - 0.212) < 0.02, "rééchantillonnage %d Hz : 1000 Hz conservé (case %d, niveau %.3f)" % [int(rate), _peak_bin(rs), _rms(rs)])
		var al := _resampled(_raw_tone(11000.0, rate, 0.5), rate)
		ok(_rms(al) < 0.212 * 0.06, "anti-repliement %d Hz : 11 kHz atténué de plus de 24 dB (%.4f)" % [int(rate), _rms(al)])
	# Trous de silence numérique (micro pas démarré, tampon sous-alimenté) retirés du flux
	var holes := PackedVector2Array()
	holes.resize(9600)
	var tone := _raw_tone(1000.0, 48000.0, 0.5)
	holes.append_array(tone.slice(0, 12000))
	var gap := PackedVector2Array()
	gap.resize(960)
	holes.append_array(gap)
	holes.append_array(tone.slice(12000))
	var hs := _resampled(holes, 48000.0)
	ok(absi(hs.size() - 8000) < 40, "silence numérique retiré (%d échantillons)" % hs.size())
	# Démarrage : aucun délai ne court tant que le micro ne livre rien, puis calibrage, puis prêt
	_states.clear()
	Voice.capture_state.connect(_on_cap_state)
	_utt = {}
	Voice.stop_listening()
	Voice.record_utterance(3.0)
	var zeros := PackedVector2Array()
	zeros.resize(48000 * 2)
	Voice.feed_raw(zeros, 48000.0)
	ok(_utt.is_empty() and not Voice.is_ready() and Voice.is_recording(), "pas d'échec tant que le micro ne livre que du silence numérique")
	var rngq := RandomNumberGenerator.new()
	rngq.seed = 9
	var amb := PackedVector2Array()
	for i in int(48000 * 0.6):
		var nv := rngq.randfn(0.0, 0.002)
		amb.append(Vector2(nv, nv))
	Voice.feed_raw(amb, 48000.0)
	ok(Voice.is_ready() and _states.has("calibrating") and _states.has("ready"), "micro prêt après calibrage : " + str(_states))
	ok(absf(Voice.time_left() - 3.0) < 0.4, "le délai de parole démarre quand le micro est prêt (%.1f s)" % Voice.time_left())
	# Un bruit bref (clic, choc) est ignoré : la capture continue et le mot suivant est pris
	var burst := _syn([[[500.0, 1500.0], 0.09]], 0.3, 1.0, 0.0, 0.3, 4)
	var hush := PackedFloat32Array()
	for i in int(0.7 * Voice.SR):
		hush.append(rngq.randfn(0.0, 0.0015))
	Voice.feed(burst)
	Voice.feed(hush)
	ok(_utt.is_empty() and Voice.is_recording() and _states.has("burst"), "bruit bref ignoré pendant l'enregistrement " + str(_states))
	Voice.feed(_syn(WORD_A))
	Voice.feed(hush)
	ok(bool(_utt.get("ok", false)), "mot capté après un bruit bref : " + str(_utt.get("reason", "")))
	# Micro muet : échec explicite « aucun son reçu », sans blocage
	_utt = {}
	Voice.record_utterance(3.0)
	for i in 360:
		Voice._process(1.0 / 60.0)
	ok(_utt.get("reason", "") == "no_audio" and not Voice.is_recording(), "aucun son reçu signalé : " + str(_utt.get("reason", "?")))
	Voice.capture_state.disconnect(_on_cap_state)
	# Volume : le même mot 20 dB plus faible donne presque les mêmes caractéristiques
	var loud_sig := _syn(WORD_A, 0.3, 1.0, 0.0005, 0.4, 2)
	var soft_sig := PackedFloat32Array()
	for v in loud_sig:
		soft_sig.append(v * 0.1)
	var loud: Dictionary = _capture(loud_sig)
	var soft: Dictionary = _capture(soft_sig, 0.00015)
	var dvol := Voice.dtw(loud["feats"], soft["feats"]) if bool(soft.get("ok", false)) else INF
	ok(dvol < 0.1, "caractéristiques indépendantes du volume (distance %.3f)" % dvol)
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
	var chk_ok := Voice.check_new_template(p, "sit", qa["feats"])
	var chk_bad := Voice.check_new_template(p, "sit", qd["feats"])
	ok(bool(chk_ok["ok"]) and not bool(chk_bad["ok"]) and chk_bad["reason"] == "incoherent", "cohérence d'un nouvel enregistrement (%.2f / %.2f)" % [chk_ok["d"], chk_bad["d"]])
	var chk_conf := Voice.check_new_template(p, "paw", qb["feats"])
	ok(chk_conf["reason"] == "confusable" and chk_conf["other"] == "down", "mot trop proche d'un autre ordre signalé")
	ok(Voice.reliability(p, "paw") == 0.0 and Voice.reliability_label(0.0) != "", "fiabilité nulle sans modèle")
	Voice.record_use(p, "sit", true)
	ok(int(p["voice"]["sit"]["uses"]) == 1 and int(p["voice"]["sit"]["hits"]) == 1, "statistiques d'usage")
	# Sauvegarde : validation de la structure
	var packed := Voice.pack_feats(fa1["feats"])
	ok(Voice.unpack_feats(packed).size() == fa1["feats"].size(), "compactage des modèles")
	var sv := Voice.sanitize_voice({"sit": {"v": Voice.FEAT_VERSION, "word": "x", "tpl": [packed, [[1, 2]], "zut"]}, "dragon": {"v": Voice.FEAT_VERSION, "tpl": [packed]}, "down": 5})
	ok(sv.size() == 1 and sv["sit"]["tpl"].size() == 1 and sv["sit"]["word"] == "x", "validation des modèles vocaux")
	# Migration : les modèles de l'ancien format sont invalidés, le mot est gardé pour être réenregistré
	var old := Voice.sanitize_voice({"sit": {"word": "assis", "tpl": [packed], "uses": 4, "hits": 1}})
	ok(old.has("sit") and old["sit"]["tpl"].is_empty() and bool(old["sit"].get("redo", false)) and old["sit"]["word"] == "assis", "anciens modèles vocaux invalidés")
	var oldpet := {"id": "old", "voice": old}
	ok(Voice.needs_redo(oldpet, "sit") and Voice.redo_count(oldpet) == 1 and Voice.trained_count(oldpet) == 0, "mot à réenregistrer signalé")
	ok(Voice.recognize(qa["feats"], oldpet)["cmd"] == "", "ancien modèle jamais reconnu")
	Voice.add_template(oldpet, "sit", fa1["feats"], "")
	ok(not Voice.needs_redo(oldpet, "sit") and Voice.word(oldpet, "sit") == "assis", "réenregistrement après migration")
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
