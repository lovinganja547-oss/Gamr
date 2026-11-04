extends Node
## Commandes vocales hors ligne par empreinte vocale (dépendantes du locuteur).
## Chaîne : micro -> rééchantillonnage 16 kHz -> porte de bruit adaptative et détection de parole
## -> caractéristiques de type MFCC (FFT 512 points en GDScript, 24 bandes mel, 12 coefficients
## + énergie) -> comparaison DTW avec les modèles enregistrés pour l'animal actif (pet["voice"]).
## Aucune donnée ne quitte l'appareil. Rien n'est jamais « reconnu » sans une marge suffisante.

signal heard(cmd: String, confidence: float)
signal unrecognized(best_cmd: String, distance: float)
signal level(value: float)
signal utterance_ready(result: Dictionary)
signal state_changed(listening: bool)
signal permission_result(granted: bool)

const SR := 16000
const FRAME := 512
const HOP := 320               # 20 ms
const N_MEL := 24
const N_CEPS := 12
const DIMS := N_CEPS + 1
const MAX_TEMPLATES := 3
const MAX_FRAMES := 120        # 2,4 s
const MIN_FRAMES := 14         # 0,28 s (avec amorce et fin)
const PRE_ROLL := 4
const END_SILENCE := 16        # 320 ms de silence = fin du mot
const MATCH_MAX := 0.92        # distance DTW maximale acceptée (caractéristiques normalisées)
const MARGIN := 0.85           # le meilleur doit être nettement plus proche que le second
const MIN_SNR_DB := 12.0
const CLIP_RATIO := 0.004
const LEGACY_PATH := "user://voice.json"

const QUALITY_TEXT := {
	"too_short": "Trop court : dites un mot entier, clairement.",
	"too_long": "Trop long : un seul mot court suffit.",
	"saturated": "Son saturé : parlez moins fort ou éloignez le téléphone.",
	"noisy": "Trop de bruit de fond : trouvez un endroit plus calme.",
	"silence": "Rien entendu : parlez plus près du micro.",
	"no_mic": "Aucun micro disponible.",
	"permission": "Autorisez l'accès au micro pour continuer.",
}

var listening := false
var test_mode := false          # tests : pas de micro, échantillons injectés par feed()
var _mode := "recognize"        # recognize | record
var _record_timeout := 0.0
var _record_t := 0.0
var _capture: AudioEffectCapture
var _player: AudioStreamPlayer
var _out: AudioStreamPlayer
var _bus := -1
var _mix_rate := 44100.0
var _pos := 0.0
var _prev := 0.0
var _in_count := 0
var _buf := PackedFloat32Array()
var _recent := PackedFloat32Array()
var _feat_ring: Array = []
var _frames: Array = []
var _frame_rms := PackedFloat32Array()
var _utt_samples := PackedFloat32Array()
var _in_speech := false
var _above := 0
var _silence := 0
var _noise := 0.004
var _nf_init := 0
var _clip := 0
var _nsamp := 0
var _cache := {}
var _perm_connected := false

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
	# Banc de filtres mel (triangulaires) entre 80 Hz et 7000 Hz
	var lo := _hz_to_mel(80.0)
	var hi := _hz_to_mel(7000.0)
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

## Caractéristiques d'un cadre : [log énergie, 12 coefficients cepstraux mel].
static func frame_features(x: PackedFloat32Array) -> PackedFloat32Array:
	_init_tables()
	var n := mini(x.size(), FRAME)
	var mean := 0.0
	for i in n:
		mean += x[i]
	mean /= maxf(1.0, float(n))
	var y := PackedFloat32Array()
	y.resize(FRAME)
	var e := 0.0
	var prev := 0.0
	for i in n:
		var v: float = x[i] - mean
		y[i] = v - 0.97 * prev   # pré-accentuation
		prev = v
		e += y[i] * y[i]
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
		mel[m] = log(s + 1e-9)
	var out := PackedFloat32Array()
	out.resize(DIMS)
	out[0] = log(e / maxf(1.0, float(n)) + 1e-9)
	for c in N_CEPS:
		var s2 := 0.0
		for m in N_MEL:
			s2 += _dct[c * N_MEL + m] * mel[m]
		out[c + 1] = s2
	return out

## Caractéristiques d'un signal complet (16 kHz) : une ligne par cadre de 20 ms.
static func features(samples: PackedFloat32Array) -> Array:
	var out: Array = []
	var i := 0
	while i + FRAME <= samples.size():
		out.append(frame_features(samples.slice(i, i + FRAME)))
		i += HOP
	return out

