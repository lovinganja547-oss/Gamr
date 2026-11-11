extends Node
## Banc de mesure de la détection vocale (exécuter : tests/run_voice_bench.sh).
## Tout est mesuré sur des signaux de SYNTHÈSE (aucun micro réel) : parole à formants
## (source glottale + résonateurs, consonnes fricatives et occlusives), produite au taux de
## mixage (44,1 ou 48 kHz, stéréo), puis passée dans un modèle de capture de téléphone :
## zéros au démarrage du micro, clic d'ouverture, gain automatique qui se stabilise, choc du
## doigt sur l'écran, trous de zéros (sous-alimentation du tampon), quantification 16 bits.
## Le banc pilote la vraie chaîne de Voice (enregistrement puis écoute continue).
## Variables d'environnement : BENCH_SPEAKERS (ex. "0,1"), BENCH_QUICK=1 (moins de tirages),
## BENCH_VERBOSE=1 (détail par énoncé).

# ------------------------------------------------------------------ phonèmes
# voisé : [F1, F2, F3, amplitude voisée, amplitude bruit, centre bruit, largeur bruit]
const PH := {
	"a": [750.0, 1400.0, 2600.0, 1.0, 0.0, 0.0, 0.0],
	"i": [280.0, 2250.0, 3000.0, 0.8, 0.0, 0.0, 0.0],
	"u": [300.0, 800.0, 2300.0, 0.85, 0.0, 0.0, 0.0],
	"e": [400.0, 2100.0, 2800.0, 0.9, 0.0, 0.0, 0.0],
	"E": [550.0, 1800.0, 2600.0, 1.0, 0.0, 0.0, 0.0],
	"o": [420.0, 850.0, 2500.0, 0.95, 0.0, 0.0, 0.0],
	"O": [520.0, 1000.0, 2500.0, 1.0, 0.0, 0.0, 0.0],
	"in": [600.0, 1500.0, 2600.0, 0.8, 0.0, 0.0, 0.0],
	"an": [650.0, 1000.0, 2500.0, 0.85, 0.0, 0.0, 0.0],
	"on": [450.0, 900.0, 2500.0, 0.8, 0.0, 0.0, 0.0],
	"l": [350.0, 1500.0, 2600.0, 0.45, 0.0, 0.0, 0.0],
	"n": [250.0, 1400.0, 2500.0, 0.35, 0.0, 0.0, 0.0],
	"m": [250.0, 1100.0, 2300.0, 0.35, 0.0, 0.0, 0.0],
	"R": [500.0, 1200.0, 2400.0, 0.3, 0.05, 1500.0, 1500.0],
	"j": [280.0, 2200.0, 3000.0, 0.55, 0.0, 0.0, 0.0],
	"v": [250.0, 1200.0, 2300.0, 0.3, 0.03, 4000.0, 3000.0],
	"Z": [280.0, 1800.0, 2500.0, 0.3, 0.08, 3000.0, 2000.0],
	"s": [300.0, 1800.0, 2600.0, 0.0, 0.16, 6000.0, 3500.0],
	"S": [300.0, 1800.0, 2600.0, 0.0, 0.2, 3000.0, 2000.0],
	"f": [300.0, 1400.0, 2500.0, 0.0, 0.05, 4500.0, 5000.0],
	# occlusives : silence de tenue puis explosion (bruit bref)
	"_": [400.0, 1400.0, 2500.0, 0.0, 0.0, 0.0, 0.0],
	"_v": [250.0, 1000.0, 2300.0, 0.07, 0.0, 0.0, 0.0],
	"p*": [400.0, 1100.0, 2400.0, 0.0, 0.2, 1000.0, 1500.0],
	"t*": [400.0, 1700.0, 2600.0, 0.0, 0.25, 4500.0, 3000.0],
	"k*": [400.0, 1500.0, 2500.0, 0.0, 0.25, 2000.0, 1500.0],
}
# mot : liste de [phonème, durée en s]
const WORDS := {
	"assis": [["a", 0.14], ["s", 0.13], ["i", 0.16]],
	"couche": [["_", 0.05], ["k*", 0.025], ["u", 0.13], ["S", 0.12], ["e", 0.17]],
	"viens": [["v", 0.07], ["j", 0.06], ["in", 0.22]],
	"la patte": [["l", 0.06], ["a", 0.12], ["_", 0.08], ["p*", 0.02], ["a", 0.15], ["_", 0.06], ["t*", 0.03]],
	"reste": [["R", 0.08], ["E", 0.14], ["s", 0.11], ["_", 0.05], ["t*", 0.03]],
	"tourne": [["t*", 0.03], ["u", 0.13], ["R", 0.09], ["n", 0.09]],
	"donne": [["_v", 0.05], ["t*", 0.012], ["O", 0.17], ["n", 0.11]],
	"saute": [["s", 0.12], ["o", 0.18], ["_", 0.06], ["t*", 0.03]],
	# mots jamais enregistrés (doivent être rejetés)
	"bravo": [["_v", 0.05], ["p*", 0.012], ["R", 0.06], ["a", 0.13], ["v", 0.07], ["o", 0.16]],
	"non": [["n", 0.08], ["on", 0.22]],
	"ici": [["i", 0.12], ["s", 0.12], ["i", 0.16]],
	"manger": [["m", 0.07], ["an", 0.16], ["Z", 0.09], ["e", 0.17]],
	"attends": [["a", 0.1], ["_", 0.07], ["t*", 0.03], ["an", 0.22]],
	"merci": [["m", 0.07], ["E", 0.1], ["R", 0.07], ["s", 0.1], ["i", 0.15]],
}
const ENROLL := {"sit": "assis", "down": "couche", "come": "viens", "paw": "la patte", "stay": "reste", "spin": "tourne", "fetch": "donne", "jump": "saute"}
const UNKNOWN := ["bravo", "non", "ici", "manger", "attends", "merci"]
const SPEAKERS := [
	{"name": "voix grave", "f0": 115.0, "fs": 0.97},
	{"name": "voix aiguë", "f0": 215.0, "fs": 1.14},
	{"name": "voix d'enfant", "f0": 290.0, "fs": 1.25},
]

