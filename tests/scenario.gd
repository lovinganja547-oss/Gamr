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
	var name: String = sc[0] if sc.size() > 0 else "search"
	await call("sc_" + name)
	print("SCENARIO DONE ", name)
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
