extends Node
## Commandes vocales hors ligne par empreinte vocale (dépendantes du locuteur).
## Chaîne : micro -> suppression des trous de silence numérique -> mono -> filtre anti-repliement
## et rééchantillonnage à 16 kHz -> attente d'audio réel, calibrage du bruit de fond, détection
## de parole à seuils relatifs (hystérésis) -> rognage précis du mot -> bandes mel (FFT 512
## points en GDScript), soustraction du bruit, cepstres normalisés par leur moyenne, énergie
## relative et dérivées -> comparaison DTW avec les modèles de l'animal actif (pet["voice"]).
## Aucune donnée ne quitte l'appareil. Rien n'est jamais « reconnu » sans une marge suffisante.

signal heard(cmd: String, confidence: float)
signal unrecognized(best_cmd: String, distance: float)
signal level(value: float)
signal utterance_ready(result: Dictionary)
signal state_changed(listening: bool)
signal permission_result(granted: bool)
## Étapes de la capture : starting (attente du micro), calibrating, ready (on peut parler),
## speech (parole en cours), burst (bruit bref ignoré), no_audio (aucun son reçu).
signal capture_state(state: String)

const SR := 16000
const FRAME := 512
const HOP := 320               # 20 ms
const N_MEL := 24
const N_CEPS := 12
const DIMS := N_CEPS + 1       # valeurs enregistrées par cadre : 12 cepstres + énergie relative
const FDIMS := DIMS * 2        # avec les dérivées, pour la comparaison
const FEAT_VERSION := 2        # format des modèles ; les anciens sont invalidés
const MAX_TEMPLATES := 3
const MAX_FRAMES := 125        # 2,5 s : durée maximale d'un mot
const MIN_FRAMES := 8          # 0,16 s de parole après rognage
const PRE_ROLL := 15           # 300 ms conservées avant le déclenchement
const START_FRAMES := 3        # 60 ms au-dessus du seuil pour déclencher
const END_SILENCE := 30        # 600 ms de silence = fin du mot
const SKIP_FRAMES := 4         # 80 ms ignorées à l'ouverture (clic du micro)
const CALIB_FRAMES := 12       # 240 ms de calibrage du bruit de fond
const START_TIMEOUT := 8.0     # délai pour commencer à parler, compté une fois le micro prêt
const NO_AUDIO_TIMEOUT := 5.0  # aucun échantillon reçu du micro
const ZERO_RUN := 24           # échantillons nuls consécutifs = trou de silence numérique
const RS_TAPS := 24
const RS_PHASES := 32
const RS_CUTOFF := 6600.0
const START_RATIO := 3.0       # seuil de début = bruit de fond x 3 (environ +9,5 dB)
const STOP_RATIO := 1.8
const EXT_RATIO := 1.4        # extension des bornes du mot : bruit de fond x 1,4
const EXT_GAP := 5             # trou toléré pendant l'extension (100 ms, tenue d'occlusive)
const EXT_MAX := 14            # extension maximale de chaque côté (280 ms)
const ABS_FLOOR := 0.0004      # plancher absolu du seuil (micros à très faible gain)
const MIN_SNR_DB := 10.0
const LISTEN_SNR_DB := 7.0
const QUIET_LEVEL := 0.0012
const CLIP_RATIO := 0.004
const LEGACY_PATH := "user://voice.json"

# Paramètres de comparaison, calibrés avec tests/voice_tune.gd sur les distances mesurées
# (même mot / autre mot / mot inconnu / bruit). Voir docs/RAPPORT_FINAL.md.
static var noise_sub := 0.0     # soustraction spectrale du bruit de fond
static var mask_rel := 0.001    # plancher relatif à la bande la plus forte (masque le bruit)
static var energy_w := 0.6      # poids de l'énergie relative
static var delta_w := 1.0       # poids des dérivées
static var dtw_open := 3        # cadres libres aux extrémités
static var dtw_band := 0.3
static var MATCH_MAX := 1.15    # distance maximale acceptée
static var MARGIN := 0.9        # le meilleur doit être nettement plus proche que le second
static var NOISY_EXTRA := 0.2   # tolérance ajoutée dans le bruit (RSB < 18 dB)…
static var NOISY_MARGIN := 0.75 # …à condition que la marge sur le second soit large
static var COHERENT_MAX := 1.4  # distance maximale entre deux enregistrements du même mot
static var NEAR_MISS := 1.5     # « non reconnu » signalé jusqu'à 1,5 x le seuil, sinon ignoré
static var ADAPT_K := 1.3       # seuil propre à un ordre = écart moyen entre ses modèles x 1,3…
static var ADAPT_CAP := 1.35    # …borné entre MATCH_MAX et cette valeur

const QUALITY_TEXT := {
	"too_short": "Trop court : dites un mot entier, clairement.",
	"too_long": "Trop long : un seul mot court suffit.",
	"saturated": "Son saturé : parlez moins fort ou éloignez le téléphone.",
	"noisy": "Trop de bruit de fond : trouvez un endroit plus calme.",
	"quiet": "Son trop faible : rapprochez le téléphone de votre bouche.",
	"silence": "Rien entendu : parlez dès que « Parlez maintenant » s'affiche.",
	"no_audio": "Aucun son reçu du micro. Vérifiez qu'une autre application ne l'utilise pas, puis réessayez.",
	"no_mic": "Aucun micro disponible.",
	"permission": "Autorisez l'accès au micro pour continuer.",
}

var listening := false
var test_mode := false          # tests : pas de micro, échantillons injectés par feed() ou feed_raw()
var debug_keep := false         # banc de mesure : conserve les données brutes des énoncés
var debug_raws: Array = []
var resample_probe_on := false  # tests : copie la sortie du rééchantillonneur
var resample_probe := PackedFloat32Array()
var redo_notice_shown := false  # message « réenregistrez vos mots » déjà affiché
var _mode := "recognize"        # recognize | record
var _capture: AudioEffectCapture
var _player: AudioStreamPlayer
var _out: AudioStreamPlayer
var _bus := -1
var _mix_rate := 44100.0
var _heal := 0                 # échantillons restants du raccord après un trou audio
const HEAL_LEN := 96
var _dbg_frames := 0            # diagnostic : images reçues du micro depuis l'ouverture
var _dbg_peak := 0.0
var _dbg_holes := 0
var _stage2 := false
var _hold := 0                  # micro maintenu ouvert (écran d'apprentissage)
var _cache := {}
var _perm_connected := false
# entrée
var _zrun := 0
var _rs_hist := PackedFloat32Array()
var _rs_pos := 0.0
var _rs_rate := 0.0
var _rs_table := PackedFloat32Array()
var _no_audio_t := 0.0
var _restarted := false
var _no_audio_sent := false
# détection
var _buf := PackedFloat32Array()
var _recent := PackedFloat32Array()
var _ring_rms := PackedFloat32Array()
var _phase := 0                 # 0 ouverture, 1 calibrage, 2 prêt
var _phase_n := 0
var _calib := PackedFloat32Array()
var _hp_x := 0.0
var _hp_y := 0.0
var _noise := 0.002
var _noise_mel := PackedFloat32Array()
var _nm_tick := 0
var _in_speech := false
var _above := 0
var _silence := 0
var _u_rms := PackedFloat32Array()
var _u_mel: Array = []
var _u_clip := PackedInt32Array()
var _utt_samples := PackedFloat32Array()
var _wait_frames := 0
var _timeout_frames := 400
var _bursts := 0
var _job := {}
var _speech_t0 := 0