## Normalisation par énoncé (moyenne et écart-type par dimension, plancher d'écart-type).
static func normalize(fr: Array) -> Array:
	if fr.is_empty():
		return []
	var dims: int = (fr[0] as PackedFloat32Array).size()
	var mean := PackedFloat32Array(); mean.resize(dims)
	var sd := PackedFloat32Array(); sd.resize(dims)
	for f in fr:
		for d in dims:
			mean[d] += f[d]
	for d in dims:
		mean[d] /= fr.size()
	for f in fr:
		for d in dims:
			sd[d] += (f[d] - mean[d]) * (f[d] - mean[d])
	for d in dims:
		sd[d] = maxf(sqrt(sd[d] / fr.size()), 0.35)
	var out: Array = []
	for f in fr:
		var g := PackedFloat32Array(); g.resize(dims)
		for d in dims:
			g[d] = (f[d] - mean[d]) / sd[d]
		out.append(g)
	return out

## Distance DTW (bande de Sakoe-Chiba), normalisée par la longueur du chemin.
static func dtw(a: Array, b: Array) -> float:
	var n := a.size()
	var m := b.size()
	if n == 0 or m == 0:
		return INF
	var inf := 1e20
	var prev := PackedFloat32Array(); prev.resize(m + 1); prev.fill(inf); prev[0] = 0.0
	var cur := PackedFloat32Array(); cur.resize(m + 1)
	var band := maxi(int(maxf(n, m) * 0.35), absi(n - m) + 2)
	for i in range(1, n + 1):
		cur.fill(inf)
		var fa: PackedFloat32Array = a[i - 1]
		var dims := fa.size()
		var j0 := maxi(1, int(float(i) * m / n) - band)
		var j1 := mini(m, int(float(i) * m / n) + band)
		for j in range(j0, j1 + 1):
			var fb: PackedFloat32Array = b[j - 1]
			var c := 0.0
			for d in dims:
				var x := fa[d] - fb[d]
				c += x * x
			cur[j] = sqrt(c / dims) + minf(prev[j], minf(cur[j - 1], prev[j - 1]))
		var t := prev; prev = cur; cur = t
	return prev[m] / float(n + m) * 2.0

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

## Valide la structure pet["voice"] : {cmd: {"word": String, "tpl": [modèle…], "uses": int, "hits": int}}.
static func sanitize_voice(v: Variant) -> Dictionary:
	var out := {}
	if not (v is Dictionary):
		return out
	for cmd in v.keys():
		if not GameData.COMMANDS.has(str(cmd)) or not (v[cmd] is Dictionary):
			continue
		var e: Dictionary = v[cmd]
		var tpls: Array = []
		for t in e.get("tpl", []):
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
		if tpls.is_empty():
			continue
		out[str(cmd)] = {
			"word": str(e.get("word", "")).substr(0, 20),
			"tpl": tpls,
			"uses": maxi(0, int(e.get("uses", 0))),
			"hits": maxi(0, int(e.get("hits", 0))),
		}
	return out

func _entry(p: Dictionary, cmd: String) -> Dictionary:
	var v: Dictionary = p.get("voice", {})
	return v.get(cmd, {})

func template_count(p: Dictionary, cmd: String) -> int:
	return (_entry(p, cmd).get("tpl", []) as Array).size()

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

func _templates(p: Dictionary, cmd: String) -> Array:
	var key := str(p.get("id", "")) + "/" + cmd
	if _cache.has(key):
		return _cache[key]
	var out: Array = []
	for t in _entry(p, cmd).get("tpl", []):
		out.append(unpack_feats(t))
	_cache[key] = out
	return out

func invalidate_cache() -> void:
	_cache.clear()

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
	if e.is_empty():
		return
	e["uses"] = int(e.get("uses", 0)) + 1
	if ok:
		e["hits"] = int(e.get("hits", 0)) + 1
	GameState.mark_dirty()

## Cohérence des modèles d'un ordre (0..1) : des modèles proches entre eux = empreinte stable.
func consistency(p: Dictionary, cmd: String) -> float:
	var t := _templates(p, cmd)
	if t.size() < 2:
		return 0.7 if t.size() == 1 else 0.0
	var tot := 0.0
	var n := 0
	for i in t.size():
		for j in range(i + 1, t.size()):
			tot += dtw(t[i], t[j])
			n += 1
	var d := tot / maxf(1.0, float(n))
	return clampf(1.25 - d / MATCH_MAX, 0.2, 1.0)

## Fiabilité estimée (0..1) : nombre de modèles, cohérence, et réussites en usage réel.
func reliability(p: Dictionary, cmd: String) -> float:
	var n := template_count(p, cmd)
	if n == 0:
		return 0.0
	var r := sqrt(float(n) / MAX_TEMPLATES) * consistency(p, cmd)
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

