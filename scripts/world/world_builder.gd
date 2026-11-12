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

static var _prop_mats := {}
static var cur_quality := 1

## Texture du jeu (assets/textures/<nom>.png).
static func tex(name: String) -> Texture2D:
	var path := "res://assets/textures/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null

## Matériau teinté avec texture en projection triplanaire (pas besoin d'UV).
static func tex_mat(c: Color, tex_name: String, scale: float = 1.0, use_vertex_ao: bool = false) -> StandardMaterial3D:
	var key := "%s_%s_%.2f_%s" % [c.to_html(), tex_name, scale, use_vertex_ao]
	if _prop_mats.has(key):
		return _prop_mats[key]
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	mt.roughness = 0.88
	mt.metallic_specular = 0.12
	mt.vertex_color_use_as_albedo = use_vertex_ao
	if tex_name != "":
		mt.albedo_texture = tex(tex_name)
		mt.uv1_triplanar = true
		mt.uv1_scale = Vector3.ONE * scale
		mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_prop_mats[key] = mt
	return mt

## Meuble arrondi sculpté (assets/models/props), teinté par le matériau.
static func prop(parent: Node3D, name: String, pos: Vector3, c: Color, rot_y: float = 0.0, tex_name: String = "", tex_scale: float = 2.0) -> MeshInstance3D:
	var q := "hi" if cur_quality >= 2 else "lo"
	var mi := MeshInstance3D.new()
	mi.mesh = load("res://assets/models/props/%s_%s.res" % [name, q])
	mi.material_override = tex_mat(c, tex_name, tex_scale, true)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

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
## cam = false : bloque la marche mais pas la caméra (eau, rivière).
static func obs_circle(root: Node, pos: Vector3, radius: float, cam: bool = true) -> void:
	if root.has_meta("obstacles"):
		(root.get_meta("obstacles") as Array).append({"c": Vector2(pos.x, pos.z), "r": radius, "cam": cam})

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
	prop(n, "bench", Vector3.ZERO, Color(0.78, 0.55, 0.36), 0.0, "wood_planks", 1.5)
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
	prop(n, "bowl", Vector3.ZERO, c)
	var fill := cyl(n, 0.145, 0.145, 0.01, Vector3(0, 0.075, 0), Color(0.6, 0.38, 0.2) if kind == "food" else Color(0.45, 0.7, 0.95), 18)
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
	cur_quality = quality
	Kit.q = quality
	Kit._pending.clear()
	var root := Node3D.new()
	root.name = "Env_" + env_id
	root.set_meta("bounds", Rect2(-2.5, -2.0, 5.0, 4.5))
	root.set_meta("obstacles", [])
	root.set_meta("sky", Color(0.62, 0.82, 0.96))
	root.set_meta("ambient", Color(1.0, 0.95, 0.9))
	match env_id:
		"house": _house(root, quality)
		"garden": _garden(root, quality)
		"park": Places.park(root, quality)
		"beach": Places.beach(root, quality)
		"forest": Places.forest(root, quality)
		"center": Places.center(root, quality)
		"shelter": Places.shelter(root, quality)
		"field": Places.field(root, quality)
		"town": Places.town(root, quality)
	Kit.flush(root)
	return root

static func _density(q: int) -> float:
	return [0.35, 0.7, 1.0][clampi(q, 0, 2)]

