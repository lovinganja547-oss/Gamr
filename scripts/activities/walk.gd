class_name WalkActivity
extends Activity
## Promenade en laisse : choix d'un itinéraire, parcours balisé en boucle (joystick),
## laisse visible, besoins naturels à ramasser, trouvailles, événements (rencontre,
## défi de dressage, trésor, point d'intérêt), énergie et retour obligatoire à la maison.

const SCALE := 10.0        # 1 m de jeu = 10 m affichés
const LEASH := 1.5
const CP_RADIUS := 1.2

var route: Dictionary = {}
var route_id := ""
var started := false
var area := Rect2(-6, -6, 12, 10)
var path: Array[Vector3] = []
var next_cp := 0
var home := Vector3.ZERO
var returning := false
var dist_done := 0.0
var _last_pos := Vector3.ZERO
var walker := Vector3.ZERO
var leash: MeshInstance3D
var flag: Node3D
var markers: Array[Node3D] = []
var items: Array[Dictionary] = []
var npcs: Array[PetController] = []
var met: Array[int] = []
var poops: Array[Node3D] = []
var picked := 0
var collected := 0
var bonus_coins := 0
var events: Array[Dictionary] = []
var peed := false
var pooped := false
var _need_t := 25.0
var _energy_acc := 0.0
var warned := false
var rng := RandomNumberGenerator.new()
var joy_base := Vector2.ZERO
var joy_vec := Vector2.ZERO
var joy_active := false
var joy_ui: Control
var joy_knob: Control
var energy_bar: ProgressBar
var obj_l: Label
var home_btn: Button

var comp := false
var elapsed := 0.0

func _init(params: Dictionary = {}) -> void:
	route_id = str(params.get("route", ""))
	comp = bool(params.get("comp", false))

func _start() -> void:
	make_top("[i:walk] " + tr("Promenade"))
	pet.state = "action"
	if route_id != "":
		_begin_route(GameData.route(route_id))
	else:
		_route_picker()

func can_recenter() -> bool:
	return started

func recenter() -> void:
	main.cam_rig.target = pet
	main.cam_rig.follow = true
	main.cam_rig.distance = 4.2
	main.cam_rig.pitch = -0.5

# ------------------------------------------------------------------ choix de l'itinéraire
func _route_picker() -> void:
	info_label.text = tr("Choisissez un itinéraire.")
	var v := UiKit.vbox(10)
	var p := GameState.active_pet()
	v.add_child(UiKit.label("[i:energy] " + tr("Énergie de %s : %d %%") % [p["name"], int(p["needs"]["energy"])], 24, UiKit.C_SUB))
	for r in GameData.ROUTES:
		var rr: Dictionary = r
		var env_ok := GameState.env_unlocked(r["env"])
		var lvl_ok := GameState.pet_level() >= int(r["level"])
		var c := UiKit.panel(14, Color(1, 0.97, 0.9))
		var h := UiKit.hbox(8)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var env: Dictionary = GameData.ENVIRONMENTS[r["env"]]
		info.add_child(UiKit.label("[i:%s] %s" % [env["icon"], tr(r["name"])], 26))
		var minutes := maxi(1, int(round(float(r["length"]) / SCALE / 1.1 / 60.0 * 1.6)))
		info.add_child(UiKit.label(tr("%s · %d m · ~%d min · %s · %d trouvailles") % [tr(env["name"]), int(r["length"]), minutes, tr(GameData.ROUTE_DIFF_NAMES[int(r["diff"])]), int(r["finds"])], 20, UiKit.C_SUB))
		info.add_child(UiKit.label(tr(r["desc"]), 20, UiKit.C_SUB))
		var need := _energy_cost(float(r["length"]))
		if not env_ok:
			info.add_child(UiKit.label("[i:lock] " + tr("Lieu à débloquer dans la boutique"), 20, UiKit.C_DANGER))
		elif not lvl_ok:
			info.add_child(UiKit.label("[i:lock] " + tr("%s doit être niveau %d") % [p["name"], int(r["level"])], 20, UiKit.C_DANGER))
		elif float(p["needs"]["energy"]) < need + 5.0:
			info.add_child(UiKit.label("[i:warning] " + tr("Énergie conseillée : %d %%") % int(need + 5.0), 20, UiKit.C_DANGER))
		h.add_child(info)
		var b := UiKit.button(tr("Partir"), func():
			started = true
			main.close_panel()
			_begin_route(rr), UiKit.C_ACCENT2, 24, 72)
		b.disabled = not env_ok or not lvl_ok
		b.custom_minimum_size = Vector2(130, 72)
		h.add_child(b)
		c.add_child(h)
		v.add_child(c)
	main.open_panel("[i:route] " + tr("Itinéraires"), UiKit.scroll(v), func():
		if not started:
			finished = true
			main.end_activity())

