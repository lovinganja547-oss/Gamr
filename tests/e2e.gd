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
	hud.feed("kibble")
	await wait(4.5)
	await shot("fed")
	hud.give_water()
	await wait(3.5)
	Panels.needs()
	await shot("needs")
	main.close_all_panels()
	Panels.shop("toy")
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
	t.quit()
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
	# Recherche
	main.start_activity(SearchGame.new({}))
	await wait(1.0)
	await shot("search")
	var sg := main.activity as SearchGame
	for i in sg.spots.size():
		if sg.finished:
			break
		sg._check(i)
		var g2 := 0
		while sg.busy_sniff and g2 < 60:
			await wait(0.2)
			g2 += 1
	print("SEARCH found ", sg.found)
	await shot("search_result")
	main.close_all_panels()
	await wait(0.3)
	# Promenade
	main.start_activity(WalkActivity.new())
	await wait(1.0)
	var w := main.activity as WalkActivity
	for it in w.items:
		main.pet_ctrl.walk_to(it["pos"], 2.0)
		await wait(1.2)
	await shot("walk")
	w.quit()
	await wait(0.5)
	main.close_all_panels()
	# Agilité
	Panels.go_to("center")
	await wait(1.0)
	await shot("center")
	main.start_activity(AgilityGame.new({}))
	var ag := main.activity as AgilityGame
	var guard2 := 0
	while not ag.finished and guard2 < 600:
		if ag.running and ag.next_obs < ag.obstacles.size():
			var o: Dictionary = ag.obstacles[ag.next_obs]
			var win := ag._window(o)
			if ag.s >= win.x + 0.1:
				var gs: String = AgilityGame.TYPES[o["type"]]["gesture"]
				ag._on_gesture("R" if gs == "H" else gs)
		if guard2 == 120:
			await shot("agility")
		await wait(0.05)
		guard2 += 1
	print("AGILITY faults ", ag.faults, " time ", ag.elapsed)
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