static func _house(r: Node3D, q: int) -> void:
	var deco: Dictionary = GameState.data.get("deco", {})
	var wall_c: Color = GameData.item(str(deco.get("wall", "wall_cream"))).get("color", Color(0.98, 0.93, 0.84))
	r.set_meta("bounds", Rect2(-2.3, -1.9, 4.6, 4.0))
	r.set_meta("indoor", true)
	r.set_meta("look", "indoor")
	var fl := ground(r, Vector2(7, 7), Color(1, 1, 1), tex("wood_planks"), 1.7)
	var fm := fl.material_override as StandardMaterial3D
	fm.roughness = 0.55
	fm.metallic_specular = 0.35
	if q >= 1 and tex("wood_planks_n"):
		fm.normal_enabled = true
		fm.normal_texture = tex("wood_planks_n")
		fm.normal_scale = 0.6
	var b := MeshBatch.new()
	var id3 := Transform3D()
	var white := Color(0.98, 0.97, 0.94)
	# Murs : papier peint, soubassement en lambris clair, cimaise, plinthe et corniche
	var faces := [
		[Transform3D(Basis(), Vector3(0, 0, -2.5)), 7.0, wall_c],
		[Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-2.9, 0, 0)), 7.0, wall_c.darkened(0.05)],
		[Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(2.9, 0, 0)), 7.0, wall_c.darkened(0.05)],
	]
	for f in faces:
		var ft: Transform3D = f[0]
		var fw: float = f[1]
		var fc: Color = f[2]
		b.box("t:wallpaper:0.55", ft, Vector3(fw, 3.2, 0.2), Vector3(0, 1.6, -0.1), fc, 0.0, false)
		b.box("flat", ft, Vector3(fw, 0.92, 0.04), Vector3(0, 0.46, 0.02), Color(0.95, 0.93, 0.88), 0.1)
		b.box("flat", ft, Vector3(fw, 0.07, 0.07), Vector3(0, 0.95, 0.035), white)
		b.box("flat", ft, Vector3(fw, 0.14, 0.06), Vector3(0, 0.07, 0.05), white)
		b.box("flat", ft, Vector3(fw, 0.12, 0.08), Vector3(0, 3.1, 0.04), white)
		var np := int(fw / 0.9)
		for k in np:
			b.box("flat", ft, Vector3(0.03, 0.74, 0.02), Vector3(-fw * 0.5 + (k + 0.5) * fw / np, 0.5, 0.045), white.darkened(0.06))
	# Fenêtres lumineuses avec rideaux
	var curtain_c: Color = GameData.item(str(deco.get("sofa", "sofa_coral"))).get("color", Color(0.95, 0.55, 0.45)).lightened(0.25)
	for wdef in [[faces[0][0], 0.9, 1.5, 1.15], [faces[1][0], -0.6, 1.2, 1.15]]:
		var wf: Transform3D = wdef[0]
		var wx: float = wdef[1]
		var ww: float = wdef[2]
		var wh: float = wdef[3]
		var wy := 1.85
		b.box("flat", wf, Vector3(ww + 0.18, wh + 0.18, 0.08), Vector3(wx, wy, 0.03), white)
		b.box("emit", wf, Vector3(ww, wh, 0.03), Vector3(wx, wy, 0.06), Color(0.72, 0.88, 1.0))
		b.box("flat", wf, Vector3(0.05, wh, 0.03), Vector3(wx, wy, 0.08), white)
		b.box("flat", wf, Vector3(ww, 0.05, 0.03), Vector3(wx, wy + wh * 0.12, 0.08), white)
		b.box("flat", wf, Vector3(ww + 0.36, 0.06, 0.2), Vector3(wx, wy - wh * 0.5 - 0.1, 0.1), white)
		b.box("metal", wf, Vector3(ww + 0.9, 0.035, 0.035), Vector3(wx, wy + wh * 0.5 + 0.2, 0.12), Color(0.55, 0.42, 0.3))
		for sd in [-1.0, 1.0]:
			for fold in 3:
				b.box("t:fabric:1.4", wf, Vector3(0.13, wh + 0.5, 0.05 + fold * 0.012), Vector3(wx + sd * (ww * 0.5 + 0.1 + fold * 0.12), wy - 0.06, 0.11), curtain_c.darkened(fold * 0.05))
	# Étagère à livres
	var sf: Transform3D = faces[2][0]
	b.box("t:wood_planks:0.5", sf, Vector3(1.3, 0.05, 0.24), Vector3(0.8, 1.7, 0.12), Color(0.82, 0.62, 0.44))
	for k in 8:
		var bh := 0.2 + (k % 3) * 0.04
		b.box("flat", sf, Vector3(0.07, bh, 0.16), Vector3(0.3 + k * 0.085, 1.725 + bh * 0.5, 0.12), Color.from_hsv(fposmod(k * 0.17, 1.0), 0.45, 0.85))
	b.commit(r, false, "Walls")
	# Tapis à motifs
	var rug_c: Color = GameData.item(str(deco.get("rug", "rug_round"))).get("color", Color(0.85, 0.55, 0.45))
	var rug := MeshInstance3D.new()
	var rq := PlaneMesh.new()
	rq.size = Vector2(2.6, 2.6)
	rug.mesh = rq
	var rm := StandardMaterial3D.new()
	rm.albedo_texture = tex("rug")
	rm.albedo_color = rug_c.lightened(0.12)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.roughness = 1.0
	rm.metallic_specular = 0.0
	rm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rug.material_override = rm
	rug.position = Vector3(0, 0.012, 0.2)
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(rug)
	# Canapé
	var sofa_c: Color = GameData.item(str(deco.get("sofa", "sofa_coral"))).get("color", Color(0.95, 0.55, 0.45))
	var sofa := Node3D.new()
	sofa.position = Vector3(-1.6, 0, -1.9)
	obs_rect(r, sofa.position, 2.15, 0.85)
	r.add_child(sofa)
	prop(sofa, "sofa", Vector3.ZERO, sofa_c, 0.0, "fabric", 3.0)
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
		prop(bed, "cushion_bed", Vector3.ZERO, bed_c, 0.0, "fabric", 3.0)
	else:
		prop(bed, "bed_basket", Vector3.ZERO, bed_c, 0.0, "fabric", 3.0)
		ball(bed, 0.34, Vector3(0, 0.07, 0), Color(0.96, 0.92, 0.84), Vector3(1, 0.18, 1), 14)
	interactive(bed, "bed", Vector3(0.9, 0.4, 0.8), Vector3(0, 0.2, 0))
	r.set_meta("bed", Vector3(1.85, 0, -1.55))
	# Plante, lampe, tableau, coffre
	var plant := str(deco.get("plant", ""))
	if plant != "":
		var pc: Color = GameData.item(plant).get("color", Color.GREEN)
		prop(r, "pot", Vector3(-2.55, 0, 0.9), Color(0.88, 0.52, 0.36))
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
		prop(r, "toybox", Vector3(-2.5, 0, -0.5), Color(0.55, 0.75, 0.95), 0.0, "wood_planks", 2.0)
		obs_rect(r, Vector3(-2.5, 0, -0.5), 0.75, 0.5)
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
	r.set_meta("look", "morning")
	var gp := Kit.ground(r, 110.0, {"rect": Rect2(-16, -16, 32, 32), "r": "pavers", "g": "dirt", "uv_r": 0.55, "tint_r": Color(0.95, 0.92, 0.88)})
	var b := MeshBatch.new()
	# Maison familiale au fond, allée dallée jusqu'au portillon
	Kit.house(b, r, Vector3(0, 0, -7.6), 0.0, {"w": 7.2, "d": 4.2, "floors": 2, "timber": true, "wall_c": Color(0.98, 0.94, 0.84),
		"roof_c": Color(0.80, 0.42, 0.34), "shutter_c": Color(0.33, 0.52, 0.58), "win": 4, "door_x": 0.0})
	gp.path(Vector2(0, -5.3), Vector2(0, -3.9), 1.3, 0)
	gp.path(Vector2(0, -3.9), Vector2(0.3, 3.6), 1.1, 0)
	gp.disc(Vector2(0, -4.6), 1.5, 0)
	# Clôture blanche et portillon ouvert
	var fc := Color(0.98, 0.97, 0.94)
	Kit.fence(b, Vector3(-5.2, 0, -3.9), Vector3(-0.9, 0, -3.9), "picket", fc)
	Kit.fence(b, Vector3(0.9, 0, -3.9), Vector3(5.2, 0, -3.9), "picket", fc)
	Kit.fence(b, Vector3(-5.2, 0, 3.6), Vector3(-5.2, 0, -3.9), "picket", fc)
	Kit.fence(b, Vector3(5.2, 0, -3.9), Vector3(5.2, 0, 3.6), "picket", fc)
	obs_rect(r, Vector3(-3.05, 0, -3.9), 4.3, 0.12)
	obs_rect(r, Vector3(3.05, 0, -3.9), 4.3, 0.12)
	obs_rect(r, Vector3(-5.2, 0, 0), 0.12, 7.5)
	obs_rect(r, Vector3(5.2, 0, 0), 0.12, 7.5)
	# Niche
	var k := Node3D.new()
	k.position = Vector3(2.9, 0, -2.5)
	obs_circle(r, k.position, 0.62)
	k.rotation.y = -0.4
	r.add_child(k)
	prop(k, "kennel", Vector3.ZERO, Color(0.86, 0.58, 0.38), 0.0, "wood_planks", 2.5)
	prop(k, "kennel_roof", Vector3.ZERO, Color(0.85, 0.34, 0.3), 0.0, "roof_tiles", 2.2)
	box(k, Vector3(0.36, 0.48, 0.04), Vector3(0, 0.25, 0.43), Color(0.22, 0.16, 0.13), Vector3.ZERO, false)
	interactive(k, "bed", Vector3(1, 1, 1), Vector3(0, 0.5, 0))
	gp.shade(Vector2(2.9, -2.5), 1.3, 0.6)
	gp.soft(Vector2(2.75, -1.8), 0.9, 1, 0.9)
	r.set_meta("bed", Vector3(2.6, 0, -1.7))
	# Potager surélevé
	var pxf := Transform3D(Basis(), Vector3(-2.9, 0, -2.8))
	for sx in [-0.86, 0.86]:
		b.box("t:wood_planks:1.2", pxf, Vector3(0.08, 0.32, 1.0), Vector3(sx, 0.16, 0), Color(0.68, 0.5, 0.34), 0.2)
	for sz in [-0.5, 0.5]:
		b.box("t:wood_planks:1.2", pxf, Vector3(1.8, 0.32, 0.08), Vector3(0, 0.16, sz), Color(0.68, 0.5, 0.34), 0.2)
	b.box("t:dirt:0.8", pxf, Vector3(1.66, 0.24, 0.9), Vector3(0, 0.13, 0), Color(0.62, 0.5, 0.42))
	for i in 10:
		var vx := -0.66 + (i % 5) * 0.33
		var vz := -0.22 + (i / 5) * 0.44
		b.cyl("flat", pxf, 0.11, 0.02, 0.2, Vector3(vx, 0.25, vz), Color(0.34, 0.62, 0.28), 6, 0.0, false)
		if i % 2 == 0:
			b.box("flat", pxf, Vector3(0.09, 0.09, 0.09), Vector3(vx + 0.04, 0.33, vz), Color(0.92, 0.3, 0.25) if i % 4 == 0 else Color(0.98, 0.62, 0.2))
	obs_rect(r, Vector3(-2.9, 0, -2.8), 1.85, 1.05)
	gp.shade(Vector2(-2.9, -2.8), 1.6, 0.5)
	# Arbres, haies et massifs
	Kit.tree(r, Vector3(-4.0, 0, -5.4), 4.6, "a", Color(0.36, 0.62, 0.27), 3)
	Kit.tree(r, Vector3(4.6, 0, -5.9), 5.2, "b", Color(0.40, 0.64, 0.28), 5)
	Kit.tree(r, Vector3(-7.5, 0, 0.5), 5.0, "c", Color(0.34, 0.58, 0.26), 7, false)
	Kit.tree(r, Vector3(8.0, 0, -1.5), 5.6, "a", Color(0.38, 0.6, 0.27), 8, false)
	Kit.bush(r, Vector3(-4.4, 0, -3.0), 0.75, Color(0.33, 0.58, 0.28))
	Kit.bush(r, Vector3(4.5, 0, 1.4), 0.7, Color(0.36, 0.6, 0.3))
	Kit.bush(r, Vector3(-4.5, 0, 2.2), 0.65, Color(0.40, 0.62, 0.30))
	Kit.hedge(r, Vector3(-9.0, 0, -4.4), Vector3(-5.6, 0, -4.4), 1.1)
	Kit.hedge(r, Vector3(5.6, 0, -4.4), Vector3(9.0, 0, -4.4), 1.1)
	Kit.rock(r, Vector3(4.3, 0, -3.2), 0.45, "a")
	Kit.rock(r, Vector3(-1.6, 0, -3.3), 0.3, "b", false)
	# Maisons voisines (profondeur du décor)
	Kit.house(b, r, Vector3(-13.5, 0, -8.5), 0.5, {"w": 5.0, "d": 3.8, "floors": 1, "wall_c": Color(0.95, 0.86, 0.74), "roof_c": Color(0.52, 0.42, 0.40)})
	Kit.house(b, r, Vector3(13.0, 0, -9.5), -0.4, {"w": 5.4, "d": 4.0, "floors": 2, "wall": "t:brick:0.7", "wall_c": Color(1, 0.95, 0.9), "roof_c": Color(0.42, 0.44, 0.50), "shutter_c": Color(0.9, 0.88, 0.82)})
	Kit.lamp(b, r, Vector3(1.5, 0, -4.4))
	b.commit(r)
	var keep := func(p: Vector2) -> bool: return not Rect2(-2.6, -1.6, 5.2, 3.6).has_point(p)
	Kit.grass(r, Rect2(-12, -11, 24, 16), 1700, 11, keep)
	Kit.flowers(r, Rect2(-5.0, -3.7, 10.0, 1.3), 90, 12)
	Kit.flowers(r, Rect2(-11, -10, 22, 14), 160, 13, keep)
	Kit.backdrop(r, {"radius": 34.0, "near": Color(0.38, 0.60, 0.32), "far": Color(0.60, 0.76, 0.70)})
	Kit.ambient(r, "pollen", Rect2(-6, -5, 12, 9))
	r.set_meta("bounds", Rect2(-3.8, -2.8, 7.6, 5.0))
	r.set_meta("walk_area", Rect2(-4.2, -3.2, 8.4, 6.0))
	r.set_meta("spots_area", Rect2(-3.5, -2.8, 7.0, 4.5))

## Distance (m) d'un point à la rue la plus proche du quartier.
static func _road_dist(q: Vector2) -> float:
	var best := INF
	for e in GameData.WALK_EDGES:
		var a: Vector2 = GameData.WALK_NODES[e[0]]["pos"]
		var b: Vector2 = GameData.WALK_NODES[e[1]]["pos"]
		var ab := b - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, q.distance_to(a + ab * t))
	return best

## Décalage autour d'un lieu qui laisse les rues dégagées (essaie 8 directions).
static func _free_offset(base: Vector3, off: Vector3, clearance: float) -> Vector3:
	var o := off
	for i in 8:
		var p := base + o
		if _road_dist(Vector2(p.x, p.z)) >= clearance:
			return o
		o = o.rotated(Vector3.UP, TAU / 8.0)
	return off

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
	return Kit.lighting(env_root, quality)
