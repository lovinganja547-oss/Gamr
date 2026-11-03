extends Node
## Commandes vocales hors ligne (facultatives).
## Le joueur enregistre sa voix pour chaque commande ; la reconnaissance compare
## ensuite les mots prononcés à ces modèles (DTW sur des caractéristiques spectrales).
## Fonctionne sans Internet sur tout appareil disposant d'un micro.

signal heard(cmd: String, confidence: float)
signal level(value: float)
signal template_recorded(cmd: String, ok: bool)
signal state_changed(listening: bool)

const VOICE_PATH := "user://voice.json"
const MAX_TEMPLATES := 3
const MATCH_THRESHOLD := 0.62
const HOP := 512

var templates := {}    # cmd -> Array[Array[PackedFloat32Array]]
var listening := false
var _recording_cmd := ""
var _capture: AudioEffectCapture
var _player: AudioStreamPlayer
var _bus := -1
var _frames: Array[PackedFloat32Array] = []
var _in_speech := false
var _silence := 0
var _noise_floor := 0.002
var _lp1 := 0.0
var _lp2 := 0.0
var _lp3 := 0.0
var _buf := PackedFloat32Array()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()

func available() -> bool:
	return AudioServer.get_input_device_list().size() > 0 or OS.has_feature("android")

func has_permission() -> bool:
	if not OS.has_feature("android"):
		return true
	return OS.get_granted_permissions().has("android.permission.RECORD_AUDIO")

func request_permission() -> void:
	if OS.has_feature("android") and not has_permission():
		OS.request_permissions()

func trained_count() -> int:
	var n := 0
	for c in templates.keys():
		if not templates[c].is_empty():
			n += 1
	return n

func _setup() -> bool:
	if _capture != null:
		return true
	_bus = AudioServer.get_bus_index("Mic")
	if _bus == -1:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, "Mic")
		AudioServer.set_bus_volume_db(_bus, -80.0)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(_bus, _capture)
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = "Mic"
	add_child(_player)
	return true

func start_listening() -> bool:
	if not has_permission():
		request_permission()
		return false
	_setup()
	if not _player.playing:
		_player.play()
	_capture.clear_buffer()
	_frames.clear()
	_in_speech = false
	listening = true
	state_changed.emit(true)
	return true

func stop_listening() -> void:
	listening = false
	_recording_cmd = ""
	if _player and _player.playing:
		_player.stop()
	state_changed.emit(false)

## Enregistre un modèle : le prochain mot prononcé sera associé à cmd.
func record_template(cmd: String) -> bool:
	if not start_listening():
		return false
	_recording_cmd = cmd
	return true

func clear_templates(cmd: String = "") -> void:
	if cmd == "":
		templates.clear()
	else:
		templates.erase(cmd)
	_save()

func _process(_delta: float) -> void:
	if not listening or _capture == null:
		return
	var n := _capture.get_frames_available()
	if n <= 0:
		return
	var st := _capture.get_buffer(n)
	# décimation x2 (mono)
	for i in range(0, st.size(), 2):
		_buf.append((st[i].x + st[i].y) * 0.5)
		if _buf.size() >= HOP:
			_frame(_buf)
			_buf = PackedFloat32Array()

func _frame(x: PackedFloat32Array) -> void:
	var e := 0.0
	var zc := 0
	var b1 := 0.0
	var b2 := 0.0
	var b3 := 0.0
	var b4 := 0.0
	var prev := 0.0
	for v in x:
		e += v * v
		if (v >= 0.0) != (prev >= 0.0):
			zc += 1
		prev = v
		_lp1 += 0.12 * (v - _lp1)      # < ~600 Hz
		_lp2 += 0.35 * (v - _lp2)      # < ~2 kHz
		_lp3 += 0.65 * (v - _lp3)      # < ~5 kHz
		b1 += _lp1 * _lp1
		b2 += (_lp2 - _lp1) * (_lp2 - _lp1)
		b3 += (_lp3 - _lp2) * (_lp3 - _lp2)
		b4 += (v - _lp3) * (v - _lp3)
	var rms := sqrt(e / x.size())
	level.emit(clampf(rms * 12.0, 0.0, 1.0))
	if not _in_speech:
		_noise_floor = lerpf(_noise_floor, rms, 0.05)
	var thr := maxf(_noise_floor * 3.5, 0.01)
	var eps := 1e-7
	var f := PackedFloat32Array([
		log(e + eps), float(zc) / x.size() * 10.0,
		log(b1 + eps), log(b2 + eps), log(b3 + eps), log(b4 + eps),
	])
	if rms > thr:
		if not _in_speech:
			_in_speech = true
			_frames.clear()
		_silence = 0
		_frames.append(f)
	elif _in_speech:
		_silence += 1
		_frames.append(f)
		if _silence > 10 or _frames.size() > 90:
			_in_speech = false
			_finish_utterance()
	if _in_speech and _frames.size() > 90:
		_in_speech = false
		_finish_utterance()