# ------------------------------------------------------------------ tables statiques
static var _win := PackedFloat32Array()
static var _cos := PackedFloat32Array()
static var _sin := PackedFloat32Array()
static var _rev := PackedInt32Array()
static var _mel: Array = []
static var _dct := PackedFloat32Array()

static func _init_tables() -> void:
	if not _win.is_empty():
		return
	_win.resize(FRAME)
	for i in FRAME:
		_win[i] = 0.54 - 0.46 * cos(TAU * i / float(FRAME - 1))
	_cos.resize(FRAME / 2)
	_sin.resize(FRAME / 2)
	for k in FRAME / 2:
		_cos[k] = cos(TAU * k / float(FRAME))
		_sin[k] = sin(TAU * k / float(FRAME))
	_rev.resize(FRAME)
	var bits := int(round(log(FRAME) / log(2.0)))
	for i in FRAME:
		var r := 0
		var v := i
		for b in bits:
			r = (r << 1) | (v & 1)
			v >>= 1
		_rev[i] = r
	# Banc de filtres mel (triangulaires) entre 100 Hz et 6800 Hz
	var lo := _hz_to_mel(100.0)
	var hi := _hz_to_mel(6800.0)
	var pts := PackedInt32Array()
	pts.resize(N_MEL + 2)
	for m in N_MEL + 2:
		var f := _mel_to_hz(lo + (hi - lo) * m / float(N_MEL + 1))
		pts[m] = clampi(int(floor((FRAME + 1) * f / SR)), 0, FRAME / 2)
	_mel.clear()
	for m in N_MEL:
		var a := pts[m]
		var c := pts[m + 1]
		var b := pts[m + 2]
		if c <= a:
			c = a + 1
		if b <= c:
			b = c + 1
		b = mini(b, FRAME / 2)
		var wts := PackedFloat32Array()
		wts.resize(b - a + 1)
		for k in range(a, b + 1):
			var w := 0.0
			if k < c:
				w = float(k - a) / float(c - a)
			else:
				w = float(b - k) / float(maxi(1, b - c))
			wts[k - a] = maxf(0.0, w)
		_mel.append([a, wts])
	_dct.resize(N_CEPS * N_MEL)
	for c in N_CEPS:
		for m in N_MEL:
			_dct[c * N_MEL + m] = cos(PI * (c + 1) * (m + 0.5) / float(N_MEL)) * sqrt(2.0 / N_MEL)

static func _hz_to_mel(f: float) -> float:
	return 2595.0 * log(1.0 + f / 700.0) / log(10.0)

static func _mel_to_hz(m: float) -> float:
	return 700.0 * (pow(10.0, m / 2595.0) - 1.0)

## FFT radix-2 en place (taille FRAME).
static func fft(re: PackedFloat32Array, im: PackedFloat32Array) -> void:
	_init_tables()
	var n := re.size()
	for i in n:
		var j := _rev[i]
		if j > i:
			var t := re[i]; re[i] = re[j]; re[j] = t
			t = im[i]; im[i] = im[j]; im[j] = t
	var span := 2
	while span <= n:
		var half := span / 2
		var step := n / span
		var i := 0
		while i < n:
			for k in half:
				var wr := _cos[k * step]
				var wi := -_sin[k * step]
				var xr := re[i + k + half]
				var xi := im[i + k + half]
				var vr := xr * wr - xi * wi
				var vi := xr * wi + xi * wr
				var ur := re[i + k]
				var ui := im[i + k]
				re[i + k] = ur + vr
				im[i + k] = ui + vi
				re[i + k + half] = ur - vr
				im[i + k + half] = ui - vi
			i += span
		span *= 2

## Spectre de puissance (FRAME/2 + 1 valeurs) d'un cadre fenêtré.
static func power_spectrum(x: PackedFloat32Array) -> PackedFloat32Array:
	_init_tables()
	var re := PackedFloat32Array()
	re.resize(FRAME)
	var im := PackedFloat32Array()
	im.resize(FRAME)
	var n := mini(x.size(), FRAME)
	for i in n:
		re[i] = x[i] * _win[i]
	fft(re, im)
	var pw := PackedFloat32Array()
	pw.resize(FRAME / 2 + 1)
	for k in FRAME / 2 + 1:
		pw[k] = re[k] * re[k] + im[k] * im[k]
	return pw


## Énergies des 24 bandes mel d'un cadre (linéaires), après pré-accentuation.
static func frame_mel(x: PackedFloat32Array) -> PackedFloat32Array:
	_init_tables()
	var n := mini(x.size(), FRAME)
	var mean := 0.0
	for i in n:
		mean += x[i]
	mean /= maxf(1.0, float(n))
	var y := PackedFloat32Array()
	y.resize(FRAME)
	var prev := 0.0
	for i in n:
		var v: float = x[i] - mean
		y[i] = v - 0.97 * prev   # pré-accentuation
		prev = v
	var pw := power_spectrum(y)
	var mel := PackedFloat32Array()
	mel.resize(N_MEL)
	for m in N_MEL:
		var f: Array = _mel[m]
		var start: int = f[0]
		var wts: PackedFloat32Array = f[1]
		var s := 0.0
		for k in wts.size():
			s += pw[start + k] * wts[k]
		mel[m] = s
	return mel

## Caractéristiques brutes d'un cadre : [log énergie, 12 coefficients cepstraux mel].
static func frame_features(x: PackedFloat32Array) -> PackedFloat32Array:
	var mel := frame_mel(x)
	var out := PackedFloat32Array()
	out.resize(DIMS)
	var e := 0.0
	var lm := PackedFloat32Array()
	lm.resize(N_MEL)
	for m in N_MEL:
		e += mel[m]
		lm[m] = log(mel[m] + 1e-9)
	out[0] = log(e + 1e-9)
	for c in N_CEPS:
		var s2 := 0.0
		for m in N_MEL:
			s2 += _dct[c * N_MEL + m] * lm[m]
		out[c + 1] = s2
	return out

## Caractéristiques d'un mot rogné : par cadre, 12 cepstres (bruit soustrait, plancher relatif,
## moyenne retirée) puis l'énergie relative au cadre le plus fort. Indépendant du volume.
static func make_feats(mels: Array, noise_mel: PackedFloat32Array) -> Array:
	_init_tables()
	var n := mels.size()
	if n == 0:
		return []
	var has_noise := noise_mel.size() == N_MEL
	var clean: Array = []
	var top := 0.0
	var emax := 0.0
	var en := PackedFloat32Array()
	en.resize(n)
	for i in n:
		var src: PackedFloat32Array = mels[i]
		var c := PackedFloat32Array()
		c.resize(N_MEL)
		var e := 0.0
		for m in N_MEL:
			var v := src[m]
			if has_noise:
				v = maxf(v - noise_sub * noise_mel[m], 0.05 * v)
			c[m] = v
			e += v
			top = maxf(top, v)
		en[i] = e
		emax = maxf(emax, e)
		clean.append(c)
	var floor_v := top * mask_rel + 1e-12
	var out: Array = []
	var mean := PackedFloat32Array()
	mean.resize(N_CEPS)
	var lm := PackedFloat32Array()
	lm.resize(N_MEL)
	for i in n:
		var c: PackedFloat32Array = clean[i]
		for m in N_MEL:
			lm[m] = log(c[m] + floor_v)
		var f := PackedFloat32Array()
		f.resize(DIMS)
		for k in N_CEPS:
			var s := 0.0
			for m in N_MEL:
				s += _dct[k * N_MEL + m] * lm[m]
			f[k] = s
			mean[k] += s
		f[N_CEPS] = maxf(log((en[i] + 1e-12) / (emax + 1e-12)), -5.0) * energy_w
		out.append(f)
	for k in N_CEPS:
		mean[k] /= n
	for f in out:
		for k in N_CEPS:
			f[k] -= mean[k]
	return out

