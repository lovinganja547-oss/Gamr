extends Node
## Parcours automatisé du jeu complet avec captures d'écran (tests/run_e2e.sh).
var main: Main
var shots := 0
var out_dir := ""

func _ready() -> void:
	out_dir = OS.get_environment("E2E_OUT")
	if out_dir == "":
		out_dir = "user://e2e"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.reset_game()
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	main = Main.inst
	_run()

const WORD_A := [[[220.0, 1100.0, 2600.0], 0.18], [[300.0, 700.0, 2300.0], 0.22]]
const WORD_D := [[[140.0, 500.0, 900.0], 0.15], [[240.0, 1300.0, 2800.0], 0.15], [[400.0, 2000.0, 2500.0], 0.15]]

## Signal vocal synthétique (voir tests/unit_tests.gd).
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
			var tt := float(i) / sr
			var env := minf(1.0, minf(float(i) / (0.02 * sr), float(n - i) / (0.02 * sr)))
			var v := 0.0
			var k := 1.0
			for f in freqs:
				v += sin(TAU * float(f) * tt) * k
				k *= 0.6
			out.append(v * amp * env + rng.randfn(0.0, noise))
	for i in npad + int(0.1 * sr):
		out.append(rng.randfn(0.0, 0.0015 + noise))
	return out

## Silence ambiant après un mot (la fin du mot est validée après 0,6 s de silence).
func _hush() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var out := PackedFloat32Array()
	for i in int(0.8 * Voice.SR):
		out.append(rng.randfn(0.0, 0.0015))
	return out

func _find_voice_panel(n: Node) -> VoicePanel:
	if n is VoicePanel:
		return n
	for c in n.get_children():
		var r := _find_voice_panel(c)
		if r:
			return r
	return null

func shot(nm: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, shots, nm])
	shots += 1
	print("SHOT ", nm)

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func tap(pos: Vector2) -> void:
	var e := InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	var r := InputEventScreenTouch.new(); r.index = 0; r.position = pos; r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame

func swipe(a: Vector2, b: Vector2, steps: int = 10) -> void:
	var e := InputEventScreenTouch.new(); e.index = 0; e.position = a; e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	for i in range(1, steps + 1):
		var d := InputEventScreenDrag.new(); d.index = 0
		d.position = a.lerp(b, float(i) / steps)
		d.relative = (b - a) / steps
		Input.parse_input_event(d)
		await get_tree().process_frame
	var r := InputEventScreenTouch.new(); r.index = 0; r.position = b; r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame

## Geste en un seul trait passant par plusieurs points.
func swipe_path(pts: Array, steps: int = 8) -> void:
	var e := InputEventScreenTouch.new(); e.index = 0; e.position = pts[0]; e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	for k in range(1, pts.size()):
		var a: Vector2 = pts[k - 1]
		var b: Vector2 = pts[k]
		for i in range(1, steps + 1):
			var d := InputEventScreenDrag.new(); d.index = 0
			d.position = a.lerp(b, float(i) / steps)
			d.relative = (b - a) / steps
			Input.parse_input_event(d)
			await get_tree().process_frame
	var r := InputEventScreenTouch.new(); r.index = 0; r.position = pts[pts.size() - 1]; r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame

