class_name AgilityGame
extends Activity
## Parcours d'agilité : l'animal court le long du parcours, le joueur fait le
## bon geste au bon moment devant chaque obstacle. Chrono + pénalités.

const TYPES := {
	"hurdle": {"name": "Haie", "gesture": "U", "icon": "↑"},
	"tunnel": {"name": "Tunnel", "gesture": "D", "icon": "↓"},
	"weave": {"name": "Slalom", "gesture": "H", "icon": "↔"},
	"tire": {"name": "Pneu", "gesture": "U", "icon": "↑"},
}
const PENALTY := 5.0

var comp := false
var level := 0
var path: PackedVector3Array = PackedVector3Array()
var cum: PackedFloat32Array = PackedFloat32Array()
var length := 0.0
var s := 0.0
var speed := 2.4
var base_speed := 2.4
var obstacles: Array[Dictionary] = []
var nodes: Array[Node3D] = []
var next_obs := 0
var elapsed := 0.0
var penalties := 0.0
var faults := 0
var running := false
var _stall := 0.0
var gesture := GestureRecognizer.new()
var prompt: PanelContainer
var prompt_l: Label
var prompt_ring: ProgressBar
var chrono_l: Label
var _countdown := 3.0
var _action_t := 0.0
var _action := ""

func _init(params: Dictionary = {}) -> void:
	comp = bool(params.get("comp", false))
	level = int(params.get("level", 0))

