class_name Competition
extends Activity
## Concours : obéissance, agilité, recherche, dressage avancé. Classement face à 7 rivaux.

var cat := "obedience"
var level := 0
var sub: Activity
var seq: Array[String] = []
var idx := 0
var points := 0.0
var max_points := 0.0
var gesture := GestureRecognizer.new()
var order_l: Label
var timer_bar: ProgressBar
var time_left := 0.0
var waiting := false
var combo := 0
var trace: Line2D
var btn_box: HFlowContainer

func _init(c: String = "obedience", lv: int = 0) -> void:
	cat = c
	level = lv

func _start() -> void:
	var cd: Dictionary = GameData.COMP_CATS[cat]
	Audio.music("music_play")
	Audio.play("cheer", 0.0, -6.0)
	match cat:
		"agility":
			_run_sub(AgilityGame.new({"comp": true, "level": mini(level + 1, GameData.AGILITY_LEVELS.size() - 1)}))
		"search":
			_run_sub(SearchGame.new({"comp": true, "level": mini(level + 1, GameData.SEARCH_LEVELS.size() - 1)}))
		"walk":
			_run_sub(WalkActivity.new({"route": GameData.COMP_WALK_ROUTES[clampi(level, 0, GameData.COMP_WALK_ROUTES.size() - 1)], "comp": true}))
		_:
			make_top("[i:%s] %s · %s" % [cd["icon"], tr(cd["name"]), tr(GameData.COMP_LEVELS[level]["name"])])
			_setup_sequence()

func _run_sub(a: Activity) -> void:
	sub = a
	sub.on_done = _on_sub_done
	add_child(sub)

func _on_sub_done(score: float) -> void:
	if finished:
		return
	await get_tree().create_timer(1.0, false).timeout
	if is_instance_valid(sub):
		sub.queue_free()
	sub = null
	_results(score)

func handle_input(event: InputEvent) -> bool:
	if sub and is_instance_valid(sub):
		return sub.handle_input(event)
	if finished or not waiting:
		return event is InputEventScreenTouch or event is InputEventScreenDrag
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			gesture.begin(event.position)
			trace.points = PackedVector2Array([event.position])
		else:
			gesture.add(event.position)
			var g := gesture.finish()
			trace.points = PackedVector2Array()
			if g == "T":
				return true
			_answer(g)
		return true
	if event is InputEventScreenDrag and event.index == 0:
		gesture.add(event.position)
		trace.add_point(event.position)
		return true
	return false