## Prépare un mot pour la comparaison : tableau plat de FDIMS valeurs par cadre
## (valeurs enregistrées puis leurs dérivées sur 5 cadres).
static func prep(feats: Array) -> PackedFloat32Array:
	var n := feats.size()
	var out := PackedFloat32Array()
	out.resize(n * FDIMS)
	for i in n:
		var f: PackedFloat32Array = feats[i]
		var a1: PackedFloat32Array = feats[maxi(0, i - 1)]
		var b1: PackedFloat32Array = feats[mini(n - 1, i + 1)]
		var a2: PackedFloat32Array = feats[maxi(0, i - 2)]
		var b2: PackedFloat32Array = feats[mini(n - 1, i + 2)]
		var o := i * FDIMS
		for d in DIMS:
			out[o + d] = f[d]
			out[o + DIMS + d] = ((b1[d] - a1[d]) + 2.0 * (b2[d] - a2[d])) * 0.1 * delta_w * 3.0
	return out

## Distance DTW entre deux mots préparés : bande de Sakoe-Chiba, extrémités libres sur
## quelques cadres, normalisée par la longueur du chemin.
static func dtw_flat(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var n := a.size() / FDIMS
	var m := b.size() / FDIMS
	if n == 0 or m == 0:
		return INF
	var inf := 1e20
	var open := mini(dtw_open, mini(n, m) / 4)
	var prev := PackedFloat32Array(); prev.resize(m + 1); prev.fill(inf)
	var cur := PackedFloat32Array(); cur.resize(m + 1)
	for j in open + 1:
		prev[j] = 0.0
	var band := maxi(int(maxf(n, m) * dtw_band), absi(n - m) + 2)
	var best := inf
	for i in range(1, n + 1):
		cur.fill(inf)
		if i <= open:
			cur[0] = 0.0
		var oa := (i - 1) * FDIMS
		var ctr := int(float(i) * m / n)
		var j0 := maxi(1, ctr - band)
		var j1 := mini(m, ctr + band)
		for j in range(j0, j1 + 1):
			var ob := (j - 1) * FDIMS
			var c := 0.0
			for d in FDIMS:
				var x := a[oa + d] - b[ob + d]
				c += x * x
			cur[j] = sqrt(c / DIMS) + minf(prev[j], minf(cur[j - 1], prev[j - 1]))
		if i >= n - open and cur[m] < inf:
			best = minf(best, cur[m] / float(i + m))
		if i == n:
			for j in range(maxi(1, m - open), m + 1):
				if cur[j] < inf:
					best = minf(best, cur[j] / float(n + j))
		var t := prev; prev = cur; cur = t
	return best * 2.0

static func dtw(a: Array, b: Array) -> float:
	return dtw_flat(prep(a), prep(b))

## Modèle moyen : les modèles sont alignés (DTW) sur le premier puis moyennés.
static func mean_template(tpls: Array) -> Array:
	if tpls.size() < 2:
		return []
	var ref: Array = tpls[0]
	var n := ref.size()
	var sums: Array = []
	var cnt := PackedInt32Array()
	cnt.resize(n)
	for i in n:
		sums.append((ref[i] as PackedFloat32Array).duplicate())
		cnt[i] = 1
	for t in range(1, tpls.size()):
		var other: Array = tpls[t]
		var path := _align(ref, other)
		for pr in path:
			var i: int = pr.x
			var f: PackedFloat32Array = other[pr.y]
			var s: PackedFloat32Array = sums[i]
			for d in DIMS:
				s[d] += f[d]
			cnt[i] += 1
	for i in n:
		var s: PackedFloat32Array = sums[i]
		for d in DIMS:
			s[d] /= cnt[i]
	return sums

## Chemin d'alignement DTW complet (petites séquences), liste de Vector2i(i, j).
static func _align(a: Array, b: Array) -> Array:
	var n := a.size()
	var m := b.size()
	var fa := prep(a)
	var fb := prep(b)
	var inf := 1e20
	var cost := PackedFloat32Array()
	cost.resize((n + 1) * (m + 1))
	cost.fill(inf)
	cost[0] = 0.0
	var w := m + 1
	for i in range(1, n + 1):
		for j in range(1, m + 1):
			var c := 0.0
			var oa := (i - 1) * FDIMS
			var ob := (j - 1) * FDIMS
			for d in FDIMS:
				var x := fa[oa + d] - fb[ob + d]
				c += x * x
			cost[i * w + j] = sqrt(c) + minf(cost[(i - 1) * w + j], minf(cost[i * w + j - 1], cost[(i - 1) * w + j - 1]))
	var path: Array = []
	var i := n
	var j := m
	while i >= 1 and j >= 1:
		path.append(Vector2i(i - 1, j - 1))
		var d0 := cost[(i - 1) * w + j - 1]
		var d1 := cost[(i - 1) * w + j]
		var d2 := cost[i * w + j - 1]
		if d0 <= d1 and d0 <= d2:
			i -= 1
			j -= 1
		elif d1 <= d2:
			i -= 1
		else:
			j -= 1
	return path

# ------------------------------------------------------------------ modèles par animal
## Compacte des caractéristiques pour la sauvegarde (listes de nombres arrondis).
static func pack_feats(feats: Array) -> Array:
	var out: Array = []
	for f in feats:
		var row: Array = []
		for v in f:
			row.append(snappedf(float(v), 0.01))
		out.append(row)
	return out

static func unpack_feats(arr: Array) -> Array:
	var out: Array = []
	for row in arr:
		if row is Array and row.size() == DIMS:
			out.append(PackedFloat32Array(row))
	return out

## Valide la structure pet["voice"] :
## {cmd: {"v": version, "word": String, "tpl": [modèle…], "uses": int, "hits": int, "redo": bool}}.
## Les modèles d'un ancien format sont retirés ; l'ordre garde son mot et le drapeau "redo"
## pour inviter le joueur à le réenregistrer.
static func sanitize_voice(v: Variant) -> Dictionary:
	var out := {}
	if not (v is Dictionary):
		return out
	for cmd in v.keys():
		if not GameData.COMMANDS.has(str(cmd)) or not (v[cmd] is Dictionary):
			continue
		var e: Dictionary = v[cmd]
		var current := int(e.get("v", 1)) == FEAT_VERSION
		var redo := bool(e.get("redo", false))
		var tpls: Array = []
		var raw_tpl: Variant = e.get("tpl", [])
		if not (raw_tpl is Array):
			raw_tpl = []
		if not current and (raw_tpl as Array).size() > 0:
			redo = true
		if current:
			for t in raw_tpl:
				if not (t is Array) or t.size() < MIN_FRAMES or t.size() > MAX_FRAMES + PRE_ROLL:
					continue
				var ok := true
				var rows: Array = []
				for row in t:
					if not (row is Array) or row.size() != DIMS:
						ok = false
						break
					var r2: Array = []
					for x in row:
						r2.append(clampf(float(x), -20.0, 20.0))
					rows.append(r2)
				if ok:
					tpls.append(rows)
				if tpls.size() >= MAX_TEMPLATES:
					break
		if tpls.is_empty() and not redo:
			continue
		out[str(cmd)] = {
			"v": FEAT_VERSION,
			"word": str(e.get("word", "")).substr(0, 20),
			"tpl": tpls,
			"uses": maxi(0, int(e.get("uses", 0))) if not tpls.is_empty() else 0,
			"hits": maxi(0, int(e.get("hits", 0))) if not tpls.is_empty() else 0,
		}
		if tpls.is_empty():
			out[str(cmd)]["redo"] = true
	return out

func _entry(p: Dictionary, cmd: String) -> Dictionary:
	var v: Dictionary = p.get("voice", {})
	return v.get(cmd, {})

func template_count(p: Dictionary, cmd: String) -> int:
	return (_entry(p, cmd).get("tpl", []) as Array).size()

## Vrai si un ancien enregistrement de cet ordre a été invalidé (format amélioré).
func needs_redo(p: Dictionary, cmd: String) -> bool:
	return bool(_entry(p, cmd).get("redo", false)) and template_count(p, cmd) == 0

## Nombre d'ordres dont le mot doit être réenregistré pour cet animal.
func redo_count(p: Dictionary = {}) -> int:
	if p.is_empty():
		p = GameState.active_pet()
	var n := 0
	if p.get("voice") is Dictionary:
		for cmd in p["voice"].keys():
			if needs_redo(p, cmd):
				n += 1
	return n

func word(p: Dictionary, cmd: String) -> String:
	var w := str(_entry(p, cmd).get("word", ""))
	if w == "":
		w = TranslationServer.translate(GameData.COMMANDS[cmd]["name"])
	return w

func trained_count(p: Dictionary = {}) -> int:
	if p.is_empty():
		p = GameState.active_pet()
	if p.is_empty():
		return 0
	var n := 0
	for cmd in p.get("voice", {}).keys():
		if template_count(p, cmd) > 0:
			n += 1
	return n

## Modèles préparés d'un ordre : {"raw": [mots], "flat": [mots préparés, modèle moyen compris]}.
func _templates(p: Dictionary, cmd: String) -> Dictionary:
	var key := str(p.get("id", "")) + "/" + cmd
	if _cache.has(key):
		return _cache[key]
	var raw: Array = []
	var flat: Array = []
	for t in _entry(p, cmd).get("tpl", []):
		var u := unpack_feats(t)
		if u.size() >= MIN_FRAMES:
			raw.append(u)
			flat.append(prep(u))
	var mt := mean_template(raw)
	if not mt.is_empty():
		flat.append(prep(mt))
	# seuil propre à cet ordre : une voix dont les répétitions varient davantage (voix réelle,
	# micro médiocre) obtient un seuil proportionnellement plus large, dans des bornes fixes
	var thr := MATCH_MAX
	if raw.size() >= 2:
		var tot := 0.0
		var cnt := 0
		for i in raw.size():
			for j in range(i + 1, raw.size()):
				tot += dtw_flat(flat[i], flat[j])
				cnt += 1
		thr = clampf(tot / cnt * ADAPT_K, MATCH_MAX, ADAPT_CAP)
	var out := {"raw": raw, "flat": flat, "thr": thr}
	_cache[key] = out
	return out

func invalidate_cache() -> void:
	_cache.clear()

## Distance d'un mot à un ordre : la plus petite sur tous ses modèles et son modèle moyen.
func distance_to(p: Dictionary, cmd: String, feats: Array) -> float:
	var q := prep(feats)
	var dmin := INF
	for t in _templates(p, cmd)["flat"]:
		dmin = minf(dmin, dtw_flat(q, t))
	return dmin

## Vérifie qu'un nouvel enregistrement est cohérent avec les précédents et ne se confond pas
## avec un autre ordre. Retourne {ok, reason ("" | "incoherent" | "confusable"), d, other}.
func check_new_template(p: Dictionary, cmd: String, feats: Array) -> Dictionary:
	var res := {"ok": true, "reason": "", "d": 0.0, "other": ""}
	if p.is_empty() or feats.size() < MIN_FRAMES:
		return res
	var own := INF
	if template_count(p, cmd) > 0:
		own = distance_to(p, cmd, feats)
		res["d"] = own
		if own > COHERENT_MAX:
			res["ok"] = false
			res["reason"] = "incoherent"
			return res
	for other in p.get("voice", {}).keys():
		if other == cmd or template_count(p, other) == 0:
			continue
		var d := distance_to(p, other, feats)
		if d < MATCH_MAX * 0.75 and (own == INF or d < own):
			res["ok"] = false
			res["reason"] = "confusable"
			res["other"] = other
			res["d"] = d
			return res
	return res

## Ajoute un modèle (le plus ancien est remplacé au-delà de MAX_TEMPLATES).
func add_template(p: Dictionary, cmd: String, feats: Array, word_txt: String = "") -> int:
	if p.is_empty() or not GameData.COMMANDS.has(cmd) or feats.size() < MIN_FRAMES:
		return 0
	if not (p.get("voice") is Dictionary):
		p["voice"] = {}
	var v: Dictionary = p["voice"]
	var e: Dictionary = v.get(cmd, {"word": "", "tpl": [], "uses": 0, "hits": 0})
	var tpls: Array = e.get("tpl", [])
	tpls.append(pack_feats(feats))
	while tpls.size() > MAX_TEMPLATES:
		tpls.pop_front()
	e["tpl"] = tpls
	e["v"] = FEAT_VERSION
	e.erase("redo")
	if word_txt.strip_edges() != "":
		e["word"] = word_txt.strip_edges().substr(0, 20)
	v[cmd] = e
	invalidate_cache()
	GameState.mark_dirty()
	return tpls.size()

func clear_cmd(p: Dictionary, cmd: String) -> void:
	if p.get("voice") is Dictionary:
		(p["voice"] as Dictionary).erase(cmd)
	invalidate_cache()
	GameState.mark_dirty()

func clear_all(p: Dictionary) -> void:
	p["voice"] = {}
	invalidate_cache()
	GameState.mark_dirty()

## Note l'usage d'un ordre vocal (pour la fiabilité affichée).
func record_use(p: Dictionary, cmd: String, ok: bool) -> void:
	var e := _entry(p, cmd)
	if e.is_empty() or template_count(p, cmd) == 0:
		return
	e["uses"] = int(e.get("uses", 0)) + 1
	if ok:
		e["hits"] = int(e.get("hits", 0)) + 1
	GameState.mark_dirty()

## Cohérence des modèles d'un ordre (0..1) : des modèles proches entre eux = empreinte stable.
func consistency(p: Dictionary, cmd: String) -> float:
	var t: Array = _templates(p, cmd)["raw"]
	if t.size() < 2:
		return 0.7 if t.size() == 1 else 0.0
	var tot := 0.0
	var n := 0
	for i in t.size():
		for j in range(i + 1, t.size()):
			tot += dtw(t[i], t[j])
			n += 1
	var d := tot / maxf(1.0, float(n))
	return clampf(1.3 - d / COHERENT_MAX, 0.2, 1.0)

## Fiabilité estimée (0..1) : nombre de modèles, cohérence, et réussites en usage réel.
func reliability(p: Dictionary, cmd: String) -> float:
	var n := template_count(p, cmd)
	if n == 0:
		return 0.0
	var key := "rel/" + str(p.get("id", "")) + "/" + cmd
	var r: float
	if _cache.has(key):
		r = _cache[key]
	else:
		r = sqrt(float(n) / MAX_TEMPLATES) * consistency(p, cmd)
		_cache[key] = r
	var e := _entry(p, cmd)
	var uses := int(e.get("uses", 0))
	if uses >= 3:
		r = lerpf(r, float(e.get("hits", 0)) / float(uses), 0.4)
	return clampf(r, 0.0, 1.0)

static func reliability_label(r: float) -> String:
	if r <= 0.0:
		return TranslationServer.translate("non enregistré")
	if r >= 0.75:
		return TranslationServer.translate("fiable")
	if r >= 0.45:
		return TranslationServer.translate("à renforcer")
	return TranslationServer.translate("fragile")

## Décision à partir des distances par ordre. Retourne {cmd, conf, best, d, second}.
## Dans le bruit (rapport signal/bruit snr < 18 dB) les distances augmentent : le seuil est
## un peu relevé, mais seulement si le second ordre est nettement plus loin.
static func decide(dists: Dictionary, snr: float = 99.0, thrs: Dictionary = {}) -> Dictionary:
	var res := {"cmd": "", "conf": 0.0, "best": "", "d": INF, "second": INF}
	var best := ""
	var best_d := INF
	var second := INF
	for cmd in dists.keys():
		var d: float = dists[cmd]
		if d < best_d:
			second = best_d
			best_d = d
			best = cmd
		elif d < second:
			second = d
	res["best"] = best
	res["d"] = best_d
	res["second"] = second
	if best == "":
		return res
	var thr: float = thrs.get(best, MATCH_MAX)
	var accept := best_d <= thr and (second == INF or best_d <= second * MARGIN)
	if not accept and second < INF:
		var k := clampf((18.0 - snr) / 5.0, 0.0, 1.0)
		accept = k > 0.0 and best_d <= thr + NOISY_EXTRA * k and best_d <= second * NOISY_MARGIN
	if not accept:
		return res
	var conf := clampf(1.15 - best_d / thr, 0.0, 1.0)
	if second < INF:
		conf = minf(conf, clampf((second - best_d) / maxf(second, 0.001) * 4.0, 0.0, 1.0))
	res["cmd"] = best
	res["conf"] = maxf(conf, 0.05)
	return res

## Compare un énoncé aux modèles de l'animal. Retourne {cmd, conf, best, d, second}.
## cmd est vide si rien n'est reconnu avec une marge suffisante.
func recognize(feats: Array, p: Dictionary = {}, snr: float = 99.0) -> Dictionary:
	if p.is_empty():
		p = GameState.active_pet()
	if p.is_empty() or feats.size() < MIN_FRAMES:
		return decide({})
	var q := prep(feats)
	var dists := {}
	var thrs := {}
	for cmd in p.get("voice", {}).keys():
		var dmin := INF
		var tp := _templates(p, cmd)
		for t in tp["flat"]:
			dmin = minf(dmin, dtw_flat(q, t))
		if dmin < INF:
			dists[cmd] = dmin
			thrs[cmd] = tp["thr"]
	return decide(dists, snr, thrs)

# ------------------------------------------------------------------ micro
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_tables()
	if FileAccess.file_exists(LEGACY_PATH):
		DirAccess.remove_absolute(LEGACY_PATH)   # ancien format (6 bandes), incompatible
	_out = AudioStreamPlayer.new()
	_out.bus = "Master"
	add_child(_out)

func available() -> bool:
	return test_mode or AudioServer.get_input_device_list().size() > 0 or OS.has_feature("android")

func has_permission() -> bool:
	if not OS.has_feature("android"):
		return true
	return OS.get_granted_permissions().has("android.permission.RECORD_AUDIO")

## Demande la permission micro si besoin ; le résultat arrive par permission_result.
func ensure_permission() -> bool:
	if has_permission():
		return true
	if OS.has_feature("android"):
		if not _perm_connected:
			_perm_connected = true
			get_tree().on_request_permissions_result.connect(_on_perm)
		OS.request_permission("RECORD_AUDIO")
	return false

## Résumé technique affiché quand la capture échoue, pour savoir où le son se perd.
func diag() -> String:
	return "micro : autorisation %s · %d entrée(s) · %d Hz · %d images · niveau max %.4f · %d trou(s)" % ["oui" if has_permission() else "non", AudioServer.get_input_device_list().size(), int(AudioServer.get_mix_rate()), _dbg_frames, _dbg_peak, _dbg_holes]

## Alias utilisé par l'écran des paramètres.
func request_permission() -> bool:
	return ensure_permission()

func _on_perm(perm: String, granted: bool) -> void:
	if perm.ends_with("RECORD_AUDIO"):
		permission_result.emit(granted)

func _setup() -> bool:
	if _capture != null:
		return true
	_bus = AudioServer.get_bus_index("Mic")
	if _bus == -1:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, "Mic")
		AudioServer.set_bus_volume_db(_bus, -80.0)   # jamais rejoué dans les haut-parleurs
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 1.0
	AudioServer.add_bus_effect(_bus, _capture)
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = "Mic"
	add_child(_player)
	return true