func _energy_cost(length: float) -> float:
	return length / 1000.0 * float(GameData.ENERGY_COST["walk_km"]) * 1.1

# ------------------------------------------------------------------ mise en place
func _begin_route(r: Dictionary) -> void:
	started = true
	route = r
	if main.env_id != r["env"]:
		main.change_env(r["env"])
		pet = main.pet_ctrl
	pet.busy = true
	pet.stop_moving()
	rng.randomize()
	area = main.env_root.get_meta("walk_area", Rect2(-6, -6, 12, 10))
	top_label.text = tr("Promenade · %s") % tr(r["name"])
	_build_ui()
	_build_path(float(r["length"]) / SCALE)
	pet.bounds = area.grow(1.0)
	pet.position = home
	pet.state = "idle"
	walker = home + Vector3(0, 0, 1.0)
	_last_pos = pet.position
	main.cam_rig.target = pet
	main.cam_rig.follow = true
	main.cam_rig.reset_view(4.2, -0.5, 0.0)
	main.cam_rig.screen_shift = 0.15
	# laisse
	leash = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = 1.0
	cm.radial_segments = 6
	leash.mesh = cm
	leash.material_override = PetModel.mat(Color(0.85, 0.25, 0.25))
	leash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.world.add_child(leash)
	_spawn_finds(int(r["finds"]))
	_plan_events(int(r["diff"]))
	GameState.change_need("mood", 5.0)
	pet.model.emote("emo_paw")
	pet.voice()
	_update_info()

func _build_ui() -> void:
	var bb := bottom_bar()
	var pv := UiKit.panel(10)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(6)
	var eh := UiKit.hbox(6)
	eh.add_child(UiKit.icon_rect("energy", 30))
	energy_bar = UiKit.bar(50, UiKit.need_color(50), 18)
	energy_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eh.add_child(energy_bar)
	v.add_child(eh)
	obj_l = UiKit.label("", 20, UiKit.C_SUB)
	v.add_child(obj_l)
	var h := UiKit.hbox(8)
	home_btn = UiKit.button("[i:home_go] " + tr("Rentrer"), _go_home, UiKit.C_ACCENT2, 22, 72)
	h.add_child(UiKit.expand(home_btn))
	h.add_child(UiKit.expand(UiKit.button("[i:shop] " + tr("Boutique"), func(): Panels.shop("sell"), UiKit.C_BLUE, 22, 72)))
	v.add_child(h)
	pv.add_child(v)
	bb.add_child(pv)
	joy_ui = Control.new()
	joy_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_ui.visible = false
	ui.add_child(joy_ui)
	var base := Panel.new()
	base.add_theme_stylebox_override("panel", UiKit.sb(Color(1, 1, 1, 0.3), 90, 4, Color(1, 1, 1, 0.7), false, 0))
	base.size = Vector2(180, 180)
	base.position = Vector2(-90, -90)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_ui.add_child(base)
	joy_knob = Panel.new()
	joy_knob.add_theme_stylebox_override("panel", UiKit.sb(Color(1, 1, 1, 0.85), 40, 0, Color.TRANSPARENT, true, 0))
	joy_knob.size = Vector2(80, 80)
	joy_knob.position = Vector2(-40, -40)
	joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_ui.add_child(joy_knob)