# ================================================================== Obéissance / dressage avancé
func _setup_sequence() -> void:
	var pool: Array = GameData.COMP_CATS[cat]["skills"]
	var n := 5 + level
	for i in n:
		var c: String = pool[randi() % pool.size()]
		if not seq.is_empty() and seq[seq.size() - 1] == c and pool.size() > 1:
			c = pool[(pool.find(c) + 1) % pool.size()]
		seq.append(c)
	var box := UiKit.panel(18, Color(1, 1, 1, 0.92))
	var v := UiKit.vbox(8)
	order_l = UiKit.label("", 56, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(order_l)
	timer_bar = UiKit.bar(100, UiKit.C_ACCENT, 20)
	v.add_child(timer_bar)
	btn_box = HFlowContainer.new()
	btn_box.add_theme_constant_override("h_separation", 8)
	btn_box.add_theme_constant_override("v_separation", 8)
	for c in pool:
		var cc: String = c
		btn_box.add_child(UiKit.button(tr(GameData.COMMANDS[c]["name"]), func(): _answer_cmd(cc, 0.9), UiKit.C_BLUE, 22, 64))
	v.add_child(btn_box)
	v.add_child(UiKit.label(tr("Faites le geste de l'ordre annoncé (ou touchez le bouton, moins de points)."), 20, UiKit.C_SUB, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(v)
	var bb := bottom_bar()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bb.add_child(box)
	trace = Line2D.new()
	trace.width = 12.0
	trace.default_color = Color(1, 1, 1, 0.85)
	ui.add_child(trace)
	pet.position = Vector3(0, 0, -1.5)
	pet.state = "action"
	pet.player_pos = Vector3(0, 0, 1.2)
	pet.face(pet.player_pos)
	pet.model.set_posture("stand")
	main.cam_rig.target = null
	main.cam_rig.follow = false
	main.cam_rig.focus = Vector3(0, 0.35, -1.5)
	main.cam_rig.reset_view(3.2, -0.28, 0.0)
	big_hint(tr("Le concours commence !"), 1.2)
	await get_tree().create_timer(1.8, false).timeout
	if not finished:
		_next()

func _next() -> void:
	if finished:
		return
	if idx >= seq.size():
		var score := clampf(points / maxf(1.0, max_points) * 100.0, 0.0, 100.0)
		_results(score)
		return
	var c := seq[idx]
	order_l.text = "« %s »" % tr(GameData.COMMANDS[c]["name"])
	info_label.text = tr("Ordre %d/%d · Points : %d") % [idx + 1, seq.size(), int(points)]
	time_left = 5.0 - level * 0.5
	waiting = true
	max_points += 15.0 if cat == "obedience" else 20.0
	Audio.play("whistle", 0.05, -8.0)

func _process(delta: float) -> void:
	if not waiting or finished:
		return
	time_left -= delta
	timer_bar.value = time_left / (5.0 - level * 0.5) * 100.0
	if time_left <= 0.0:
		waiting = false
		combo = 0
		big_hint(tr("Trop lent !"), 0.8, UiKit.C_DANGER)
		Audio.play("buzz")
		idx += 1
		await get_tree().create_timer(1.0, false).timeout
		_next()

func _answer(g: String) -> void:
	var c := seq[idx]
	var cmd_for := ""
	for k in GameData.COMMANDS.keys():
		if GameData.COMMANDS[k]["gesture"] == g:
			cmd_for = k
	if cmd_for == "":
		big_hint(tr("Geste inconnu"), 0.6, UiKit.C_DANGER)
		return
	_answer_cmd(cmd_for, 1.0)
	if cmd_for != c:
		pass

func _answer_cmd(given: String, mult: float) -> void:
	if not waiting:
		return
	waiting = false
	var c := seq[idx]
	var speed_bonus := clampf(time_left / (5.0 - level * 0.5), 0.0, 1.0)
	var ok := false
	if given == c:
		var chance := GameState.success_chance(c) * (0.95 - level * 0.03)
		ok = randf() < chance
	var dur := pet.perform(given if given == c else c) if ok else pet.fail_behaviour(c)
	await get_tree().create_timer(minf(dur, 2.0), false).timeout
	if finished:
		return
	if ok:
		combo += 1
		var base := 10.0 if cat == "obedience" else 12.0 + GameState.skill(c) / 20.0
		var pts := (base + speed_bonus * 5.0) * mult
		if cat == "tricks" and combo >= 2:
			pts *= 1.0 + minf(0.3, combo * 0.1)
		points += pts
		Audio.play("chime", 0.05, -4.0)
		big_hint("+%d" % int(pts), 0.6, UiKit.C_ACCENT2)
		pet.model.emote("emo_star")
	else:
		combo = 0
		Audio.play("fail", 0.0, -6.0)
		big_hint(tr("Raté"), 0.6, UiKit.C_DANGER)
	idx += 1
	await get_tree().create_timer(0.6, false).timeout
	_next()

# ================================================================== Classement
func _results(score: float) -> void:
	finished = true
	waiting = false
	var res := GameState.comp_result(cat, level, snappedf(score, 0.1), randi())
	var place: int = res["place"]
	var medals := ["medal_gold", "medal_silver", "medal_bronze"]
	# Podium
	pet.busy = true
	if place <= 3 and cat != "walk":
		var pos: Vector3 = [Vector3(6.0, 0.5, -6.0), Vector3(5.1, 0.35, -6.0), Vector3(6.9, 0.25, -6.0)][place - 1]
		pet.stop_moving()
		pet.position = pos
		pet.rotation.y = 0.0
		pet._yaw_target = 0.0
		pet.model.set_posture("sit")
		pet.model.expression = "happy"
		pet.model.wag_amp = 1.0
		pet.model.emote(["emo_medal1", "emo_medal2", "emo_medal3"][place - 1], 3.0)
		main.cam_rig.target = null
		main.cam_rig.follow = false
		main.cam_rig.focus = Vector3(6.0, 0.6, -6.0)
		main.cam_rig.reset_view(3.0, -0.2, 0.0)
		Audio.play("cheer")
		Audio.play("levelup", 0.0, -4.0)
	else:
		Audio.play("fail", 0.0, -4.0)
	var v := UiKit.vbox(8)
	v.add_child(UiKit.label(tr("Votre note : %.1f / 100") % score, 30))
	var rank: Array = res["ranking"]
	for i in rank.size():
		var r: Dictionary = rank[i]
		var p := UiKit.panel(8, Color(1, 0.92, 0.6) if r["player"] else Color(1, 0.97, 0.92))
		var h := UiKit.hbox(8)
		var l := UiKit.label(("[i:%s] " % medals[i] if i < 3 else "") + "%d. %s" % [i + 1, r["name"]], 26)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(UiKit.label("%.1f" % float(r["score"]), 26, UiKit.C_SUB))
		p.add_child(h)
		v.add_child(p)
	v.add_child(UiKit.label("[i:coin] +%d " % int(res["prize"]) + tr("pièces") + "   ·   +%d " % int(res["xp"]) + tr("pts d'expérience"), 32, UiKit.C_ACCENT))
	v.add_child(UiKit.button(tr("Continuer"), func(): main.close_panel(), UiKit.C_ACCENT2, 30, 92))
	var title := tr("%de place !") % place if place > 1 else tr("Victoire !")
	main.open_panel("[i:trophy] " + title, UiKit.scroll(v), func():
		Audio.music("music_home")
		main.end_activity())

func quit() -> void:
	if sub and is_instance_valid(sub):
		sub.quit()
		return
	if finished:
		main.end_activity()
		return
	main.confirm(tr("Abandonner le concours ? L'inscription n'est pas remboursée."), func():
		finished = true
		Audio.music("music_home")
		main.end_activity(), "Abandonner")

func _exit_tree() -> void:
	super._exit_tree()
	if sub and is_instance_valid(sub):
		sub.queue_free()