func _open_mic() -> void:
	if test_mode:
		return
	_setup()
	_mix_rate = float(AudioServer.get_mix_rate())
	if _player and not _player.playing:
		_player.play()

func _close_mic() -> void:
	if _hold > 0 or listening:
		return
	if _player and _player.playing:
		_player.stop()

## Garde le micro ouvert entre deux captures (écran d'apprentissage) : évite le délai de
## redémarrage du micro à chaque enregistrement.
func hold_mic(on: bool) -> void:
	_hold = maxi(0, _hold + (1 if on else -1))
	if on:
		if has_permission() and available():
			_open_mic()
	else:
		_close_mic()
	Audio.duck_for_mic(_hold > 0 or listening)

func _reset_stream() -> void:
	_buf = PackedFloat32Array()
	_recent = PackedFloat32Array()
	_ring_rms = PackedFloat32Array()
	_u_rms = PackedFloat32Array()
	_u_mel = []
	_u_clip = PackedInt32Array()
	_utt_samples = PackedFloat32Array()
	_calib = PackedFloat32Array()
	_noise_mel = PackedFloat32Array()
	_in_speech = false
	_above = 0
	_silence = 0
	_phase = 0
	_phase_n = 0
	_hp_x = 0.0
	_hp_y = 0.0
	_noise = 0.002
	_nm_tick = 0
	_zrun = 0
	_rs_hist = PackedFloat32Array()
	_rs_pos = 0.0
	_no_audio_t = 0.0
	_restarted = false
	_stage2 = false
	_dbg_frames = 0
	_dbg_peak = 0.0
	_dbg_holes = 0
	_no_audio_sent = false
	_wait_frames = 0
	_bursts = 0
	_job = {}