## Compare un énoncé aux modèles de l'animal. Retourne {cmd, conf, best, d, second}.
## cmd est vide si rien n'est reconnu avec une marge suffisante.
func recognize(feats: Array, p: Dictionary = {}) -> Dictionary:
	if p.is_empty():
		p = GameState.active_pet()
	var res := {"cmd": "", "conf": 0.0, "best": "", "d": INF, "second": INF}
	if p.is_empty() or feats.size() < MIN_FRAMES:
		return res
	var best := ""
	var best_d := INF
	var second := INF
	for cmd in p.get("voice", {}).keys():
		var dmin := INF
		for tpl in _templates(p, cmd):
			dmin = minf(dmin, dtw(feats, tpl))
		if dmin < best_d:
			second = best_d
			best_d = dmin
			best = cmd
		elif dmin < second:
			second = dmin
	res["best"] = best
	res["d"] = best_d
	res["second"] = second
	if best == "" or best_d > MATCH_MAX:
		return res
	if second < INF and best_d > second * MARGIN:
		return res
	var conf := clampf(1.0 - best_d / MATCH_MAX, 0.0, 1.0)
	if second < INF:
		conf = minf(conf, clampf((second - best_d) / maxf(second, 0.001) * 3.0, 0.0, 1.0))
	if conf < 0.1:
		return res
	res["cmd"] = best
	res["conf"] = conf
	return res

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
	_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(_bus, _capture)
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = "Mic"
	add_child(_player)
	_mix_rate = float(AudioServer.get_mix_rate())
	return true

func _reset_stream() -> void:
	_buf = PackedFloat32Array()
	_recent = PackedFloat32Array()
	_feat_ring.clear()
	_frames.clear()
	_frame_rms = PackedFloat32Array()
	_utt_samples = PackedFloat32Array()
	_in_speech = false
	_above = 0
	_silence = 0
	_clip = 0
	_nsamp = 0
	_pos = 0.0
	_prev = 0.0
	_in_count = 0
	_nf_init = 0
	_noise = 0.004

## Écoute continue : les mots reconnus arrivent par heard(cmd, confiance).
func start_listening() -> bool:
	if not test_mode:
		if not ensure_permission():
			return false
		if not available():
			return false
		_setup()
		if _player and not _player.playing:
			_player.play()
		if _capture:
			_capture.clear_buffer()
	if not listening:
		_reset_stream()
	listening = true
	_mode = "recognize"
	state_changed.emit(true)
	return true

func stop_listening() -> void:
	var was := listening
	listening = false
	_mode = "recognize"
	if _player and _player.playing:
		_player.stop()
	if was:
		state_changed.emit(false)

## Capture un seul mot (pour l'apprentissage) ; le résultat arrive par utterance_ready.
func record_utterance(timeout: float = 5.0) -> bool:
	var resume := listening
	if not start_listening():
		utterance_ready.emit({"ok": false, "reason": "permission" if not has_permission() else "no_mic"})
		return false
	_mode = "record"
	_record_timeout = timeout
	_record_t = 0.0
	_in_speech = false
	_frames.clear()
	_frame_rms = PackedFloat32Array()
	_utt_samples = PackedFloat32Array()
	set_meta("resume", resume)
	return true

func cancel_record() -> void:
	if _mode == "record":
		_mode = "recognize"
		if not bool(get_meta("resume", false)):
			stop_listening()

func is_recording() -> bool:
	return listening and _mode == "record"

## Joue un enregistrement (échantillons 16 kHz).
func play_samples(s: PackedFloat32Array) -> void:
	if s.is_empty() or _out == null:
		return
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	w.data = bytes
	_out.stream = w
	_out.play()

func _process(delta: float) -> void:
	if not listening:
		return
	if _mode == "record":
		_record_t += delta
		if not _in_speech and _record_t > _record_timeout:
			_mode = "recognize"
			if not bool(get_meta("resume", false)):
				stop_listening()
			utterance_ready.emit({"ok": false, "reason": "silence"})
			return
	if _capture == null or test_mode:
		return
	var n := _capture.get_frames_available()
	if n <= 0:
		return
	var st := _capture.get_buffer(n)
	var ratio := _mix_rate / float(SR)
	var out := PackedFloat32Array()
	for i in n:
		var mono: float = (st[i].x + st[i].y) * 0.5
		var g := float(_in_count + i)
		while _pos <= g:
			var frac := clampf(_pos - (g - 1.0), 0.0, 1.0)
			out.append(lerpf(_prev, mono, frac))
			_pos += ratio
		_prev = mono
	_in_count += n
	feed(out)

