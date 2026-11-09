class_name WorldBuilder
extends RefCounted

## Grille de navigation couvrant toutes les zones jouables du lieu.
static func make_nav(root: Node3D, radius: float = 0.22) -> NavGrid:
	var area: Rect2 = root.get_meta("bounds")
	for k in ["walk_area", "throw_area", "spots_area"]:
		if root.has_meta(k):
			area = area.merge(root.get_meta(k))
	area = area.grow(1.0)
	var nav := NavGrid.new()
	nav.build(area, root.get_meta("obstacles", []), radius)
	return nav
## Construit procéduralement les 6 environnements 3D.
## Retourne un Node3D avec des métadonnées (points d'intérêt, limites, cachettes…).

static var _tex_cache := {}

static func m(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	return PetModel.mat(c, rough, 0.0)

static func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m(c)
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func cyl(parent: Node3D, r_bot: float, r_top: float, h: float, pos: Vector3, c: Color, seg: int = 16, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bot
	cm.top_radius = r_top
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func ball(parent: Node3D, r: float, pos: Vector3, c: Color, scl: Vector3 = Vector3.ONE, seg: int = 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = maxi(4, seg / 2)
	mi.mesh = sm
	mi.material_override = m(c)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func torus(parent: Node3D, inner: float, outer: float, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 20
	tm.ring_segments = 8
	mi.mesh = tm
	mi.material_override = m(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func ground(parent: Node3D, size: Vector2, c: Color, tex: Texture2D = null, uv: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	mt.roughness = 1.0
	mt.metallic_specular = 0.05
	if tex:
		mt.albedo_texture = tex
		mt.uv1_scale = Vector3(uv, uv, uv)
		mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = mt
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	# Sol cliquable (couche 1)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("part", "ground")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, 0.1, size.y)
	cs.shape = bs
	cs.position = Vector3(0, -0.05, 0)
	body.add_child(cs)
	parent.add_child(body)
	return mi

## Texture procédurale (bruit doux ou rayures) mise en cache.
static func noise_tex(key: String, base: Color, var_c: Color, stripes: int = 0, sz: int = 128) -> Texture2D:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(sz, sz, true, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new()
	n.seed = hash(key)
	n.frequency = 0.06
	for y in sz:
		for x in sz:
			var v := (n.get_noise_2d(x, y) + 1.0) * 0.5
			var c := base.lerp(var_c, v * 0.6)
			if stripes > 0:
				var row := int(float(y) / sz * stripes)
				if y % (sz / stripes) == 0:
					c = c.darkened(0.25)
				if (row % 2) == 0:
					c = c.darkened(0.05)
				if (x + row * 37) % sz == 0:
					c = c.darkened(0.2)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t

## Touffes d'herbe / fleurs instanciées (une seule draw call par type).
static func scatter(parent: Node3D, mesh: Mesh, c: Color, count: int, area: Rect2, seed_v: int, scl: Vector2 = Vector2(0.8, 1.2), avoid: Rect2 = Rect2(), colors: Array = []) -> void:
	if count <= 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in count:
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var tries := 0
		while avoid.has_area() and avoid.has_point(p) and tries < 8:
			p = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
			tries += 1
		var s := rng.randf_range(scl.x, scl.y)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, 0, p.y))
		mm.set_instance_transform(i, t)
		if mm.use_colors:
			mm.set_instance_color(i, colors[rng.randi() % colors.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mt := m(c)
	if mm.use_colors:
		mt = StandardMaterial3D.new()
		mt.vertex_color_use_as_albedo = true
		mt.albedo_color = Color.WHITE
		mt.roughness = 0.9
		mt.metallic_specular = 0.1
	mmi.material_override = mt
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)

## Enregistre un obstacle de navigation (cercle ou rectangle au sol) sur la racine du lieu.
static func obs_circle(root: Node, pos: Vector3, radius: float) -> void:
	if root.has_meta("obstacles"):
		(root.get_meta("obstacles") as Array).append({"c": Vector2(pos.x, pos.z), "r": radius})

static func obs_rect(root: Node, center: Vector3, size_x: float, size_z: float) -> void:
	if root.has_meta("obstacles"):
		(root.get_meta("obstacles") as Array).append({"rect": Rect2(center.x - size_x * 0.5, center.z - size_z * 0.5, size_x, size_z)})

static func tree(parent: Node3D, pos: Vector3, h: float, c: Color, seed_v: int) -> void:
	obs_circle(parent, pos, 0.16 * h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	cyl(parent, 0.12 * h, 0.08 * h, h * 0.55, pos + Vector3(0, h * 0.27, 0), Color(0.5, 0.35, 0.22), 10)
	for i in 4:
		var o := Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, 0.35), rng.randf_range(-0.3, 0.3)) * h
		ball(parent, h * rng.randf_range(0.28, 0.38), pos + Vector3(0, h * 0.75, 0) + o, c.lightened(rng.randf_range(-0.08, 0.1)), Vector3.ONE, 12)

static func bush(parent: Node3D, pos: Vector3, s: float, c: Color) -> void:
	obs_circle(parent, pos + Vector3(0, 0, s * 0.1), s * 0.75)
	for i in 3:
		ball(parent, s * (0.5 - i * 0.08), pos + Vector3((i - 1) * s * 0.45, s * 0.35, (i % 2) * s * 0.2), c.lightened(i * 0.05), Vector3(1, 0.8, 1), 10)

static func bench(parent: Node3D, pos: Vector3, rot_y: float) -> Node3D:
	obs_circle(parent, pos, 0.8)
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	var wood := Color(0.7, 0.45, 0.28)
	for k in 3:
		box(n, Vector3(1.4, 0.05, 0.12), Vector3(0, 0.45, -0.15 + k * 0.15), wood)
	for k in 2:
		box(n, Vector3(1.4, 0.12, 0.05), Vector3(0, 0.65 + k * 0.17, -0.25), wood)
	for sx in [-0.6, 0.6]:
		box(n, Vector3(0.06, 0.45, 0.4), Vector3(sx, 0.22, -0.05), Color(0.3, 0.3, 0.32))
	return n

static func fence_line(parent: Node3D, a: Vector3, b: Vector3, c: Color, step: float = 0.5) -> void:
	var d := b - a
	var n := maxi(1, int(d.length() / step))
	for i in n + 1:
		var p := a + d * (float(i) / n)
		box(parent, Vector3(0.08, 0.7, 0.08), p + Vector3(0, 0.35, 0), c)
	var mid := (a + b) * 0.5
	var ang := atan2(d.x, d.z)
	for hgt in [0.25, 0.55]:
		box(parent, Vector3(0.05, 0.08, d.length()), mid + Vector3(0, hgt, 0), c, Vector3(0, ang, 0))

static func make_bowl(parent: Node3D, pos: Vector3, c: Color, kind: String) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.name = "Bowl_" + kind
	parent.add_child(n)
	cyl(n, 0.16, 0.2, 0.08, Vector3(0, 0.04, 0), c, 18)
	var fill := cyl(n, 0.16, 0.16, 0.01, Vector3(0, 0.075, 0), Color(0.6, 0.38, 0.2) if kind == "food" else Color(0.45, 0.7, 0.95), 18)
	fill.name = "Fill"
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.set_meta("part", "bowl_" + kind)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.3
	sh.height = 0.3
	cs.shape = sh
	cs.position.y = 0.1
	body.add_child(cs)
	n.add_child(body)
	return n

static func interactive(node: Node3D, part: String, size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.set_meta("part", part)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = offset
	body.add_child(cs)
	node.add_child(body)

# ================================================================== Environnements
static func build(env_id: String, quality: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Env_" + env_id
	root.set_meta("bounds", Rect2(-2.5, -2.0, 5.0, 4.5))
	root.set_meta("obstacles", [])
	root.set_meta("sky", Color(0.62, 0.82, 0.96))
	root.set_meta("ambient", Color(1.0, 0.95, 0.9))
	match env_id:
		"house": _house(root, quality)
		"garden": _garden(root, quality)
		"park": _park(root, quality)
		"beach": _beach(root, quality)
		"forest": _forest(root, quality)
		"center": _center(root, quality)
		"shelter": _shelter(root, quality)
	return root

static func _density(q: int) -> float:
	return [0.35, 0.7, 1.0][clampi(q, 0, 2)]

static func _house(r: Node3D, q: int) -> void:
	var deco: Dictionary = GameState.data.get("deco", {})
	var wall_c: Color = GameData.item(str(deco.get("wall", "wall_cream"))).get("color", Color(0.98, 0.93, 0.84))
	r.set_meta("bounds", Rect2(-2.3, -1.9, 4.6, 4.0))
	r.set_meta("indoor", true)
	ground(r, Vector2(7, 7), Color(0.85, 0.65, 0.45), noise_tex("wood", Color(0.86, 0.66, 0.46), Color(0.7, 0.5, 0.32), 8), 3.0)
	box(r, Vector3(7, 3.2, 0.2), Vector3(0, 1.6, -2.6), wall_c, Vector3.ZERO, false)
	box(r, Vector3(0.2, 3.2, 7), Vector3(-3.0, 1.6, 0), wall_c.darkened(0.06), Vector3.ZERO, false)
	box(r, Vector3(0.2, 3.2, 7), Vector3(3.0, 1.6, 0), wall_c.darkened(0.06), Vector3.ZERO, false)
	box(r, Vector3(7, 0.15, 0.25), Vector3(0, 0.07, -2.47), Color(1, 1, 1))
	# Fenêtre
	box(r, Vector3(1.5, 1.1, 0.06), Vector3(0.9, 1.75, -2.48), Color(1, 1, 1))
	var glass := box(r, Vector3(1.3, 0.9, 0.05), Vector3(0.9, 1.75, -2.45), Color(0.7, 0.88, 1.0))
	var gm := m(Color(0.7, 0.88, 1.0)).duplicate() as StandardMaterial3D
	gm.emission_enabled = true
	gm.emission = Color(0.55, 0.75, 0.95)
	gm.emission_energy_multiplier = 0.5
	glass.material_override = gm
	box(r, Vector3(0.05, 0.9, 0.06), Vector3(0.9, 1.75, -2.42), Color(1, 1, 1))
	box(r, Vector3(1.3, 0.05, 0.06), Vector3(0.9, 1.75, -2.42), Color(1, 1, 1))
	# Tapis
	var rug_c: Color = GameData.item(str(deco.get("rug", "rug_round"))).get("color", Color(0.85, 0.55, 0.45))
	cyl(r, 1.2, 1.2, 0.02, Vector3(0, 0.01, 0.2), rug_c, 32)
	cyl(r, 0.9, 0.9, 0.022, Vector3(0, 0.012, 0.2), rug_c.lightened(0.18), 32)
	# Canapé
	var sofa_c: Color = GameData.item(str(deco.get("sofa", "sofa_coral"))).get("color", Color(0.95, 0.55, 0.45))
	var sofa := Node3D.new()
	sofa.position = Vector3(-1.6, 0, -1.9)
	obs_rect(r, sofa.position, 2.15, 0.85)
	r.add_child(sofa)
	box(sofa, Vector3(1.9, 0.4, 0.8), Vector3(0, 0.25, 0), sofa_c)
	box(sofa, Vector3(1.9, 0.6, 0.25), Vector3(0, 0.6, -0.3), sofa_c.darkened(0.05))
	for sx in [-0.95, 0.95]:
		box(sofa, Vector3(0.22, 0.55, 0.8), Vector3(sx, 0.35, 0), sofa_c.darkened(0.08))
	for sx in [-0.45, 0.45]:
		box(sofa, Vector3(0.85, 0.12, 0.6), Vector3(sx, 0.5, 0.06), sofa_c.lightened(0.1))
	# Couchage
	var bed_id := str(deco.get("bed", "bed_basic"))
	var bed_c: Color = GameData.item(bed_id).get("color", Color(0.7, 0.45, 0.3))
	var bed := Node3D.new()
	bed.position = Vector3(1.85, 0, -1.6)
	bed.name = "Bed"
	r.add_child(bed)
	if bed_id == "bed_royal":
		box(bed, Vector3(1.0, 0.25, 0.8), Vector3(0, 0.12, 0), Color(0.85, 0.7, 0.35))
		box(bed, Vector3(0.9, 0.12, 0.7), Vector3(0, 0.3, 0), bed_c)
		box(bed, Vector3(1.0, 0.6, 0.08), Vector3(0, 0.4, -0.38), Color(0.85, 0.7, 0.35))
	elif bed_id == "bed_cloud":
		for k in 5:
			ball(bed, 0.28, Vector3(cos(k * 1.256) * 0.3, 0.12, sin(k * 1.256) * 0.25), bed_c, Vector3(1, 0.55, 1))
		cyl(bed, 0.4, 0.4, 0.08, Vector3(0, 0.08, 0), bed_c.darkened(0.05), 20)
	else:
		torus(bed, 0.3, 0.48, Vector3(0, 0.09, 0), bed_c, Vector3.ZERO)
		cyl(bed, 0.38, 0.38, 0.06, Vector3(0, 0.04, 0), Color(0.95, 0.9, 0.8), 20)
	interactive(bed, "bed", Vector3(0.9, 0.4, 0.8), Vector3(0, 0.2, 0))
	r.set_meta("bed", Vector3(1.85, 0, -1.55))
	# Plante, lampe, tableau, coffre
	var plant := str(deco.get("plant", ""))
	if plant != "":
		var pc: Color = GameData.item(plant).get("color", Color.GREEN)
		cyl(r, 0.18, 0.22, 0.35, Vector3(-2.55, 0.18, 0.9), Color(0.85, 0.5, 0.35), 14)
		obs_circle(r, Vector3(-2.55, 0, 0.9), 0.3)
		match plant:
			"plant_cactus":
				cyl(r, 0.1, 0.1, 0.6, Vector3(-2.55, 0.6, 0.9), pc, 10)
				cyl(r, 0.06, 0.06, 0.25, Vector3(-2.42, 0.62, 0.9), pc, 8, Vector3(0, 0, -0.9))
			"plant_flowers":
				for k in 6:
					ball(r, 0.08, Vector3(-2.55 + cos(k) * 0.12, 0.6 + (k % 3) * 0.06, 0.9 + sin(k) * 0.12), [Color(0.95, 0.4, 0.5), Color(1, 0.85, 0.3), Color(0.7, 0.5, 0.95)][k % 3])
				ball(r, 0.18, Vector3(-2.55, 0.45, 0.9), Color(0.35, 0.65, 0.3))
			_:
				for k in 5:
					ball(r, 0.2, Vector3(-2.55 + cos(k * 1.3) * 0.15, 0.55 + k * 0.05, 0.9 + sin(k * 1.3) * 0.15), pc.lightened(k * 0.04), Vector3(1, 1.4, 1))
	var lamp := str(deco.get("lamp", ""))
	if lamp != "":
		var lc: Color = GameData.item(lamp).get("color", Color(1, 0.9, 0.6))
		cyl(r, 0.18, 0.18, 0.04, Vector3(2.5, 0.02, 0.6), Color(0.3, 0.3, 0.3))
		obs_circle(r, Vector3(2.5, 0, 0.6), 0.22)
		cyl(r, 0.025, 0.025, 1.5, Vector3(2.5, 0.75, 0.6), Color(0.3, 0.3, 0.3), 8)
		var shade := cyl(r, 0.32, 0.18, 0.35, Vector3(2.5, 1.55, 0.6), lc)
		var sm := m(lc).duplicate() as StandardMaterial3D
		sm.emission_enabled = true
		sm.emission = lc
		sm.emission_energy_multiplier = 0.6
		shade.material_override = sm
		if lamp == "lamp_star":
			ball(r, 0.08, Vector3(2.5, 1.8, 0.6), Color(1, 0.95, 0.4))
		if q >= 1:
			var ol := OmniLight3D.new()
			ol.position = Vector3(2.4, 1.4, 0.7)
			ol.light_color = lc
			ol.light_energy = 0.35
			ol.omni_range = 3.0
			r.add_child(ol)
	var frame := str(deco.get("frame", ""))
	if frame != "":
		var fc: Color = GameData.item(frame).get("color", Color.ORANGE)
		box(r, Vector3(0.9, 0.7, 0.05), Vector3(-1.4, 1.75, -2.47), Color(0.55, 0.35, 0.2))
		box(r, Vector3(0.78, 0.58, 0.05), Vector3(-1.4, 1.75, -2.44), Color(0.95, 0.95, 0.92))
		if frame == "frame_sun":
			cyl(r, 0.15, 0.15, 0.02, Vector3(-1.4, 1.8, -2.41), fc, 16, Vector3(PI / 2, 0, 0))
		else:
			box(r, Vector3(0.78, 0.25, 0.04), Vector3(-1.4, 1.58, -2.41), fc)
	if str(deco.get("box", "")) == "toybox":
		box(r, Vector3(0.7, 0.45, 0.45), Vector3(-2.5, 0.23, -0.5), Color(0.55, 0.75, 0.95))
		obs_rect(r, Vector3(-2.5, 0, -0.5), 0.75, 0.5)
		box(r, Vector3(0.72, 0.08, 0.47), Vector3(-2.5, 0.48, -0.5), Color(0.95, 0.6, 0.4))
		ball(r, 0.08, Vector3(-2.4, 0.6, -0.45), Color(0.9, 0.2, 0.2))
	# Étagère à trophées
	var trophies: Array = GameState.data.get("trophies", [])
	box(r, Vector3(1.2, 0.06, 0.3), Vector3(-0.3, 1.35, -2.4), Color(0.6, 0.4, 0.25))
	for i in mini(trophies.size(), 6):
		var t: Dictionary = trophies[trophies.size() - 1 - i]
		var tc: Color = [Color(1, 0.82, 0.25), Color(0.8, 0.82, 0.86), Color(0.8, 0.5, 0.3)][clampi(int(t.get("place", 3)) - 1, 0, 2)]
		var x := -0.75 + i * 0.18
		cyl(r, 0.04, 0.05, 0.04, Vector3(x, 1.4, -2.4), Color(0.3, 0.25, 0.2), 8)
		cyl(r, 0.012, 0.012, 0.08, Vector3(x, 1.46, -2.4), tc, 6)
		cyl(r, 0.035, 0.06, 0.09, Vector3(x, 1.54, -2.4), tc, 10)
	# Gamelles
	var bowls: Dictionary = GameState.data.get("bowls", {})
	var bf := make_bowl(r, Vector3(0.05, 0, -2.05), Color(0.95, 0.45, 0.45), "food")
	var bw := make_bowl(r, Vector3(0.6, 0, -2.05), Color(0.45, 0.65, 0.95), "water")
	bf.get_node("Fill").visible = float(bowls.get("food", 0.0)) > 0.0
	bw.get_node("Fill").visible = float(bowls.get("water", 0.0)) > 0.0
	r.set_meta("bowl_food", Vector3(0.05, 0, -2.05))
	r.set_meta("bowl_water", Vector3(0.6, 0, -2.05))
	r.set_meta("cam_box", AABB(Vector3(-2.75, 0.25, -2.35), Vector3(5.5, 2.75, 7.5)))
	r.set_meta("ambient", Color(1.0, 0.92, 0.85))

static func _garden(r: Node3D, q: int) -> void:
	var d := _density(q)
	ground(r, Vector2(30, 30), Color(0.55, 0.78, 0.4), noise_tex("grass", Color(0.56, 0.8, 0.4), Color(0.4, 0.65, 0.3)), 6.0)
	var tuft := _cone_mesh(0.05, 0.0, 0.18)
	scatter(r, tuft, Color(0.42, 0.7, 0.32), int(500 * d), Rect2(-7, -6, 14, 10), 11, Vector2(0.7, 1.3), Rect2(-2.5, -1.5, 5, 3.5))
	var flower := SphereMesh.new()
	flower.radius = 0.05; flower.height = 0.1; flower.radial_segments = 6; flower.rings = 3
	scatter(r, flower, Color.WHITE, int(120 * d), Rect2(-6, -6, 12, 4), 12, Vector2(0.8, 1.2), Rect2(), [Color(1, 0.85, 0.3), Color(1, 0.5, 0.6), Color(0.95, 0.95, 1), Color(0.7, 0.5, 1)])
	# Clôture
	var fc := Color(0.98, 0.96, 0.92)
	fence_line(r, Vector3(-4.5, 0, -3.5), Vector3(4.5, 0, -3.5), fc)
	fence_line(r, Vector3(-4.5, 0, -3.5), Vector3(-4.5, 0, 3), fc)
	fence_line(r, Vector3(4.5, 0, -3.5), Vector3(4.5, 0, 3), fc)
	# Niche
	var k := Node3D.new()
	k.position = Vector3(2.6, 0, -2.4)
	obs_circle(r, k.position, 0.62)
	k.rotation.y = -0.4
	r.add_child(k)
	box(k, Vector3(1.0, 0.8, 1.0), Vector3(0, 0.4, 0), Color(0.85, 0.55, 0.35))
	box(k, Vector3(0.75, 0.12, 1.2), Vector3(-0.3, 0.98, 0), Color(0.85, 0.3, 0.3), Vector3(0, 0, 0.75))
	box(k, Vector3(0.75, 0.12, 1.2), Vector3(0.3, 0.98, 0), Color(0.85, 0.3, 0.3), Vector3(0, 0, -0.75))
	box(k, Vector3(0.4, 0.5, 0.05), Vector3(0, 0.25, 0.5), Color(0.25, 0.18, 0.15))
	interactive(k, "bed", Vector3(1, 1, 1), Vector3(0, 0.5, 0))
	r.set_meta("bed", Vector3(2.6, 0, -1.7))
	tree(r, Vector3(-3.6, 0, -4.8), 3.2, Color(0.35, 0.65, 0.3), 3)
	tree(r, Vector3(4.2, 0, -5.5), 3.6, Color(0.4, 0.7, 0.32), 5)
	bush(r, Vector3(-3.6, 0, -2.8), 0.8, Color(0.35, 0.62, 0.3))
	# Potager
	box(r, Vector3(1.6, 0.25, 0.8), Vector3(-2.2, 0.12, -2.7), Color(0.55, 0.38, 0.25))
	obs_rect(r, Vector3(-2.2, 0, -2.7), 1.65, 0.85)
	for i in 5:
		ball(r, 0.1, Vector3(-2.8 + i * 0.3, 0.32, -2.7), Color(0.95, 0.45, 0.25) if i % 2 else Color(0.4, 0.75, 0.3))
	# Maison en arrière-plan
	box(r, Vector3(6, 3, 0.4), Vector3(0, 1.5, -7), Color(0.98, 0.9, 0.78))
	box(r, Vector3(6.6, 0.3, 3), Vector3(0, 3.3, -6.5), Color(0.8, 0.35, 0.3), Vector3(0.35, 0, 0))
	box(r, Vector3(1, 1.8, 0.1), Vector3(0, 0.9, -6.78), Color(0.55, 0.35, 0.25))
	r.set_meta("bounds", Rect2(-3.8, -2.8, 7.6, 5.0))
	r.set_meta("walk_area", Rect2(-4.2, -3.2, 8.4, 6.0))
	r.set_meta("spots_area", Rect2(-3.5, -2.8, 7.0, 4.5))

static func _park(r: Node3D, q: int) -> void:
	var d := _density(q)
	ground(r, Vector2(40, 40), Color(0.5, 0.75, 0.38), noise_tex("park", Color(0.5, 0.76, 0.38), Color(0.38, 0.6, 0.28)), 8.0)
	var path := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.0, 40)
	path.mesh = pm
	path.material_override = m(Color(0.88, 0.78, 0.6))
	path.position = Vector3(3.5, 0.005, 0)
	path.rotation.y = 0.15
	r.add_child(path)
	var tuft := _cone_mesh(0.05, 0.0, 0.2)
	scatter(r, tuft, Color(0.4, 0.68, 0.3), int(700 * d), Rect2(-10, -10, 20, 16), 21, Vector2(0.7, 1.4), Rect2(-3, -2, 6, 4))
	var flower := SphereMesh.new()
	flower.radius = 0.045; flower.height = 0.09; flower.radial_segments = 6; flower.rings = 3
	scatter(r, flower, Color.WHITE, int(150 * d), Rect2(-10, -10, 20, 14), 22, Vector2(0.8, 1.2), Rect2(-3, -2, 6, 4), [Color(1, 1, 1), Color(1, 0.9, 0.3), Color(0.9, 0.5, 0.9)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 9:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(6.5, 11.0)
		tree(r, Vector3(cos(a) * dist, 0, -absf(sin(a)) * dist - 1.0), rng.randf_range(2.8, 4.2), Color(0.3, 0.6, 0.28).lightened(rng.randf() * 0.15), i)
	bench(r, Vector3(-3.2, 0, -3.4), 0.3)
	bench(r, Vector3(5.5, 0, -2.0), -1.3)
	# Étang
	cyl(r, 1.8, 1.8, 0.02, Vector3(-5.5, 0.01, -1.0), Color(0.4, 0.65, 0.9), 32)
	obs_circle(r, Vector3(-5.5, 0, -1.0), 1.85)
	cyl(r, 1.95, 1.95, 0.015, Vector3(-5.5, 0.005, -1.0), Color(0.7, 0.62, 0.5), 32)
	for i in 3:
		cyl(r, 0.15, 0.15, 0.02, Vector3(-5.2 + i * 0.4, 0.025, -0.8 + (i % 2) * 0.4), Color(0.35, 0.65, 0.3), 10)
	for i in 4:
		bush(r, Vector3(-7 + i * 4.0, 0, -6.0 - (i % 2)), 0.9, Color(0.32, 0.58, 0.3))
	# Lampadaires
	for z in [-4.0, 2.0]:
		obs_circle(r, Vector3(2.2, 0, z), 0.12)
		cyl(r, 0.06, 0.05, 2.4, Vector3(2.2, 1.2, z), Color(0.25, 0.28, 0.3), 8)
		ball(r, 0.16, Vector3(2.2, 2.45, z), Color(1, 0.95, 0.75))
	# Fontaine (boire)
	var f := Node3D.new()
	f.position = Vector3(4.6, 0, 1.2)
	obs_circle(r, f.position, 0.3)
	r.add_child(f)
	cyl(f, 0.2, 0.15, 0.9, Vector3(0, 0.45, 0), Color(0.6, 0.62, 0.66), 10)
	cyl(f, 0.25, 0.22, 0.1, Vector3(0, 0.95, 0), Color(0.6, 0.62, 0.66), 12)
	cyl(f, 0.2, 0.2, 0.02, Vector3(0, 1.0, 0), Color(0.5, 0.75, 1.0), 12)
	r.set_meta("fountain", Vector3(4.6, 0, 1.2))
	r.set_meta("bounds", Rect2(-3.5, -3.0, 7.0, 5.5))
	r.set_meta("walk_area", Rect2(-8, -8, 16, 12))
	r.set_meta("spots_area", Rect2(-4, -3, 8, 5))
	r.set_meta("throw_area", Rect2(-4, -9, 8, 9))

static func pine(parent: Node3D, pos: Vector3, h: float, c: Color) -> void:
	obs_circle(parent, pos, 0.14 * h)
	cyl(parent, 0.09 * h, 0.07 * h, h * 0.35, pos + Vector3(0, h * 0.17, 0), Color(0.45, 0.3, 0.2), 8)
	for k in 3:
		var rr := h * (0.36 - k * 0.09)
		cyl(parent, rr, 0.01, h * 0.42, pos + Vector3(0, h * (0.42 + k * 0.2), 0), c.lightened(k * 0.05), 10)

static func log_obj(parent: Node3D, pos: Vector3, length: float, rot_y: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	cyl(n, 0.16, 0.16, length, Vector3(0, 0.16, 0), Color(0.5, 0.34, 0.22), 10, Vector3(0, 0, PI / 2))
	cyl(n, 0.13, 0.13, 0.01, Vector3(length * 0.5 + 0.001, 0.16, 0), Color(0.82, 0.68, 0.48), 10, Vector3(0, 0, PI / 2))
	ball(n, 0.06, Vector3(length * 0.2, 0.3, 0.05), Color(0.4, 0.62, 0.3), Vector3(1.4, 0.5, 1.2), 6)
	obs_rect(parent, pos, absf(cos(rot_y)) * length + 0.35, absf(sin(rot_y)) * length + 0.35)

static func rock(parent: Node3D, pos: Vector3, s: float) -> void:
	obs_circle(parent, pos, s * 0.9)
	ball(parent, s, pos + Vector3(0, s * 0.35, 0), Color(0.58, 0.58, 0.56), Vector3(1.2, 0.75, 1.0), 9)
	ball(parent, s * 0.6, pos + Vector3(s * 0.7, s * 0.2, s * 0.2), Color(0.62, 0.62, 0.6), Vector3(1.1, 0.7, 1.0), 8)

static func _forest(r: Node3D, q: int) -> void:
	var d := _density(q)
	ground(r, Vector2(40, 40), Color(0.42, 0.58, 0.32), noise_tex("forest", Color(0.42, 0.56, 0.3), Color(0.5, 0.42, 0.26)), 8.0)
	# sentier de terre
	var path := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.6, 40)
	path.mesh = pm
	path.material_override = m(Color(0.62, 0.5, 0.36))
	path.position = Vector3(-0.4, 0.005, 0)
	path.rotation.y = -0.12
	r.add_child(path)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var placed: Array[Vector2] = []
	for i in 34:
		var p := Vector3(rng.randf_range(-11, 11), 0, rng.randf_range(-12, 6))
		if absf(p.x + 0.4 + p.z * 0.12) < 1.6 or Rect2(-3.5, -2.5, 7, 5).has_point(Vector2(p.x, p.z)):
			continue
		var close := false
		for o in placed:
			if o.distance_to(Vector2(p.x, p.z)) < 1.4:
				close = true
		if close:
			continue
		placed.append(Vector2(p.x, p.z))
		if rng.randf() < 0.7:
			pine(r, p, rng.randf_range(2.6, 4.2), Color(0.22, 0.45, 0.28).lightened(rng.randf() * 0.12))
		else:
			tree(r, p, rng.randf_range(2.6, 3.6), Color(0.35, 0.58, 0.28), i)
	log_obj(r, Vector3(-2.6, 0, -1.6), 1.6, 0.4)
	log_obj(r, Vector3(2.8, 0, 0.8), 1.3, -0.9)
	rock(r, Vector3(2.4, 0, -2.2), 0.45)
	rock(r, Vector3(-3.0, 0, 1.6), 0.35)
	for i in int(10 * d) + 4:
		var mp := Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 3))
		cyl(r, 0.025, 0.03, 0.12, mp + Vector3(0, 0.06, 0), Color(0.96, 0.92, 0.84), 6)
		ball(r, 0.07, mp + Vector3(0, 0.13, 0), Color(0.85, 0.3, 0.25) if i % 3 else Color(0.85, 0.62, 0.35), Vector3(1, 0.55, 1), 8)
	var fern := _cone_mesh(0.07, 0.0, 0.3)
	scatter(r, fern, Color(0.3, 0.55, 0.3), int(500 * d), Rect2(-11, -12, 22, 18), 61, Vector2(0.8, 1.6), Rect2(-3.2, -2.4, 6.4, 4.6))
	var leaf := SphereMesh.new()
	leaf.radius = 0.05; leaf.height = 0.02; leaf.radial_segments = 6; leaf.rings = 2
	scatter(r, leaf, Color.WHITE, int(260 * d), Rect2(-8, -8, 16, 12), 62, Vector2(0.8, 1.5), Rect2(), [Color(0.82, 0.48, 0.2), Color(0.9, 0.7, 0.25), Color(0.62, 0.36, 0.18)])
	r.set_meta("sky", Color(0.6, 0.78, 0.86))
	r.set_meta("ambient", Color(0.92, 0.98, 0.9))
	r.set_meta("bounds", Rect2(-3.2, -2.6, 6.4, 5.0))
	r.set_meta("walk_area", Rect2(-8, -9, 16, 13))
	r.set_meta("spots_area", Rect2(-3.2, -2.6, 6.4, 4.4))
	r.set_meta("throw_area", Rect2(-1.8, -9, 3.2, 9))

static func _beach(r: Node3D, q: int) -> void:
	var d := _density(q)
	ground(r, Vector2(40, 40), Color(0.96, 0.88, 0.68), noise_tex("sand", Color(0.97, 0.89, 0.7), Color(0.88, 0.78, 0.58)), 8.0)
	# Mer animée (shader simple compatible)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 30)
	pm.subdivide_width = 30 if q > 0 else 10
	pm.subdivide_depth = 15 if q > 0 else 5
	sea.mesh = pm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
uniform vec4 deep : source_color = vec4(0.2, 0.55, 0.85, 1.0);
uniform vec4 shallow : source_color = vec4(0.45, 0.85, 0.9, 1.0);
varying float wave;
void vertex() {
	wave = sin(VERTEX.x * 0.6 + TIME * 1.3) * 0.5 + sin(VERTEX.z * 0.9 + TIME * 0.9) * 0.5;
	VERTEX.y += wave * 0.06;
}
void fragment() {
	float edge = smoothstep(0.35, 0.5, UV.y);
	ALBEDO = mix(deep.rgb, shallow.rgb, edge) + vec3(max(wave, 0.0) * 0.06);
	ROUGHNESS = 0.4;
}"""
	var smat := ShaderMaterial.new()
	smat.shader = sh
	sea.material_override = smat
	sea.position = Vector3(0, 0.02, -19)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(sea)
	box(r, Vector3(60, 0.02, 1.0), Vector3(0, 0.015, -4.0), Color(0.98, 0.98, 0.98), Vector3.ZERO, false)
	# Parasol + serviette
	cyl(r, 0.03, 0.03, 2.2, Vector3(-2.6, 1.1, -2.0), Color(0.95, 0.95, 0.95), 8, Vector3(0, 0, 0.1))
	obs_circle(r, Vector3(-2.6, 0, -2.0), 0.12)
	cyl(r, 1.2, 0.05, 0.45, Vector3(-2.71, 2.2, -2.0), Color(0.95, 0.4, 0.35), 12, Vector3(0, 0, 0.1))
	box(r, Vector3(0.9, 0.02, 1.7), Vector3(-1.9, 0.01, -1.6), Color(0.3, 0.6, 0.9), Vector3(0, 0.3, 0), false)
	box(r, Vector3(0.9, 0.022, 0.3), Vector3(-1.9, 0.012, -1.6), Color(1, 1, 1), Vector3(0, 0.3, 0), false)
	# Palmiers
	for p in [Vector3(4.5, 0, -2.5), Vector3(6.0, 0, 0.5), Vector3(-5.5, 0, 1.0)]:
		obs_circle(r, p, 0.25)
		for i in 6:
			cyl(r, 0.12 - i * 0.01, 0.11 - i * 0.01, 0.5, p + Vector3(i * 0.05, 0.25 + i * 0.48, 0), Color(0.6, 0.45, 0.3), 8, Vector3(0, 0, -0.08))
		for k in 6:
			var a := k * TAU / 6.0
			box(r, Vector3(0.25, 0.04, 1.4), p + Vector3(0.3 + cos(a) * 0.55, 3.0, sin(a) * 0.55), Color(0.3, 0.65, 0.3), Vector3(0.35, -a + PI / 2, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in int(14 * d) + 4:
		ball(r, rng.randf_range(0.15, 0.4), Vector3(rng.randf_range(-9, 9), 0.05, rng.randf_range(-3.5, -7) if i % 2 else rng.randf_range(3, 6)), Color(0.6, 0.58, 0.55).lightened(rng.randf() * 0.2), Vector3(1, 0.6, 1), 8)
	var shell := SphereMesh.new()
	shell.radius = 0.05; shell.height = 0.05; shell.radial_segments = 6; shell.rings = 3
	scatter(r, shell, Color.WHITE, int(60 * d), Rect2(-9, -3.5, 18, 8), 31, Vector2(0.8, 1.4), Rect2(-2.5, -1.5, 5, 3.5), [Color(1, 0.85, 0.8), Color(1, 1, 0.95), Color(0.95, 0.75, 0.6)])
	# Château de sable
	cyl(r, 0.35, 0.3, 0.3, Vector3(2.2, 0.15, 1.8), Color(0.92, 0.82, 0.6), 10)
	obs_circle(r, Vector3(2.2, 0, 1.8), 0.4)
	cyl(r, 0.18, 0.15, 0.3, Vector3(2.2, 0.45, 1.8), Color(0.92, 0.82, 0.6), 10)
	r.set_meta("sky", Color(0.55, 0.8, 0.98))
	r.set_meta("bounds", Rect2(-3.5, -3.2, 7.0, 5.5))
	r.set_meta("walk_area", Rect2(-9, -3.6, 18, 9))
	r.set_meta("spots_area", Rect2(-4, -3, 8, 5))
	r.set_meta("throw_area", Rect2(-4, -3.8, 8, 3.8))

static func _center(r: Node3D, q: int) -> void:
	ground(r, Vector2(30, 30), Color(0.55, 0.78, 0.4), noise_tex("grass2", Color(0.5, 0.75, 0.38), Color(0.42, 0.66, 0.32)), 6.0)
	cyl(r, 6.0, 6.0, 0.02, Vector3(0, 0.01, -2.5), Color(0.86, 0.75, 0.55), 40)
	# Barrière blanche de l'arène
	for i in 28:
		var a := TAU * i / 28.0
		if absf(a - PI / 2) < 0.4:
			continue
		box(r, Vector3(0.08, 0.6, 0.08), Vector3(cos(a) * 6.2, 0.3, -2.5 + sin(a) * 6.2), Color(1, 1, 1))
	torus(r, 6.17, 6.23, Vector3(0, 0.55, -2.5), Color(0.95, 0.3, 0.3))
	# Tribunes + public
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for row in 3:
		box(r, Vector3(12, 0.4, 0.8), Vector3(0, 0.2 + row * 0.4, -9.5 - row * 0.8), Color(0.45, 0.55, 0.75))
		for i in 14:
			if rng.randf() < 0.75:
				var c := Color.from_hsv(rng.randf(), 0.5, 0.9)
				cyl(r, 0.15, 0.13, 0.35, Vector3(-5.5 + i * 0.85, 0.6 + row * 0.4, -9.5 - row * 0.8), c, 8)
				ball(r, 0.11, Vector3(-5.5 + i * 0.85, 0.88 + row * 0.4, -9.5 - row * 0.8), Color(0.95, 0.8, 0.65), Vector3.ONE, 8)
	# Guirlande de fanions
	for i in 16:
		var x := -6.0 + i * 0.8
		box(r, Vector3(0.3, 0.35, 0.02), Vector3(x, 2.6 - absf(sin(i * 0.4)) * 0.2, -8.2), Color.from_hsv(float(i % 5) / 5.0, 0.6, 0.95), Vector3(0, 0, PI / 4))
	# Podium
	for k in 3:
		var h: float = [0.5, 0.35, 0.25][k]
		var x: float = [0.0, -0.9, 0.9][k]
		box(r, Vector3(0.85, h, 0.8), Vector3(x + 6.0, h * 0.5, -6.0), [Color(1, 0.82, 0.3), Color(0.8, 0.82, 0.86), Color(0.85, 0.55, 0.35)][k])
	r.set_meta("bounds", Rect2(-3.5, -4.5, 7.0, 6.5))
	r.set_meta("ambient", Color(1.0, 0.96, 0.9))

static func _shelter(r: Node3D, q: int) -> void:
	var d := _density(q)
	ground(r, Vector2(30, 30), Color(0.6, 0.78, 0.45), noise_tex("grass3", Color(0.6, 0.8, 0.45), Color(0.48, 0.68, 0.36)), 6.0)
	box(r, Vector3(14, 0.02, 3.4), Vector3(0, 0.01, -0.6), Color(0.9, 0.85, 0.75), Vector3.ZERO, false)
	# Bâtiment du refuge
	box(r, Vector3(14, 3.2, 0.4), Vector3(0, 1.6, -4.5), Color(0.98, 0.9, 0.8))
	box(r, Vector3(14.6, 0.3, 2.4), Vector3(0, 3.35, -4.0), Color(0.45, 0.65, 0.55), Vector3(0.25, 0, 0))
	box(r, Vector3(4.2, 0.8, 0.1), Vector3(0, 2.5, -4.25), Color(0.98, 0.6, 0.4))
	var sign_l := Label3D.new()
	sign_l.text = "REFUGE DES PATTES DOUCES"
	sign_l.font_size = 64
	sign_l.pixel_size = 0.004
	sign_l.modulate = Color.WHITE
	sign_l.outline_size = 0
	sign_l.position = Vector3(0, 2.5, -4.18)
	r.add_child(sign_l)
	for i in 4:
		box(r, Vector3(0.8, 0.8, 0.06), Vector3(-5.0 + i * 3.3, 1.6, -4.27), Color(0.7, 0.88, 1.0))
	# Enclos individuels
	for i in 7:
		var x := -4.5 + i * 1.5
		box(r, Vector3(0.06, 0.8, 1.6), Vector3(x, 0.4, -2.9), Color(0.85, 0.85, 0.88))
	for i in 6:
		var x := -3.75 + i * 1.5
		cyl(r, 0.35, 0.35, 0.05, Vector3(x, 0.03, -3.2), Color(0.95, 0.85, 0.4), 12)
	bush(r, Vector3(-6.5, 0, -2.0), 0.9, Color(0.35, 0.62, 0.3))
	bush(r, Vector3(6.5, 0, -2.0), 0.9, Color(0.35, 0.62, 0.3))
	tree(r, Vector3(-8, 0, -6), 3.5, Color(0.35, 0.62, 0.3), 9)
	tree(r, Vector3(8, 0, -6), 3.2, Color(0.4, 0.68, 0.32), 10)
	var tuft := _cone_mesh(0.05, 0.0, 0.18)
	scatter(r, tuft, Color(0.45, 0.7, 0.35), int(300 * d), Rect2(-9, -3, 18, 9), 41, Vector2(0.7, 1.2), Rect2(-7, -2.5, 14, 3.5))
	r.set_meta("bounds", Rect2(-5.0, -3.0, 10.0, 4.0))

static func _cone_mesh(rb: float, rt: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = rb
	c.top_radius = rt
	c.height = h
	c.radial_segments = 4
	c.rings = 1
	return c

## Lumière + ciel adaptés à l'environnement et à la qualité graphique.
static func make_lighting(env_root: Node3D, quality: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Lighting"
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.95, 0.55, 0)
	sun.light_energy = 0.5
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = quality >= 1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 14.0
	sun.shadow_blur = 1.5
	n.add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky_c: Color = env_root.get_meta("sky", Color(0.62, 0.82, 0.96))
	if quality >= 1 and not env_root.get_meta("indoor", false):
		var sky := Sky.new()
		var psm := ProceduralSkyMaterial.new()
		psm.sky_top_color = sky_c.darkened(0.15)
		psm.sky_horizon_color = sky_c.lightened(0.35)
		psm.ground_horizon_color = sky_c.lightened(0.35)
		psm.ground_bottom_color = Color(0.5, 0.6, 0.45)
		psm.sun_angle_max = 20.0
		sky.sky_material = psm
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		sky.process_mode = Sky.PROCESS_MODE_QUALITY
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = sky_c.lightened(0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = env_root.get_meta("ambient", Color(1, 0.95, 0.9))
	env.ambient_light_energy = 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if quality >= 2:
		env.glow_enabled = true
		env.glow_intensity = 0.3
		env.glow_bloom = 0.05
	we.environment = env
	n.add_child(we)
	return n