## Écoute continue : les mots reconnus arrivent par heard(cmd, confiance).
func start_listening() -> bool:
	if not test_mode:
		if not ensure_permission():
			return false
		if not available():
			return false
		_open_mic()
		if _capture:
			_capture.clear_buffer()
	if not listening:
		_reset_stream()
		capture_state.emit("starting")
	listening = true
	_mode = "recognize"
	Audio.duck_for_mic(true)
	state_changed.emit(true)
	return true

func stop_listening() -> void:
	var was := listening
	listening = false
	_mode = "recognize"
	_job = {}
	_close_mic()
	Audio.duck_for_mic(_hold > 0)
	if was:
		state_changed.emit(false)

## Capture un seul mot (pour l'apprentissage) ; le résultat arrive par utterance_ready.
## timeout : temps laissé pour commencer à parler, compté à partir du moment où le micro
## livre réellement du son et où le bruit de fond est calibré (signal capture_state "ready").
func record_utterance(timeout: float = START_TIMEOUT) -> bool:
	var resume := listening
	if not start_listening():
		utterance_ready.emit({"ok": false, "reason": "permission" if not has_permission() else "no_mic"})
		return false
	_mode = "record"
	_timeout_frames = int(timeout * SR / HOP)
	_wait_frames = 0
	_bursts = 0
	_in_speech = false
	_above = 0
	_no_audio_t = 0.0
	_no_audio_sent = false
	_job = {}
	set_meta("resume", resume)
	capture_state.emit("ready" if _phase == 2 else "starting")
	return true

