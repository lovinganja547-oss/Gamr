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
	var vq := OS.get_environment("VIS_Q")
	if vq != "":
		main.apply_quality(int(vq))
	var ve := OS.get_environment("VIS_ENVS")
	var envs: Array = ["garden", "house", "park", "forest", "beach", "center", "town", "field"]
	if ve != "":
		envs = Array(ve.split(","))
	main.screen.visible = OS.get_environment("VIS_UI") != "0"
	for e in envs:
		var t0 := Time.get_ticks_msec()
		main.change_env(e)
		print("BUILD ", e, " ms=", Time.get_ticks_msec() - t0)
		await wait(1.5)
		if e == "town":
			for nid in OS.get_environment("VIS_NODES").split(",", false):
				var np: Vector2 = GameData.WALK_NODES[nid]["pos"]
				main.pet_ctrl.position = Vector3(np.x, 0, np.y)
				main.cam_rig.distance = float(OS.get_environment("VIS_DIST")) if OS.get_environment("VIS_DIST") != "" else 9.0
				main.cam_rig.pitch = -0.42
				main.cam_rig.yaw = 0.0
				main.close_all_panels()
				await wait(1.2)
				main.close_all_panels()
				await shot("town_" + nid)
		main.close_all_panels()
		for ch in main.env_root.get_children():
			if ch is MeshInstance3D and str(ch.name).begins_with("Batch"):
				var am: ArrayMesh = ch.mesh
				print("BATCH ", e, " surfaces=", am.get_surface_count(), " aabb=", am.get_aabb(), " faces=", am.get_faces().size() / 3)
		await shot("env_" + e)
		main.cam_rig.distance = 4.8 if e == "house" else 6.5
		main.cam_rig.pitch = -0.45
		main.cam_rig.yaw = 0.5
		await wait(1.2)
		await shot("wide_" + e)
		print("PERF ", e, " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " fps=", Performance.get_monitor(Performance.TIME_FPS))

func sc_perf() -> void:
	main.change_env("town")
	main.close_all_panels()
	await wait(1.5)
	for q in [0, 1, 2]:
		main.apply_quality(q)
		await wait(1.5)
		print("PERFQ q=", q, " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), " vmem_MB=", snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1), " mem_MB=", snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1))
		await shot("perf_q%d" % q)

# ================================================================== Corrections de jouabilité
func _touch(a: Node, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	a.handle_input(e)

func _drag(a: Node, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	e.relative = rel
	a.handle_input(e)

## Frotte toutes les zones : pour chaque vue de zone, cherche à l'écran des points qui touchent la zone.
func _care_run(act: Activity, done: Dictionary, needed: float, label: String) -> void:
	for z in ["head", "back", "legs", "tail"]:
		act.care_view(z)
		await wait(1.4)
		await shot(label + "_" + z)
		var pts: Array = []
		var y := 120.0
		while y < vp.y - 120.0:
			var x := 30.0
			while x < vp.x - 30.0:
				var hit := main.raycast(Vector2(x, y), 2)
				if not hit.is_empty() and act.care_zone(hit) == z:
					pts.append(Vector2(x, y))
				x += 24.0
			y += 24.0
		print("CARE ", label, " zone=", z, " points_visibles=", pts.size())
		var g := 0
		while float(done[z]) < needed and g < 80 and not pts.is_empty():
			var p0: Vector2 = pts[g % pts.size()]
			_touch(act, p0, true)
			for k in 6:
				var p1 := p0 + Vector2(sin(k * 1.3) * 10.0, cos(k * 1.3) * 10.0)
				_drag(act, p1, Vector2(16, 12))
			_touch(act, p0, false)
			g += 1
			await get_tree().process_frame
	var tot := 0.0
	for z in done.keys():
		tot += float(done[z]) / needed
	print("CARE ", label, " fini=", done, " progression=", int(tot / done.size() * 100.0), "%")

func sc_care() -> void:
	main.start_activity(BathActivity.new())
	await wait(1.2)
	var b := main.activity as BathActivity
	# rotation de la caméra par glissement à côté de l'animal
	var y0 := main.cam_rig.yaw
	var hh := main.raycast(Vector2(40, 300), 2)
	print("CARE appui a cote : ", hh.is_empty(), " ", hh.get("collider"), " ", hh.get("position"), " pet=", b.pet.position, " cam=", main.cam_rig.cam.global_position)
	_touch(b, Vector2(40, 300), true)
	print("CARE mode=", b._care_mode)
	_drag(b, Vector2(140, 300), Vector2(100, 0))
	_touch(b, Vector2(140, 300), false)
	print("CARE rotation camera=", absf(main.cam_rig.yaw - y0) > 0.3)
	await _care_run(b, b.zone_done, BathActivity.NEEDED, "bath")
	b.quit()
	await wait(1.0)
	main.close_all_panels()
	main.end_activity()
	await wait(0.6)
	main.start_activity(BrushActivity.new())
	await wait(1.2)
	var br := main.activity as BrushActivity
	await _care_run(br, br.done, BrushActivity.NEEDED, "brush")
	br._finish()
	await wait(0.8)
	main.close_all_panels()
	await wait(0.5)

func sc_tug() -> void:
	for mode in ["actif", "passif"]:
		main.start_activity(TugActivity.new())
		await wait(0.6)
		var t := main.activity as TugActivity
		var el := 0.0
		while not t.finished and el < 24.0:
			if mode == "actif":
				var p := Vector2(360, 500)
				_touch(t, p, true)
				for k in 5:
					p += Vector2(0, 50)
					_drag(t, p, Vector2(0, 50))
					await get_tree().process_frame
				_touch(t, p, false)
			await wait(0.18)
			el += 0.18
		print("TUG ", mode, " balance=", int(t.balance), " fini=", t.finished, " duree=", snappedf(el, 0.1), "s gagne=", t.balance > 0.0)
		await shot("tug_" + mode)
		main.close_all_panels()
		main.end_activity()
		await wait(0.5)

func _count_toys() -> int:
	var n := 0
	for c in main.world.get_children():
		if c.name.begins_with("Toy"):
			n += 1
	if main.pet_ctrl.held and is_instance_valid(main.pet_ctrl.held):
		n += 1
	return n

func sc_toy() -> void:
	var pc := main.pet_ctrl
	pc.play_with_toy()
	await wait(1.6)
	await shot("toy_play")
	pc.walk_to(pc.position + Vector3(0.8, 0, 0.4), 1.0)   # interruption par le joueur
	await wait(1.2)
	print("TOY apres interruption : jouets restants=", _count_toys(), " ia_suspendue=", pc._hold_ai)
	pc.play_with_toy()
	var g := 0.0
	while pc._toy_node != null and g < 20.0:
		await wait(0.25)
		g += 0.25
	await wait(0.5)
	print("TOY partie complete : duree=", g, "s etat=", pc.state, " jouets restants=", _count_toys(), " ia_suspendue=", pc._hold_ai)
	main.start_activity(BathActivity.new())
	await wait(0.4)
	print("TOY puis activite : jouets restants=", _count_toys())
	main.end_activity()
	await wait(0.5)

func sc_fetch() -> void:
	var hud := main.screen
	hud.throw_free()
	await wait(1.2)
	var f := main.activity as FetchGame
	print("FETCH lieu=", main.env_id)
	await shot("fetch_ready")
	for i in 3:
		while f._phase != "ready":
			await wait(0.2)
		f._throw(Vector2([-250, 0, 300][i], -900))
		var out := 0
		var samples := 0
		var t := 0.0
		while f._phase != "ready" and t < 25.0:
			await wait(0.2)
			t += 0.2
			samples += 1
			if not main.cam_rig.cam.is_position_in_frustum(f.pet.global_position + Vector3(0, 0.3, 0)):
				out += 1
			if f._phase == "playing":
				f._call_back()
			if i == 0 and t > 0.4 and t < 0.65:
				await shot("fetch_flight")
		print("FETCH lancer ", i, " : animal hors champ ", out, "/", samples, " balle=", f.toy.position.round(), " repere_visible=", f.marker.visible)
	await shot("fetch_back")
	f.quit()
	await wait(1.0)
	print("FETCH sortie : lieu=", main.env_id)

func sc_walkmap() -> void:
	main.start_activity(WalkActivity.new())
	await wait(0.8)
	var w := main.activity as WalkActivity
	var m := w.map_ui
	await wait(0.3)
	# tracé au doigt : maison -> carrefour -> fontaine -> boutique, puis carrefour -> parc
	for id in ["lane", "fountain", "shop"]:
		m._try_add(m.to_screen(id))
	print("MAP trace=", m.route, " utilise=", int(m.used()), " endurance=", int(m.endurance))
	m._try_add(m.to_screen("comp"))   # pas voisin : refusé
	print("MAP non voisin refuse=", not m.route.has("comp"))
	var ok := m.auto_return()
	print("MAP retour auto=", ok, " trace=", m.route, " complet=", m.is_complete(), " utilise=", int(m.used()))
	await shot("walk_map")
	var pl: Array = m.route.duplicate()
	w.started = true
	main.close_panel()
	w._begin_plan(pl)
	await wait(1.0)
	print("WALK lieu=", main.env_id, " points=", w.path.size(), " lieux=", w.pois.size())
	await shot("walk_town")
	var shop_seen := false
	var guard := 0
	while not w.finished and guard < 400:
		guard += 1
		if main.has_panel():
			if not shop_seen:
				shop_seen = true
				await shot("walk_poi_shop")
			main.close_all_panels()
		if w.next_cp < w.path.size():
			var tgt: Vector3 = w.path[w.next_cp]
			var pc := w.pet
			pc.position = pc.position.move_toward(tgt, 0.9)
		await wait(0.08)
	print("WALK fin=", w.finished, " etapes=", w.next_cp, "/", w.path.size(), " boutique_ouverte=", shop_seen)
	await shot("walk_end")
	main.close_all_panels()
	await wait(0.8)
	print("WALK retour lieu=", main.env_id)
	# balle au parc pendant une promenade, puis reprise
	main.start_activity(WalkActivity.new())
	await wait(0.6)
	w = main.activity as WalkActivity
	m = w.map_ui
	for id in ["lane", "cafe", "market", "park"]:
		m._try_add(m.to_screen(id))
	m.auto_return()
	pl = m.route.duplicate()
	w.started = true
	main.close_panel()
	w._begin_plan(pl)
	await wait(0.8)
	guard = 0
	var at_park := false
	while main.activity == w and not at_park and guard < 400:
		guard += 1
		if main.has_panel():
			for po in w.pois:
				if po["id"] == "park" and po["inside"]:
					at_park = true
			if not at_park:
				main.close_all_panels()
		if not at_park and w.next_cp < w.path.size():
			w.pet.position = w.pet.position.move_toward(w.path[w.next_cp], 0.9)
		await wait(0.08)
	print("WALK parc atteint, panneau=", main.has_panel())
	await shot("walk_poi_park")
	main.close_all_panels()
	var park_pos := Vector3.ZERO
	for po in w.pois:
		if po["id"] == "park":
			park_pos = po["pos"]
	w._sub_fetch(park_pos, "park")
	await wait(1.0)
	var f := w.sub as FetchGame
	await shot("walk_park_fetch")
	var tt := 0.0
	while is_instance_valid(f) and not f.finished and tt < 90.0:
		if f._phase == "ready":
			f._throw(Vector2(randf_range(-100, 100), -700))
		elif f._phase == "playing":
			f._call_back()
		await wait(0.3)
		tt += 0.3
	await wait(1.5)
	print("WALK reprise : sous_activite=", w.sub != null, " lieu=", main.env_id, " fini=", w.finished, " animal_pres_du_parc=", w.pet.position.distance_to(park_pos) < 6.0)
	await shot("walk_resumed")
	w._finish(false)
	await wait(0.5)
	main.close_all_panels()
	await wait(0.6)

func sc_save() -> void:
	var before := GameState.coins()
	GameState.add_coins(37)
	await wait(2.5)
	var d: Variant = GameState._read_save(GameState.SAVE_PATH)
	print("SAVE auto apres changement : ", d is Dictionary and int(d["coins"]) == before + 37)
	var snaps := DirAccess.get_files_at(GameState.SNAP_DIR)
	print("SAVE copies du jour : ", snaps)
	GameState.data["future_key"] = {"x": 1}
	GameState.save_game()
	for pth in [GameState.SAVE_PATH, GameState.BACKUP_PATH]:
		var fw := FileAccess.open(pth, FileAccess.WRITE)
		fw.store_string("abimé")
		fw.close()
	GameState.load_game()
	print("SAVE apres corruption : statut=", GameState.load_status, " pieces_ok=", GameState.coins() == before + 37, " cle_future_gardee=", GameState.data.has("future_key"))
	var kept := 0
	for fn in DirAccess.get_files_at("user://"):
		if fn.begins_with("save.unreadable"):
			kept += 1
	print("SAVE fichiers illisibles mis de cote : ", kept)
