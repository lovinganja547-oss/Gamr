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

## Matière lumineuse (abat-jour, lanterne, étoiles).
static func _emit_mat(c: Color, energy: float) -> StandardMaterial3D:
	var sm := StandardMaterial3D.new()
	sm.albedo_color = c
	sm.emission_enabled = true
	sm.emission = c
	sm.emission_energy_multiplier = energy
	return sm

## Rectangle vertical tourné vers l'intérieur de la pièce (normale -Z), invisible de l'extérieur.
static func _inq(b: MeshBatch, key: String, x0: float, y0: float, x1: float, y1: float, z: float, c_lo: Color, c_hi: Color) -> void:
	b.quad(key, Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), Vector3(x0, y0, z), c_lo, c_hi, c_hi, c_lo, Vector3(-1, 0, 0))

static func _density(q: int) -> float:
	return [0.35, 0.7, 1.0][clampi(q, 0, 2)]

static func _house(r: Node3D, q: int) -> void:
	var deco: Dictionary = GameState.data.get("deco", {})
	var wall_c: Color = GameData.item(str(deco.get("wall", "wall_cream"))).get("color", Color(0.98, 0.93, 0.84))
	r.set_meta("bounds", Rect2(-2.3, -1.9, 4.6, 4.0))
	r.set_meta("indoor", true)
	r.set_meta("look", "indoor")
	var fl := ground(r, Vector2(7, 7), Color(1, 1, 1), tex("wood_planks"), 2.2)
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
	# Quatrième mur (côté joueur) : visible seulement de l'intérieur, pour ne jamais cacher la pièce.
	# Il apparaît quand on fait pivoter la caméra ; vu de l'extérieur, il est transparent.
	var zf := 3.5
	var wc := wall_c.lightened(0.15)
	_inq(b, "t:wallpaper:0.55", -2.9, 0.0, 2.9, 3.2, zf, wc, wc)
	var pan := Color(0.95, 0.93, 0.88)
	_inq(b, "flat", -2.9, 0.0, 2.9, 0.92, zf - 0.01, pan.darkened(0.1), pan)
	_inq(b, "flat", -2.9, 0.92, 2.9, 0.99, zf - 0.02, white, white)
	_inq(b, "flat", -2.9, 3.04, 2.9, 3.16, zf - 0.02, white, white)
	# porte d'entrée et tableau sur ce mur
	var dcol := Color(0.62, 0.42, 0.28)
	_inq(b, "flat", -1.75, 0.0, -0.65, 2.15, zf - 0.03, white, white)
	_inq(b, "t:wood_planks:0.5", -1.68, 0.0, -0.72, 2.08, zf - 0.04, dcol, dcol)
	_inq(b, "metal", -1.56, 1.0, -1.48, 1.08, zf - 0.05, Color(0.9, 0.75, 0.35), Color(0.9, 0.75, 0.35))
	var frc := Color(0.5, 0.36, 0.26)
	_inq(b, "flat", 0.7, 1.45, 1.9, 2.25, zf - 0.03, frc, frc)
	_inq(b, "flat", 0.78, 1.53, 1.82, 2.17, zf - 0.04, Color(0.66, 0.84, 0.95), Color(0.5, 0.74, 0.95))
	_inq(b, "flat", 0.78, 1.53, 1.82, 1.75, zf - 0.045, Color(0.42, 0.66, 0.36), Color(0.5, 0.72, 0.4))
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
	var d := MeshBatch.new()   # tout le mobilier fusionné (ombres portées)
	var wood := Color(0.80, 0.60, 0.42)
	var gold := Color(0.92, 0.76, 0.34)
	# Canapé : assise sculptée, pieds en bois, deux coussins et un plaid
	var sofa_c: Color = GameData.item(str(deco.get("sofa", "sofa_coral"))).get("color", Color(0.95, 0.55, 0.45))
	var sofa := Node3D.new()
	sofa.position = Vector3(-1.6, 0, -1.9)
	obs_rect(r, sofa.position, 2.15, 0.85)
	r.add_child(sofa)
	prop(sofa, "sofa", Vector3(0, 0.05, 0), sofa_c, 0.0, "fabric", 3.0)
	var sxf := Transform3D(Basis(), sofa.position)
	for fx in [-0.92, 0.92]:
		for fz in [-0.3, 0.3]:
			d.cyl("t:wood_planks:0.5", sxf, 0.045, 0.03, 0.09, Vector3(fx, 0, fz), wood.darkened(0.3), 6)
	for k in 2:
		var cu := prop(sofa, "cushion_bed", Vector3(-0.55 + k * 1.1, 0.5, -0.06), sofa_c.lightened(0.35) if k == 0 else Color(0.98, 0.9, 0.7), 0.0, "fabric", 4.0)
		cu.scale = Vector3(0.5, 0.75, 0.55)
		cu.rotation = Vector3(-0.9, 0.2 - k * 0.4, 0)
	# Couchage
	var bed_id := str(deco.get("bed", "bed_basic"))
	var bed_c: Color = GameData.item(bed_id).get("color", Color(0.7, 0.45, 0.3))
	var bed := Node3D.new()
	bed.position = Vector3(1.85, 0, -1.6)
	bed.name = "Bed"
	r.add_child(bed)
	var bxf := Transform3D(Basis(), bed.position)
	if bed_id == "bed_royal":
		# lit royal : cadre doré, matelas de velours, tête de lit et colonnes à boules
		d.box("t:wood_planks:0.5", bxf, Vector3(1.08, 0.2, 0.86), Vector3(0, 0.1, 0), gold, 0.2)
		d.box("flat", bxf, Vector3(1.12, 0.05, 0.9), Vector3(0, 0.2, 0), gold.lightened(0.15))
		var mat_r := prop(bed, "cushion_bed", Vector3(0, 0.2, 0), bed_c, 0.0, "fabric", 3.0)
		mat_r.scale = Vector3(1.05, 1.0, 0.95)
		d.box("t:fabric:1.5", bxf, Vector3(1.0, 0.62, 0.08), Vector3(0, 0.52, -0.42), bed_c.darkened(0.1))
		d.box("flat", bxf, Vector3(1.1, 0.07, 0.11), Vector3(0, 0.85, -0.42), gold)
		for px in [-0.52, 0.52]:
			for pz in [-0.42, 0.42]:
				d.cyl("flat", bxf, 0.04, 0.035, 0.75 if pz < 0 else 0.34, Vector3(px, 0, pz), gold, 8)
				ball(bed, 0.055, Vector3(px, (0.79 if pz < 0 else 0.38), pz), gold.lightened(0.1), Vector3.ONE, 10)
		for k in 3:
			d.cyl("flat", bxf, 0.05, 0.005, 0.11, Vector3(-0.12 + k * 0.12, 0.89, -0.42), gold, 4, 0.0, false)
	elif bed_id == "bed_cloud":
		prop(bed, "cushion_bed", Vector3.ZERO, bed_c, 0.0, "fabric", 3.0)
		var top := prop(bed, "cushion_bed", Vector3(0, 0.1, -0.12), Color(1, 1, 1), 0.0, "fabric", 3.0)
		top.scale = Vector3(0.62, 0.8, 0.5)
	else:
		prop(bed, "bed_basket", Vector3.ZERO, bed_c, 0.0, "wood_planks", 5.0)
		var cs2 := prop(bed, "cushion_bed", Vector3(0, 0.03, 0), Color(0.96, 0.92, 0.84), 0.0, "fabric", 3.0)
		cs2.scale = Vector3(0.82, 0.7, 0.82)
	interactive(bed, "bed", Vector3(0.9, 0.4, 0.8), Vector3(0, 0.2, 0))
	r.set_meta("bed", Vector3(1.85, 0, -1.55))
	# Plante en pot
	var plant := str(deco.get("plant", ""))
	if plant != "":
		var pc: Color = GameData.item(plant).get("color", Color.GREEN)
		var pp := Vector3(-2.55, 0, 0.9)
		var pxf := Transform3D(Basis(), pp)
		prop(r, "pot", pp, Color(0.88, 0.52, 0.36), 0.0, "plaster", 4.0)
		d.disc("t:dirt:1.5", pxf, 0.165, Vector3(0, 0.335, 0), Color(0.5, 0.4, 0.32), 12)
		obs_circle(r, pp, 0.3)
		match plant:
			"plant_cactus":
				d.cyl("flat", pxf, 0.1, 0.085, 0.55, Vector3(0, 0.33, 0), pc, 10, 0.15)
				d.cyl("flat", pxf, 0.085, 0.02, 0.1, Vector3(0, 0.88, 0), pc.lightened(0.06), 10, 0.0, false)
				for sdx in [-1.0, 1.0]:
					var af := pxf * Transform3D(Basis(Vector3(0, 0, 1), -sdx * 0.9), Vector3(sdx * 0.1, 0.55 + sdx * 0.06, 0))
					d.cyl("flat", af, 0.05, 0.045, 0.2, Vector3.ZERO, pc.darkened(0.05), 8)
					d.cyl("flat", pxf, 0.045, 0.02, 0.2, Vector3(sdx * 0.26, 0.66 + sdx * 0.06, 0), pc, 8, 0.0, false)
				d.cyl("flat", pxf, 0.04, 0.005, 0.05, Vector3(0, 0.97, 0), Color(1.0, 0.5, 0.7), 6, 0.0, false)
			"plant_flowers":
				var fpal: Array = [Color(0.95, 0.4, 0.5), Color(1, 0.85, 0.3), Color(0.7, 0.5, 0.95), Color(1, 1, 1)]
				for k in 9:
					var fa := k * 0.7
					var fr := 0.04 + (k % 3) * 0.045
					var fh := 0.36 + (k % 4) * 0.07
					d.cyl("flat", pxf, 0.009, 0.007, fh, Vector3(cos(fa) * fr, 0.33, sin(fa) * fr), Color(0.35, 0.6, 0.3), 5, 0.0, false)
					ball(r, 0.05, pp + Vector3(cos(fa) * fr, 0.34 + fh, sin(fa) * fr), fpal[k % 4], Vector3(1, 0.75, 1), 8)
					ball(r, 0.022, pp + Vector3(cos(fa) * fr, 0.365 + fh, sin(fa) * fr), Color(1.0, 0.8, 0.25), Vector3.ONE, 6)
				Kit.inst("bush", Kit.foliage_mat(), Transform3D(Basis().scaled(Vector3(0.22, 0.2, 0.22)), pp + Vector3(0, 0.3, 0)), Color(0.38, 0.62, 0.3), false)
			"plant_monstera":
				d.cyl("t:bark:1.5", pxf, 0.03, 0.022, 0.75, Vector3(0, 0.33, 0), Color(0.7, 0.58, 0.46), 6)
				for k in 4:
					var ma := k * 1.6
					Kit.inst("canopy_c", Kit.foliage_mat(), Transform3D(Basis(Vector3.UP, ma).scaled(Vector3(0.26, 0.16, 0.22)), pp + Vector3(cos(ma) * 0.17, 0.75 + k * 0.14, sin(ma) * 0.17)), pc.lightened(k * 0.04), false)
			_:
				for k in 3:
					Kit.inst("bush", Kit.foliage_mat(), Transform3D(Basis(Vector3.UP, k * 2.1).scaled(Vector3(0.36 - k * 0.05, 0.5 - k * 0.06, 0.36 - k * 0.05)), pp + Vector3(cos(k * 2.1) * 0.05, 0.3 + k * 0.1, sin(k * 2.1) * 0.05)), pc.lightened(k * 0.06), false)
	# Lampe sur pied
	var lamp := str(deco.get("lamp", ""))
	if lamp != "":
		var lc: Color = GameData.item(lamp).get("color", Color(1, 0.9, 0.6))
		var lp := Vector3(2.5, 0, 0.6)
		var lxf := Transform3D(Basis(), lp)
		d.cyl("metal", lxf, 0.19, 0.16, 0.035, Vector3.ZERO, Color(0.32, 0.3, 0.3), 14)
		d.cyl("metal", lxf, 0.022, 0.018, 1.42, Vector3(0, 0.035, 0), gold if lamp == "lamp_star" else Color(0.32, 0.3, 0.3), 8)
		obs_circle(r, lp, 0.22)
		if lamp == "lamp_paper":
			var lan := ball(r, 0.26, lp + Vector3(0, 1.58, 0), lc, Vector3(1, 1.1, 1), 16)
			lan.material_override = _emit_mat(lc, 0.75)
			for k in 4:
				d.cyl("flat", lxf, 0.262 - absf(k - 1.5) * 0.04, 0.262 - absf(k - 1.5) * 0.04, 0.008, Vector3(0, 1.4 + k * 0.12, 0), lc.darkened(0.25), 14, 0.0, false)
		else:
			var shade := cyl(r, 0.33, 0.19, 0.36, lp + Vector3(0, 1.56, 0), lc)
			shade.material_override = _emit_mat(lc, 0.6)
			d.cyl("flat", lxf, 0.335, 0.335, 0.02, Vector3(0, 1.37, 0), lc.darkened(0.3), 16, 0.0, false)
			d.cyl("flat", lxf, 0.195, 0.195, 0.02, Vector3(0, 1.73, 0), lc.darkened(0.3), 14, 0.0, false)
			if lamp == "lamp_star":
				for k in 5:
					var sa := TAU * k / 5.0
					var star := ball(r, 0.05, lp + Vector3(cos(sa) * 0.24, 1.2 + (k % 2) * 0.1, sin(sa) * 0.24), Color(1, 0.95, 0.5), Vector3.ONE, 8)
					star.material_override = _emit_mat(Color(1, 0.95, 0.5), 1.0)
					d.cyl("flat", lxf, 0.003, 0.003, 0.2 - (k % 2) * 0.1, Vector3(cos(sa) * 0.24, 1.2 + (k % 2) * 0.1, sin(sa) * 0.24), Color(0.9, 0.9, 0.85), 4, 0.0, false)
		if q >= 1:
			var ol := OmniLight3D.new()
			ol.position = Vector3(2.4, 1.4, 0.7)
			ol.light_color = lc
			ol.light_energy = 0.35
			ol.omni_range = 3.0
			r.add_child(ol)
	# Tableau encadré (mur du fond)
	var frame := str(deco.get("frame", ""))
	if frame != "":
		var fc: Color = GameData.item(frame).get("color", Color.ORANGE)
		var ff: Transform3D = faces[0][0]
		d.box("t:wood_planks:0.6", ff, Vector3(0.98, 0.78, 0.05), Vector3(-1.4, 1.95, 0.025), Color(0.62, 0.42, 0.26))
		d.box("flat", ff, Vector3(0.84, 0.64, 0.02), Vector3(-1.4, 1.95, 0.055), Color(0.97, 0.96, 0.92))
		match frame:
			"frame_sun":
				d.box("flat", ff, Vector3(0.76, 0.56, 0.01), Vector3(-1.4, 1.95, 0.068), Color(0.62, 0.84, 0.98))
				d.box("flat", ff, Vector3(0.76, 0.18, 0.012), Vector3(-1.4, 1.76, 0.07), Color(0.52, 0.76, 0.42))
				d.cyl("flat", ff * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-1.2, 2.07, 0.072)), 0.12, 0.12, 0.01, Vector3.ZERO, fc, 16)
			"frame_sea":
				d.box("flat", ff, Vector3(0.76, 0.56, 0.01), Vector3(-1.4, 1.95, 0.068), Color(0.72, 0.88, 0.98))
				d.box("flat", ff, Vector3(0.76, 0.26, 0.012), Vector3(-1.4, 1.8, 0.07), fc)
				d.box("flat", ff, Vector3(0.76, 0.05, 0.014), Vector3(-1.4, 1.69, 0.072), Color(0.95, 0.88, 0.66))
				d.tri("flat", ff * Vector3(-1.5, 1.89, 0.074), ff * Vector3(-1.5, 2.15, 0.074), ff * Vector3(-1.3, 1.89, 0.074), Color(1, 1, 1), Vector3.RIGHT)
			_:
				d.box("flat", ff, Vector3(0.76, 0.56, 0.01), Vector3(-1.4, 1.95, 0.068), fc.lightened(0.5))
				d.cyl("flat", ff * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-1.4, 1.9, 0.072)), 0.13, 0.13, 0.01, Vector3.ZERO, fc, 14)
				for k in 4:
					d.cyl("flat", ff * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-1.58 + k * 0.12, 2.07, 0.072)), 0.045, 0.045, 0.01, Vector3.ZERO, fc, 10)
	# Coffre à jouets
	if str(deco.get("box", "")) == "toybox":
		prop(r, "toybox", Vector3(-2.5, 0, -0.5), Color(0.62, 0.82, 1.0), 0.0, "plaster", 3.0)
		obs_rect(r, Vector3(-2.5, 0, -0.5), 0.75, 0.5)
		ball(r, 0.08, Vector3(-2.4, 0.6, -0.45), Color(0.9, 0.2, 0.2))
		ball(r, 0.065, Vector3(-2.62, 0.58, -0.52), Color(0.98, 0.8, 0.25))
		var txf := Transform3D(Basis(), Vector3(-2.5, 0, -0.5))
		d.box("flat", txf, Vector3(0.05, 0.16, 0.05), Vector3(0.18, 0.6, 0.08), Color(0.97, 0.95, 0.9))
		d.box("flat", txf, Vector3(0.13, 0.05, 0.05), Vector3(0.18, 0.69, 0.08), Color(0.97, 0.95, 0.9))
		d.box("flat", txf, Vector3(0.3, 0.03, 0.02), Vector3(0, 0.3, 0.255), gold)
	# Bibliothèque (mur de droite)
	var shelf := str(deco.get("shelf", ""))
	if shelf != "":
		var sc: Color = GameData.item(shelf).get("color", wood)
		var sf2: Transform3D = faces[2][0] * Transform3D(Basis(), Vector3(-2.2, 0, 0))
		var skey := "t:wood_planks:0.5" if shelf != "shelf_white" else "flat"
		d.box(skey, sf2, Vector3(1.1, 1.7, 0.04), Vector3(0, 0.85, 0.02), sc.darkened(0.12))
		for sx2 in [-0.53, 0.53]:
			d.box(skey, sf2, Vector3(0.04, 1.7, 0.3), Vector3(sx2, 0.85, 0.15), sc, 0.1)
		for k in 5:
			d.box(skey, sf2, Vector3(1.1, 0.04, 0.3), Vector3(0, 0.02 + k * 0.415, 0.15), sc)
		var rngb := RandomNumberGenerator.new()
		rngb.seed = 12
		for row in 4:
			var x := -0.48
			while x < 0.42:
				var bw := rngb.randf_range(0.045, 0.08)
				var bh := rngb.randf_range(0.24, 0.34)
				if row == 1 and x > 0.1:
					break
				d.box("flat", sf2, Vector3(bw, bh, 0.2), Vector3(x + bw * 0.5, 0.04 + row * 0.415 + bh * 0.5, 0.14), Color.from_hsv(rngb.randf(), 0.42, 0.86))
				x += bw + 0.006
		d.cyl("metal", sf2, 0.05, 0.07, 0.04, Vector3(0.3, 0.455, 0.15), gold, 8)
		d.cyl("metal", sf2, 0.02, 0.02, 0.1, Vector3(0.3, 0.495, 0.15), gold, 6)
		d.cyl("metal", sf2, 0.045, 0.075, 0.12, Vector3(0.3, 0.59, 0.15), gold, 10)
		var so: Vector3 = sf2 * Vector3(0, 0, 0.15)
		obs_rect(r, so, 0.42, 1.2)
	# Table d'appoint (coin avant gauche) : vase de fleurs ou aquarium
	var table := str(deco.get("table", ""))
	if table != "":
		var tp := Vector3(-2.45, 0, 2.5)
		var tx2 := Transform3D(Basis(), tp)
		d.cyl("t:wood_planks:0.5", tx2, 0.36, 0.36, 0.045, Vector3(0, 0.56, 0), wood, 18)
		d.cyl("t:wood_planks:0.5", tx2, 0.05, 0.04, 0.56, Vector3.ZERO, wood.darkened(0.15), 8)
		d.cyl("t:wood_planks:0.5", tx2, 0.22, 0.2, 0.03, Vector3.ZERO, wood.darkened(0.15), 12)
		obs_circle(r, tp, 0.42)
		if table == "table_aquarium":
			var aq := box(r, Vector3(0.5, 0.34, 0.34), tp + Vector3(0, 0.79, 0), Color(0.5, 0.8, 0.95), Vector3.ZERO, false)
			var am := StandardMaterial3D.new()
			am.albedo_color = Color(0.45, 0.78, 0.95, 0.55)
			am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			am.roughness = 0.05
			am.metallic_specular = 0.8
			aq.material_override = am
			d.box("flat", tx2, Vector3(0.54, 0.03, 0.38), Vector3(0, 0.62, 0), Color(0.25, 0.27, 0.3))
			d.box("flat", tx2, Vector3(0.54, 0.03, 0.38), Vector3(0, 0.975, 0), Color(0.25, 0.27, 0.3))
			d.box("t:sand:2.0", tx2, Vector3(0.48, 0.03, 0.32), Vector3(0, 0.65, 0), Color(1, 0.95, 0.85))
			for k in 3:
				var fp2 := Vector3(-0.14 + k * 0.14, 0.76 + (k % 2) * 0.09, -0.04 + (k % 2) * 0.08)
				d.box("flat", tx2, Vector3(0.07, 0.04, 0.02), fp2, [Color(1.0, 0.55, 0.2), Color(1.0, 0.85, 0.3), Color(0.95, 0.4, 0.5)][k])
				d.tri("flat", tx2 * (fp2 + Vector3(-0.035, 0, 0)), tx2 * (fp2 + Vector3(-0.075, 0.03, 0)), tx2 * (fp2 + Vector3(-0.075, -0.03, 0)), Color(1.0, 0.7, 0.3), Vector3.RIGHT)
			d.cyl("flat", tx2, 0.012, 0.004, 0.16, Vector3(0.17, 0.66, 0.05), Color(0.35, 0.65, 0.35), 5, 0.0, false)
		else:
			d.cyl("t:plaster:2.0", tx2, 0.07, 0.1, 0.22, Vector3(0, 0.605, 0), Color(0.62, 0.8, 0.9), 12)
			var vpal: Array = [Color(1.0, 0.6, 0.7), Color(1, 1, 1), Color(1.0, 0.85, 0.35)]
			for k in 6:
				var va := k * 1.05
				d.cyl("flat", tx2, 0.006, 0.005, 0.22, Vector3(cos(va) * 0.04, 0.82, sin(va) * 0.04), Color(0.35, 0.6, 0.3), 5, 0.0, false)
				ball(r, 0.045, tp + Vector3(cos(va) * 0.07, 1.06 + (k % 2) * 0.05, sin(va) * 0.07), vpal[k % 3], Vector3(1, 0.8, 1), 8)
	# Pouf
	var pouf := str(deco.get("pouf", ""))
	if pouf != "":
		var pfc: Color = GameData.item(pouf).get("color", Color(0.95, 0.6, 0.7))
		var pfp := Vector3(2.0, 0, 2.3)
		var pm2 := prop(r, "cushion_bed", pfp, pfc, 0.0, "fabric", 3.0)
		pm2.scale = Vector3(0.78, 1.9, 0.86)
		ball(r, 0.04, pfp + Vector3(0, 0.36, 0), pfc.darkened(0.2), Vector3(1, 0.5, 1), 8)
		obs_circle(r, pfp, 0.36)
	# Horloge murale
	var clock := str(deco.get("clock", ""))
	if clock != "":
		var ckc: Color = GameData.item(clock).get("color", wood)
		var cf: Transform3D = faces[0][0] * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(2.25, 2.3, 0.03))
		d.cyl("t:wood_planks:0.6" if clock == "clock_wood" else "flat", cf, 0.3, 0.3, 0.05, Vector3.ZERO, ckc, 20)
		d.cyl("flat", cf, 0.25, 0.25, 0.012, Vector3(0, 0.05, 0), Color(0.99, 0.98, 0.94), 20)
		for k in 12:
			var ha := TAU * k / 12.0
			d.box("flat", cf, Vector3(0.018, 0.006, 0.04 if k % 3 == 0 else 0.022), Vector3(sin(ha) * 0.21, 0.064, cos(ha) * 0.21), Color(0.3, 0.24, 0.2))
		d.box("flat", cf * Transform3D(Basis(Vector3.UP, 0.9), Vector3(0, 0.07, 0)), Vector3(0.022, 0.008, 0.15), Vector3(0, 0, -0.06), Color(0.25, 0.2, 0.18))
		d.box("flat", cf * Transform3D(Basis(Vector3.UP, -1.2), Vector3(0, 0.075, 0)), Vector3(0.016, 0.008, 0.21), Vector3(0, 0, -0.09), Color(0.25, 0.2, 0.18))
		d.cyl("flat", cf, 0.022, 0.022, 0.02, Vector3(0, 0.065, 0), gold, 8)
	# Étagère à trophées
	var trophies: Array = GameState.data.get("trophies", [])
	var tf: Transform3D = faces[0][0]
	# sous le tableau, à gauche de la fenêtre (jamais devant la vitre ni les rideaux)
	d.box("t:wood_planks:0.5", tf, Vector3(1.2, 0.05, 0.26), Vector3(-1.4, 1.2, 0.13), Color(0.66, 0.46, 0.3))
	for sx3 in [-1.9, -0.9]:
		d.box("t:wood_planks:0.5", tf, Vector3(0.04, 0.16, 0.2), Vector3(sx3, 1.1, 0.1), Color(0.6, 0.42, 0.28))
	for i in mini(trophies.size(), 6):
		var t: Dictionary = trophies[trophies.size() - 1 - i]
		var tc: Color = [Color(1, 0.82, 0.25), Color(0.8, 0.82, 0.86), Color(0.8, 0.5, 0.3)][clampi(int(t.get("place", 3)) - 1, 0, 2)]
		var tx3 := -1.85 + i * 0.18
		d.cyl("flat", tf, 0.045, 0.055, 0.04, Vector3(tx3, 1.225, 0.13), Color(0.3, 0.25, 0.2), 8)
		d.cyl("metal", tf, 0.012, 0.012, 0.07, Vector3(tx3, 1.265, 0.13), tc, 6)
		d.cyl("metal", tf, 0.03, 0.06, 0.1, Vector3(tx3, 1.335, 0.13), tc, 10)
	d.commit(r, q >= 1, "Furniture")
	# volumes que la caméra contourne (sans gêner la marche de l'animal)
	var cam_only: Array = [{"c": Vector2(-2.2, -1.9), "r": 0.75}, {"c": Vector2(-1.0, -1.9), "r": 0.75}, {"c": Vector2(1.85, -1.6), "r": 0.7}]
	if shelf != "":
		cam_only.append({"c": Vector2(2.6, 2.2), "r": 0.7})
	if table != "":
		cam_only.append({"c": Vector2(-2.45, 2.5), "r": 0.6})
	r.set_meta("cam_obstacles", cam_only)
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