func _finish_utterance() -> void:
	var fr := _frames.duplicate()
	_frames.clear()
	while fr.size() > 0 and _silence > 0:
		fr.pop_back()
		_silence -= 1
	_silence = 0
	if fr.size() < 6:
		return
	var feats := normalize(fr)
	if _recording_cmd != "":
		var cmd := _recording_cmd
		_recording_cmd = ""
		var arr: Array = templates.get(cmd, [])
		arr.append(feats)
		while arr.size() > MAX_TEMPLATES:
			arr.pop_front()
		templates[cmd] = arr
		_save()
		template_recorded.emit(cmd, true)
		return
	var res := recognize(feats)
	if res[0] != "":
		heard.emit(res[0], res[1])

static func normalize(fr: Array) -> Array:
	var dims: int = fr[0].size()
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
		sd[d] = sqrt(sd[d] / fr.size()) + 0.0001
	var out: Array = []
	for f in fr:
		var g := PackedFloat32Array(); g.resize(dims)
		for d in dims:
			g[d] = (f[d] - mean[d]) / sd[d]
		out.append(g)
	return out

static func dtw(a: Array, b: Array) -> float:
	var n := a.size()
	var m := b.size()
	if n == 0 or m == 0:
		return INF
	var inf := 1e20
	var prev := PackedFloat32Array(); prev.resize(m + 1); prev.fill(inf); prev[0] = 0.0
	var cur := PackedFloat32Array(); cur.resize(m + 1)
	var band := maxi(int(maxf(n, m) * 0.4), absi(n - m) + 2)
	for i in range(1, n + 1):
		cur.fill(inf)
		var fa: PackedFloat32Array = a[i - 1]
		var j0 := maxi(1, int(float(i) * m / n) - band)
		var j1 := mini(m, int(float(i) * m / n) + band)
		for j in range(j0, j1 + 1):
			var fb: PackedFloat32Array = b[j - 1]
			var c := 0.0
			for d in fa.size():
				c += absf(fa[d] - fb[d])
			cur[j] = c / fa.size() + minf(prev[j], minf(cur[j - 1], prev[j - 1]))
		var t := prev; prev = cur; cur = t
	return prev[m] / float(n + m)

## Retourne [commande, confiance] ou ["", 0].
func recognize(feats: Array) -> Array:
	var best := ""
	var best_d := INF
	var second := INF
	for cmd in templates.keys():
		var dmin := INF
		for tpl in templates[cmd]:
			dmin = minf(dmin, dtw(feats, tpl))
		if dmin < best_d:
			second = best_d
			best_d = dmin
			best = cmd
		elif dmin < second:
			second = dmin
	if best == "" or best_d > MATCH_THRESHOLD:
		return ["", 0.0]
	var conf := clampf(1.0 - best_d / MATCH_THRESHOLD, 0.0, 1.0)
	if second < INF:
		conf = minf(conf, clampf((second - best_d) / maxf(second, 0.001) * 3.0, 0.0, 1.0))
	if conf < 0.08:
		return ["", 0.0]
	return [best, conf]

func _save() -> void:
	var out := {}
	for cmd in templates.keys():
		var arr: Array = []
		for tpl in templates[cmd]:
			var flat: Array = []
			for f in tpl:
				flat.append(Array(f))
			arr.append(flat)
		out[cmd] = arr
	var f := FileAccess.open(VOICE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))
		f.close()

func _load() -> void:
	templates.clear()
	if not FileAccess.file_exists(VOICE_PATH):
		return
	var f := FileAccess.open(VOICE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	for cmd in parsed.keys():
		if not GameData.COMMANDS.has(cmd) or not (parsed[cmd] is Array):
			continue
		var arr: Array = []
		for tpl in parsed[cmd]:
			if not (tpl is Array) or tpl.is_empty():
				continue
			var frames: Array = []
			var ok := true
			for fr in tpl:
				if not (fr is Array) or fr.size() != 6:
					ok = false
					break
				frames.append(PackedFloat32Array(fr))
			if ok:
				arr.append(frames)
		if not arr.is_empty():
			templates[cmd] = arr
