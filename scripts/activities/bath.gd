class_name BathActivity
extends Activity
## Bain : savonner chaque partie du corps (tête, dos, ventre et pattes, queue),
## rincer à la douche, puis l'animal s'ébroue. Récompense selon le travail réel.

const ZONES := {"head": "Tête", "back": "Dos", "legs": "Ventre et pattes", "tail": "Queue"}
const NEEDED := 9.0          # passages de savon par zone
const XP_COOLDOWN_H := 3.0   # un bain ne rapporte de l'expérience qu'une fois toutes les 3 h

var tub: Node3D
var zone_done := {"head": 0.0, "back": 0.0, "legs": 0.0, "tail": 0.0}
var zone_bars := {}
var rinse_btn: Button
var shampoo_btn: Button
var bubbles: Array[Node3D] = []
var _rubbing := false
var _acc := 0.0
var shampoo := false
var shampoo_id := ""
var foam_c := Color(1, 1, 1)

func _init(id: String = "") -> void:
	shampoo_id = id
var _rinsing := false
var clean_before := 0.0
var shower: CPUParticles3D

func _start() -> void:
	# Pas de bain sans shampooing : celui choisi (ou le premier du sac) est utilisé dès le début
	if shampoo_id == "" or GameState.item_count(shampoo_id) <= 0:
		shampoo_id = ""
		for id in GameData.ITEMS.keys():
			if GameData.ITEMS[id].get("bath", false) and GameState.item_count(id) > 0:
				shampoo_id = id
				break
	if shampoo_id == "" or not GameState.consume(shampoo_id):
		finished = true
		main.toast(tr("Il faut du shampooing pour donner le bain : la boutique du quartier en vend."))
		main.call_deferred("end_activity")
		return
	shampoo = true
	foam_c = GameData.item(shampoo_id).get("foam", Color(1, 1, 1))
	make_top("[i:wash] " + tr("Bain de %s") % pet_name())
	info_label.text = tr("Frottez l'animal du doigt. Glissez à côté pour tourner, ou touchez une zone.")
	var bb := bottom_bar()
	var pv := UiKit.panel(14)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vv := UiKit.vbox(6)
	var zp := care_zone_panel(ZONES, Color(0.55, 0.85, 0.95))
	zone_bars = zp["bars"]
	vv.add_child(zp["grid"])
	rinse_btn = UiKit.button("[i:shower] " + tr("Rincer"), _rinse, UiKit.C_ACCENT2, 24, 76)
	rinse_btn.disabled = true
	vv.add_child(rinse_btn)
	pv.add_child(vv)
	bb.add_child(pv)
	clean_before = float(GameState.active_pet()["needs"]["clean"])
	# Baquet
	care_setup()
	tub = Node3D.new()
	tub.position = pet.position
	main.world.add_child(tub)
	var r := maxf(0.6, pet.model.body_length() * 0.66)
	Kit.q = main.quality
	var tb := MeshBatch.new()
	var tx := Transform3D()
	# tapis de bain, baquet en bois cerclé, fond, eau mousseuse
	tb.disc("t:fabric:1.4", tx, r * 1.55, Vector3(0, 0.008, 0), Color(0.62, 0.80, 0.92), 28)
	tb.disc("t:fabric:1.4", tx, r * 1.38, Vector3(0, 0.011, 0), Color(0.92, 0.96, 1.0), 28)
	var staves := 22
	var wall_h := 0.15
	for i in staves:
		var a := TAU * i / staves
		var sx := Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * r * 1.08, 0, sin(a) * r * 1.08))
		tb.box("t:wood_planks:0.6", sx, Vector3(0.05, wall_h, TAU * r * 1.08 / staves + 0.01), Vector3(0, 0.02 + wall_h * 0.5, 0), Color(0.92, 0.74, 0.52).darkened((i % 3) * 0.05), 0.15)
		for hy in [0.05, 0.135]:
			tb.box("metal", sx, Vector3(0.012, 0.022, TAU * r * 1.08 / staves + 0.012), Vector3(0.03, hy, 0), Color(0.62, 0.64, 0.68))
	tb.disc("t:wood_planks:0.6", tx, r * 1.07, Vector3(0, 0.022, 0), Color(0.8, 0.64, 0.46), 24)
	var tmi := tb.commit(tub, false, "Tub")
	tmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = r * 1.05
	wm.bottom_radius = r * 1.05
	wm.height = 0.01
	wm.radial_segments = 32
	wm.rings = 1
	water.mesh = wm
	water.material_override = Kit.water_mat({"radius": r * 1.05, "center": Vector2(tub.position.x, tub.position.z), "scale": 3.0,
		"shallow": Color(0.66, 0.88, 0.96), "deep": Color(0.42, 0.72, 0.9)})
	water.position = Vector3(0, 0.105, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tub.add_child(water)
	pet.face(pet.player_pos)
	pet.model.set_posture("stand", 3.0)
	pet.state = "action"
	care_view("back")
	Audio.play("splash")

func can_recenter() -> bool:
	return true

func recenter() -> void:
	care_view("back")

func handle_input(event: InputEvent) -> bool:
	if finished or _rinsing:
		return false
	return care_input(event, _rub)

func _rub(event: InputEventScreenDrag, hit: Dictionary) -> void:
	_acc += event.relative.length()
	if _acc < 32.0:
		return
	_acc = 0.0
	var z := care_zone(hit)
	zone_done[z] = minf(NEEDED, zone_done[z] + (1.5 if shampoo else 1.0))
	(zone_bars[z] as ProgressBar).value = zone_done[z] / NEEDED * 100.0
	_add_bubble(hit["position"])
	if randf() < 0.3:
		Audio.play("bubble", 0.1, -8.0)
	if z == "head" and randf() < 0.15:
		pet.model.head_extra.z = randf_range(-0.3, 0.3)
	pet.model.expression = "happy" if randf() < 0.7 else "closed"
	pet.model.wag_amp = 0.5
	var p := progress()
	pet.model.set_dirt(lerpf(pet.model.dirt, 0.0, 0.04))
	if p >= 0.6:
		rinse_btn.disabled = false
	if zone_done[z] >= NEEDED:
		var nx := _next_zone()
		info_label.text = (tr("Mousse : %d %%") % int(p * 100.0)) + ("   " + tr("Reste : %s") % tr(ZONES[nx]) if nx != "" else "")
	else:
		info_label.text = tr("Mousse : %d %%") % int(p * 100.0)

func _next_zone() -> String:
	for z in ZONES.keys():
		if zone_done[z] < NEEDED:
			return z
	return ""

func progress() -> float:
	var t := 0.0
	for z in zone_done.keys():
		t += zone_done[z] / NEEDED
	return t / zone_done.size()

func _add_bubble(p: Vector3) -> void:
	if bubbles.size() > 90:
		return
	var b := WorldBuilder.ball(main.world, randf_range(0.03, 0.07), p + Vector3(randf_range(-0.03, 0.03), 0.015, randf_range(-0.03, 0.03)), foam_c, Vector3.ONE, 8)
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.scale = Vector3.ONE * 0.2
	b.create_tween().tween_property(b, "scale", Vector3.ONE * randf_range(0.8, 1.3), 0.15)
	bubbles.append(b)

func _rinse() -> void:
	_rinsing = true
	rinse_btn.disabled = true
	Audio.play("splash")
	# Douche : gouttes d'eau
	shower = CPUParticles3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.012
	dm.height = 0.03
	dm.radial_segments = 6
	dm.rings = 3
	shower.mesh = dm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.7, 0.88, 1.0, 0.8)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shower.material_override = wm
	shower.amount = 90 if main.quality > 0 else 40
	shower.lifetime = 0.7
	shower.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	shower.emission_sphere_radius = pet.model.body_length() * 0.35
	shower.direction = Vector3.DOWN
	shower.spread = 12.0
	shower.initial_velocity_min = 1.5
	shower.initial_velocity_max = 2.5
	shower.gravity = Vector3(0, -6, 0)
	shower.position = pet.position + Vector3(0, pet.model.top_height() + 0.5, 0)
	main.world.add_child(shower)
	shower.emitting = true
	var tw := create_tween()
	for b in bubbles:
		if is_instance_valid(b):
			tw.parallel().tween_property(b, "scale", Vector3.ZERO, 1.2)
	await tw.finished
	for b in bubbles:
		if is_instance_valid(b):
			b.queue_free()
	bubbles.clear()
	shower.emitting = false
	pet.model.set_dirt(0.0)
	pet.state = "idle"
	pet.shake_off()
	# éclaboussures quand il s'ébroue
	var splash := shower.duplicate() as CPUParticles3D
	splash.position = pet.position + Vector3(0, pet.model.top_height() * 0.6, 0)
	splash.direction = Vector3.UP
	splash.spread = 80.0
	splash.one_shot = true
	splash.initial_velocity_min = 1.0
	splash.initial_velocity_max = 2.2
	main.world.add_child(splash)
	splash.emitting = true
	get_tree().create_timer(1.6, false).timeout.connect(splash.queue_free)
	await get_tree().create_timer(1.1, false).timeout
	var q := progress()
	GameState.bath_done(q)
	var fx: Dictionary = GameData.item(shampoo_id).get("fx", {})
	for k in fx.keys():
		GameState.change_need(str(k), float(fx[k]))
	pet.model.emote("emo_sparkle")
	# Récompense selon le travail réel, sans abus par répétition
	var p := GameState.active_pet()
	var now := Time.get_unix_time_from_system()
	var last := float(p.get("last_bath", 0.0))
	var dirty_k := clampf((100.0 - clean_before) / 60.0, 0.15, 1.0)
	var xp := int(round(25.0 * q * dirty_k))
	var coins := int(round(8.0 * q * dirty_k))
	var lines: Array = [tr("%s sent bon la rose.") % pet_name(), tr("Propreté : %d") % int(p["needs"]["clean"])]
	if now - last < XP_COOLDOWN_H * 3600.0:
		xp = 0
		coins = 0
		lines.append(tr("Déjà lavé récemment : pas de récompense cette fois."))
	else:
		p["last_bath"] = now
	show_results("[i:wash] " + tr("Tout propre !"), lines, coins, xp)

func _exit_tree() -> void:
	super._exit_tree()
	care_teardown()
	for b in bubbles:
		if is_instance_valid(b):
			b.queue_free()
	if tub and is_instance_valid(tub):
		tub.queue_free()
	if shower and is_instance_valid(shower):
		shower.queue_free()
