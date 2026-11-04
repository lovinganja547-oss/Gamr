class_name AgilityGame
extends Activity
## Parcours d'agilité : l'animal court le long du tracé ; devant chaque obstacle un gros bouton
## d'action contextuel apparaît et il faut le toucher dans la fenêtre (verte = parfait).
## 5 niveaux, 8 types d'obstacles, 4 tracés, score, médailles et records par animal.

const PENALTY := 3.0

var comp := false
var level := 0
var L: Dictionary
var layout := "oval"
var seed_v := 0
var path := PackedVector3Array()
var cum := PackedFloat32Array()
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
var perfects := 0
var points := 0.0
var running := false
var _stall := 0.0
var _hold := 0.0
var _countdown := 3.0
var _early_lock := 0.0
var _act: Dictionary = {}       # obstacle en cours d'animation
var action_btn: Button
var action_box: PanelContainer
var action_sub: Label
var timing_bar: ProgressBar
var zone: ColorRect
var chrono_l: Label
var restart_btn: Button

func _init(params: Dictionary = {}) -> void:
	comp = bool(params.get("comp", false))
	level = clampi(int(params.get("level", 0)), 0, GameData.AGILITY_LEVELS.size() - 1)
	seed_v = int(params.get("seed", 0))
	if seed_v == 0:
		seed_v = randi()