## Boucle balisée (ellipse, plusieurs tours si besoin) qui part de la maison et y revient.
func _build_path(total: float) -> void:
	var c := area.get_center()
	var rx := maxf(1.5, area.size.x * 0.5 - 1.0)
	var rz := maxf(1.5, area.size.y * 0.5 - 1.0)
	var perim := PI * (3.0 * (rx + rz) - sqrt((3.0 * rx + rz) * (rx + 3.0 * rz)))
	var laps := maxf(1.0, ceil(total / perim))
	var k := clampf(total / (perim * laps), 0.45, 1.0)
	rx *= k
	rz *= k
	var n := maxi(8, int(total / 1.6))
	for i in n + 1:
		var a := PI * 0.5 + TAU * laps * float(i) / n
		var p := Vector2(c.x + cos(a) * rx, c.y + sin(a) * rz)
		if main.nav:
			p = main.nav.nearest_free(p)
		path.append(Vector3(p.x, 0, p.y))
	home = path[0]
	path.remove_at(0)
	# empreintes au sol (une sur deux) + drapeau du prochain point
	for i in path.size():
		if i % 2 == 0:
			var mk := WorldBuilder.cyl(main.world, 0.07, 0.07, 0.01, path[i] + Vector3(0, 0.012, 0), Color(1, 0.95, 0.75), 10)
			mk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			markers.append(mk)
	flag = Node3D.new()
	main.world.add_child(flag)
	WorldBuilder.cyl(flag, 0.02, 0.02, 0.9, Vector3(0, 0.45, 0), Color(0.95, 0.95, 0.95), 6)
	WorldBuilder.box(flag, Vector3(0.3, 0.18, 0.02), Vector3(0.15, 0.8, 0), Color(0.45, 0.8, 0.45), Vector3.ZERO, false)
	var tw := flag.create_tween().set_loops()
	tw.tween_property(flag, "scale", Vector3(1.15, 1.15, 1.15), 0.5)
	tw.tween_property(flag, "scale", Vector3.ONE, 0.5)

func _spawn_finds(n: int) -> void:
	var pool: Array = GameData.collectibles(main.env_id).filter(func(id): return int(GameData.item(id).get("rarity", 1)) < 3)
	if pool.is_empty():
		pool = GameData.collectibles("park")
	for i in n:
		var cp := path[rng.randi_range(1, path.size() - 2)]
		var p := cp + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9))
		if main.nav:
			var f := main.nav.nearest_free(Vector2(p.x, p.z))
			p = Vector3(f.x, 0, f.y)
		var id: String = pool[rng.randi() % pool.size()]
		items.append({"pos": p, "id": id, "node": _make_marker(p, str(GameData.item(id)["icon"])), "taken": false, "kind": "find"})

func _make_marker(p: Vector3, icon: String) -> Node3D:
	var n := Node3D.new()
	n.position = p
	main.world.add_child(n)
	var l := Sprite3D.new()
	l.texture = UiKit.icon(icon)
	l.pixel_size = 0.0022
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 0.35, 0)
	n.add_child(l)
	var ring := WorldBuilder.torus(n, 0.18, 0.24, Vector3(0, 0.02, 0), Color(1, 0.9, 0.4))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "position:y", 0.45, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "position:y", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	return n