func cancel_record() -> void:
	if _mode == "record":
		_mode = "recognize"
		if not bool(get_meta("resume", false)):
			stop_listening()

func is_recording() -> bool:
	return listening and _mode == "record"

## Vrai quand le micro livre du son et que le bruit de fond est calibré.
func is_ready() -> bool:
	return listening and _phase == 2

## Secondes restantes pour commencer à parler (capture d'un mot).
func time_left() -> float:
	return maxf(0.0, float(_timeout_frames - _wait_frames) * HOP / SR)

## Joue un enregistrement (échantillons 16 kHz), volume normalisé.
func play_samples(s: PackedFloat32Array) -> void:
	if s.is_empty() or _out == null:
		return
	var pk := 0.0
	for v in s:
		pk = maxf(pk, absf(v))
	var g := minf(0.7 / maxf(pk, 0.001), 30.0)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	var n := s.size()
	var fade := mini(240, n / 4)
	var prev := 0.0
	for i in n:
		var env := 1.0
		if i < fade:
			env = float(i) / fade
		elif i > n - fade:
			env = float(n - i) / fade
		# lissage très léger : adoucit le souffle aigu sans étouffer la voix
		prev = lerpf(prev, s[i], 0.8)
		bytes.encode_s16(i * 2, int(clampf(prev * g * env, -1.0, 1.0) * 32767.0))
	w.data = bytes
	_out.stream = w
	_out.play()

func _fail_record(reason: String) -> void:
	_mode = "recognize"
	_in_speech = false
	if not bool(get_meta("resume", false)):
		stop_listening()
	utterance_ready.emit({"ok": false, "reason": reason})

func _process(delta: float) -> void:
	if not listening:
		if _hold > 0 and _capture != null and not test_mode:
			_capture.clear_buffer()
		return
	# garde-fou : le micro ne livre aucun son (délai compté en temps réel)
	_no_audio_t += delta
	if _no_audio_t > 1.5 and not _restarted and not test_mode and _player != null:
		_restarted = true
		_player.stop()
		_player.play()
	if _no_audio_t > 3.0 and not _stage2 and not test_mode and _player != null:
		# toujours rien : on rouvre complètement l'entrée audio du système
		_stage2 = true
		_player.stop()
		_player.queue_free()
		AudioServer.input_device = AudioServer.input_device
		_player = AudioStreamPlayer.new()
		_player.stream = AudioStreamMicrophone.new()
		_player.bus = "Mic"
		add_child(_player)
		_player.play()
		if _capture:
			_capture.clear_buffer()
	if _no_audio_t > NO_AUDIO_TIMEOUT:
		if _mode == "record":
			_fail_record("no_audio")
			return
		elif not _no_audio_sent:
			_no_audio_sent = true
			capture_state.emit("no_audio")
	if not _job.is_empty():
		_job_step(5000)
	if _capture == null or test_mode:
		return
	var n := _capture.get_frames_available()
	if n <= 0:
		return
	feed_raw(_capture.get_buffer(n), _mix_rate)

func _build_resampler(rate: float) -> void:
	_rs_rate = rate
	_rs_hist = PackedFloat32Array()
	_rs_pos = float(RS_TAPS / 2)
	_rs_table = PackedFloat32Array()
	_rs_table.resize(RS_TAPS * RS_PHASES)
	var fc := minf(RS_CUTOFF, rate * 0.45) / rate     # cycles par échantillon d'entrée
	var half := RS_TAPS / 2
	for ph in RS_PHASES:
		var frac := float(ph) / RS_PHASES
		var sum := 0.0
		for k in RS_TAPS:
			var t := float(k - half + 1) - frac
			var s := 2.0 * fc
			if absf(t) > 1e-6:
				s = sin(TAU * fc * t) / (PI * t)
			var wn := 0.5 + 0.5 * cos(PI * clampf(t / float(half), -1.0, 1.0))
			_rs_table[ph * RS_TAPS + k] = s * wn
			sum += s * wn
		for k in RS_TAPS:
			_rs_table[ph * RS_TAPS + k] /= sum

## Reçoit l'audio du micro tel que livré par le moteur (stéréo, taux de mixage) : retire les
## trous de silence numérique (micro pas encore démarré, tampon d'entrée sous-alimenté),
## passe en mono, filtre (anti-repliement) et rééchantillonne à 16 kHz, puis alimente feed().
func feed_raw(frames: PackedVector2Array, mix_rate: float) -> void:
	if not listening or frames.is_empty():
		return
	if mix_rate != _rs_rate or _rs_table.is_empty():
		_build_resampler(mix_rate)
	var hist := _rs_hist
	var zr := _zrun
	var heal := _heal
	var pk := _dbg_peak
	for fr in frames:
		var v := (fr.x + fr.y) * 0.5
		if v == 0.0:
			zr += 1
			continue
		if zr > 0:
			if zr < ZERO_RUN:
				# quelques zéros de suite sont du vrai signal (micro à faible niveau) : on les garde
				for k in zr:
					hist.append(0.0)
			else:
				# trou du pilote audio (tampon d'entrée sous-alimenté) : on le retire et on raccorde
				# en douceur sur quelques millisecondes pour éviter le clic (grésillement)
				heal = HEAL_LEN
				_dbg_holes += 1
			zr = 0
		if heal > 0 and hist.size() > 0:
			var k2 := 1.0 - float(heal) / HEAL_LEN
			v = lerpf(hist[hist.size() - 1], v, k2 * k2)
			heal -= 1
		if absf(v) > pk:
			pk = absf(v)
		hist.append(v)
	_dbg_peak = pk
	_dbg_frames += frames.size()
	_zrun = zr
	_heal = heal
	var ratio := mix_rate / float(SR)
	var out := PackedFloat32Array()
	var half := RS_TAPS / 2
	var pos := _rs_pos
	var limit := float(hist.size() - half - 1)
	var table := _rs_table
	while pos < limit:
		var i0 := int(pos)
		var tb := int((pos - i0) * RS_PHASES) * RS_TAPS
		var b := i0 - half + 1
		var s := 0.0
		for k in RS_TAPS:
			s += hist[b + k] * table[tb + k]
		out.append(s)
		pos += ratio
	var drop := int(pos) - half
	if drop > 0:
		hist = hist.slice(drop)
		pos -= drop
	_rs_hist = hist
	_rs_pos = pos
	if resample_probe_on:
		resample_probe.append_array(out)
	feed(out)

