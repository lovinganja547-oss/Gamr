extends Node
## Banc d'essai rapide : un seul scénario avec rendu et captures.
## Usage : tests/run_scenario.sh <nom>   (search, walk, missions, collection, tournament…)
var main: Main
var out_dir := ""
var shots := 0
var vp := Vector2.ZERO

func _ready() -> void:
	out_dir = OS.get_environment("E2E_OUT")
	if out_dir == "":
		out_dir = "user://scenario"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.reset_game()
	GameState.create_pet("shiba", "Moka", "f", 0, 0, "collar_red", "acc_none", "curieux")
	GameState.add_coins(2000)
	GameState.active_pet()["level"] = 8
	for e in ["park", "forest", "beach"]:
		if not GameState.data["envs"].has(e):
			GameState.data["envs"].append(e)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	main = Main.inst
	vp = get_viewport().get_visible_rect().size
	await wait(0.5)
	main.change_env("house")
	main.show_screen("home")
	await wait(0.8)
	var sc: Array = OS.get_cmdline_user_args()
	var sc_name: String = sc[0] if sc.size() > 0 else "search"
	await call("sc_" + sc_name)
	print("SCENARIO DONE ", sc_name)
	get_tree().quit()

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func shot(nm: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [out_dir, shots, nm])
	shots += 1

func sc_search() -> void:
	Panels.go_to("forest")
	await wait(1.0)
	main.start_activity(SearchGame.new({"level": 1}))
	await wait(1.0)
	var sg := main.activity as SearchGame
	await shot("search_start")
	sg._use_clue()
	await wait(1.5)
	await shot("search_clue")
	for i in sg.spots.size():
		if sg.finished:
			break
		if not sg.spots[i]["has"] and i % 2 == 0:
			continue
		while sg.clue_busy:
			await wait(0.1)
		sg._check(i)
		var g := 0
		while sg.busy_sniff and g < 100:
			await wait(0.2)
			g += 1
		print("SEARCH check ", i, " has=", sg.spots[i]["has"], " checked=", sg.spots[i]["checked"], " busy=", sg.busy_sniff, " pos=", sg.pet.position, " state=", sg.pet.state)
	print("SEARCH found ", sg.found_items, " finished=", sg.finished, " errors_left=", sg.errors_left)
	await shot("search_end")

func sc_progress() -> void:
	GameState.add_item("shell", 3)
	GameState.add_item("gem", 1)
	GameState.data["login"] = {"last": "", "streak": 0, "claimed": ""}
	Panels.daily()
	await shot("daily")
	main.close_all_panels()
	for t in ["pets", "breeds", "items", "acc"]:
		Panels.collection(t)
		await shot("collection_" + t)
		main.close_all_panels()
	Panels.competitions()
	await shot("competitions")
	main.close_all_panels()
	# défi de promenade complet
	GameState.active_pet()["skills"]["sit"] = 50.0
	main.start_activity(Competition.new("walk", 0))
	await wait(1.5)
	var cp := main.activity as Competition
	var w := cp.sub as WalkActivity
	var guard := 0
	while is_instance_valid(w) and not w.finished and guard < 900:
		if main.has_panel():
			main.close_panel()
		if w.pet.state != "action":
			var goal: Vector3 = w.home if w.returning or w.next_cp >= w.path.size() else w.path[w.next_cp]
			for it in w.items:
				if not it["taken"] and w.pet.position.distance_to(it["pos"]) < 2.0:
					goal = it["pos"]
			if w.pet.state != "moving" or w.pet._target.distance_to(goal) > 0.3:
				w.pet.walk_to(goal, 2.2)
		if guard == 60:
			await shot("walk_comp")
		await wait(0.1)
		guard += 1
	await wait(2.0)
	await shot("walk_comp_result")
	print("BOARDS ", GameState.data["boards"].keys(), " comp_walk=", GameState.data["comp"]["walk"])
	main.close_all_panels()
	await wait(0.5)
	Panels.collection("records")
	await shot("records")

func sc_visuals() -> void:
	GameState.data["deco"]["plant"] = "plant_fern"
	GameState.data["deco"]["box"] = "toybox"
	for e in ["garden", "house", "park", "forest", "beach", "center"]:
		Panels.go_to(e)
		await wait(1.5)
		main.close_all_panels()
		await shot("env_" + e)
		main.cam_rig.distance = 4.8 if e == "house" else 6.5
		main.cam_rig.pitch = -0.45
		main.cam_rig.yaw = 0.5
		await wait(1.2)
		await shot("wide_" + e)
		print("PERF ", e, " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " fps=", Performance.get_monitor(Performance.TIME_FPS))

func sc_perf() -> void:
	Panels.go_to("park")
	await wait(1.5)
	for q in [0, 1, 2]:
		main.apply_quality(q)
		await wait(1.5)
		print("PERFQ q=", q, " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), " vmem_MB=", snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1), " mem_MB=", snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1))
		await shot("perf_q%d" % q)