func _start() -> void:
	make_top("🏃 " + tr("Parcours d'agilité"), not comp)
	info_label.text = tr("Faites le geste indiqué quand l'anneau est vert !")
	chrono_l = UiKit.label("0.0 s", 44, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var cp := UiKit.panel(10)
	cp.add_child(chrono_l)
	cp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	cp.position = Vector2(-120, 140)
	cp.custom_minimum_size = Vector2(240, 0)
	ui.add_child(cp)
	prompt = UiKit.panel(16, Color(1, 1, 1, 0.92))
	var pv := UiKit.vbox(6)
	prompt_l = UiKit.label("", 64, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	pv.add_child(prompt_l)
	prompt_ring = UiKit.bar(0, UiKit.C_ACCENT2, 18)
	pv.add_child(prompt_ring)
	prompt.add_child(pv)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.custom_minimum_size = Vector2(420, 0)
	prompt.position = Vector2(-210, -330)
	prompt.visible = false
	ui.add_child(prompt)
	_build_course()
	var p := GameState.active_pet()
	var b := GameData.breed(p["breed"])
	base_speed = (2.0 + float(b["stats"]["agility"]) / 100.0 * 1.4) * lerpf(0.6, 1.0, p["needs"]["energy"] / 100.0)
	base_speed *= 1.0 + GameState.skill("jump") / 100.0 * 0.15
	speed = base_speed
	pet.position = path[0]
	pet.state = "action"
	pet.model.set_posture("stand")
	main.cam_rig.target = pet
	main.cam_rig.follow = true
	main.cam_rig.reset_view(4.6, -0.6, PI)
	Audio.music("music_play")
	big_hint("3", 0.5)
	Audio.play("tick")

func _build_course() -> void:
	var n := 5 + level
	var center := Vector3(0, 0, -2.5)
	var rx := 4.3
	var rz := 3.3
	var steps := 96
	for i in steps + 1:
		var a := PI / 2 + TAU * float(i) / steps
		path.append(center + Vector3(cos(a) * rx, 0, sin(a) * rz))
	cum.append(0.0)
	for i in range(1, path.size()):
		length += path[i].distance_to(path[i - 1])
		cum.append(length)
	var kinds: Array = ["hurdle", "weave", "tunnel", "tire", "hurdle", "weave", "tunnel", "hurdle"]
	for i in n:
		var d := length * (0.1 + 0.82 * float(i) / maxf(1.0, n - 1.0))
		var kind: String = kinds[i % kinds.size()]
		obstacles.append({"d": d, "type": kind, "done": false, "ok": false})
		nodes.append(_make_obstacle(kind, d))

func _sample(d: float) -> Vector3:
	d = clampf(d, 0.0, length)
	var lo := 0
	var hi := cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if cum[mid] < d:
			lo = mid
		else:
			hi = mid
	var seg := cum[hi] - cum[lo]
	var t := 0.0 if seg <= 0.0 else (d - cum[lo]) / seg
	return path[lo].lerp(path[hi], t)

func _make_obstacle(kind: String, d: float) -> Node3D:
	var n := Node3D.new()
	var p := _sample(d)
	var p2 := _sample(d + 0.1)
	n.position = p
	n.rotation.y = atan2(p2.x - p.x, p2.z - p.z)
	main.world.add_child(n)
	var col := Color(0.95, 0.35, 0.3)
	match kind:
		"hurdle":
			for sx in [-0.55, 0.55]:
				WorldBuilder.box(n, Vector3(0.07, 0.6, 0.07), Vector3(sx, 0.3, 0), Color(1, 1, 1))
			WorldBuilder.cyl(n, 0.025, 0.025, 1.1, Vector3(0, 0.38, 0), col, 8, Vector3(0, 0, PI / 2))
		"tire":
			for sx in [-0.6, 0.6]:
				WorldBuilder.box(n, Vector3(0.07, 1.0, 0.07), Vector3(sx, 0.5, 0), Color(1, 1, 1))
			WorldBuilder.torus(n, 0.22, 0.34, Vector3(0, 0.6, 0), Color(0.25, 0.25, 0.3), Vector3(PI / 2, 0, 0))
		"tunnel":
			for k in 6:
				WorldBuilder.torus(n, 0.32, 0.4, Vector3(0, 0.32, -0.6 + k * 0.24), Color(0.3, 0.55, 0.95) if k % 2 else Color(0.95, 0.85, 0.3), Vector3(PI / 2, 0, 0))
		"weave":
			for k in 6:
				WorldBuilder.cyl(n, 0.025, 0.025, 0.9, Vector3(0, 0.45, -0.75 + k * 0.3), col if k % 2 else Color(1, 1, 1), 8)
	return n

func handle_input(event: InputEvent) -> bool:
	if finished or not running:
		return true
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			gesture.begin(event.position)
		else:
			gesture.add(event.position)
			_on_gesture(gesture.finish())
		return true
	if event is InputEventScreenDrag and event.index == 0:
		gesture.add(event.position)
		return true
	return false

func _window(o: Dictionary) -> Vector2:
	var w := 1.8 - level * 0.2
	return Vector2(o["d"] - w, o["d"] - 0.15)

func _on_gesture(g: String) -> void:
	if next_obs >= obstacles.size() or g == "T":
		return
	var o := obstacles[next_obs]
	var win := _window(o)
	if s < win.x - 1.2:
		return   # trop tôt : ignoré
	var want: String = TYPES[o["type"]]["gesture"]
	var ok := false
	if want == "H":
		ok = g.length() > 0 and g.replace("L", "").replace("R", "") == ""
	else:
		ok = g == want
	if ok and s >= win.x:
		_pass(o)
	else:
		_fault(o, tr("Raté !") if not ok else tr("Trop tôt !"))

func _pass(o: Dictionary) -> void:
	o["done"] = true
	o["ok"] = true
	next_obs += 1
	prompt.visible = false
	Audio.play("chime", 0.05, -6.0)
	_action = o["type"]
	_action_t = 0.0
	match _action:
		"hurdle", "tire":
			pet._jump_t = 0.0
			pet._jump_dur = 0.55
			pet._jump_h = 0.45
			pet.model.set_posture("jump", 10.0)
	speed = base_speed * 1.05

func _fault(o: Dictionary, msg: String) -> void:
	o["done"] = true
	next_obs += 1
	faults += 1
	penalties += PENALTY
	prompt.visible = false
	Audio.play("buzz")
	big_hint(msg + "  +%ds" % int(PENALTY), 0.8, UiKit.C_DANGER)
	_stall = 1.2
	pet.model.emote("❓")
	pet.model.set_posture("alert")
	main.cam_rig.shake(0.04)

func _process(delta: float) -> void:
	if finished:
		return
	if not running:
		_countdown -= delta
		var c := int(ceil(_countdown))
		if c != int(ceil(_countdown + delta)):
			if c > 0:
				big_hint(str(c), 0.5)
				Audio.play("tick")
			else:
				big_hint(tr("Partez !"), 0.6, UiKit.C_ACCENT2)
				Audio.play("whistle")
				running = true
		return
	elapsed += delta
	chrono_l.text = "%.1f s" % (elapsed + penalties)
	if _stall > 0.0:
		_stall -= delta
		pet.model.move_speed = 0.0
		if _stall <= 0.0:
			pet.model.set_posture("stand")
		return
	s += speed * delta
	speed = move_toward(speed, base_speed, delta)
	var p := _sample(s)
	var ahead := _sample(s + 0.3)
	# Slalom / tunnel : petit décalage et posture basse
	var lateral := Vector3.ZERO
	if _action != "":
		_action_t += delta
		if _action == "weave" and _action_t < 1.2:
			var dirv := (ahead - p).normalized()
			lateral = Vector3(dirv.z, 0, -dirv.x) * sin(_action_t * 14.0) * 0.18
		elif _action == "tunnel" and _action_t < 0.9:
			pet.model.set_posture("lie", 10.0)
			pet.model.move_speed = 0.0
		elif _action_t > 0.6:
			if pet.model.posture != "stand":
				pet.model.set_posture("stand", 6.0)
			_action = ""
	pet.position = p + lateral
	pet._yaw_target = atan2(ahead.x - p.x, ahead.z - p.z)
	if _action != "tunnel":
		pet.model.move_speed = speed
	main.cam_rig.yaw = lerp_angle(main.cam_rig.yaw, pet.rotation.y + PI, minf(1.0, delta * 2.0))
	# Invite pour l'obstacle suivant
	if next_obs < obstacles.size():
		var o := obstacles[next_obs]
		var win := _window(o)
		if s >= win.x - 1.2:
			prompt.visible = true
			prompt_l.text = "%s  %s" % [TYPES[o["type"]]["icon"], tr(TYPES[o["type"]]["name"])]
			var k := clampf((s - (win.x - 1.2)) / 1.2, 0.0, 1.0)
			prompt_ring.value = k * 100.0
			var in_win := s >= win.x
			prompt.modulate = Color(0.75, 1.0, 0.75) if in_win else Color.WHITE
		if s > win.y:
			_fault(o, tr("Trop tard !"))
	if s >= length:
		_finish()

func _finish() -> void:
	running = false
	finished = true
	prompt.visible = false
	pet.model.move_speed = 0.0
	pet.model.set_posture("sit")
	var total := elapsed + penalties
	var par := length / 3.0 + obstacles.size() * 0.2
	var score := clampf(100.0 - maxf(0.0, total - par) * 3.0 - faults * 6.0, 0.0, 100.0)
	GameState.inc_stat("agility_run", 1)
	if faults == 0:
		GameState.set_stat_max("agility_clean", 1)
	GameState.spend_energy("agility")
	GameState.change_need("thirst", -8.0)
	GameState.change_need("hunger", -5.0)
	GameState.add_relation(6)
	Audio.play("cheer")
	pet.model.expression = "happy"
	pet.model.emote("🏁")
	Audio.music("music_home")
	if on_done.is_valid():
		on_done.call(score)
		return
	show_results("🏃 " + tr("Parcours terminé"), [
		tr("Temps : %.1f s (dont %d s de pénalités)") % [total, int(penalties)],
		tr("Fautes : %d") % faults, tr("Note : %d / 100") % int(score)], int(score / 3.0) + 5, 30)

func _on_quit() -> void:
	Audio.music("music_home")

func _exit_tree() -> void:
	super._exit_tree()
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