func _start() -> void:
	L = GameData.AGILITY_LEVELS[level]
	make_top("[i:agility] " + tr("Agilité · %s") % tr(L["name"]), not comp)
	chrono_l = UiKit.label("0.0 s", 40, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var cp := UiKit.panel(10)
	cp.add_child(chrono_l)
	cp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	cp.position = Vector2(-120, 140)
	cp.custom_minimum_size = Vector2(240, 0)
	ui.add_child(cp)
	# Gros bouton d'action contextuel + jauge de timing
	var bb := bottom_bar()
	action_box = UiKit.panel(14, Color(1, 1, 1, 0.94))
	action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(8)
	action_sub = UiKit.label("", 22, UiKit.C_SUB, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(action_sub)
	var tb := Control.new()
	tb.custom_minimum_size = Vector2(0, 22)
	timing_bar = UiKit.bar(0, UiKit.C_ACCENT, 22)
	timing_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tb.add_child(timing_bar)
	zone = ColorRect.new()
	zone.color = Color(0.36, 0.7, 0.62, 0.55)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zone.anchor_left = 0.55
	zone.offset_left = 0
	tb.add_child(zone)
	v.add_child(tb)
	var h := UiKit.hbox(10)
	action_btn = UiKit.button(tr("Prêt…"), action, UiKit.C_DISABLED, 40, 150)
	action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(action_btn)
	restart_btn = UiKit.button("[i:reload]", restart, UiKit.C_BLUE, 30, 150)
	restart_btn.custom_minimum_size = Vector2(110, 150)
	restart_btn.tooltip_text = tr("Recommencer")
	restart_btn.visible = not comp
	h.add_child(restart_btn)
	v.add_child(h)
	action_box.add_child(v)
	bb.add_child(action_box)
	_build_course()
	var p := GameState.active_pet()
	var b := GameData.breed(p["breed"])
	base_speed = (1.9 + float(b["stats"]["agility"]) / 100.0 * 1.3) * lerpf(0.7, 1.0, p["needs"]["energy"] / 100.0) * float(L["speed"])
	base_speed *= 1.0 + GameState.skill("jump") / 100.0 * 0.12
	speed = base_speed
	pet.position = path[0]
	pet.state = "action"
	pet.model.set_posture("stand")
	pet._yaw_target = atan2(path[1].x - path[0].x, path[1].z - path[0].z)
	pet.rotation.y = pet._yaw_target
	main.cam_rig.target = pet
	main.cam_rig.follow = true
	main.cam_rig.focus_offset = Vector3(0, 0.3, 0)
	main.cam_rig.reset_view(4.4, -0.55, pet.rotation.y + PI)
	main.cam_rig.snap()
	Audio.music("music_play")
	info_label.text = tr("Tracé %s · %d obstacles") % [tr(GameData.AGILITY_LAYOUT_NAMES[layout]), obstacles.size()]
	big_hint("3", 0.5)
	Audio.play("tick")
	_update_prompt()

# ================================================================== Tracés
func _layout_points(kind: String) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var c := Vector3(0, 0, -2.5)
	var steps := 120
	match kind:
		"serpentine":
			for i in steps + 1:
				var t := float(i) / steps
				pts.append(c + Vector3(sin(t * PI * 3.0) * 3.2, 0, 4.0 - t * 8.5))
		"figure8":
			for i in steps + 1:
				var t := TAU * float(i) / steps
				var k := 1.0 + sin(t) * sin(t)
				pts.append(c + Vector3(4.6 * cos(t) / k, 0, 3.4 * sin(t) * cos(t) / k * 2.0))
		"loop":
			var rx := 4.2
			var rz := 3.2
			var r := 1.3
			var corners := [Vector3(rx - r, 0, rz - r), Vector3(-(rx - r), 0, rz - r), Vector3(-(rx - r), 0, -(rz - r)), Vector3(rx - r, 0, -(rz - r))]
			for ci in 4:
				var cc: Vector3 = c + corners[ci]
				var a0 := ci * PI * 0.5
				for i in 16:
					var a := a0 + PI * 0.5 * float(i) / 15.0
					pts.append(cc + Vector3(cos(a) * r, 0, sin(a) * r))
			pts.append(pts[0])
		_:
			for i in steps + 1:
				var a := PI / 2 + TAU * float(i) / steps
				pts.append(c + Vector3(cos(a) * 4.3, 0, sin(a) * 3.3))
	return pts

func _build_course() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var layouts: Array = L["layouts"]
	layout = str(layouts[rng.randi() % layouts.size()])
	path = _layout_points(layout)
	cum = PackedFloat32Array([0.0])
	length = 0.0
	for i in range(1, path.size()):
		length += path[i].distance_to(path[i - 1])
		cum.append(length)
	var n := int(L["obstacles"])
	var kinds: Array = L["kinds"]
	var d0 := length * 0.09
	var spacing := length * 0.84 / float(n)
	var last := ""
	for i in n:
		var kind := str(kinds[rng.randi() % kinds.size()])
		if kind == last and kinds.size() > 1:
			kind = str(kinds[(kinds.find(kind) + 1) % kinds.size()])
		if kind == "stop" and (i == n - 1 or last == "stop"):
			kind = "hurdle"
		var d := d0 + spacing * i
		if kind == "combo":
			_add_obstacle("hurdle", d, 1)
			_add_obstacle("hoop", d + 1.4, 2)
		else:
			_add_obstacle(kind, d, 0)
		last = kind

func _add_obstacle(kind: String, d: float, combo: int) -> void:
	var o := {"d": d, "type": kind, "done": false, "ok": false, "combo": combo, "span": float(GameData.AGILITY_OBSTACLES[kind]["span"])}
	obstacles.append(o)
	nodes.append(_make_obstacle(kind, d, o["span"]))

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

func _make_obstacle(kind: String, d: float, span: float) -> Node3D:
	var n := Node3D.new()
	var p := _sample(d)
	var p2 := _sample(d + 0.1)
	n.position = p
	n.rotation.y = atan2(p2.x - p.x, p2.z - p.z)
	main.world.add_child(n)
	var red := Color(0.95, 0.35, 0.3)
	var white := Color(1, 1, 1)
	var wood := Color(0.78, 0.58, 0.38)
	match kind:
		"hurdle":
			for sx in [-0.55, 0.55]:
				WorldBuilder.box(n, Vector3(0.07, 0.6, 0.07), Vector3(sx, 0.3, 0), white)
			WorldBuilder.cyl(n, 0.025, 0.025, 1.1, Vector3(0, 0.38, 0), red, 8, Vector3(0, 0, PI / 2))
		"hoop":
			WorldBuilder.box(n, Vector3(0.9, 0.06, 0.4), Vector3(0, 0.03, 0), Color(0.3, 0.3, 0.34))
			WorldBuilder.cyl(n, 0.03, 0.03, 0.5, Vector3(0, 0.25, 0), white, 8)
			WorldBuilder.torus(n, 0.3, 0.38, Vector3(0, 0.72, 0), red, Vector3(0, 0, 0))
		"tunnel":
			for k in 6:
				WorldBuilder.torus(n, 0.32, 0.4, Vector3(0, 0.32, 0.05 + k * span / 5.5), Color(0.3, 0.55, 0.95) if k % 2 else Color(0.95, 0.85, 0.3), Vector3(PI / 2, 0, 0))
		"weave":
			for k in 6:
				WorldBuilder.cyl(n, 0.025, 0.025, 0.9, Vector3(0, 0.45, 0.1 + k * span / 5.5), red if k % 2 else white, 8)
		"platform":
			WorldBuilder.box(n, Vector3(0.9, 0.3, span), Vector3(0, 0.15, span * 0.5), wood)
			WorldBuilder.box(n, Vector3(0.92, 0.03, span + 0.02), Vector3(0, 0.31, span * 0.5), Color(0.35, 0.65, 0.9))
		"walkway":
			var ramp := 0.6
			var mid := span - 2.0 * ramp
			WorldBuilder.box(n, Vector3(0.5, 0.05, ramp * 1.08), Vector3(0, 0.22, ramp * 0.5), wood, Vector3(-atan2(0.45, ramp), 0, 0))
			WorldBuilder.box(n, Vector3(0.5, 0.05, mid), Vector3(0, 0.45, ramp + mid * 0.5), wood)
			WorldBuilder.box(n, Vector3(0.5, 0.05, ramp * 1.08), Vector3(0, 0.22, span - ramp * 0.5), wood, Vector3(atan2(0.45, ramp), 0, 0))
			for z in [ramp + 0.1, span - ramp - 0.1]:
				for sx in [-0.2, 0.2]:
					WorldBuilder.box(n, Vector3(0.05, 0.43, 0.05), Vector3(sx, 0.21, z), Color(0.3, 0.3, 0.34))
		"stop":
			WorldBuilder.cyl(n, 0.6, 0.6, 0.02, Vector3(0, 0.01, span * 0.5), Color(0.95, 0.85, 0.3), 8)
			WorldBuilder.cyl(n, 0.45, 0.45, 0.022, Vector3(0, 0.012, span * 0.5), red, 8)
			WorldBuilder.cyl(n, 0.03, 0.03, 0.9, Vector3(0.75, 0.45, span * 0.5), Color(0.3, 0.3, 0.34), 8)
			WorldBuilder.cyl(n, 0.2, 0.2, 0.03, Vector3(0.75, 0.95, span * 0.5), red, 8, Vector3(0, 0, PI / 2))
	return n

# ================================================================== Jeu
func _window(o: Dictionary) -> Vector2:
	var w := float(L["window"]) * (0.8 if int(o["combo"]) == 2 else 1.0)
	if o["type"] == "stop":
		return Vector2(o["d"] - w * 0.4, o["d"] + float(o["span"]) * 0.7)   # on s'arrête en entrant dans la zone
	return Vector2(o["d"] - w, o["d"] - 0.15)

var _btn_state := ""
func _btn_style(state: String, col: Color) -> void:
	if state == _btn_state:
		return
	_btn_state = state
	action_btn.add_theme_stylebox_override("normal", UiKit.sb(col))
	action_btn.add_theme_stylebox_override("hover", UiKit.sb(col))
	action_btn.add_theme_stylebox_override("pressed", UiKit.sb(col.darkened(0.12), 28, 0, Color.TRANSPARENT, false))
	action_btn.add_theme_stylebox_override("hover_pressed", UiKit.sb(col.darkened(0.12), 28, 0, Color.TRANSPARENT, false))

func _update_prompt() -> void:
	if next_obs >= obstacles.size() or not running:
		action_btn.text = tr("Prêt…") if not running else tr("Fonce !")
		action_btn.icon = null
		_btn_style("off", UiKit.C_DISABLED)
		action_sub.text = ""
		timing_bar.value = 0.0
		return
	var o := obstacles[next_obs]
	var def: Dictionary = GameData.AGILITY_OBSTACLES[o["type"]]
	var win := _window(o)
	var k := clampf((s - win.x) / (win.y - win.x), 0.0, 1.0)
	timing_bar.value = k * 100.0
	var in_win := s >= win.x
	var perfect := in_win and k >= 0.55
	if perfect:
		_btn_style("perfect", UiKit.C_ACCENT2)
	elif in_win:
		_btn_style("ok", UiKit.C_GOLD)
	else:
		_btn_style("wait", UiKit.C_DISABLED)
	var txt: String = tr(def["action"])
	if action_btn.text != txt:
		action_btn.text = txt
		action_btn.icon = UiKit.icon(def["icon"])
	var sub := tr(def["name"])
	if int(o["combo"]) > 0:
		sub = tr("Combiné %d/2 · ") % int(o["combo"]) + sub
	action_sub.text = sub + "   (%d/%d)" % [next_obs + 1, obstacles.size()]

## Appui sur le gros bouton d'action.
func action() -> void:
	if finished or not running or next_obs >= obstacles.size():
		return
	var o := obstacles[next_obs]
	var win := _window(o)
	if s < win.x:
		if _early_lock <= 0.0:
			_early_lock = 0.6
			big_hint(tr("Trop tôt !"), 0.5, UiKit.C_DANGER)
			Audio.play("buzz", 0.0, -12.0)
			main.cam_rig.shake(0.02)
		return
	var k := (s - win.x) / maxf(0.01, win.y - win.x)
	_pass(o, k >= 0.55)

func _pass(o: Dictionary, perfect: bool) -> void:
	o["done"] = true
	o["ok"] = true
	next_obs += 1
	points += 10.0 if perfect else 6.0
	if perfect:
		perfects += 1
		big_hint(tr("Parfait !"), 0.6, UiKit.C_ACCENT2)
		Audio.play("chime", 0.05, -4.0)
	else:
		big_hint(tr("Bien !"), 0.5, UiKit.C_GOLD)
		Audio.play("pop", 0.05, -6.0)
	_act = o.duplicate()
	_act["start"] = s
	match str(o["type"]):
		"hurdle", "hoop":
			pet._jump_t = 0.0
			pet._jump_dur = 0.55 if o["type"] == "hurdle" else 0.62
			pet._jump_h = 0.42 if o["type"] == "hurdle" else 0.62
			pet.model.set_posture("jump", 10.0)
			if o["type"] == "hoop":
				pet.voice()
		"tunnel":
			pet.model.set_posture("lie", 10.0)
		"stop":
			_hold = 0.9
			pet.model.set_posture("sit", 10.0)
			pet.model.move_speed = 0.0
			pet.model.emote("emo_paw")
		"walkway":
			pet.model.set_posture("stand", 6.0)
	speed = base_speed * (1.05 if perfect else 1.0)
	_update_prompt()

func _fault(o: Dictionary, msg: String) -> void:
	o["done"] = true
	next_obs += 1
	faults += 1
	penalties += PENALTY
	Audio.play("buzz")
	big_hint(msg + "  +%ds" % int(PENALTY), 0.8, UiKit.C_DANGER)
	_stall = 1.0
	_act = {}
	pet.model.emote("emo_question")
	pet.model.set_posture("alert")
	main.cam_rig.shake(0.04)
	_update_prompt()

func restart() -> void:
	if comp:
		return
	var params := {"level": level}
	main.end_activity()
	main.start_activity(AgilityGame.new(params))

func _process(delta: float) -> void:
	if finished:
		return
	_early_lock = maxf(0.0, _early_lock - delta)
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
				_update_prompt()
		return
	elapsed += delta
	chrono_l.text = "%.1f s" % (elapsed + penalties)
	if _stall > 0.0:
		_stall -= delta
		pet.model.move_speed = 0.0
		if _stall <= 0.0:
			pet.model.set_posture("stand")
		return
	if _hold > 0.0:
		_hold -= delta
		pet.model.move_speed = 0.0
		if _hold <= 0.0:
			pet.model.set_posture("stand", 6.0)
			_act = {}
		return
	s += speed * delta
	speed = move_toward(speed, base_speed, delta)
	var p := _sample(s)
	var ahead := _sample(s + 0.3)
	var lateral := Vector3.ZERO
	var height := 0.0
	if not _act.is_empty():
		var ds: float = s - float(_act["d"])
		var span: float = _act["span"]
		match str(_act["type"]):
			"weave":
				if ds < span:
					var dirv := (ahead - p).normalized()
					lateral = Vector3(dirv.z, 0, -dirv.x) * sin(ds / span * PI * 5.0) * 0.2
				else:
					_act = {}
			"tunnel":
				if ds >= span:
					pet.model.set_posture("stand", 6.0)
					_act = {}
			"platform":
				if ds < -0.25:
					height = 0.0
				elif ds < 0.0:
					height = lerpf(0.0, 0.3, (ds + 0.25) / 0.25)
				elif ds < span:
					height = 0.3
				elif ds < span + 0.3:
					height = lerpf(0.3, 0.0, (ds - span) / 0.3)
				else:
					_act = {}
			"walkway":
				speed = minf(speed, base_speed * 0.7)
				var ramp := 0.6
				if ds < 0.0:
					height = 0.0
				elif ds < ramp:
					height = 0.45 * ds / ramp
				elif ds < span - ramp:
					height = 0.45
				elif ds < span:
					height = 0.45 * (span - ds) / ramp
				else:
					_act = {}
			_:
				if ds > 0.8:
					if pet.model.posture != "stand" and pet._jump_t < 0.0:
						pet.model.set_posture("stand", 6.0)
					_act = {}
	if pet._jump_t < 0.0:
		pet.model.jump_y = height
	pet.position = p + lateral
	pet._yaw_target = atan2(ahead.x - p.x, ahead.z - p.z)
	pet.model.move_speed = speed
	main.cam_rig.yaw = lerp_angle(main.cam_rig.yaw, pet.rotation.y + PI, minf(1.0, delta * 2.0))
	if next_obs < obstacles.size():
		var o := obstacles[next_obs]
		var win := _window(o)
		_update_prompt()
		if s > win.y:
			_fault(o, tr("Trop tard !"))
	if s >= length:
		_finish()

func _finish() -> void:
	running = false
	finished = true
	pet.model.move_speed = 0.0
	pet.model.jump_y = 0.0
	pet.model.set_posture("sit")
	var total := elapsed + penalties
	var stops := 0
	for o in obstacles:
		if o["type"] == "stop":
			stops += 1
	var par := length / (base_speed * 0.92) + obstacles.size() * 0.3 + stops * 1.0
	var obs_score := points / maxf(1.0, 10.0 * obstacles.size()) * 70.0
	var time_score := clampf(1.0 - maxf(0.0, total - par) / par, 0.0, 1.0) * 30.0
	var score := clampf(obs_score + time_score, 0.0, 100.0)
	var medal := GameData.medal_for(score)
	GameState.inc_stat("agility_run", 1)
	if faults == 0:
		GameState.set_stat_max("agility_clean", 1)
	if medal != "":
		GameState.inc_stat("agility_medal", 1)
		if medal == "gold":
			GameState.inc_stat("agility_gold", 1)
	GameState.spend_energy("agility", 1.0 + level * 0.15)
	GameState.change_need("thirst", -8.0)
	GameState.change_need("hunger", -5.0)
	GameState.change_need("mood", 6.0)
	GameState.add_relation(6)
	var new_best := GameState.set_record("agility_%d" % level, score)
	var new_time := GameState.set_record("agility_time_%d" % level, total, false)
	Audio.play("cheer")
	pet.model.expression = "happy"
	pet.model.emote("emo_flag")
	Audio.music("music_home")
	if on_done.is_valid():
		on_done.call(score)
		return
	var mult := {"gold": 1.0, "silver": 0.7, "bronze": 0.45}.get(medal, 0.2) as float
	var coins := int(round(float(L["coins"]) * mult))
	var xp := maxi(10, int(round(float(L["xp"]) * mult)))
	GameState.add_coins(coins)
	GameState.add_xp(xp)
	Audio.play("coin")
	var v := UiKit.vbox(10)
	if medal != "":
		v.add_child(UiKit.label("[i:medal_%s] " % medal + tr("Médaille %s !") % tr(GameData.medal_name(medal)), 34, UiKit.C_GOLD))
	else:
		v.add_child(UiKit.label(tr("Pas de médaille cette fois (bronze à partir de 45)."), 26, UiKit.C_SUB))
	v.add_child(UiKit.label(tr("Note : %d / 100") % int(score), 30))
	v.add_child(UiKit.label(tr("Temps : %.1f s (dont %d s de pénalités) · Fautes : %d · Parfaits : %d/%d") % [total, int(penalties), faults, perfects, obstacles.size()], 24, UiKit.C_SUB))
	if new_best:
		v.add_child(UiKit.label("[i:star] " + tr("Nouveau record personnel de %s !") % pet_name(), 26, UiKit.C_ACCENT))
	elif new_time:
		v.add_child(UiKit.label("[i:timer] " + tr("Meilleur temps pour ce niveau !"), 26, UiKit.C_ACCENT))
	else:
		v.add_child(UiKit.label(tr("Record : %d / 100") % int(GameState.record("agility_%d" % level)), 24, UiKit.C_SUB))
	v.add_child(UiKit.label("[i:coin] +%d " % coins + tr("pièces") + "   ·   +%d " % xp + tr("pts d'expérience"), 32, UiKit.C_ACCENT))
	var h := UiKit.hbox(10)
	h.add_child(UiKit.expand(UiKit.button("[i:reload] " + tr("Recommencer"), func():
		main.close_panel()
		restart(), UiKit.C_BLUE, 28, 90)))
	h.add_child(UiKit.expand(UiKit.button(tr("Continuer"), func(): main.close_panel(), UiKit.C_ACCENT2, 28, 90)))
	v.add_child(h)
	main.open_panel("[i:agility] " + tr("Parcours terminé"), UiKit.scroll(v), func():
		if main.activity == self:
			main.end_activity())
	GameState.save_game()

func _on_quit() -> void:
	Audio.music("music_home")

func _exit_tree() -> void:
	super._exit_tree()
	if pet and pet.model:
		pet.model.jump_y = 0.0
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
