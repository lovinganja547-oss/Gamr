extends Node
## Musique (fondu enchaîné), ambiances et effets sonores sur bus séparés.

const POOL_SIZE := 8
var _music: Array[AudioStreamPlayer] = []
var _music_idx := 0
var _amb: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _cache := {}
var _current_music := ""
var _current_amb := ""
var _duck := false
var sfx_until_msec := 0     # fin estimée du dernier effet sonore joué (le micro l'entend aussi)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		add_child(m)
		_music.append(m)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "SFX"
	_amb.volume_db = -6.0
	add_child(_amb)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	apply_volumes()

func _stream(sound_name: String, looped: bool = false) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var path := "res://assets/audio/%s.wav" % sound_name
	if not ResourceLoader.exists(path):
		push_warning("Son manquant : " + sound_name)
		_cache[sound_name] = null
		return null
	var s: AudioStream = load(path)
	if looped and s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
	_cache[sound_name] = s
	return s

func apply_volumes() -> void:
	var st: Dictionary = GameState.data.get("settings", {})
	_set_bus("Master", float(st.get("master", 0.9)))
	_set_bus("Music", float(st.get("music", 0.6)) * (0.12 if _duck else 1.0))
	_set_bus("SFX", float(st.get("sfx", 0.9)))

## Baisse la musique pendant que le micro écoute (elle couvrirait la voix du joueur).
func duck_for_mic(on: bool) -> void:
	if on == _duck:
		return
	_duck = on
	apply_volumes()
	if _amb:
		_amb.volume_db = -22.0 if on else -6.0

func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))

func play(sound_name: String, pitch_var: float = 0.06, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := _stream(sound_name)
	if s == null:
		return
	sfx_until_msec = maxi(sfx_until_msec, Time.get_ticks_msec() + int(s.get_length() * 1000.0))
	var p: AudioStreamPlayer = null
	for q in _pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _pool[0]
		_pool.push_back(_pool.pop_front())
	p.stream = s
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.volume_db = vol_db
	p.play()

func music(track: String) -> void:
	if track == _current_music:
		return
	_current_music = track
	var old := _music[_music_idx]
	_music_idx = 1 - _music_idx
	var nw := _music[_music_idx]
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, 1.2)
		tw.tween_callback(old.stop)
	if track == "":
		return
	nw.stream = _stream(track, true)
	if nw.stream == null:
		return
	nw.volume_db = -40.0
	nw.play()
	var tw2 := create_tween()
	tw2.tween_property(nw, "volume_db", -4.0, 1.5)

func ambience(sound_name: String) -> void:
	if sound_name == _current_amb:
		return
	_current_amb = sound_name
	if sound_name == "":
		_amb.stop()
		return
	_amb.stream = _stream(sound_name, true)
	if _amb.stream:
		_amb.play()

func vibrate(ms: int = 30) -> void:
	if GameState.setting("vibration") and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