var quick := false
var verbose := false
var new_api := false
var _utt: Dictionary = {}
var _got_utt := false
var _events: Array = []
var _noise_bank := PackedFloat32Array()

func _ready() -> void:
	quick = OS.get_environment("BENCH_QUICK") == "1"
	verbose = OS.get_environment("BENCH_VERBOSE") == "1"
	new_api = Voice.has_method("feed_raw")
	var sp_env := OS.get_environment("BENCH_SPEAKERS")
	var speakers: Array = []
	if sp_env == "":
		speakers = range(SPEAKERS.size())
	else:
		for s in sp_env.split(","):
			speakers.append(int(s))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	_noise_bank.resize(96000)
	var lp := 0.0
	for i in _noise_bank.size():
		var w := rng.randfn(0.0, 1.0)
		lp = lp * 0.7 + w * 0.3     # bruit légèrement rosé
		_noise_bank[i] = w * 0.5 + lp * 1.4
	var e := 0.0
	for v in _noise_bank:
		e += v * v
	e = sqrt(e / _noise_bank.size())
	for i in _noise_bank.size():
		_noise_bank[i] /= e
	GameState.reset_game()
	GameState.create_pet("beagle", "Banc", "m", 1, 2, "collar_blue", "bow", "calin")
	Voice.test_mode = true
	Voice.utterance_ready.connect(func(r): _utt = r; _got_utt = true)
	Voice.heard.connect(func(c, conf): _events.append([c, conf]))
	Voice.unrecognized.connect(func(b, d): _events.append(["", d, b]))
	print("BANC VOCAL (signaux de synthèse) — chaîne ", "nouvelle" if new_api else "d'origine", ", locuteurs ", speakers, ", rapide=", quick)
	var tot := {}
	var t0 := Time.get_ticks_msec()
	for si in speakers:
		var r := _run_speaker(si)
		for k in r.keys():
			tot[k] = int(tot.get(k, 0)) + int(r[k])
	_report("TOTAL", tot)
	print("BANC durée : %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	GameState.reset_game()
	get_tree().quit(0)

func _pct(a: int, b: int) -> String:
	return "%d/%d (%.1f %%)" % [a, b, 100.0 * a / maxf(1.0, float(b))]

func _report(title: String, r: Dictionary) -> void:
	print("BANC [", title, "]")
	print("BANC   capture (parole 0,5 à 3 s après ouverture) : réussies ", _pct(r.get("cap_ok", 0), r.get("cap_n", 0)),
		" · échec avant la parole ", r.get("cap_early", 0), " · délai dépassé ", r.get("cap_timeout", 0),
		" · mot tronqué ", r.get("cap_trunc", 0), " · refus qualité ", r.get("cap_qc", 0), " · sans réponse ", r.get("cap_none", 0))
	print("BANC   capture (joueur lent, parole 4 à 6,5 s après ouverture) : réussies ", _pct(r.get("slow_ok", 0), r.get("slow_n", 0)))
	print("BANC   apprentissage : essais nécessaires ", r.get("enr_tries", 0), " pour ", r.get("enr_n", 0), " modèles")
	print("BANC   reconnaissance (mots enregistrés) : correct ", _pct(r.get("rec_ok", 0), r.get("rec_n", 0)),
		" · confondu ", r.get("rec_wrong", 0), " · non reconnu ", r.get("rec_miss", 0), " · aucun événement ", r.get("rec_none", 0))
	print("BANC   mots inconnus : acceptés à tort ", _pct(r.get("unk_fp", 0), r.get("unk_n", 0)))
	print("BANC   bruits (claquement, choc, souffle, musique) : acceptés à tort ", _pct(r.get("noi_fp", 0), r.get("noi_n", 0)))

# ------------------------------------------------------------------ synthèse de parole
## Retourne un mot (mono, taux sr), crête normalisée à 1.
func _speak(word: String, sp: Dictionary, sr: float, rng: RandomNumberGenerator, var_amt: float = 1.0) -> PackedFloat32Array:
	var seq: Array = WORDS[word]
	var speed := 1.0 + rng.randf_range(-0.15, 0.2) * var_amt
	var fscale: float = float(sp["fs"]) * (1.0 + rng.randf_range(-0.03, 0.03) * var_amt)
	var f0: float = float(sp["f0"]) * (1.0 + rng.randf_range(-0.08, 0.08) * var_amt)
	var f0_start := 1.0 + rng.randf_range(0.0, 0.1)
	var f0_end := 1.0 - rng.randf_range(0.05, 0.2)
	# cibles par phonème
	var segs: Array = []
	var total := 0
	for ph in seq:
		var d: Array = PH[ph[0]]
		var n := int(float(ph[1]) * speed * (1.0 + rng.randf_range(-0.1, 0.1) * var_amt) * sr)
		var plosive: bool = str(ph[0]).ends_with("*") or str(ph[0]).begins_with("_")
		if plosive:
			n = int(float(ph[1]) * (1.0 + rng.randf_range(-0.15, 0.15) * var_amt) * sr)
		var g := pow(10.0, rng.randf_range(-2.0, 2.0) * var_amt / 20.0)
		var fj := 1.0 + rng.randf_range(-0.03, 0.03) * var_amt
		segs.append([n, d[0] * fscale * fj, d[1] * fscale * fj, d[2] * fscale * fj, d[3] * g, d[4] * g, d[5], d[6]])
		total += n
	var out := PackedFloat32Array()
	out.resize(total)
	var tr_n := int(0.035 * sr)
	var phase := 0.0
	var y1 := [0.0, 0.0, 0.0, 0.0]
	var y2 := [0.0, 0.0, 0.0, 0.0]
	var n1 := 0.0
	var n2 := 0.0
	var glp := 0.0
	var pos := 0
	var cb := [0.0, 0.0, 0.0, 0.0]
	var cc := [0.0, 0.0, 0.0, 0.0]
	var ca := [0.0, 0.0, 0.0, 0.0]
	var nb := 0.0
	var nc := 0.0
	var na := 0.0
	var av := 0.0
	var an := 0.0
	var bws := [70.0, 100.0, 140.0, 200.0]
	var shimmer := 1.0
	for si in segs.size():
		var s: Array = segs[si]
		var n: int = s[0]
		var prv: Array = segs[maxi(0, si - 1)]
		var nxt: Array = segs[mini(segs.size() - 1, si + 1)]
		for i in n:
			if i % 64 == 0:
				# interpolation des cibles près des frontières (coarticulation)
				var tgt: Array = s
				var w := 0.0
				var oth: Array = s
				if i < tr_n and si > 0:
					oth = prv
					w = 0.5 * (1.0 - float(i) / tr_n)
				elif n - i < tr_n and si < segs.size() - 1:
					oth = nxt
					w = 0.5 * (1.0 - float(n - i) / tr_n)
				var fr := [lerpf(tgt[1], oth[1], w), lerpf(tgt[2], oth[2], w), lerpf(tgt[3], oth[3], w), 3500.0 * fscale]
				for k in 4:
					var c := -exp(-TAU * bws[k] / sr)
					var b := 2.0 * exp(-PI * bws[k] / sr) * cos(TAU * fr[k] / sr)
					cc[k] = c
					cb[k] = b
					ca[k] = 1.0 - b - c
				# amplitudes : transitions rapides (10 ms) sauf silence d'occlusive, immédiat
				var edge := minf(1.0, minf(float(i) / (0.012 * sr), float(n - i) / (0.012 * sr)))
				if si == 0 and i < int(0.012 * sr):
					av = float(tgt[4]) * edge
					an = float(tgt[5]) * edge
				elif si == segs.size() - 1 and n - i < int(0.03 * sr):
					var fall := float(n - i) / (0.03 * sr)
					av = float(tgt[4]) * fall
					an = float(tgt[5]) * fall
				else:
					av = lerpf(av, float(tgt[4]), 0.5)
					an = lerpf(an, float(tgt[5]), 0.6)
				if float(tgt[6]) > 0.0:
					var nf := minf(float(tgt[6]), sr * 0.45)
					var c2 := -exp(-TAU * float(tgt[7]) / sr)
					var b2 := 2.0 * exp(-PI * float(tgt[7]) / sr) * cos(TAU * nf / sr)
					nc = c2
					nb = b2
					na = (1.0 - b2 - c2)
			var prog := float(pos) / maxf(1.0, float(total))
			var f := f0 * lerpf(f0_start, f0_end, prog)
			phase += f / sr
			if phase >= 1.0:
				phase -= 1.0
				shimmer = 1.0 + rng.randf_range(-0.08, 0.08)
				phase += rng.randf_range(-0.01, 0.01)
			# source glottale : dent de scie adoucie (pente d'environ -12 dB/octave)
			var saw := (1.0 - 2.0 * phase) * shimmer
			glp = glp * 0.82 + saw * 0.18
			var x := glp * av
			for k in 4:
				var y: float = ca[k] * x + cb[k] * y1[k] + cc[k] * y2[k]
				y2[k] = y1[k]
				y1[k] = y
				x = y
			var o := x
			if an > 0.0001:
				var wn := rng.randf() * 2.0 - 1.0
				var yn := na * wn + nb * n1 + nc * n2
				n2 = n1
				n1 = yn
				o += yn * an * 6.0
			out[pos] = o
			pos += 1
	var pk := 0.0
	for v in out:
		pk = maxf(pk, absf(v))
	if pk > 0.0:
		for i in out.size():
			out[i] /= pk
	return out

## Bruits non vocaux (crête 1) : claquement, choc sourd, souffle, mélodie.
func _noise_event(kind: int, sr: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	match kind % 4:
		0:   # claquement de mains : salve de bruit très brève
			var n := int(0.06 * sr)
			out.resize(n)
			for i in n:
				out[i] = (rng.randf() * 2.0 - 1.0) * exp(-float(i) / (0.012 * sr))
		1:   # porte / choc sourd
			var n := int(0.35 * sr)
			out.resize(n)
			for i in n:
				var t := float(i) / sr
				out[i] = sin(TAU * 90.0 * t) * exp(-t / 0.08) + (rng.randf() * 2.0 - 1.0) * 0.3 * exp(-t / 0.02)
		2:   # souffle dans le micro : bruit grave prolongé
			var n := int(0.6 * sr)
			out.resize(n)
			var lp := 0.0
			for i in n:
				lp = lp * 0.97 + (rng.randf() * 2.0 - 1.0) * 0.03
				out[i] = lp * sin(PI * float(i) / n)
		3:   # trois notes (sonnerie, musique)
			var n := int(0.6 * sr)
			out.resize(n)
			var notes := [660.0, 880.0, 990.0]
			for i in n:
				var t := float(i) / sr
				var k := mini(2, int(t / 0.2))
				var tl := t - k * 0.2
				out[i] = (sin(TAU * notes[k] * t) + 0.4 * sin(TAU * 2.0 * notes[k] * t)) * minf(1.0, tl / 0.01) * exp(-tl / 0.12)
	var pk := 0.0
	for v in out:
		pk = maxf(pk, absf(v))
	for i in out.size():
		out[i] /= maxf(pk, 1e-6)
	return out

func _rms_top(x: PackedFloat32Array) -> float:
	# niveau efficace des 50 % de blocs de 20 ms les plus forts
	var blocks := PackedFloat32Array()
	var bl := 800
	var i := 0
	while i + bl <= x.size():
		var e := 0.0
		for k in bl:
			e += x[i + k] * x[i + k]
		blocks.append(sqrt(e / bl))
		i += bl
	blocks.sort()
	var s := 0.0
	var c := 0
	for k in range(blocks.size() / 2, blocks.size()):
		s += blocks[k]
		c += 1
	return s / maxf(1.0, float(c))

## Construit un flux tel que le micro du téléphone le livrerait (stéréo, taux sr).
## opts : lead (s avant la parole), peak_db, noise_db (niveau efficace du bruit, dBFS),
## startup (bool : zéros + clic + gain auto), tap (bool), gaps (int), tail (s), tilt, echo.
func _stream(word_sig: PackedFloat32Array, sr: float, rng: RandomNumberGenerator, o: Dictionary) -> PackedVector2Array:
	var lead := int(float(o.get("lead", 1.0)) * sr)
	var tail := int(float(o.get("tail", 1.3)) * sr)
	var peak := pow(10.0, float(o.get("peak_db", -12.0)) / 20.0)
	var noise := pow(10.0, float(o.get("noise_db", -55.0)) / 20.0)
	var n := lead + word_sig.size() + tail
	var mono := PackedFloat32Array()
	mono.resize(n)
	var nbs := _noise_bank.size()
	var off := rng.randi() % nbs
	for i in n:
		mono[i] = _noise_bank[(off + i) % nbs] * noise
	# canal : inclinaison spectrale (distance au micro) et un écho court (pièce)
	var tilt := float(o.get("tilt", 0.0))
	var echo := float(o.get("echo", 0.0))
	var ed := int(0.031 * sr)
	var lp := 0.0
	var w := word_sig.duplicate()
	for i in w.size():
		lp = lp * tilt + w[i] * (1.0 - tilt)
		w[i] = lp
	for i in w.size():
		var v := w[i] * peak
		mono[lead + i] += v
		if echo > 0.0 and lead + i + ed < n:
			mono[lead + i + ed] += v * echo
	if bool(o.get("startup", false)):
		# gain automatique : le bruit de fond démarre fort puis se stabilise en 0,4 s
		if rng.randf() < 0.6:
			var na := int(0.4 * sr)
			var g0 := rng.randf_range(2.0, 5.0)
			for i in mini(na, lead):
				mono[i] *= lerpf(g0, 1.0, float(i) / na)
		# clic d'ouverture du micro
		if rng.randf() < 0.6:
			var nc := int(0.02 * sr)
			var a := rng.randf_range(0.05, 0.3)
			for i in mini(nc, n):
				mono[i] += a * exp(-float(i) / (0.004 * sr)) * (1.0 if i % 2 == 0 else -0.6)
	if bool(o.get("tap", false)):
		# choc du doigt sur l'écran juste après l'appui sur « Enregistrer »
		var t0 := int(rng.randf_range(0.03, 0.25) * sr)
		var nt := int(0.07 * sr)
		var a := rng.randf_range(0.08, 0.35)
		for i in nt:
			if t0 + i < lead - int(0.15 * sr):
				var t := float(i) / sr
				mono[t0 + i] += a * sin(TAU * 140.0 * t) * exp(-t / 0.018)
	# quantification 16 bits et écrêtage
	for i in n:
		mono[i] = clampf(round(mono[i] * 32768.0) / 32768.0, -1.0, 1.0)
	var out := PackedVector2Array()
	# zéros de démarrage (le moteur livre du silence numérique tant que le micro n'a rien fourni)
	if bool(o.get("startup", false)):
		var nz := int(rng.randf_range(0.2, 1.0) * sr)
		out.resize(nz)
	# trous de zéros insérés (sous-alimentation du tampon d'entrée)
	var gaps: Array = []
	for g in int(o.get("gaps", 0)):
		gaps.append(rng.randi() % n)
	gaps.sort()
	var gi := 0
	for i in n:
		if i == lead:
			_word_start_s = out.size() / sr
		while gi < gaps.size() and int(gaps[gi]) == i:
			var gl := int(rng.randf_range(0.005, 0.025) * sr)
			for k in gl:
				out.append(Vector2.ZERO)
			gi += 1
		out.append(Vector2(mono[i], mono[i]))
	return out

# ------------------------------------------------------------------ pilotage de Voice
var _o_pos := 0.0
var _o_prev := 0.0
var _o_count := 0

## Envoie un flux par tranches d'une image (1/60 s) en faisant avancer l'horloge de Voice.
func _drive(st: PackedVector2Array, sr: float, stop_on_utt: bool) -> void:
	var chunk := int(sr / 60.0)
	var i := 0
	while i < st.size():
		var c := st.slice(i, mini(st.size(), i + chunk))
		i += chunk
		_fed_seconds = i / sr
		Voice._process(1.0 / 60.0)
		if not Voice.listening:
			break
		if new_api:
			Voice.call("feed_raw", c, sr)
		else:
			# chaîne d'origine : rééchantillonnage linéaire recopié de Voice._process
			var ratio := sr / float(Voice.SR)
			var out := PackedFloat32Array()
			for k in c.size():
				var mono: float = (c[k].x + c[k].y) * 0.5
				var g := float(_o_count + k)
				while _o_pos <= g:
					var frac := clampf(_o_pos - (g - 1.0), 0.0, 1.0)
					out.append(lerpf(_o_prev, mono, frac))
					_o_pos += ratio
				_o_prev = mono
			_o_count += c.size()
			Voice.feed(out)
		if stop_on_utt and _got_utt:
			break
	# le joueur attend encore un peu (images sans nouvel audio)
	if stop_on_utt and not _got_utt:
		for k in 30:
			Voice._process(1.0 / 60.0)

func _reset_old_resampler() -> void:
	_o_pos = 0.0
	_o_prev = 0.0
	_o_count = 0

## Un appui sur « Enregistrer » : retourne {ok, reason, duration, t_end (s depuis l'ouverture)}.
func _record(st: PackedVector2Array, sr: float) -> Dictionary:
	Voice.stop_listening()
	_utt = {}
	_got_utt = false
	_reset_old_resampler()
	if new_api:
		Voice.record_utterance()
	else:
		Voice.record_utterance(5.0)     # valeur passée par l'écran d'origine
	_drive(st, sr, true)
	if Voice.listening:
		Voice.cancel_record()
		Voice.stop_listening()
	return _utt

func _rand_rate(rng: RandomNumberGenerator) -> float:
	return 44100.0 if rng.randf() < 0.5 else 48000.0

func _cond(rng: RandomNumberGenerator, noise_db: float, peak_lo: float, peak_hi: float) -> Dictionary:
	var peak := rng.randf_range(peak_lo, peak_hi)
	# la parole efficace est environ 12 dB sous la crête : garantir au moins 10 dB de RSB
	if peak - 12.0 - noise_db < 10.0:
		peak = noise_db + 22.0
	return {"peak_db": minf(peak, -3.0), "noise_db": noise_db, "tilt": rng.randf_range(0.0, 0.45), "echo": rng.randf_range(0.0, 0.25)}

func _run_speaker(si: int) -> Dictionary:
	var sp: Dictionary = SPEAKERS[si]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + si * 77
	var r := {}
	var p := GameState.active_pet()
	Voice.clear_all(p)
	var cmds: Array = ENROLL.keys()
	# --- 1. apprentissage : 3 enregistrements par mot, pièce calme, comme un joueur
	for cmd in cmds:
		var got := 0
		var tries := 0
		while got < 3 and tries < 8:
			tries += 1
			var sr := _rand_rate(rng)
			var o := _cond(rng, rng.randf_range(-62.0, -52.0), -24.0, -9.0)
			o["lead"] = rng.randf_range(0.5, 3.0)
			o["startup"] = true
			o["tap"] = rng.randf() < 0.5
			o["gaps"] = (rng.randi() % 4) if rng.randf() < 0.35 else 0
			var w := _speak(ENROLL[cmd], sp, sr, rng, 0.7)
			var res := _record(_stream(w, sr, rng, o), sr)
			var wd := w.size() / sr
			if verbose:
				print("  appr ", cmd, " essai ", tries, " -> ", res.get("ok", false), " ", res.get("reason", ""), " durée=", res.get("duration", 0.0), " mot=", wd)
			# le joueur valide ce que le jeu accepte (il ne voit pas la troncature)
			if bool(res.get("ok", false)):
				if new_api and Voice.has_method("check_new_template"):
					var chk: Dictionary = Voice.call("check_new_template", p, cmd, res["feats"])
					if not bool(chk.get("ok", true)):
						continue
				Voice.add_template(p, cmd, res["feats"], ENROLL[cmd])
				got += 1
		r["enr_tries"] = int(r.get("enr_tries", 0)) + tries
		r["enr_n"] = int(r.get("enr_n", 0)) + got
	# --- 2. capture : conditions variées, parole 0,5 à 3 s après l'ouverture du micro
	var ncap := 16 if quick else 48
	for i in ncap:
		var cmd: String = cmds[i % cmds.size()]
		var sr := 44100.0 if i % 2 == 0 else 48000.0
		var o := _cond(rng, [-62.0, -52.0, -44.0][i % 3] + rng.randf_range(-3.0, 3.0), -30.0, -6.0)
		o["lead"] = rng.randf_range(0.5, 3.0)
		o["startup"] = true
		o["tap"] = rng.randf() < 0.5
		o["gaps"] = (rng.randi() % 5) if rng.randf() < 0.35 else 0
		var w := _speak(ENROLL[cmd], sp, sr, rng)
		var st := _stream(w, sr, rng, o)
		var res := _record(st, sr)
		var wd := w.size() / sr
		r["cap_n"] = int(r.get("cap_n", 0)) + 1
		var key := ""
		if res.is_empty():
			key = "cap_none"
		elif bool(res.get("ok", false)):
			key = "cap_ok" if float(res.get("duration", 0.0)) >= 0.6 * wd else "cap_trunc"
		else:
			var reason := str(res.get("reason", ""))
			if reason == "silence" or reason == "no_audio":
				key = "cap_timeout"
			elif _fed_seconds < _word_start_s + 0.05:
				key = "cap_early"       # échec prononcé avant même le début du mot
			else:
				key = "cap_qc"
		r[key] = int(r.get(key, 0)) + 1
		if verbose:
			print("  capt ", cmd, " ", o, " -> ", key, " ", res.get("reason", ""), " durée=", res.get("duration", 0.0), " mot=", wd)
	# --- 2 bis. joueur lent : parole 4 à 6,5 s après l'ouverture
	var nslow := 6 if quick else 16
	for i in nslow:
		var cmd: String = cmds[i % cmds.size()]
		var sr := 44100.0 if i % 2 == 0 else 48000.0
		var o := _cond(rng, rng.randf_range(-60.0, -48.0), -26.0, -8.0)
		o["lead"] = rng.randf_range(4.0, 6.5)
		o["startup"] = true
		o["tap"] = rng.randf() < 0.5
		var w := _speak(ENROLL[cmd], sp, sr, rng)
		var res := _record(_stream(w, sr, rng, o), sr)
		r["slow_n"] = int(r.get("slow_n", 0)) + 1
		if bool(res.get("ok", false)) and float(res.get("duration", 0.0)) >= 0.6 * w.size() / sr:
			r["slow_ok"] = int(r.get("slow_ok", 0)) + 1
		elif verbose:
			print("  lent ", cmd, " -> ", res.get("reason", "aucune réponse"))
	# --- 3. reconnaissance en écoute continue : trois ambiances
	Voice.stop_listening()
	_reset_old_resampler()
	Voice.start_listening()
	var nrec := 3 if quick else 8
	var first := true
	for amb in 3:
		var noise_db: float = [-60.0, -52.0, -45.0][amb]
		var sr := 44100.0 if amb % 2 == si % 2 else 48000.0
		for k in nrec:
			for cmd in cmds:
				var o := _cond(rng, noise_db, -30.0, -6.0)
				o["lead"] = rng.randf_range(0.5, 1.5)
				o["tail"] = 1.2
				o["startup"] = first
				o["gaps"] = (rng.randi() % 4) if rng.randf() < 0.3 else 0
				first = false
				var w := _speak(ENROLL[cmd], sp, sr, rng)
				_events.clear()
				_drive(_stream(w, sr, rng, o), sr, false)
				r["rec_n"] = int(r.get("rec_n", 0)) + 1
				var key := _classify(cmd)
				r[key] = int(r.get(key, 0)) + 1
				if verbose:
					print("  reco ", cmd, " crête=%.0f bruit=%.0f" % [o["peak_db"], noise_db], " -> ", key, " ", _events)
		# mots inconnus et bruits dans la même ambiance
		for k in (1 if quick else 3):
			for uw in UNKNOWN:
				var o := _cond(rng, noise_db, -26.0, -6.0)
				o["lead"] = rng.randf_range(0.5, 1.2)
				var w := _speak(uw, sp, sr, rng)
				_events.clear()
				_drive(_stream(w, sr, rng, o), sr, false)
				r["unk_n"] = int(r.get("unk_n", 0)) + 1
				if _any_heard():
					r["unk_fp"] = int(r.get("unk_fp", 0)) + 1
					if verbose:
						print("  FAUX POSITIF mot ", uw, " ", _events)
		for k in (4 if quick else 8):
			var o := _cond(rng, noise_db, -24.0, -4.0)
			o["lead"] = rng.randf_range(0.4, 1.0)
			_events.clear()
			_drive(_stream(_noise_event(k, sr, rng), sr, rng, o), sr, false)
			r["noi_n"] = int(r.get("noi_n", 0)) + 1
			if _any_heard():
				r["noi_fp"] = int(r.get("noi_fp", 0)) + 1
				if verbose:
					print("  FAUX POSITIF bruit ", k % 4, " ", _events)
	Voice.stop_listening()
	_report(str(sp["name"]), r)
	return r

var _fed_seconds := 0.0
var _word_start_s := 0.0

func _any_heard() -> bool:
	for e in _events:
		if str(e[0]) != "":
			return true
	return false

func _classify(cmd: String) -> String:
	if _events.is_empty():
		return "rec_none"
	var good := false
	for e in _events:
		if str(e[0]) == cmd:
			good = true
		elif str(e[0]) != "":
			return "rec_wrong"
	return "rec_ok" if good else "rec_miss"
