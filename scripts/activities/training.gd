class_name TrainingActivity
extends Activity
## Séance de dressage : démonstration, geste/voix, tentative, récompense, progression.

var cmd := "sit"
var data: Dictionary
var gesture := GestureRecognizer.new()
var step := "demo"   # demo, wait_order, attempt, feedback
var last_ok := false
var skill_bar: ProgressBar
var skill_l: Label
var hint_l: Label
var fb_box: HBoxContainer
var order_btn: Button
var reps := 0
var successes := 0
var start_skill := 0.0
var instructor: PetController
var trace: Line2D
var demo_trace: Line2D
var _last_result_ms := 0
var _impatience := 0
var voice_btn: Button
var _voice_started := false
var _cam_tw: Tween

func _init(c: String = "sit") -> void:
	cmd = c

func _start() -> void:
	data = GameData.COMMANDS[cmd]
	start_skill = GameState.skill(cmd)
	make_top("[i:training] " + tr("Dressage : « %s »") % tr(data["name"]))
	var bb := bottom_bar()
	var pnl := UiKit.panel(16)
	pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(10)
	hint_l = UiKit.label("", 28, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(hint_l)
	var sh := UiKit.hbox(8)
	skill_l = UiKit.label("", 22, UiKit.C_SUB)
	skill_l.custom_minimum_size = Vector2(250, 0)
	sh.add_child(skill_l)
	skill_bar = UiKit.bar(start_skill, UiKit.C_BLUE, 22)
	skill_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(skill_bar)
	v.add_child(sh)
	fb_box = UiKit.hbox(8)
	var treats := GameState.item_count("biscuit") + GameState.item_count("cheese") + GameState.item_count("cookie") + GameState.item_count("chew")
	fb_box.add_child(UiKit.expand(UiKit.button("[i:treat] " + tr("Friandise"), func(): _feedback(true, true), UiKit.C_GOLD, 24, 84)))
	fb_box.add_child(UiKit.expand(UiKit.button("[i:check] " + tr("Bravo"), func(): _feedback(true, false), UiKit.C_ACCENT2, 24, 84)))
	fb_box.add_child(UiKit.expand(UiKit.button("[i:stop] " + tr("Non"), func(): _feedback(false, false), UiKit.C_DANGER, 24, 84)))
	fb_box.visible = false
	v.add_child(fb_box)
	order_btn = UiKit.button(tr("Donner l'ordre (bouton)"), _order_button, UiKit.C_BLUE, 24, 76)
	order_btn.visible = false
	v.add_child(order_btn)
	voice_btn = UiKit.button("", _open_voice, UiKit.C_ACCENT, 22, 70)
	v.add_child(voice_btn)
	_update_voice_btn()
	pnl.add_child(v)
	bb.add_child(pnl)
	trace = Line2D.new()
	trace.width = 12.0
	trace.default_color = Color(1, 1, 1, 0.85)
	trace.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trace.end_cap_mode = Line2D.LINE_CAP_ROUND
	ui.add_child(trace)
	demo_trace = Line2D.new()
	demo_trace.width = 16.0
	demo_trace.default_color = Color(1, 0.8, 0.3, 0.9)
	demo_trace.begin_cap_mode = Line2D.LINE_CAP_ROUND
	demo_trace.end_cap_mode = Line2D.LINE_CAP_ROUND
	ui.add_child(demo_trace)
	_update_skill()
	pet.position = Vector3(0.35, 0, 0.2)
	pet.state = "action"
	pet.model.set_posture("stand")
	main.cam_rig.target = null
	main.cam_rig.follow = false
	main.cam_rig.focus = Vector3(0, 0.35, 0.2)
	main.cam_rig.reset_view(3.0, -0.3, 0.0)
	pet.player_pos = Vector3(0.0, 0, 2.6)
	pet.face(pet.player_pos)
	if treats == 0:
		main.toast(tr("Pas de friandise : le « Bravo » fonctionne aussi !"))
	Voice.heard.connect(_on_voice)
	Voice.unrecognized.connect(_on_voice_miss)
	_demo()

func _update_voice_btn() -> void:
	var p := GameState.active_pet()
	var n := Voice.template_count(p, cmd)
	if n == 0 and Voice.needs_redo(p, cmd):
		voice_btn.text = tr("Voix : mot à réenregistrer (reconnaissance améliorée)")
		voice_btn.icon = UiKit.icon("mic")
	elif n == 0:
		voice_btn.text = tr("Voix : associer un mot à cet ordre")
		voice_btn.icon = UiKit.icon("mic")
	else:
		voice_btn.text = tr("Voix « %s » · %d/%d · %s") % [Voice.word(p, cmd), n, Voice.MAX_TEMPLATES, Voice.reliability_label(Voice.reliability(p, cmd))]
		voice_btn.icon = UiKit.icon("mic")
	if step == "wait_order":
		_wait_order()

func _open_voice() -> void:
	if step == "attempt":
		return
	var was_listening := Voice.listening
	main.open_panel("[i:mic] " + tr("Mot vocal pour « %s »") % tr(data["name"]), UiKit.scroll(VoicePanel.new(cmd, _update_voice_btn)), func():
		if was_listening and not Voice.listening:
			Voice.start_listening())

## Écoute le micro si un mot est associé à cet ordre (permission demandée au besoin).
func _ensure_listening() -> void:
	if Voice.template_count(GameState.active_pet(), cmd) == 0:
		return
	if not Voice.listening and Voice.has_permission() and Voice.available():
		if Voice.start_listening():
			_voice_started = true
	elif not Voice.listening:
		Voice.ensure_permission()

func _update_skill() -> void:
	var s := GameState.skill(cmd)
	skill_bar.value = s
	skill_l.text = "%s · %d %%" % [tr(GameData.skill_label(s)), int(s)]
	info_label.text = tr("Répétitions : %d · Réussites : %d · Motivation : %d %%") % [reps, successes, int(GameState.motivation(GameState.active_pet()) * 100.0)]

func _demo() -> void:
	step = "demo"
	fb_box.visible = false
	order_btn.visible = false
	hint_l.text = tr("Démonstration : regardez la monitrice Praline !")
	instructor = main.add_extra_pet(GameState.sanitize_pet({"breed": "poodle", "palette": 2, "eyes": 1, "collar": "collar_gold", "accessory": "bow", "name": "Praline"}), Vector3(-0.6, 0, 0.0))
	instructor.busy = true
	instructor.player_pos = pet.player_pos
	instructor.face(pet.player_pos)
	instructor.model.emote("emo_paw")
	await get_tree().create_timer(0.8, false).timeout
	if finished or not is_instance_valid(instructor):
		return
	var dur := instructor.perform(cmd)
	_animate_gesture()
	await get_tree().create_timer(dur + 0.6, false).timeout
	if finished:
		return
	if is_instance_valid(instructor):
		instructor.model.emote("emo_sparkle")
		var tw := instructor.create_tween()
		tw.tween_property(instructor, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		tw.tween_callback(instructor.queue_free)
	main.extra_pets.erase(instructor)
	instructor = null
	_wait_order()

## Dessine le geste attendu à l'écran.
func _animate_gesture() -> void:
	var g: String = data["gesture"]
	var c := main.get_viewport().get_visible_rect().size * Vector2(0.5, 0.42)
	var pts := PackedVector2Array()
	if g == "O":
		for i in 25:
			var a := -PI / 2 + TAU * i / 24.0
			pts.append(c + Vector2(cos(a), sin(a)) * 110.0)
	elif g == "TT":
		pts = PackedVector2Array([c, c + Vector2(1, 1)])
	else:
		var p := c - Vector2(0, 0)
		pts.append(p)
		var dirs := {"U": Vector2(0, -1), "D": Vector2(0, 1), "L": Vector2(-1, 0), "R": Vector2(1, 0)}
		for ch in g:
			p += dirs[ch] * 160.0
			pts.append(p)
		var off := (pts[0] + pts[pts.size() - 1]) * 0.5 - c
		for i in pts.size():
			pts[i] -= off
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var n := maxi(2, int(k * pts.size()))
		demo_trace.points = pts.slice(0, n), 0.0, 1.0, 0.9)
	tw.tween_interval(0.6)
	tw.tween_callback(func(): demo_trace.points = PackedVector2Array())
	big_hint(GestureRecognizer.pretty(g), 1.2, UiKit.C_GOLD)

func _wait_order() -> void:
	step = "wait_order"
	fb_box.visible = false
	order_btn.visible = true
	pet.model.set_posture("stand")
	pet.face(pet.player_pos)
	pet.model.expression = "focus"
	_ensure_listening()
	var voice_txt := ""
	if Voice.listening and Voice.template_count(GameState.active_pet(), cmd) > 0:
		voice_txt = "  " + tr("ou dites « %s »") % Voice.word(GameState.active_pet(), cmd)
	hint_l.text = tr("À vous ! Geste : %s (%s)") % [GestureRecognizer.pretty(data["gesture"]), tr(data["hint"])] + voice_txt
	_update_skill()

func handle_input(event: InputEvent) -> bool:
	if finished:
		return false
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			gesture.begin(event.position)
			trace.points = PackedVector2Array([event.position])
		else:
			gesture.add(event.position)
			var g := gesture.finish()
			var t := trace.create_tween()
			t.tween_property(trace, "modulate:a", 0.0, 0.3)
			t.tween_callback(func():
				trace.points = PackedVector2Array()
				trace.modulate.a = 1.0)
			if g == "T" and data["gesture"] == "TT":
				return true   # attendre la seconde tape
			_on_gesture(g)
		return true
	if event is InputEventScreenDrag and event.index == 0:
		gesture.add(event.position)
		trace.add_point(event.position)
		return true
	return false

func _on_gesture(g: String) -> void:
	if step != "wait_order":
		if step == "attempt" or step == "feedback":
			_impatience += 1
			if _impatience >= 3:
				_impatience = 0
				big_hint(tr("Patience…"), 0.8)
				GameState.change_need("mood", -2.0)
		return
	if g == "T":
		return
	if g != data["gesture"]:
		big_hint(tr("Geste : %s") % GestureRecognizer.pretty(data["gesture"]), 0.9, UiKit.C_DANGER)
		pet.head_tilt()
		return
	_attempt(1.0)

func _order_button() -> void:
	if step == "wait_order":
		_attempt(0.95)

func _on_voice(c: String, _conf: float) -> void:
	if step != "wait_order" or main.has_panel():
		return
	var p := GameState.active_pet()
	if c == cmd:
		Voice.record_use(p, cmd, true)
		# plus l'empreinte est fiable, plus l'animal est sûr de lui
		_attempt(1.0 + 0.1 * Voice.reliability(p, cmd))
	else:
		Voice.record_use(p, cmd, false)
		big_hint(tr("Il a entendu « %s »…") % Voice.word(p, c), 1.0, UiKit.C_DANGER)
		_attempt(1.0, c)

func _on_voice_miss(_best: String, _d: float) -> void:
	if step != "wait_order" or main.has_panel():
		return
	Voice.record_use(GameState.active_pet(), cmd, false)
	big_hint(tr("Mot non reconnu"), 0.9, UiKit.C_DANGER)
	pet.head_tilt()

func _attempt(bonus: float, heard_other: String = "") -> void:
	step = "attempt"
	order_btn.visible = false
	reps += 1
	var chance := GameState.success_chance(cmd) * bonus
	if Time.get_ticks_msec() - _last_result_ms < 900:
		chance *= 0.8   # ordre donné trop vite : l'animal n'est pas prêt
	last_ok = randf() < chance
	if heard_other != "":
		last_ok = false
	hint_l.text = tr("%s essaie…") % pet_name()
	var dur := 0.0
	if heard_other != "":
		dur = pet.perform(heard_other)
	elif last_ok:
		dur = pet.perform(cmd)
	else:
		dur = pet.fail_behaviour(cmd)
	if cmd == "stay":
		_step_away(minf(dur, 2.4))
	await get_tree().create_timer(minf(dur, 2.4), false).timeout
	if finished:
		return
	step = "feedback"
	_last_result_ms = Time.get_ticks_msec()
	if last_ok:
		successes += 1
		hint_l.text = tr("Réussi ! Récompensez-le vite.")
	else:
		hint_l.text = tr("Ce n'est pas ça… Un « Non » doux l'aide à comprendre.")
	fb_box.visible = true

func _feedback(positive: bool, treat: bool) -> void:
	if step != "feedback":
		return
	fb_box.visible = false
	var used_treat := false
	if treat:
		for id in ["biscuit", "cheese", "chew", "cookie"]:
			if GameState.give_treat(id):
				used_treat = true
				break
		if not used_treat:
			main.toast(tr("Plus de friandises ! Achetez-en à la boutique."))
	var delta := GameState.training_feedback(cmd, last_ok, positive, used_treat)
	if positive:
		pet.praise()
		if used_treat:
			pet.model.chew = 1.0
			Audio.play("crunch", 0.05, -4.0)
	else:
		pet.scold()
	if absf(delta) >= 0.1:
		big_hint(("+%.1f" % delta) if delta > 0.0 else ("%.1f" % delta), 0.6, UiKit.C_ACCENT2 if delta > 0.0 else UiKit.C_DANGER)
	_update_skill()
	await get_tree().create_timer(1.4, false).timeout
	if finished:
		return
	pet.model.chew = 0.0
	var mot := GameState.motivation(GameState.active_pet())
	if mot < 0.22:
		hint_l.text = tr("%s est fatigué. Faites une pause !") % pet_name()
		await get_tree().create_timer(1.2, false).timeout
		_end_session()
		return
	if reps % 6 == 0 and GameState.skill(cmd) < GameData.SKILL_LEARNED:
		_demo()
	else:
		_wait_order()

## « Reste » : le joueur (caméra) s'éloigne puis revient ; l'animal doit rester en place.
func _step_away(dur: float) -> void:
	if _cam_tw and _cam_tw.is_valid():
		_cam_tw.kill()
	var d0 := main.cam_rig.distance
	_cam_tw = create_tween()
	_cam_tw.tween_property(main.cam_rig, "distance", d0 + 1.8, dur * 0.6).set_trans(Tween.TRANS_SINE)
	_cam_tw.tween_property(main.cam_rig, "distance", d0, dur * 0.4).set_trans(Tween.TRANS_SINE)
	hint_l.text = tr("Éloignez-vous… il doit rester en place.")

func _end_session() -> void:
	if finished:
		return
	finished = true
	var gained := GameState.skill(cmd) - start_skill
	var lines: Array = [
		tr("Répétitions : %d, réussites : %d") % [reps, successes],
		tr("« %s » : %d %% (%s%.1f)") % [tr(data["name"]), int(GameState.skill(cmd)), "+" if gained >= 0.0 else "", gained],
		tr("Niveau : %s") % tr(GameData.skill_label(GameState.skill(cmd))),
	]
	show_results("[i:training] " + tr("Fin de séance"), lines, successes * 2, 5 + successes * 2)

func quit() -> void:
	if not finished and reps > 0:
		_end_session()
		return
	finished = true
	main.end_activity()

func _exit_tree() -> void:
	super._exit_tree()
	if Voice.heard.is_connected(_on_voice):
		Voice.heard.disconnect(_on_voice)
	if Voice.unrecognized.is_connected(_on_voice_miss):
		Voice.unrecognized.disconnect(_on_voice_miss)
	if _voice_started:
		Voice.stop_listening()
	if instructor and is_instance_valid(instructor):
		main.extra_pets.erase(instructor)
		instructor.queue_free()