## Injecte des échantillons mono à 16 kHz (utilisé par le micro et par les tests).
func feed(samples: PackedFloat32Array) -> void:
	if samples.is_empty():
		return
	_buf.append_array(samples)
	var keep := (PRE_ROLL + 2) * HOP
	_recent.append_array(samples)
	if _recent.size() > keep:
		_recent = _recent.slice(_recent.size() - keep)
	while _buf.size() >= FRAME and listening:
		_on_frame(_buf.slice(0, FRAME))
		_buf = _buf.slice(HOP)

func _on_frame(x: PackedFloat32Array) -> void:
	var e := 0.0
	var clip := 0
	for v in x:
		e += v * v
		if absf(v) > 0.985:
			clip += 1
	var rms := sqrt(e / x.size())
	level.emit(clampf(rms * 9.0, 0.0, 1.0))
	if not _in_speech:
		if _nf_init < 8:
			_noise = lerpf(_noise, rms, 0.4)
			_nf_init += 1
		elif rms < _noise:
			_noise = lerpf(_noise, rms, 0.25)
		else:
			_noise = lerpf(_noise, rms, 0.03)
	var start_thr := maxf(_noise * 2.5, 0.006)
	var stop_thr := maxf(_noise * 1.6, 0.004)
	var f: Variant = null
	if _in_speech or rms > stop_thr:
		f = frame_features(x)
	if not _in_speech:
		_feat_ring.append(f)
		while _feat_ring.size() > PRE_ROLL:
			_feat_ring.pop_front()
		if rms > start_thr:
			_above += 1
			if _above >= 2:
				_in_speech = true
				_silence = 0
				_frames.clear()
				_frame_rms = PackedFloat32Array()
				_clip = 0
				_nsamp = 0
				for pf in _feat_ring:
					if pf != null:
						_frames.append(pf)
						_frame_rms.append(0.0)
				_feat_ring.clear()
				_utt_samples = _recent.duplicate()
		else:
			_above = 0
		return
	_frames.append(f)
	_frame_rms.append(rms)
	_clip += clip
	_nsamp += HOP
	_utt_samples.append_array(x.slice(FRAME - HOP))
	if rms < stop_thr:
		_silence += 1
	else:
		_silence = 0
	if _silence >= END_SILENCE or _frames.size() >= MAX_FRAMES:
		var forced := _frames.size() >= MAX_FRAMES
		_in_speech = false
		_above = 0
		_finish_utterance(forced)

func _finish_utterance(forced: bool) -> void:
	var fr: Array = _frames.duplicate()
	var rm := _frame_rms.duplicate()
	_frames.clear()
	_frame_rms = PackedFloat32Array()
	var trim := maxi(0, _silence - 3)
	_silence = 0
	for i in trim:
		if fr.size() > 1:
			fr.pop_back()
			rm.remove_at(rm.size() - 1)
	var res := analyze(fr, rm, _noise, float(_clip) / maxf(1.0, float(_nsamp)), forced)
	res["samples"] = _utt_samples.duplicate()
	_utt_samples = PackedFloat32Array()
	if _mode == "record":
		_mode = "recognize"
		if not bool(get_meta("resume", false)):
			stop_listening()
		utterance_ready.emit(res)
		return
	if not res["ok"]:
		if res["reason"] != "too_short":
			unrecognized.emit("", INF)
		return
	var r := recognize(res["feats"])
	if r["cmd"] != "":
		heard.emit(r["cmd"], r["conf"])
	else:
		unrecognized.emit(str(r["best"]), float(r["d"]))

## Contrôle qualité d'un énoncé. Retourne {ok, reason, feats, duration, snr, frames}.
static func analyze(fr: Array, rms: PackedFloat32Array, noise: float, clip_ratio: float, forced: bool) -> Dictionary:
	var n := fr.size()
	var res := {"ok": false, "reason": "", "feats": [], "duration": n * HOP / float(SR), "snr": 0.0, "frames": n}
	var sorted := rms.duplicate()
	sorted.sort()
	var top := 0.0
	var cnt := 0
	for i in range(sorted.size() / 2, sorted.size()):
		top += sorted[i]
		cnt += 1
	var speech := top / maxf(1.0, float(cnt))
	var snr := 20.0 * log(maxf(speech, 1e-6) / maxf(noise, 1e-5)) / log(10.0)
	res["snr"] = snr
	if n < MIN_FRAMES:
		res["reason"] = "too_short"
		return res
	if forced:
		res["reason"] = "too_long"
		return res
	if clip_ratio > CLIP_RATIO:
		res["reason"] = "saturated"
		return res
	if snr < MIN_SNR_DB:
		res["reason"] = "noisy"
		return res
	res["ok"] = true
	res["feats"] = normalize(fr)
	return res