## Injecte des échantillons mono à 16 kHz (utilisé par le micro et par les tests).
func feed(samples: PackedFloat32Array) -> void:
	if samples.is_empty():
		return
	_no_audio_t = 0.0
	_buf.append_array(samples)
	var off := 0
	var total := _buf.size()
	while off + FRAME <= total and listening:
		_on_frame(_buf.slice(off, off + FRAME))
		off += HOP
	if off > 0:
		_buf = _buf.slice(off)

func _start_thr() -> float:
	return maxf(_noise * START_RATIO, ABS_FLOOR)

func _stop_thr() -> float:
	return maxf(_noise * STOP_RATIO, ABS_FLOOR * 0.7)

func _update_noise_mel(x: PackedFloat32Array, fast: bool) -> void:
	var m := frame_mel(x)
	if _noise_mel.size() != N_MEL:
		_noise_mel = m
		return
	var a := 0.5 if fast else 0.15
	for k in N_MEL:
		_noise_mel[k] = lerpf(_noise_mel[k], m[k], a)

func _on_frame(x: PackedFloat32Array) -> void:
	# niveau du cadre après un passe-haut à environ 200 Hz (chocs, souffle, ronflement ignorés)
	var e := 0.0
	var clip := 0
	var hx := _hp_x
	var hy := _hp_y
	var first := _recent.is_empty()
	var i0 := 0 if first else FRAME - HOP
	if first:
		hx = x[0]
	var eh := 0.0
	for i in range(i0, FRAME):
		var v := x[i]
		hy = v - hx + 0.92 * hy
		hx = v
		eh += hy * hy
		e += v * v
		if absf(v) > 0.985:
			clip += 1
	_hp_x = hx
	_hp_y = hy
	var rms := sqrt(eh / float(FRAME - i0))
	level.emit(clampf(rms / maxf(_noise * 30.0, 0.01), 0.0, 1.0))
	# mémoire glissante (échantillons et niveaux) pour récupérer le début du mot
	_recent.append_array(x if first else x.slice(FRAME - HOP))
	var keep := (PRE_ROLL - 1) * HOP + FRAME
	if _recent.size() > keep:
		_recent = _recent.slice(_recent.size() - keep)
	if not _in_speech:
		_ring_rms.append(rms)
		if _ring_rms.size() > PRE_ROLL:
			_ring_rms = _ring_rms.slice(_ring_rms.size() - PRE_ROLL)
	if _phase == 0:
		_phase_n += 1
		if _phase_n >= SKIP_FRAMES:
			_phase = 1
			_phase_n = 0
			_calib = PackedFloat32Array()
			capture_state.emit("calibrating")
		return
	if _phase == 1:
		_calib.append(rms)
		if _calib.size() % 4 == 0:
			_update_noise_mel(x, true)
		if _calib.size() >= CALIB_FRAMES:
			var s := _calib.duplicate()
			s.sort()
			_noise = maxf(s[s.size() / 3] * 1.15, 1e-5)
			_phase = 2
			_above = 0
			_wait_frames = 0
			capture_state.emit("ready")
		return
	if not _in_speech:
		var st := _start_thr()
		if rms < _noise:
			_noise = maxf(lerpf(_noise, rms, 0.15), 1e-5)
		elif rms < st:
			_noise = lerpf(_noise, rms, 0.03)
		if rms < st:
			_nm_tick += 1
			if _nm_tick >= 4:
				_nm_tick = 0
				_update_noise_mel(x, false)
		if _mode == "record":
			_wait_frames += 1
		if rms > st:
			_above += 1
			if _above >= START_FRAMES:
				_begin_speech()
				return
		else:
			_above = 0
		if _mode == "record" and _wait_frames > _timeout_frames:
			# un bruit ambiant très fort empêche de distinguer la voix
			_fail_record("noisy" if _noise > 0.02 else ("too_short" if _bursts > 0 else "silence"))
		return
	_u_rms.append(rms)
	_u_mel.append(frame_mel(x))
	_u_clip.append(clip)
	_utt_samples.append_array(x.slice(FRAME - HOP))
	if rms < _stop_thr():
		_silence += 1
	else:
		_silence = 0
	if _silence >= END_SILENCE or _u_rms.size() >= MAX_FRAMES + PRE_ROLL + END_SILENCE:
		_in_speech = false
		_above = 0
		_finish_utterance(_silence < END_SILENCE)

func _begin_speech() -> void:
	_in_speech = true
	_silence = 0
	_u_rms = _ring_rms.duplicate()
	_u_mel = []
	_u_clip = PackedInt32Array()
	for k in _u_rms.size():
		_u_mel.append(null)      # calculé plus tard si le cadre fait partie du mot
		_u_clip.append(0)
	var need := (_u_rms.size() - 1) * HOP + FRAME
	_utt_samples = _recent.slice(maxi(0, _recent.size() - need))
	_ring_rms = PackedFloat32Array()
	_speech_t0 = Time.get_ticks_msec() - PRE_ROLL * 20
	if _mode == "record":
		capture_state.emit("speech")

## Bornes du mot dans l'énoncé capté. Le cœur du mot est délimité par les cadres nettement
## au-dessus du bruit (et à moins de 22 dB du niveau de la parole) ; il est ensuite étendu de
## chaque côté aux sons faibles voisins (consonnes sourdes, explosion finale après une courte
## tenue), avec un seuil plus bas, puis deux cadres de marge.
static func endpoints(rms: PackedFloat32Array, noise: float) -> Dictionary:
	var n := rms.size()
	var sorted := rms.duplicate()
	sorted.sort()
	var top := 0.0
	var cnt := 0
	for i in range(n - maxi(1, n / 4), n):
		top += sorted[i]
		cnt += 1
	var speech := top / maxf(1.0, float(cnt))
	var thr := maxf(noise * 2.0, speech * 0.08)
	var s := -1
	for i in n:
		if rms[i] > thr and (i + 1 >= n or rms[i + 1] > thr):
			s = i
			break
	var e := -1
	for i in range(n - 1, -1, -1):
		if rms[i] > thr:
			e = i
			break
	if s < 0 or e < s:
		return {"s": 0, "e": -1, "speech": speech, "active": 0}
	var active := 0
	for i in range(s, e + 1):
		if rms[i] > thr:
			active += 1
	# bruit local de part et d'autre du cœur (médiane) : si le bruit ambiant a monté depuis le
	# calibrage, l'extension ne doit pas avaler ce bruit
	var ext := maxf(maxf(noise, _median(rms, 0, s)) * EXT_RATIO, speech * 0.03)
	var gap := 0
	var i2 := s - 1
	var s0 := s
	while i2 >= 0 and gap <= EXT_GAP and s0 - i2 <= EXT_MAX:
		if rms[i2] > ext and (i2 == 0 or rms[i2 - 1] > ext or gap == 0):
			s = i2
			gap = 0
		else:
			gap += 1
		i2 -= 1
	gap = 0
	i2 = e + 1
	var e0 := e
	ext = maxf(maxf(noise, _median(rms, e + 1, n)) * EXT_RATIO, speech * 0.03)
	while i2 < n and gap <= EXT_GAP and i2 - e0 <= EXT_MAX:
		if rms[i2] > ext and (i2 == n - 1 or rms[i2 + 1] > ext or gap == 0):
			e = i2
			gap = 0
		else:
			gap += 1
		i2 += 1
	return {"s": maxi(0, s - 2), "e": mini(n - 1, e + 2), "speech": speech, "active": active}