func _run() -> void:
	await wait(1.0)
	await shot("title")
	(main.screen as TitleScreen)._new_game()
	await wait(1.0)
	await shot("shelter")
	var ad := main.screen as AdoptScreen
	ad._move(1)
	await wait(1.0)
	await shot("shelter_shiba")
	ad._adopt()
	await wait(0.8)
	await shot("customize")
	ad.custom["palette"] = 1
	ad._build_custom(false, "body")
	await wait(0.8)
	await shot("customize_palette")
	ad.custom["eyes"] = 2
	ad._build_custom(false, "head")
	await wait(0.8)
	await shot("customize_eyes")
	ad.custom["collar"] = "collar_blue"
	ad._build_custom(false, "neck")
	await wait(0.8)
	await shot("customize_collar")
	ad.custom["accessory"] = "bow"
	ad._build_custom(false, "head")
	await wait(0.8)
	await shot("customize_acc")
	ad._confirm()
	await wait(1.5)
	main.close_all_panels()
	await shot("home")
	print("PERF draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " mem_MB=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	var hud := main.screen as HomeHud
	# Caresses
	var vp := get_viewport().get_visible_rect().size
	var pp := main.cam_rig.cam.unproject_position(main.pet_ctrl.global_position + Vector3(0, 0.3, 0))
	for i in 4:
		await swipe(pp + Vector2(-60, 0), pp + Vector2(60, 0), 6)
	print("PET STAT ", GameState.get_stat("pet"))
	# Repas : le chien doit contourner les meubles et ne jamais être dans un obstacle
	main.pet_ctrl.position = Vector3(-1.4, 0, -0.9)
	hud.feed("kibble")
	var blocked_frames := 0
	for i in 60:
		await get_tree().process_frame
		await get_tree().create_timer(0.1).timeout
		var pp2 := main.pet_ctrl.position
		if main.nav.is_blocked_point(Vector2(pp2.x, pp2.z), -0.08):
			blocked_frames += 1
		if i == 25:
			await shot("eating")
	print("MEAL blocked_frames=", blocked_frames, " pos=", main.pet_ctrl.position, " hunger=", GameState.active_pet()["needs"]["hunger"])
	await shot("fed")
	hud.give_water()
	await wait(3.5)
	Panels.needs()
	await shot("needs")
	main.close_all_panels()
	Panels.open_shop("toy", "shop")
	await shot("shop")
	main.close_all_panels()
	Panels.inventory()
	await shot("inventory")
	main.close_all_panels()
	# Bain
	main.start_activity(BathActivity.new())
	await wait(0.6)
	var a := main.activity as BathActivity
	pp = main.cam_rig.cam.unproject_position(main.pet_ctrl.model.body_pivot.global_position)
	for i in 30:
		await swipe(pp + Vector2(-50, -10), pp + Vector2(50, 10), 4)
	await shot("bath")
	a._rinse()
	await wait(2.5)
	await shot("bath_done")
	main.close_all_panels()
	await wait(0.3)
	# Phase 3 : brossage, câlin, corde, jouet, mode photo
	main.start_activity(BrushActivity.new())
	await wait(0.8)
	pp = main.cam_rig.cam.unproject_position(main.pet_ctrl.model.body_pivot.global_position)
	for i in 20:
		await swipe(pp + Vector2(-60, -20), pp + Vector2(60, 0), 4)
	await shot("brush")
	(main.activity as BrushActivity)._finish()
	await wait(0.6)
	main.close_all_panels()
	await wait(0.3)
	main.start_activity(CuddleActivity.new())
	await wait(2.5)
	var cu := main.activity as CuddleActivity
	cu._touching = true
	cu._arrived = true
	await wait(3.0)
	await shot("cuddle")
	await wait(3.5)
	main.close_all_panels()
	await wait(0.3)
	GameState.active_pet()["level"] = 3
	main.start_activity(TugActivity.new())
	await wait(1.0)
	for i in 2:
		await swipe(vp * Vector2(0.5, 0.4), vp * Vector2(0.5, 0.7), 3)
	await shot("tug")
	for i in 40:
		await swipe(vp * Vector2(0.5, 0.4), vp * Vector2(0.5, 0.7), 3)
	await shot("tug_result")
	await wait(26.0)
	print("TUG finished=", (main.activity as TugActivity).finished if main.activity else true)
	main.close_all_panels()
	await wait(0.3)
	main.pet_ctrl.play_with_toy()
	await wait(2.5)
	await shot("toy_play")
	await wait(6.0)
	main.start_activity(PhotoMode.new())
	await wait(0.8)
	var pm := main.activity as PhotoMode
	pm._pose("beg")
	pm._deco("hearts")
	await wait(1.0)
	await shot("photo_mode")
	pm._shoot()
	await wait(1.0)
	pm.quit()
	await wait(0.5)
	# Dressage
	GameState.data["level"] = 6
	main.start_activity(TrainingActivity.new("sit"))
	await wait(1.4)
	await shot("training_demo")
	await wait(3.0)
	var t := main.activity as TrainingActivity
	for i in 4:
		if t.step == "wait_order":
			await swipe(vp * Vector2(0.5, 0.3), vp * Vector2(0.5, 0.55), 10)
			await wait(2.6)
			if t.step == "feedback":
				t._feedback(t.last_ok, false)
				await wait(1.6)
	await shot("training")
	print("SIT SKILL ", GameState.skill("sit"))
	# Phase 4 : mot vocal associé pendant la séance (micro simulé)
	Voice.test_mode = true
	t._open_voice()
	await wait(0.6)
	var vpan: VoicePanel = _find_voice_panel(main.panel_stack[main.panel_stack.size() - 1])
	print("VOICE panel=", vpan != null)
	if vpan:
		vpan._record()
		Voice.feed(_hush())      # le micro livre du son : calibrage puis « Parlez maintenant »
		await wait(0.3)
		print("VOICE ready=", Voice.is_ready(), " status=", vpan.status_l.text)
		await shot("voice_recording")
		Voice.feed(_syn(WORD_A, 0.3, 1.0, 0.004, 0.4, 11))
		Voice.feed(_hush())
		await wait(0.3)
		print("VOICE state=", vpan.state, " reason=", vpan.result.get("reason", "ok"))
		await shot("voice_review")
		vpan._validate()
		await wait(0.3)
		print("VOICE templates=", Voice.template_count(GameState.active_pet(), "sit"), " word=", Voice.word(GameState.active_pet(), "sit"))
		await shot("voice_done")
	main.close_all_panels()
	await wait(0.5)
	if t.step != "wait_order":
		await wait(3.0)
	var on_heard := func(c: String, cf: float): print("VOICE signal heard ", c, " conf=%.2f" % cf)
	var on_miss := func(b: String, d: float): print("VOICE signal unrecognized best=", b, " d=%.2f" % d)
	Voice.heard.connect(on_heard)
	Voice.unrecognized.connect(on_miss)
	print("VOICE listening=", Voice.listening, " step=", t.step, " panel=", main.has_panel())
	Voice.feed(_syn(WORD_A, 0.32, 1.1, 0.005, 0.4, 12))
	Voice.feed(_hush())
	await wait(0.5)
	print("VOICE heard -> step=", t.step, " reps=", t.reps)
	await shot("training_voice")
	await wait(2.5)
	if t.step == "feedback":
		t._feedback(t.last_ok, false)
	await wait(1.0)
	Voice.feed(_syn(WORD_D, 0.3, 1.0, 0.005, 0.4, 13))
	Voice.feed(_hush())
	await wait(0.4)
	print("VOICE unknown word -> step=", t.step, " reps=", t.reps)
	Voice.heard.disconnect(on_heard)
	Voice.unrecognized.disconnect(on_miss)
	t.quit()
	await wait(0.5)
	main.close_all_panels()
	await wait(0.3)
	Voice.test_mode = false
	# Ordre « Reste » : la caméra s'éloigne pendant que l'animal reste en place
	main.start_activity(TrainingActivity.new("stay"))
	await wait(4.5)
	var ts := main.activity as TrainingActivity
	if ts.step == "wait_order":
		await swipe_path([vp * Vector2(0.5, 0.55), vp * Vector2(0.5, 0.3), vp * Vector2(0.5, 0.55)], 8)
	await wait(1.2)
	print("STAY step=", ts.step, " reps=", ts.reps)
	await shot("training_stay")
	await wait(2.0)
	ts.quit()
	await wait(0.5)
	main.close_all_panels()
	await wait(0.3)
	# Jardin + lancer de balle
	Panels.go_to("garden")
	await wait(1.0)
	await shot("garden")
	main.start_activity(FetchGame.new(false))
	await wait(1.0)
	var fg := main.activity as FetchGame
	for i in 5:
		await swipe(vp * Vector2(0.5, 0.85), vp * Vector2(0.52, 0.5), 8)
		await wait(0.8)
		if i == 0:
			await shot("fetch_throw")
		var guard := 0
		while fg._phase != "ready" and not fg.finished and guard < 120:
			if fg._phase == "playing":
				fg._call_back()
			await wait(0.25)
			guard += 1
	print("FETCH SCORE ", fg.score, " throws ", fg.throws_done)
	await shot("fetch_result")
	main.close_all_panels()
	await wait(0.3)
	# Recherche : sélecteur de niveau, puis partie en forêt avec flair
	main.start_activity(SearchGame.new({}))
	await wait(1.0)
	await shot("search_levels")
	main.close_all_panels()
	await wait(0.3)
	GameState.data["envs"].append("forest")
	Panels.go_to("forest")
	await wait(1.2)
	await shot("forest")
	main.start_activity(SearchGame.new({"level": 1}))
	await wait(1.0)
	var sg := main.activity as SearchGame
	sg._use_clue()
	await wait(1.0)
	await shot("search")
	var inv_before := 0
	for id in GameState.data["inventory"].keys():
		inv_before += int(GameState.data["inventory"][id])
	for i in sg.spots.size():
		if sg.finished:
			break
		if not sg.spots[i]["has"] and i % 2 == 0:
			continue   # joue « bien » : surtout les bonnes cachettes
		while sg.clue_busy:
			await wait(0.1)
		sg._check(i)
		var g2 := 0
		while sg.busy_sniff and g2 < 60:
			await wait(0.2)
			g2 += 1
	var inv_after := 0
	for id in GameState.data["inventory"].keys():
		inv_after += int(GameState.data["inventory"][id])
	print("SEARCH found ", sg.found_items, " finished=", sg.finished, " level_now=", GameState.data["search_level"], " inv ", inv_before, "->", inv_after)
	await shot("search_result")
	main.close_all_panels()
	await wait(0.3)
	# Promenade : sélecteur d'itinéraire, puis parcours complet en laisse jusqu'à la maison
	main.start_activity(WalkActivity.new())
	await wait(1.0)
	await shot("walk_routes")
	main.close_all_panels()
	await wait(0.5)
	main.start_activity(WalkActivity.new({"route": "park_pond"}))
	await wait(1.5)
	var w := main.activity as WalkActivity
	var guard_w := 0
	var shot_w := false
	while not w.finished and guard_w < 900:
		if main.has_panel():
			main.close_panel()   # défi de dressage : on passe
		if w.pet.state != "action":
			var goal: Vector3 = w.home if w.returning or w.next_cp >= w.path.size() else w.path[w.next_cp]
			for it in w.items:
				if not it["taken"] and w.pet.position.distance_to(it["pos"]) < 2.0:
					goal = it["pos"]
			if w.pet.state != "moving" or w.pet._target.distance_to(goal) > 0.3:
				w.pet.walk_to(goal, 2.2)
		for i in w.poops.size():
			if is_instance_valid(w.poops[i]):
				w._pick_poop(i)
		if not shot_w and w.next_cp > 3:
			shot_w = true
			await shot("walk")
		await wait(0.1)
		guard_w += 1
	print("WALK finished=", w.finished, " cp=", w.next_cp, "/", w.path.size(), " dist_m=", int(w.dist_done * 10.0), " finds=", w.collected, " met=", w.met.size(), " peed=", w.peed, " pooped=", w.pooped, " picked=", w.picked)
	await shot("walk_result")
	main.close_all_panels()
	await wait(0.5)
	# Agilité
	Panels.go_to("center")
	await wait(1.0)
	await shot("center")
	Panels.agility_levels()
	await shot("agility_levels")
	main.close_all_panels()
	GameState.active_pet()["level"] = 9
	GameState.active_pet()["skills"]["jump"] = 60.0
	GameState.active_pet()["skills"]["stay"] = 50.0
	GameState.active_pet()["skills"]["sit"] = 50.0
	GameState.active_pet()["needs"]["energy"] = 90.0
	print("AGILITY req L4 '", GameState.agility_requirements(3), "' L5 '", GameState.agility_requirements(4), "'")
	main.start_activity(AgilityGame.new({"level": 3, "seed": 4242}))
	var ag := main.activity as AgilityGame
	var guard2 := 0
	var shots_ag := 0
	while not ag.finished and guard2 < 900:
		if ag.running and ag.next_obs < ag.obstacles.size():
			var o: Dictionary = ag.obstacles[ag.next_obs]
			var win := ag._window(o)
			if ag.s >= win.x + (win.y - win.x) * 0.62:
				ag.action()
				if shots_ag < 3 and o["type"] in ["walkway", "platform", "stop", "weave"]:
					shots_ag += 1
					await wait(0.35)
					await shot("agility_" + str(o["type"]))
		if guard2 == 100:
			await shot("agility")
		await wait(0.05)
		guard2 += 1
	print("AGILITY faults ", ag.faults, " perfects ", ag.perfects, " time ", ag.elapsed, " layout ", ag.layout, " record ", GameState.record("agility_3"))
	await shot("agility_result")
	main.close_all_panels()
	await wait(0.3)
	# Concours obéissance
	for c in ["sit", "down", "stand", "come"]:
		GameState.active_pet()["skills"][c] = 90.0
	GameState.add_coins(100)
	print("REQ ", GameState.comp_requirements("obedience", 0))
	main.start_activity(Competition.new("obedience", 0))
	await wait(2.2)
	var cp := main.activity as Competition
	var g3 := 0
	while not cp.finished and g3 < 400:
		if cp.waiting:
			cp._answer_cmd(cp.seq[cp.idx], 1.0)
		await wait(0.1)
		g3 += 1
	await wait(1.0)
	await shot("competition")
	main.close_all_panels()
	await wait(0.5)
	# Concours agilité (sous-jeu)
	main.start_activity(Competition.new("agility", 0))
	await wait(1.0)
	(main.activity as Competition).quit()
	await wait(1.5)
	main.close_all_panels()
	# Parc + plage
	GameState.data["envs"].append("park")
	GameState.data["envs"].append("beach")
	for e in ["park", "beach"]:
		Panels.go_to(e)
		await wait(1.2)
		await shot(e)
		print("PERF ", e, " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	# Photo + album + paramètres + succès
	Panels.go_to("house")
	await wait(1.0)
	main.take_photo()
	await wait(0.8)
	Panels.album()
	await shot("album")
	main.close_all_panels()
	Panels.achievements()
	await shot("achievements")
	main.close_all_panels()
	Panels.settings()
	await shot("settings")
	main.close_all_panels()
	Panels.deco()
	await shot("deco")
	main.close_all_panels()
	for q in [0, 2, 1]:
		main.apply_quality(q)
		await wait(0.4)
	# Sauvegarde puis rechargement
	var coins := GameState.coins()
	GameState.save_game()
	GameState.load_game()
	print("RELOAD ", GameState.load_status, " coins ", GameState.coins() == coins, " pets ", GameState.data["pets"].size())
	main.show_screen("home")
	await shot("home_end")
	print("E2E DONE")
	get_tree().quit()