## Événements répartis le long du parcours selon la difficulté.
func _plan_events(diff: int) -> void:
	var kinds: Array = ["meet", "training", "treasure", "poi"]
	for i in range(kinds.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = kinds[i]; kinds[i] = kinds[j]; kinds[j] = t
	var count := 2 + (1 if diff >= 2 else 0)
	for i in count:
		events.append({"kind": kinds[i], "at": float(i + 1) / float(count + 1), "done": false})

# ------------------------------------------------------------------ entrées
func handle_input(event: InputEvent) -> bool:
	if finished or not started:
		return false
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			# ramasser une crotte ?
			var part := main.hit_part(main.raycast(event.position, 4))
			if part.begins_with("poop_"):
				_pick_poop(int(part.substr(5)))
				return true
			joy_active = true
			joy_base = event.position
			joy_vec = Vector2.ZERO
			joy_ui.position = joy_base
			joy_ui.visible = true
			joy_knob.position = Vector2(-40, -40)
		else:
			joy_active = false
			joy_ui.visible = false
			if joy_vec.length() < 0.15 and pet.state != "action":
				var gp: Variant = main.ground_point(event.position)
				if gp is Vector3:
					pet.walk_to(gp, 1.1)
			elif pet.state == "moving":
				pet.stop_moving()
			joy_vec = Vector2.ZERO
		return true
	if event is InputEventScreenDrag and event.index == 0 and joy_active:
		var d: Vector2 = event.position - joy_base
		joy_vec = d.limit_length(90.0) / 90.0
		joy_knob.position = joy_vec * 90.0 - Vector2(40, 40)
		return true
	return false

# ------------------------------------------------------------------ boucle
func _process(delta: float) -> void:
	if finished or not started or pet == null:
		return
	elapsed += delta
	var energy: float = GameState.active_pet()["needs"]["energy"]
	if joy_active and joy_vec.length() > 0.15 and pet.state != "action":
		var basis := main.cam_rig.cam.global_transform.basis
		var fwd := -basis.z
		fwd.y = 0
		var right := basis.x
		right.y = 0
		var dir := (right.normalized() * joy_vec.x - fwd.normalized() * joy_vec.y)
		var spd := (0.6 + joy_vec.length() * 1.5) * (0.55 if energy < 10.0 else 1.0)
		var tgt := pet.position + dir.normalized() * 0.6
		if main.nav == null or not main.nav.is_blocked_point(Vector2(tgt.x, tgt.z)):
			pet.walk_to(tgt, spd)
		elif pet.state == "moving":
			pet.stop_moving()
	# distance et énergie
	var moved := pet.position.distance_to(_last_pos)
	_last_pos = pet.position
	if moved < 1.0:
		dist_done += moved
		_energy_acc += moved
		if _energy_acc >= 1.0:
			_energy_acc -= 1.0
			GameState.spend_energy("walk_km", SCALE / 1000.0 * (1.0 + (int(route["diff"]) - 1) * 0.2))
	# promeneur et laisse
	var to_pet := pet.position - walker
	to_pet.y = 0
	if to_pet.length() > LEASH:
		walker += to_pet.normalized() * (to_pet.length() - LEASH)
	_update_leash()
	main.cam_rig.yaw = lerp_angle(main.cam_rig.yaw, atan2(walker.x - pet.position.x, walker.z - pet.position.z), minf(1.0, delta * 1.5))
	# points de passage
	if returning:
		if pet.position.distance_to(home) < CP_RADIUS:
			_finish(true)
			return
	elif next_cp < path.size():
		if pet.position.distance_to(path[next_cp]) < CP_RADIUS:
			next_cp += 1
			Audio.play("tick", 0.05, -10.0)
			if next_cp >= path.size():
				_finish(true)
				return
	var goal := home if returning or next_cp >= path.size() else path[next_cp]
	flag.position = goal
	# événements
	var frac := progress()
	for e in events:
		if not e["done"] and frac >= float(e["at"]):
			e["done"] = true
			_trigger(e["kind"])
	# trouvailles, trésors et points d'intérêt
	for it in items:
		if not it["taken"] and pet.position.distance_to(it["pos"]) < 0.55:
			it["taken"] = true
			if it["kind"] == "water":
				pet.stop_moving()
				pet.face(it["pos"])
				pet.eat("water", 1.6)
				GameState.change_need("thirst", 40.0)
				GameState.change_need("energy", 4.0)
			else:
				_collect(it)
	for i in npcs.size():
		if not met.has(i) and pet.position.distance_to(npcs[i].position) < 0.9:
			met.append(i)
			_meet(npcs[i])
	# besoins naturels
	_need_t -= delta
	if _need_t <= 0.0 and pet.state != "action":
		_need_t = rng.randf_range(25.0, 45.0)
		if not peed:
			_pee()
		elif not pooped and rng.randf() < 0.7:
			_poop()
	# fatigue
	if energy < 15.0 and not warned:
		warned = true
		pet.model.emote("emo_sleepy")
		main.toast(tr("%s commence à fatiguer : pensez à rentrer.") % pet_name())
		home_btn.add_theme_stylebox_override("normal", UiKit.sb(UiKit.C_DANGER))
	_update_info()

func progress() -> float:
	return clampf(float(next_cp) / float(maxi(1, path.size())), 0.0, 1.0)

func _update_leash() -> void:
	if leash == null:
		return
	var a := pet.model.acc_root.global_position
	var b := walker + Vector3(0, 0.95, 0)
	leash.global_position = (a + b) * 0.5
	var len := a.distance_to(b)
	leash.scale = Vector3(1, maxf(len, 0.01), 1)
	if len > 0.02:
		var up := Vector3.UP if absf((b - a).normalized().y) < 0.98 else Vector3.RIGHT
		leash.look_at(b, up)
		leash.rotate_object_local(Vector3.RIGHT, PI / 2)

func _update_info() -> void:
	var p := GameState.active_pet()
	var e: float = p["needs"]["energy"]
	_set_energy(e)
	var finds_total := int(route.get("finds", 0))
	var txt := tr("%d m parcourus · Parcours %d %% · Trouvailles %d/%d") % [int(dist_done * SCALE), int(progress() * 100.0), collected, finds_total]
	if returning:
		txt = tr("Retour à la maison : suivez le drapeau. Trouvailles %d/%d") % [collected, finds_total]
	obj_l.text = txt
	info_label.text = tr("Joystick : touchez et glissez. Suivez le drapeau vert.")

func _set_energy(e: float) -> void:
	energy_bar.value = e
	energy_bar.add_theme_stylebox_override("fill", UiKit.sb(UiKit.need_color(e), 12, 0, Color.TRANSPARENT, false, 0))

# ------------------------------------------------------------------ actions
func _collect(it: Dictionary) -> void:
	var n: Node3D = it["node"]
	var id: String = it["id"]
	var data := GameData.item(id)
	GameState.add_item(id, 1)
	collected += 1
	Audio.play("coin", 0.05, -4.0)
	var rare := int(data.get("rarity", 1)) >= 2
	main.toast("[i:%s] %s%s" % [data["icon"], tr(data["name"]), (" · " + tr(GameData.RARITY_NAMES[int(data.get("rarity", 1))])) if rare else ""])
	pet.model.emote("emo_star" if rare else "emo_sparkle")
	if is_instance_valid(n):
		var tw := n.create_tween()
		tw.tween_property(n, "scale", Vector3.ZERO, 0.25)
		tw.tween_callback(n.queue_free)

func _meet(c: PetController) -> void:
	pet.stop_moving()
	pet.face(c.position)
	c.stop_moving()
	c.face(pet.position)
	c.play_bow()
	pet.play_bow()
	c.voice()
	pet.model.hearts(2)
	c.model.emote("emo_heart")
	bonus_coins += 10
	GameState.change_need("mood", 8.0)
	GameState.change_need("affection", 4.0)
	main.toast(tr("%s a rencontré %s ! Ils jouent ensemble.") % [pet_name(), c.pet.get("name", "?")])

func _pee() -> void:
	peed = true
	pet.stop_moving()
	pet.state = "action"
	pet.model.set_posture("sniff")
	pet.model.sniff = 1.0
	await get_tree().create_timer(0.9, false).timeout
	if finished:
		return
	pet.model.sniff = 0.0
	pet.model.set_posture("pee", 4.0)
	await get_tree().create_timer(1.8, false).timeout
	if finished:
		return
	GameState.change_need("outside", 25.0)
	pet.model.set_posture("stand")
	pet.state = "idle"

func _poop() -> void:
	pooped = true
	pet.stop_moving()
	pet.state = "action"
	pet.model.set_posture("squat", 3.0)
	await get_tree().create_timer(2.0, false).timeout
	if finished:
		return
	var back := pet.position - Vector3(sin(pet.rotation.y), 0, cos(pet.rotation.y)) * 0.35
	var n := Node3D.new()
	n.position = back
	main.world.add_child(n)
	WorldBuilder.ball(n, 0.05, Vector3(0, 0.03, 0), Color(0.42, 0.28, 0.18), Vector3(1.2, 0.7, 1.0), 8)
	WorldBuilder.ball(n, 0.035, Vector3(0.01, 0.07, 0), Color(0.45, 0.3, 0.2), Vector3(1, 0.8, 1), 8)
	WorldBuilder.interactive(n, "poop_%d" % poops.size(), Vector3(0.5, 0.4, 0.5), Vector3(0, 0.1, 0))
	poops.append(n)
	GameState.change_need("outside", 35.0)
	pet.model.set_posture("stand")
	pet.state = "idle"
	main.toast(tr("Pensez à ramasser : touchez-la avec un sac !"))

func _pick_poop(i: int) -> void:
	if i < 0 or i >= poops.size() or not is_instance_valid(poops[i]):
		return
	poops[i].queue_free()
	picked += 1
	bonus_coins += 5
	Audio.play("pop")
	main.toast(tr("Bien joué, promeneur responsable ! +5 pièces"))

func _trigger(kind: String) -> void:
	var ahead := path[mini(next_cp + 2, path.size() - 1)]
	match kind:
		"meet":
			var breed: String = GameData.BREED_ORDER[rng.randi() % GameData.BREED_ORDER.size()]
			var bd := GameData.breed(breed)
			var np := GameState.sanitize_pet({"breed": breed, "palette": rng.randi() % bd["palettes"].size(), "eyes": rng.randi() % 5,
				"collar": "collar_blue", "name": GameData.RIVAL_NAMES[rng.randi() % GameData.RIVAL_NAMES.size()]})
			var c := main.add_extra_pet(np, ahead + Vector3(0.6, 0, 0))
			c.bounds = Rect2(ahead.x - 1.5, ahead.z - 1.5, 3, 3)
			npcs.append(c)
			main.toast(tr("Un autre chien arrive, allez le saluer !"))
		"treasure":
			var rares: Array = GameData.collectibles(main.env_id, 3)
			if rares.is_empty():
				rares = GameData.collectibles(main.env_id, 2)
			if rares.is_empty():
				return
			var id: String = rares[rng.randi() % rares.size()]
			var p := ahead + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
			if main.nav:
				var f := main.nav.nearest_free(Vector2(p.x, p.z))
				p = Vector3(f.x, 0, f.y)
			items.append({"pos": p, "id": id, "node": _make_marker(p, "sparkle"), "taken": false, "kind": "treasure"})
			pet.model.emote("emo_exclaim")
			main.toast(tr("%s a flairé quelque chose de précieux !") % pet_name())
		"poi":
			var p2 := ahead + Vector3(1.0, 0, 0)
			if main.nav:
				var f2 := main.nav.nearest_free(Vector2(p2.x, p2.z))
				p2 = Vector3(f2.x, 0, f2.y)
			var bowl := WorldBuilder.make_bowl(main.world, p2, Color(0.45, 0.65, 0.95), "water")
			markers.append(bowl)
			items.append({"pos": p2, "id": "", "node": bowl, "taken": false, "kind": "water"})
			main.toast(tr("Un point d'eau pour chiens, juste devant !"))
		"training":
			_training_challenge()

func _training_challenge() -> void:
	var learned: Array = GameData.COMMAND_ORDER.filter(func(c): return GameState.skill(c) >= 20.0 and c in ["sit", "down", "paw", "spin", "beg", "jump"])
	var cmd: String = learned[rng.randi() % learned.size()] if not learned.is_empty() else "sit"
	var v := UiKit.vbox(12)
	v.add_child(UiKit.label(tr("Un passant aimerait voir %s faire « %s ». Vous relevez le défi ?") % [pet_name(), tr(GameData.COMMANDS[cmd]["name"])], 26))
	var h := UiKit.hbox(10)
	h.add_child(UiKit.expand(UiKit.button(tr("Passer"), func(): main.close_panel(), UiKit.C_DISABLED, 24, 76)))
	h.add_child(UiKit.expand(UiKit.button("[i:training] " + tr("Donner l'ordre"), func():
		main.close_panel()
		_do_challenge(cmd), UiKit.C_ACCENT, 24, 76)))
	v.add_child(h)
	main.open_panel("[i:training] " + tr("Défi de dressage"), v)

func _do_challenge(cmd: String) -> void:
	pet.stop_moving()
	var ok := randf() < GameState.success_chance(cmd)
	var dur := pet.perform(cmd) if ok else pet.fail_behaviour(cmd)
	await get_tree().create_timer(minf(dur, 2.0), false).timeout
	if finished:
		return
	if ok:
		bonus_coins += 15
		GameState.add_xp(8)
		pet.model.hearts(2)
		main.toast(tr("Le passant applaudit ! +15 pièces"))
	else:
		main.toast(tr("Pas cette fois… Continuez l'entraînement."))
	pet.state = "idle"

func _go_home() -> void:
	if returning:
		return
	returning = true
	for m in markers:
		if is_instance_valid(m) and m is MeshInstance3D:
			m.visible = false
	main.toast(tr("Direction la maison : suivez le drapeau."))

# ------------------------------------------------------------------ fin
func _finish(arrived: bool) -> void:
	if finished:
		return
	finished = true
	pet.stop_moving()
	var frac := 1.0 if next_cp >= path.size() else maxf(progress(), 0.15)
	if on_done.is_valid():
		# défi de promenade : parcours, trouvailles et chrono
		var par := maxf(10.0, float(path.size()) * 1.6 / 1.6)
		var finds_k := clampf(float(collected) / maxf(1.0, float(route.get("finds", 1))), 0.0, 1.0)
		var time_k := clampf((par * 1.6 - elapsed) / (par * 0.8), 0.0, 1.0) if arrived and frac >= 1.0 else 0.0
		var sc := (frac * 55.0 + finds_k * 25.0 + time_k * 20.0) if arrived else frac * 30.0
		GameState.spend_energy("walk_km", float(route.get("length", 300)) / 1000.0)
		on_done.call(clampf(sc, 0.0, 100.0))
		return
	var length := float(route["length"])
	var lines: Array = []
	var coins := 0
	var xp := 0
	if arrived:
		coins = int(length / 12.0 * frac) + bonus_coins + collected * 2
		xp = int(length / 15.0 * frac) + 10
		if frac >= 0.5:
			GameState.inc_stat("walk", 1)
		GameState.change_need("outside", 60.0 * frac)
		GameState.change_need("mood", 10.0)
		GameState.change_need("hunger", -6.0 * frac)
		GameState.change_need("thirst", -8.0 * frac)
		GameState.change_need("clean", -(12.0 if main.env_id in ["beach", "forest"] else 6.0) * frac)
		GameState.add_relation(int(12 * frac) + 3)
		lines.append(tr("Itinéraire « %s » : %d %% parcouru (%d m).") % [tr(route["name"]), int(frac * 100.0), int(dist_done * SCALE)])
	else:
		lines.append(tr("Promenade écourtée : pas de récompense finale."))
	lines.append(tr("Trouvailles : %d · Rencontres : %d") % [collected, met.size()])
	if pooped:
		lines.append(tr("Crottes ramassées : %d / 1") % picked)
	var rec_key := "walk_" + str(route["id"])
	var p := GameState.active_pet()
	var recs: Dictionary = p.get("records", {})
	if arrived and int(dist_done * SCALE) > int(recs.get(rec_key, 0)):
		recs[rec_key] = int(dist_done * SCALE)
		p["records"] = recs
	show_results("[i:walk] " + (tr("Belle promenade !") if arrived else tr("Promenade")), lines, coins, xp)

func quit() -> void:
	if finished or not started:
		finished = true
		main.end_activity()
		return
	main.confirm(tr("Abandonner la promenade ? Les trouvailles sont gardées, mais pas la récompense finale."), func(): _finish(false), "Abandonner")

func _exit_tree() -> void:
	super._exit_tree()
	for it in items:
		var n: Variant = it["node"]
		if is_instance_valid(n):
			(n as Node).queue_free()
	for m in markers:
		if is_instance_valid(m):
			m.queue_free()
	for pp in poops:
		if is_instance_valid(pp):
			pp.queue_free()
	if flag and is_instance_valid(flag):
		flag.queue_free()
	if leash and is_instance_valid(leash):
		leash.queue_free()
	if main:
		main._clear_extra_pets()