## Médiane de rms[from:to] (0 si moins de 4 valeurs).
static func _median(rms: PackedFloat32Array, from: int, to: int) -> float:
	if to - from < 4:
		return 0.0
	var part := rms.slice(from, to)
	part.sort()
	return part[part.size() / 2]

func _finish_utterance(forced: bool) -> void:
	var rms := _u_rms
	var mels := _u_mel
	var clips := _u_clip
	var samples := _utt_samples
	_u_rms = PackedFloat32Array()
	_u_mel = []
	_u_clip = PackedInt32Array()
	_utt_samples = PackedFloat32Array()
	_silence = 0
	var ep := endpoints(rms, _noise)
	var s: int = ep["s"]
	var e: int = ep["e"]
	var n := e - s + 1
	var speech: float = ep["speech"]
	var snr := 20.0 * log(maxf(speech, 1e-7) / maxf(_noise, 1e-6)) / log(10.0)
	var res := {"ok": false, "reason": "", "feats": [], "duration": maxi(0, n) * HOP / float(SR), "snr": snr, "frames": maxi(0, n)}
	var record := _mode == "record"
	if forced:
		# son continu : soit une phrase trop longue, soit le bruit ambiant qui a monté
		var med := rms.duplicate()
		med.sort()
		var was := _noise
		_noise = maxf(med[med.size() / 2], 1e-5)
		if record and med[med.size() / 2] > was * 6.0:
			res["reason"] = "too_long"
			_end_record(res)
		return
	if int(ep["active"]) < MIN_FRAMES - 1 or n < MIN_FRAMES:
		# bruit bref (clic, choc du doigt, toux) : ignoré, la capture continue
		if record:
			_bursts += 1
			capture_state.emit("burst")
		return
	var clip := 0
	for i in range(s, e + 1):
		clip += clips[i]
	var a := maxi(0, s * HOP - 1600)
	var b := mini(samples.size(), e * HOP + FRAME + 1600)
	res["samples"] = samples.slice(a, b)
	if record:
		if float(clip) / float(n * HOP) > CLIP_RATIO:
			res["reason"] = "saturated"
		elif snr < MIN_SNR_DB:
			res["reason"] = "noisy"
		elif speech < QUIET_LEVEL:
			res["reason"] = "quiet"
		if res["reason"] != "":
			_end_record(res)
			return
	elif snr < LISTEN_SNR_DB:
		return

	var use: Array = []
	for i in range(s, e + 1):
		if mels[i] == null:
			mels[i] = frame_mel(samples.slice(i * HOP, i * HOP + FRAME))
		use.append(mels[i])
	if debug_keep:
		debug_raws.append({"mel": use, "noise_mel": _noise_mel.duplicate(), "snr": snr, "mode": _mode})
	res["feats"] = make_feats(use, _noise_mel)
	res["ok"] = true
	if record:
		_end_record(res)
		return
	_start_job(res["feats"], snr)

func _end_record(res: Dictionary) -> void:
	_mode = "recognize"
	if not bool(get_meta("resume", false)):
		stop_listening()
	utterance_ready.emit(res)

## Reconnaissance répartie sur plusieurs images (quelques millisecondes par image) pour ne
## jamais bloquer le rendu ; immédiate en mode test.
func _start_job(feats: Array, snr: float) -> void:
	var p := GameState.active_pet()
	var pairs: Array = []
	var thrs := {}
	if not p.is_empty():
		for cmd in p.get("voice", {}).keys():
			var tp := _templates(p, cmd)
			for t in tp["flat"]:
				pairs.append([cmd, t])
				thrs[cmd] = tp["thr"]
	_job = {"q": prep(feats), "pairs": pairs, "i": 0, "d": {}, "snr": snr, "thr": thrs,
		# un effet sonore du jeu (aboiement, jingle) a pu être capté par le micro : dans ce cas
		# un échec de reconnaissance n'est pas signalé au joueur
		"sfx": not test_mode and Audio.sfx_until_msec > _speech_t0}
	if test_mode:
		_job_step(100000000)

func _job_step(budget_usec: int) -> void:
	var t0 := Time.get_ticks_usec()
	var pairs: Array = _job["pairs"]
	var d: Dictionary = _job["d"]
	var i: int = _job["i"]
	while i < pairs.size():
		var pr: Array = pairs[i]
		var dist := dtw_flat(_job["q"], pr[1])
		d[pr[0]] = minf(float(d.get(pr[0], INF)), dist)
		i += 1
		if Time.get_ticks_usec() - t0 > budget_usec:
			break
	_job["i"] = i
	if i < pairs.size():
		return
	var snr: float = _job["snr"]
	var thrs: Dictionary = _job["thr"]
	var sfx: bool = _job["sfx"]
	_job = {}
	var r := decide(d, snr, thrs)
	if r["cmd"] != "":
		heard.emit(r["cmd"], r["conf"])
	elif float(r["d"]) <= MATCH_MAX * NEAR_MISS and not sfx:
		# seuls les sons qui ressemblent à un mot enregistré sont signalés « non reconnu » ;
		# les bruits sans rapport (porte, toux, conversation) sont ignorés en silence
		unrecognized.emit(str(r["best"]), float(r["d"]))

## Contrôle qualité d'un énoncé déjà découpé (compatibilité, utilisé par les tests).
static func analyze(fr: Array, rms: PackedFloat32Array, noise: float, _clip_ratio: float, forced: bool) -> Dictionary:
	var n := fr.size()
	var res := {"ok": false, "reason": "", "feats": [], "duration": n * HOP / float(SR), "snr": 0.0, "frames": n}
	if n < MIN_FRAMES or rms.size() < n:
		res["reason"] = "too_short"
		return res
	if forced:
		res["reason"] = "too_long"
		return res
	var ep := endpoints(rms, noise)
	res["snr"] = 20.0 * log(maxf(float(ep["speech"]), 1e-7) / maxf(noise, 1e-6)) / log(10.0)
	if res["snr"] < MIN_SNR_DB:
		res["reason"] = "noisy"
		return res
	res["ok"] = true
	res["feats"] = make_feats(fr, PackedFloat32Array())
	return res
