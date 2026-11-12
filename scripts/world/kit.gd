class_name Kit
extends RefCounted
## Kit de décor : matières partagées, sols peints, eau, végétation instanciée, bâtiments détaillés,
## collines lointaines et ambiances lumineuses. Tout est généré par le jeu (aucune ressource externe).

static var q := 1                       # qualité graphique courante (0 faible, 1 moyen, 2 élevé)
static var _mats := {}
static var _meshes := {}
static var _pending := {}               # (maillage|matière) -> {mesh, mat, xf: [], col: [], shadow}

# ================================================================== Ambiances lumineuses
## sun_rot : (inclinaison, azimut) en radians. Les énergies restent modérées : en rendu Compatibilité
## les lumières s'additionnent sans compression, des valeurs fortes brûlent les couleurs claires.
const LOOKS := {
	"morning": {"top": Color(0.25, 0.52, 0.90), "hor": Color(0.78, 0.90, 0.99), "ground": Color(0.50, 0.62, 0.42),
		"sun": Color(1.0, 0.95, 0.84), "sun_e": 0.60, "amb": Color(0.80, 0.88, 1.0), "amb_e": 0.36,
		"rot": Vector2(-0.82, 0.62), "cover": 0.40, "fog": Color(0.80, 0.90, 0.98), "cloud_shade": Color(0.74, 0.80, 0.90)},
	"noon": {"top": Color(0.20, 0.47, 0.88), "hor": Color(0.72, 0.87, 0.98), "ground": Color(0.50, 0.62, 0.42),
		"sun": Color(1.0, 0.97, 0.90), "sun_e": 0.62, "amb": Color(0.82, 0.90, 1.0), "amb_e": 0.36,
		"rot": Vector2(-1.0, 0.45), "cover": 0.36, "fog": Color(0.76, 0.88, 0.98), "cloud_shade": Color(0.72, 0.79, 0.90)},
	"afternoon": {"top": Color(0.24, 0.48, 0.86), "hor": Color(0.86, 0.90, 0.94), "ground": Color(0.52, 0.60, 0.42),
		"sun": Color(1.0, 0.92, 0.76), "sun_e": 0.62, "amb": Color(0.86, 0.88, 0.98), "amb_e": 0.35,
		"rot": Vector2(-0.72, -0.75), "cover": 0.44, "fog": Color(0.86, 0.90, 0.95), "cloud_shade": Color(0.78, 0.78, 0.88)},
	"golden": {"top": Color(0.30, 0.47, 0.82), "hor": Color(1.0, 0.84, 0.66), "ground": Color(0.70, 0.62, 0.48),
		"sun": Color(1.0, 0.90, 0.74), "sun_e": 0.56, "amb": Color(0.92, 0.90, 0.94), "amb_e": 0.36,
		"rot": Vector2(-0.50, 0.95), "cover": 0.46, "fog": Color(0.98, 0.86, 0.74), "cloud_shade": Color(0.88, 0.70, 0.70),
		"cloud": Color(1.0, 0.94, 0.86)},
	"forest": {"top": Color(0.28, 0.52, 0.80), "hor": Color(0.80, 0.92, 0.90), "ground": Color(0.38, 0.50, 0.34),
		"sun": Color(1.0, 0.95, 0.78), "sun_e": 0.56, "amb": Color(0.76, 0.92, 0.82), "amb_e": 0.36,
		"rot": Vector2(-0.90, 0.5), "cover": 0.50, "fog": Color(0.74, 0.88, 0.82), "cloud_shade": Color(0.72, 0.80, 0.86)},
	"indoor": {"top": Color(0.30, 0.55, 0.90), "hor": Color(0.82, 0.90, 0.98), "ground": Color(0.5, 0.6, 0.42),
		"sun": Color(1.0, 0.93, 0.80), "sun_e": 0.40, "amb": Color(1.0, 0.92, 0.84), "amb_e": 0.32,
		"rot": Vector2(-0.95, 0.55), "cover": 0.40, "fog": Color(0.8, 0.9, 0.98), "cloud_shade": Color(0.74, 0.8, 0.9)},
}

static func tex(name: String) -> Texture2D:
	var path := "res://assets/textures/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null

static func shader(name: String) -> Shader:
	return load("res://assets/shaders/%s.gdshader" % name)

# ================================================================== Matières
## Matière d'une surface fusionnée (voir MeshBatch) : teinte par sommet, texture répétée en mètres.
static func batch_material(key: String) -> Material:
	var ck := "b|%s|%d" % [key, q]
	if _mats.has(ck):
		return _mats[ck]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.88
	m.metallic_specular = 0.1
	var parts := key.split(":")
	match parts[0]:
		"t":
			m.albedo_texture = tex(parts[1])
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if q >= 2 else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			var nt := tex(parts[1] + "_n") if q >= 1 else null
			if nt:
				m.normal_enabled = true
				m.normal_texture = nt
				m.normal_scale = 0.9
		"glass":
			m.roughness = 0.08
			m.metallic_specular = 0.9
			m.metallic = 0.25
		"emit":
			m.emission_enabled = true
			m.emission = Color(1.0, 0.86, 0.6)
			m.emission_energy_multiplier = 0.7
		"metal":
			m.roughness = 0.35
			m.metallic = 0.6
			m.metallic_specular = 0.6
	_mats[ck] = m
	return m

## Matière texturée pour un maillage sculpté (projection sur trois axes, occlusion par sommet).
static func sculpt_mat(tex_name: String, scale: float = 1.0) -> StandardMaterial3D:
	var ck := "s|%s|%.2f|%d" % [tex_name, scale, q]
	if _mats.has(ck):
		return _mats[ck]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.metallic_specular = 0.08
	if tex_name != "":
		m.albedo_texture = tex(tex_name)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var nt := tex(tex_name + "_n") if q >= 2 else null
		if nt:
			m.normal_enabled = true
			m.normal_texture = nt
	_mats[ck] = m
	return m

static func foliage_mat() -> ShaderMaterial:
	if not _mats.has("foliage"):
		var m := ShaderMaterial.new()
		m.shader = shader("foliage")
		m.set_shader_parameter("tex", tex("leaves"))
		_mats["foliage"] = m
	return _mats["foliage"]

static func card_mat(tex_name: String, atlas: int, wind: float) -> ShaderMaterial:
	var ck := "card|%s" % tex_name
	if not _mats.has(ck):
		var m := ShaderMaterial.new()
		m.shader = shader("grass_card")
		m.set_shader_parameter("tex", tex(tex_name))
		m.set_shader_parameter("atlas", float(atlas))
		m.set_shader_parameter("wind", wind)
		_mats[ck] = m
	return _mats[ck]

static func prop_mesh(name: String) -> Mesh:
	# la version détaillée n'existe que pour les meubles ; la végétation utilise toujours le maillage léger
	var key := "%s_%s" % [name, "hi" if q >= 2 else "lo"]
	if not ResourceLoader.exists("res://assets/models/props/%s.res" % key):
		key = name + "_lo"
	if not _meshes.has(key):
		_meshes[key] = load("res://assets/models/props/%s.res" % key)
	return _meshes[key]

## Deux plans croisés (herbe, fleurs) : base au sol, largeur w, hauteur h.
static func card_mesh(w: float, h: float) -> ArrayMesh:
	var key := "card_%.2f_%.2f" % [w, h]
	if _meshes.has(key):
		return _meshes[key]
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var n := PackedVector3Array()
	for ang in [0.0, PI * 0.5]:
		var d := Vector3(cos(ang), 0, sin(ang)) * w * 0.5
		var pts := [-d, -d + Vector3(0, h, 0), d + Vector3(0, h, 0), -d, d + Vector3(0, h, 0), d]
		var uvs := [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)]
		for i in 6:
			v.append(pts[i]); uv.append(uvs[i]); n.append(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_NORMAL] = n
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_meshes[key] = m
	return m

# ================================================================== Sol
## Sol peint. o : base, r, g (textures), tint_*, uv_*, rect (zone du masque), res.
static func ground(root: Node3D, size: float, o: Dictionary = {}) -> GroundPaint:
	var rect: Rect2 = o.get("rect", Rect2(-size * 0.5, -size * 0.5, size, size))
	var gp := GroundPaint.new(rect, int(o.get("res", 512)) if q >= 1 else 256)
	gp.name = "GroundPaint"
	root.add_child(gp)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = shader("ground")
	m.set_shader_parameter("tex_base", tex(str(o.get("base", "grass"))))
	m.set_shader_parameter("tex_r", tex(str(o.get("r", "dirt"))))
	m.set_shader_parameter("tex_g", tex(str(o.get("g", "sand"))))
	m.set_shader_parameter("noise_tex", tex("noise"))
	m.set_shader_parameter("mask", gp.get_texture())
	m.set_shader_parameter("mask_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	if o.has("g2"):
		m.set_shader_parameter("tex_g2", tex(str(o["g2"])))
	for k in ["uv_base", "uv_r", "uv_g", "macro_amount", "g2_z"]:
		if o.has(k):
			m.set_shader_parameter(k, float(o[k]))
	for k in ["tint_base", "tint_var", "tint_r", "tint_g", "tint_g2"]:
		if o.has(k):
			var c: Color = o[k]
			m.set_shader_parameter(k, Vector3(c.r, c.g, c.b))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Ground"
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("part", "ground")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size, 0.1, size)
	cs.shape = bs
	cs.position = Vector3(0, -0.05, 0)
	body.add_child(cs)
	root.add_child(body)
	root.set_meta("ground_paint", gp)
	return gp

static func water_mat(o: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("water")
	m.set_shader_parameter("noise_tex", tex("noise"))
	for k in ["radius", "shore_z", "scale"]:
		if o.has(k):
			m.set_shader_parameter(k, float(o[k]))
	if o.has("center"):
		m.set_shader_parameter("center", o["center"])
	for k in ["shallow", "deep"]:
		if o.has(k):
			var c: Color = o[k]
			m.set_shader_parameter(k, Vector3(c.r, c.g, c.b))
	return m

## Plan d'eau rond avec berge peinte et écume.
static func pond(root: Node3D, gp: GroundPaint, c: Vector3, r: float, o: Dictionary = {}) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	cm.radial_segments = 40
	cm.rings = 1
	mi.mesh = cm
	var oo := o.duplicate()
	oo["radius"] = r
	oo["center"] = Vector2(c.x, c.z)
	mi.material_override = water_mat(oo)
	mi.position = c + Vector3(0, 0.018, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if gp:
		gp.disc(Vector2(c.x, c.z), r + 0.45, 0)
		gp.shade(Vector2(c.x, c.z), r + 1.4, 0.35)
	WorldBuilder.obs_circle(root, c, r + 0.05, false)

static func sea(root: Node3D, rect: Rect2, shore_z: float, o: Dictionary = {}) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = rect.size
	mi.mesh = pm
	var oo := o.duplicate()
	oo["shore_z"] = shore_z
	mi.material_override = water_mat(oo)
	mi.position = Vector3(rect.get_center().x, 0.03, rect.get_center().y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

# ================================================================== Instances (une passe de rendu par type)
static func inst(mesh_name: String, mat: Material, xf: Transform3D, col: Color = Color.WHITE, shadow: bool = true, mesh: Mesh = null) -> void:
	var key := "%s|%d" % [mesh_name, mat.get_instance_id()]
	if not _pending.has(key):
		_pending[key] = {"mesh": mesh if mesh else prop_mesh(mesh_name), "mat": mat, "xf": [], "col": [], "shadow": shadow}
	(_pending[key]["xf"] as Array).append(xf)
	(_pending[key]["col"] as Array).append(col)

## Crée les MultiMesh des instances déclarées depuis le dernier appel.
static func flush(root: Node3D) -> void:
	for key in _pending.keys():
		var e: Dictionary = _pending[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = e["mesh"]
		var n: int = (e["xf"] as Array).size()
		mm.instance_count = n
		for i in n:
			mm.set_instance_transform(i, e["xf"][i])
			mm.set_instance_color(i, e["col"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = e["mat"]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (e["shadow"] and q >= 1) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	_pending.clear()

static func _xf(pos: Vector3, rot_y: float, scl: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y).scaled(scl), pos)

# ================================================================== Végétation
## Arbre feuillu : tronc sculpté + houppier (a, b ou c). h = hauteur totale en mètres.
static func tree(root: Node3D, pos: Vector3, h: float, kind: String = "a", tint: Color = Color(0.36, 0.60, 0.26), seed_v: int = 0, obstacle: bool = true) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + int(pos.x * 31.0) + int(pos.z * 17.0)
	var rot := rng.randf() * TAU
	var th := h * (0.46 if kind != "c" else 0.4)
	var tr := h * 0.36
	inst("trunk", sculpt_mat("bark", 1.6), _xf(pos, rot, Vector3(tr, th, tr)), Color(0.86, 0.74, 0.62))
	var cr := h * (0.36 if kind == "a" else (0.33 if kind == "b" else 0.4))
	var cy := th + cr * (0.62 if kind != "b" else 0.75)
	var t := tint.lightened(rng.randf_range(-0.06, 0.08))
	inst("canopy_" + kind, foliage_mat(), _xf(pos + Vector3(0, cy, 0), rot, Vector3(cr, cr * rng.randf_range(0.92, 1.08), cr)), t)
	if obstacle:
		WorldBuilder.obs_circle(root, pos, maxf(0.16, tr * 0.34))
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		gp.shade(Vector2(pos.x, pos.z), cr * 1.25, 0.5)
		gp.soft(Vector2(pos.x, pos.z), tr * 1.1, 0, 0.55)

static func pine(root: Node3D, pos: Vector3, h: float, tint: Color = Color(0.22, 0.44, 0.27), obstacle: bool = true) -> void:
	var rot := fposmod(pos.x * 3.7 + pos.z * 5.1, TAU)
	var th := h * 0.22
	inst("trunk", sculpt_mat("bark", 1.6), _xf(pos, rot, Vector3(h * 0.22, th * 1.3, h * 0.22)), Color(0.72, 0.6, 0.5))
	var s := h * 0.8
	inst("pine", foliage_mat(), _xf(pos + Vector3(0, th, 0), rot, Vector3(s * 0.85, s, s * 0.85)), tint.lightened(fposmod(pos.x * 0.37, 0.1) - 0.04))
	if obstacle:
		WorldBuilder.obs_circle(root, pos, maxf(0.16, h * 0.07))
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		gp.shade(Vector2(pos.x, pos.z), s * 0.55, 0.55)

static func bush(root: Node3D, pos: Vector3, s: float, tint: Color = Color(0.34, 0.58, 0.28), obstacle: bool = true) -> void:
	var rot := fposmod(pos.x * 2.3 + pos.z * 4.7, TAU)
	inst("bush", foliage_mat(), _xf(pos, rot, Vector3(s, s, s)), tint)
	if obstacle:
		WorldBuilder.obs_circle(root, pos, s * 0.62)
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		gp.shade(Vector2(pos.x, pos.z), s * 1.0, 0.5)

## Haie taillée de a à b.
static func hedge(root: Node3D, a: Vector3, b: Vector3, height: float = 0.9, tint: Color = Color(0.30, 0.52, 0.26)) -> void:
	var d := b - a
	var n := maxi(1, int(round(d.length() / 1.9)))
	var seg := d.length() / n
	var rot := atan2(-d.z, d.x)
	for i in n:
		var p := a + d * ((i + 0.5) / n)
		inst("hedge", foliage_mat(), _xf(p, rot, Vector3(seg / 2.0 * 1.04, height / 0.76, 1.0)), tint.lightened((i % 3) * 0.02))
		WorldBuilder.obs_circle(root, p, minf(seg * 0.5, 0.6))
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		gp.path(Vector2(a.x, a.z), Vector2(b.x, b.z), 1.0, 2)

static func rock(root: Node3D, pos: Vector3, s: float, kind: String = "a", obstacle: bool = true, tint: Color = Color(0.92, 0.90, 0.86)) -> void:
	var rot := fposmod(pos.x * 1.9 + pos.z * 3.3, TAU)
	inst("rock_" + kind, sculpt_mat("rock", 1.4), _xf(pos, rot, Vector3(s, s, s)), tint)
	if obstacle and s > 0.35:
		WorldBuilder.obs_circle(root, pos, s * 0.5)
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		gp.shade(Vector2(pos.x, pos.z), s * 0.9, 0.5)

static func stump(root: Node3D, pos: Vector3, s: float = 1.0) -> void:
	inst("stump", sculpt_mat("bark", 2.0), _xf(pos, pos.x, Vector3(s, s, s)), Color(0.82, 0.7, 0.58))
	WorldBuilder.obs_circle(root, pos, 0.3 * s)

static func log_prop(root: Node3D, pos: Vector3, rot_y: float, s: float = 1.0) -> void:
	inst("log", sculpt_mat("bark", 2.0), _xf(pos, rot_y, Vector3(s, s, s)), Color(0.8, 0.68, 0.56))
	var d := Vector3(cos(rot_y), 0, -sin(rot_y)) * 0.5 * s
	WorldBuilder.obs_circle(root, pos - d, 0.3 * s)
	WorldBuilder.obs_circle(root, pos + d, 0.3 * s)
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		gp.path(Vector2(pos.x - d.x, pos.z - d.z), Vector2(pos.x + d.x, pos.z + d.z), 0.7 * s, 2)

## Herbe haute en touffes animées. keep(p) -> bool permet d'épargner chemins et bâtiments.
static func grass(root: Node3D, area: Rect2, count: int, seed_v: int, keep: Callable = Callable(), tint: Color = Color(0.50, 0.70, 0.36), size: Vector2 = Vector2(0.4, 0.75)) -> void:
	var n := int(count * [0.3, 0.7, 1.0][q])
	if n <= 0:
		return
	var occ := _occupancy(root, area)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var xfs: Array = []
	var cols: Array = []
	var tries := 0
	while xfs.size() < n and tries < n * 4:
		tries += 1
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if _occupied(occ, p):
			continue
		if keep.is_valid() and not keep.call(p):
			continue
		var s := rng.randf_range(size.x, size.y)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)), Vector3(p.x, 0, p.y)))
		var v := rng.randf_range(0.82, 1.08)
		cols.append(Color(tint.r * v, tint.g * v, tint.b * v * rng.randf_range(0.85, 1.0), 1.0))
	_multimesh(root, card_mesh(0.5, 0.36), card_mat("grass_card", 1, 0.07), xfs, cols)

## Fleurs des champs (planche de 4 fleurs, couleurs variées).
static func flowers(root: Node3D, area: Rect2, count: int, seed_v: int, keep: Callable = Callable(), palette: Array = []) -> void:
	var n := int(count * [0.3, 0.7, 1.0][q])
	if n <= 0:
		return
	if palette.is_empty():
		palette = [Color(1, 1, 1), Color(1, 0.86, 0.35), Color(1, 0.6, 0.72), Color(0.78, 0.62, 1.0), Color(1.0, 0.5, 0.4)]
	var occ := _occupancy(root, area.grow(0.6))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var xfs: Array = []
	var cols: Array = []
	var tries := 0
	# par bouquets : plus naturel qu'une répartition uniforme
	while xfs.size() < n and tries < n * 3:
		tries += 1
		var c := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var pc: Color = palette[rng.randi() % palette.size()]
		var kind := rng.randi() % 4
		for j in rng.randi_range(2, 6):
			var p := c + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
			if _occupied(occ, p):
				continue
			if keep.is_valid() and not keep.call(p):
				continue
			var s := rng.randf_range(0.7, 1.2)
			xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, 0, p.y)))
			cols.append(Color(pc.r, pc.g, pc.b, (kind + 0.5) / 4.0))
	_multimesh(root, card_mesh(0.22, 0.3), card_mat("flower_card", 2, 0.04), xfs, cols)

static func _multimesh(root: Node3D, mesh: Mesh, mat: Material, xfs: Array, cols: Array) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)

## Grille d'occupation (chemins, matières peintes, obstacles) : évite de tester chaque brin d'herbe
## contre chaque obstacle. Calculée une fois par appel de semis.
static func _occupancy(root: Node3D, area: Rect2) -> Dictionary:
	var cell := 0.4
	var w := maxi(1, int(ceil(area.size.x / cell)))
	var h := maxi(1, int(ceil(area.size.y / cell)))
	var data := PackedByteArray()
	data.resize(w * h)
	data.fill(0)
	var shapes: Array = []
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		for o in gp.ops:
			if int(o["ch"]) <= 1:
				shapes.append(o)
	for o in root.get_meta("obstacles", []):
		if o.has("rect"):
			shapes.append({"t": "rect", "r": o["rect"]})
		else:
			shapes.append({"t": "disc", "c": o["c"], "r": float(o["r"]) * 0.8})
	for o in shapes:
		var box := Rect2()
		var m := 0.15
		match str(o["t"]):
			"line":
				var hw := float(o["w"]) * 0.5 + m
				box = Rect2(o["a"], Vector2.ZERO).expand(o["b"]).grow(hw)
			"disc":
				box = Rect2((o["c"] as Vector2) - Vector2.ONE * (float(o["r"]) + m), Vector2.ONE * (float(o["r"]) + m) * 2.0)
			"soft":
				var sr := float(o["r"]) * 0.55 + m
				box = Rect2((o["c"] as Vector2) - Vector2.ONE * sr, Vector2.ONE * sr * 2.0)
			"rect":
				box = (o["r"] as Rect2).grow(m)
			"poly":
				box = Rect2(o["pts"][0], Vector2.ZERO)
				for pt in o["pts"]:
					box = box.expand(pt)
		if not box.intersects(area):
			continue
		var i0 := clampi(int(floor((box.position.x - area.position.x) / cell)), 0, w - 1)
		var i1 := clampi(int(floor((box.end.x - area.position.x) / cell)), 0, w - 1)
		var j0 := clampi(int(floor((box.position.y - area.position.y) / cell)), 0, h - 1)
		var j1 := clampi(int(floor((box.end.y - area.position.y) / cell)), 0, h - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				if data[j * w + i] == 1:
					continue
				var p := area.position + Vector2((i + 0.5) * cell, (j + 0.5) * cell)
				var hit := false
				match str(o["t"]):
					"line":
						var a: Vector2 = o["a"]
						var ab: Vector2 = (o["b"] as Vector2) - a
						var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
						hit = p.distance_to(a + ab * t) < float(o["w"]) * 0.5 + m
					"disc":
						hit = p.distance_to(o["c"]) < float(o["r"]) + m
					"soft":
						hit = p.distance_to(o["c"]) < float(o["r"]) * 0.55 + m
					"rect":
						hit = true
					"poly":
						hit = Geometry2D.is_point_in_polygon(p, PackedVector2Array(o["pts"]))
				if hit:
					data[j * w + i] = 1
	return {"area": area, "cell": cell, "w": w, "h": h, "data": data}

static func _occupied(occ: Dictionary, p: Vector2) -> bool:
	var a: Rect2 = occ["area"]
	var i := int((p.x - a.position.x) / float(occ["cell"]))
	var j := int((p.y - a.position.y) / float(occ["cell"]))
	if i < 0 or j < 0 or i >= int(occ["w"]) or j >= int(occ["h"]):
		return false
	return (occ["data"] as PackedByteArray)[j * int(occ["w"]) + i] == 1

static func _in_obstacle(obs: Array, p: Vector2) -> bool:
	for o in obs:
		if o.has("rect"):
			if (o["rect"] as Rect2).has_point(p):
				return true
		elif p.distance_to(o["c"]) < float(o["r"]) * 0.8:
			return true
	return false

## Le point est-il sur un chemin ou une matière peinte (canaux 0 et 1) ?
static func gp_painted(gp: GroundPaint, p: Vector2, margin: float = 0.0) -> bool:
	for o in gp.ops:
		if int(o["ch"]) > 1:
			continue
		match str(o["t"]):
			"line":
				var a: Vector2 = o["a"]
				var b: Vector2 = o["b"]
				var ab := b - a
				var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				if p.distance_to(a + ab * t) < float(o["w"]) * 0.5 + margin:
					return true
			"disc":
				if p.distance_to(o["c"]) < float(o["r"]) + margin:
					return true
			"soft":
				if p.distance_to(o["c"]) < float(o["r"]) * 0.55 + margin:
					return true
			"rect":
				if (o["r"] as Rect2).grow(margin).has_point(p):
					return true
			"poly":
				if Geometry2D.is_point_in_polygon(p, PackedVector2Array(o["pts"])):
					return true
	return false

# ================================================================== Lointains
## Collines en couches autour du terrain + silhouettes d'arbres : donne de la profondeur à l'horizon.
static func backdrop(root: Node3D, o: Dictionary = {}) -> void:
	var near_c: Color = o.get("near", Color(0.36, 0.58, 0.30))
	var far_c: Color = o.get("far", Color(0.56, 0.72, 0.62))
	var r0: float = o.get("radius", 40.0)
	var seed_v: int = o.get("seed", 5)
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.35
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var seg := 72 if q >= 1 else 40
	var tree_xf: Array = []
	var tree_col: Array = []
	var gap_from: float = o.get("gap_from", 9.0)   # secteur (radians) laissé ouvert, ex. vers la mer
	var gap_to: float = o.get("gap_to", 9.0)
	for layer in 3:
		var rr := r0 + layer * 9.0
		var hmax := (3.5 + layer * 3.0) * float(o.get("height", 1.0))
		var col := near_c.lerp(far_c, layer / 2.0)
		var col_lo := col.darkened(0.12)
		for i in seg:
			var a0 := TAU * float(i) / seg
			var a1 := TAU * float(i + 1) / seg
			if a0 >= gap_from and a1 <= gap_to:
				continue
			var h0 := hmax * (0.45 + 0.55 * (noise.get_noise_2d(cos(a0) * 3.0 + layer * 7.0, sin(a0) * 3.0) * 0.5 + 0.5))
			var h1 := hmax * (0.45 + 0.55 * (noise.get_noise_2d(cos(a1) * 3.0 + layer * 7.0, sin(a1) * 3.0) * 0.5 + 0.5))
			var p0 := Vector3(cos(a0) * rr, -0.5, sin(a0) * rr)
			var p1 := Vector3(cos(a1) * rr, -0.5, sin(a1) * rr)
			var t0 := Vector3(cos(a0) * (rr + 4.0), h0, sin(a0) * (rr + 4.0))
			var t1 := Vector3(cos(a1) * (rr + 4.0), h1, sin(a1) * (rr + 4.0))
			for p in [p0, t0, t1, p0, t1, p1]:
				v.append(p)
			for cc in [col_lo, col, col, col_lo, col, col_lo]:
				c.append(cc)
			# sommet arrondi vers l'arrière (évite un bord découpé sur le ciel)
			var b0 := Vector3(cos(a0) * (rr + 9.0), h0 * 0.7, sin(a0) * (rr + 9.0))
			var b1 := Vector3(cos(a1) * (rr + 9.0), h1 * 0.7, sin(a1) * (rr + 9.0))
			for p in [t0, b0, b1, t0, b1, t1]:
				v.append(p)
			for cc in [col, col, col, col, col, col]:
				c.append(cc)
			if layer < 2 and o.get("trees", true):
				for k in 4:
					var ta := lerpf(a0, a1, (k + 0.5) / 4.0)
					var th := lerpf(h0, h1, (k + 0.5) / 4.0)
					var tp := Vector3(cos(ta) * (rr + 1.0 + (k % 2) * 2.2), th * (0.38 + 0.36 * (k % 2)), sin(ta) * (rr + 1.0 + (k % 2) * 2.2))
					var s := 1.3 + fposmod(ta * 37.0, 1.1)
					tree_xf.append(Transform3D(Basis().scaled(Vector3(s, s * 1.7, s)), tp))
					tree_col.append(col.darkened(0.10 + fposmod(ta * 13.0, 0.08)))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Backdrop"
	root.add_child(mi)
	if not tree_xf.is_empty():
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.55
		cone.height = 1.0
		cone.radial_segments = 6
		cone.rings = 1
		_multimesh(root, cone, m, tree_xf, tree_col)

# ================================================================== Lumière et ciel
static func lighting(env_root: Node3D, quality: int) -> Node3D:
	var L: Dictionary = LOOKS[str(env_root.get_meta("look", "morning"))]
	var indoor: bool = env_root.get_meta("indoor", false)
	var n := Node3D.new()
	n.name = "Lighting"
	var sun := DirectionalLight3D.new()
	var rot: Vector2 = L["rot"]
	sun.rotation = Vector3(rot.x, rot.y, 0)
	sun.light_energy = float(L["sun_e"])
	sun.light_color = L["sun"]
	sun.shadow_enabled = quality >= 1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL   # une seule passe d'ombre : coût maîtrisé sur téléphone
	sun.directional_shadow_max_distance = 12.0 if indoor else (26.0 if quality >= 2 else 20.0)
	sun.directional_shadow_split_1 = 0.32
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.82
	sun.shadow_bias = 0.045
	sun.shadow_normal_bias = 1.6
	sun.shadow_blur = 1.3
	sun.shadow_opacity = 0.72
	n.add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	if quality >= 1 and not env_root.get_meta("no_sky", false):
		var sky := Sky.new()
		var sm := ShaderMaterial.new()
		sm.shader = shader("sky")
		for k in [["top_color", "top"], ["horizon_color", "hor"], ["ground_color", "ground"], ["sun_color", "sun"], ["cloud_shade", "cloud_shade"]]:
			var c: Color = L[k[1]]
			sm.set_shader_parameter(k[0], Vector3(c.r, c.g, c.b))
		if L.has("cloud"):
			var cc: Color = L["cloud"]
			sm.set_shader_parameter("cloud_color", Vector3(cc.r, cc.g, cc.b))
		sm.set_shader_parameter("cloud_cover", float(L["cover"]))
		sm.set_shader_parameter("noise_tex", tex("noise"))
		sm.set_shader_parameter("cloud_offset", Vector2(fposmod(float(hash(env_root.name)) * 0.001, 1.0), 0.3))
		sky.sky_material = sm
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		sky.process_mode = Sky.PROCESS_MODE_QUALITY
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = (L["hor"] as Color).lerp(L["top"], 0.45)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = L["amb"]
	env.ambient_light_energy = float(L["amb_e"])
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if indoor:
		if quality >= 1:
			var ceil_l := OmniLight3D.new()
			ceil_l.position = Vector3(0, 2.6, 0.4)
			ceil_l.light_color = Color(1.0, 0.86, 0.68)
			ceil_l.light_energy = 0.26
			ceil_l.omni_range = 5.5
			ceil_l.omni_attenuation = 1.4
			n.add_child(ceil_l)
	else:
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = L["fog"]
		env.fog_light_energy = 1.0
		env.fog_density = 0.82
		env.fog_depth_begin = float(env_root.get_meta("fog_begin", 16.0))
		env.fog_depth_end = float(env_root.get_meta("fog_end", 78.0))
		env.fog_depth_curve = 1.25
		env.fog_sky_affect = 0.0
	if quality >= 2:
		env.glow_enabled = true
		env.glow_intensity = 0.28
		env.glow_bloom = 0.04
		env.glow_hdr_threshold = 0.95
	we.environment = env
	n.add_child(we)
	return n

## Poussières / pollens en suspension, feuilles qui tombent, papillons : un peu de vie dans l'air.
static func ambient(root: Node3D, kind: String, area: Rect2, height: float = 2.5) -> void:
	if q < 1:
		return
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex("soft_blob")
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(area.size.x * 0.5, height * 0.5, area.size.y * 0.5)
	p.position = Vector3(area.get_center().x, height * 0.5 + 0.2, area.get_center().y)
	p.gravity = Vector3.ZERO
	p.direction = Vector3(1, 0.1, 0.3)
	p.spread = 60.0
	match kind:
		"pollen":
			qm.size = Vector2(0.035, 0.035)
			p.amount = 40 if q >= 2 else 22
			p.lifetime = 9.0
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.18
			p.color = Color(1.0, 0.98, 0.8, 0.55)
		"leaves":
			qm.size = Vector2(0.07, 0.05)
			m.albedo_texture = null
			p.amount = 16 if q >= 2 else 9
			p.lifetime = 7.0
			p.gravity = Vector3(0.15, -0.35, 0.05)
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.3
			p.angular_velocity_min = -90.0
			p.angular_velocity_max = 90.0
			p.color = Color(0.9, 0.6, 0.22, 0.9)
			p.position.y = height
		"spray":
			qm.size = Vector2(0.05, 0.05)
			p.amount = 24
			p.lifetime = 4.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.3
			p.color = Color(1, 1, 1, 0.5)
	qm.material = m
	p.mesh = qm
	p.preprocess = p.lifetime
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)

# ================================================================== Mobilier fusionné
## Clôture à piquets (style "picket") ou barrière en bois (style "rail").
static func fence(b: MeshBatch, a: Vector3, e: Vector3, style: String = "picket", col: Color = Color(0.98, 0.96, 0.92)) -> void:
	var d := e - a
	var len := d.length()
	var rot := atan2(-d.z, d.x)
	var xf := Transform3D(Basis(Vector3.UP, rot), a)
	var key := "t:wood_planks:0.45"
	if style == "picket":
		key = "flat"
		var n := maxi(2, int(len / 0.16))
		for i in n + 1:
			var x := len * float(i) / n
			var post := i % 8 == 0
			b.box(key, xf, Vector3(0.09 if post else 0.07, 0.86 if post else 0.72, 0.05 if not post else 0.09), Vector3(x, 0.43 if post else 0.38, 0), col, 0.12)
		for y in [0.22, 0.55]:
			b.box(key, xf, Vector3(len, 0.06, 0.035), Vector3(len * 0.5, y, -0.035), col.darkened(0.06))
	else:
		var n2 := maxi(1, int(round(len / 1.8)))
		for i in n2 + 1:
			b.box(key, xf, Vector3(0.12, 0.95, 0.12), Vector3(len * float(i) / n2, 0.47, 0), col, 0.18)
		for y in [0.38, 0.72]:
			b.box(key, xf, Vector3(len, 0.09, 0.05), Vector3(len * 0.5, y, 0), col.darkened(0.05))

## Réverbère : fût, crosse et lanterne lumineuse.
static func lamp(b: MeshBatch, root: Node3D, pos: Vector3, lit: bool = false) -> void:
	var xf := Transform3D(Basis(), pos)
	var c := Color(0.20, 0.23, 0.26)
	b.cyl("metal", xf, 0.1, 0.07, 0.25, Vector3.ZERO, c, 8)
	b.cyl("metal", xf, 0.045, 0.035, 2.5, Vector3(0, 0.25, 0), c, 8)
	b.box("metal", xf, Vector3(0.26, 0.04, 0.26), Vector3(0, 2.77, 0), c)
	b.box("emit", xf, Vector3(0.2, 0.28, 0.2), Vector3(0, 2.93, 0), Color(1.0, 0.93, 0.72))
	b.cyl("metal", xf, 0.19, 0.02, 0.14, Vector3(0, 3.07, 0), c, 4)
	WorldBuilder.obs_circle(root, pos, 0.12)
	if lit and q >= 2:
		var ol := OmniLight3D.new()
		ol.position = pos + Vector3(0, 2.8, 0)
		ol.light_color = Color(1.0, 0.86, 0.6)
		ol.light_energy = 0.25
		ol.omni_range = 4.5
		root.add_child(ol)

## Panneau en bois sur poteau avec texte.
static func signpost(b: MeshBatch, root: Node3D, pos: Vector3, rot_y: float, text: String, h: float = 1.7) -> void:
	var xf := Transform3D(Basis(Vector3.UP, rot_y), pos)
	var wood := Color(0.72, 0.54, 0.36)
	b.box("t:wood_planks:1.0", xf, Vector3(0.1, h, 0.1), Vector3(0, h * 0.5, 0), wood.darkened(0.15), 0.2)
	var bw := maxf(1.0, text.length() * 0.115 + 0.3)
	b.box("t:wood_planks:1.0", xf, Vector3(bw, 0.42, 0.06), Vector3(0, h - 0.1, 0.07), wood)
	for s in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 56
		l.pixel_size = 0.0035
		l.outline_size = 0
		l.modulate = Color(0.25, 0.16, 0.1)
		l.transform = xf * Transform3D(Basis(Vector3.UP, 0.0 if s > 0 else PI), Vector3(0, h - 0.1, 0.07 + 0.035 * s))
		l.double_sided = false
		root.add_child(l)

## Banc sculpté (instancié).
static func bench(root: Node3D, pos: Vector3, rot_y: float) -> void:
	inst("bench", sculpt_mat("wood_planks", 1.5), _xf(pos, rot_y, Vector3.ONE), Color(0.9, 0.68, 0.48))
	WorldBuilder.obs_circle(root, pos, 0.8)
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		gp.shade(Vector2(pos.x, pos.z), 1.0, 0.45)

# ================================================================== Bâtiments
## Fenêtre complète sur une façade (repère de façade : x vers la droite, y vers le haut, z vers l'extérieur).
static func window(b: MeshBatch, f: Transform3D, cx: float, cy: float, ww: float, wh: float, o: Dictionary = {}) -> void:
	var trim: Color = o.get("trim_c", Color(0.97, 0.96, 0.93))
	var lit: bool = o.get("lit", false)
	b.box("flat", f, Vector3(ww + 0.16, wh + 0.16, 0.08), Vector3(cx, cy, 0.03), trim)
	b.box("emit" if lit else "glass", f, Vector3(ww, wh, 0.03), Vector3(cx, cy, 0.065), Color(1.0, 0.9, 0.68) if lit else Color(0.30, 0.42, 0.56))
	b.box("flat", f, Vector3(0.05, wh, 0.03), Vector3(cx, cy, 0.085), trim)
	b.box("flat", f, Vector3(ww, 0.05, 0.03), Vector3(cx, cy + wh * 0.12, 0.085), trim)
	b.box("flat", f, Vector3(ww + 0.34, 0.07, 0.18), Vector3(cx, cy - wh * 0.5 - 0.1, 0.08), trim.darkened(0.06))
	if o.get("shutters", true):
		var sc: Color = o.get("shutter_c", Color(0.36, 0.55, 0.50))
		for s in [-1.0, 1.0]:
			b.box("t:wood_planks:0.7", f, Vector3(ww * 0.5, wh + 0.06, 0.05), Vector3(cx + s * (ww * 0.75 + 0.1), cy, 0.045), sc)
	if o.get("flowers", false):
		b.box("t:wood_planks:1.2", f, Vector3(ww + 0.12, 0.17, 0.2), Vector3(cx, cy - wh * 0.5 - 0.02, 0.2), Color(0.6, 0.42, 0.28))
		var pal: Array = [Color(0.95, 0.35, 0.42), Color(1.0, 0.8, 0.3), Color(0.95, 0.55, 0.75), Color(1, 1, 1)]
		var nfl := int(ww / 0.13)
		for i in nfl:
			var fx := cx - ww * 0.5 + (i + 0.5) * ww / nfl
			b.cyl("flat", f, 0.075, 0.03, 0.14, Vector3(fx, cy - wh * 0.5 + 0.05, 0.2), Color(0.32, 0.56, 0.26), 5, 0.0, false)
			b.box("flat", f, Vector3(0.08, 0.08, 0.08), Vector3(fx + 0.02, cy - wh * 0.5 + 0.2 + (i % 2) * 0.04, 0.22), pal[(i + int(cx * 10.0)) % pal.size()])

static func door(b: MeshBatch, f: Transform3D, cx: float, base_y: float, o: Dictionary = {}) -> void:
	var trim: Color = o.get("trim_c", Color(0.97, 0.96, 0.93))
	var dc: Color = o.get("door_c", Color(0.42, 0.28, 0.2))
	var dw := 0.95
	var dh := 2.0
	b.box("flat", f, Vector3(dw + 0.2, dh + 0.1, 0.1), Vector3(cx, base_y + dh * 0.5 + 0.05, 0.03), trim)
	b.box("t:wood_planks:0.5", f, Vector3(dw, dh, 0.06), Vector3(cx, base_y + dh * 0.5, 0.075), dc)
	for py in [0.5, 1.35]:
		b.box("t:wood_planks:0.5", f, Vector3(dw * 0.62, 0.62 if py > 1 else 0.7, 0.02), Vector3(cx, base_y + py, 0.11), dc.darkened(0.18))
	b.box("metal", f, Vector3(0.06, 0.06, 0.06), Vector3(cx + dw * 0.36, base_y + 1.0, 0.13), Color(0.9, 0.75, 0.35))
	b.box("t:stone_wall:0.7", f, Vector3(dw + 0.6, 0.16, 0.5), Vector3(cx, base_y - 0.08, 0.25), Color(0.82, 0.8, 0.76))
	if o.get("canopy", true):
		var roof_c: Color = o.get("roof_c", Color(0.72, 0.36, 0.3))
		var cf := f * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(cx, base_y + dh + 0.18, 0.32))
		b.gable_roof("t:roof_tiles:0.9", cf, 0.75, dw + 0.7, 0.34, Vector3.ZERO, roof_c, 0.05)
		for s in [-1.0, 1.0]:
			b.box("t:wood_planks:1.2", f, Vector3(0.07, 0.07, 0.6), Vector3(cx + s * (dw * 0.5 + 0.2), base_y + dh + 0.14, 0.3), Color(0.5, 0.36, 0.26))

## Maison ou boutique complète. Façade principale côté +Z local.
## o : w, d, floors, wall (clé de matière), wall_c, roof_c, trim_c, shutter_c, door_c, timber, chimney,
##     shop (auvent rayé + vitrine), sign (texte), awning_c, win (fenêtres par étage), lit (0..1), door (bool).
static func house(b: MeshBatch, root: Node3D, pos: Vector3, rot_y: float, o: Dictionary = {}) -> void:
	var w: float = o.get("w", 4.4)
	var d: float = o.get("d", 3.4)
	var floors: int = o.get("floors", 1)
	var fh := 2.45
	var wall_h := fh * floors + 0.15
	var base_h := 0.36
	var xf := Transform3D(Basis(Vector3.UP, rot_y), pos)
	var wall_key: String = o.get("wall", "t:plaster:0.4")
	var wall_c: Color = o.get("wall_c", Color(0.97, 0.92, 0.82))
	var roof_c: Color = o.get("roof_c", Color(0.78, 0.40, 0.32))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 131.0 + pos.z * 71.0) + 3
	b.box("t:stone_wall:0.55", xf, Vector3(w + 0.14, base_h, d + 0.14), Vector3(0, base_h * 0.5, 0), Color(0.80, 0.77, 0.72), 0.25)
	b.box(wall_key, xf, Vector3(w, wall_h, d), Vector3(0, base_h + wall_h * 0.5, 0), wall_c, 0.1)
	var y0 := base_h + wall_h
	var roof_h: float = o.get("roof_h", d * 0.42)
	var ov := 0.38
	b.gable_roof("t:roof_tiles:0.8", xf, w + ov * 2.0, d + ov * 2.0, roof_h * (d + ov * 2.0) / d, Vector3(0, y0 - ov * roof_h / (d * 0.5), 0), roof_c)
	b.gable_ends(wall_key, xf, w, d, roof_h, y0, wall_c)
	b.box("flat", xf, Vector3(w + ov * 2.0 + 0.06, 0.1, 0.1), Vector3(0, y0 + roof_h + 0.02, 0), roof_c.darkened(0.25))   # faîtage
	if o.get("chimney", true):
		var cx := w * 0.26 * (1.0 if rng.randf() < 0.5 else -1.0)
		b.box("t:brick:1.0", xf, Vector3(0.5, roof_h + 0.9, 0.5), Vector3(cx, y0 + (roof_h + 0.9) * 0.5 - 0.1, -d * 0.18), Color(0.86, 0.6, 0.5))
		b.box("t:stone_wall:1.0", xf, Vector3(0.62, 0.1, 0.62), Vector3(cx, y0 + roof_h + 0.82, -d * 0.18), Color(0.75, 0.73, 0.7))
	var faces := [
		xf * Transform3D(Basis(), Vector3(0, 0, d * 0.5)),
		xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -d * 0.5)),
		xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w * 0.5, 0, 0)),
		xf * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-w * 0.5, 0, 0)),
	]
	var widths := [w, w, d, d]
	var lit_p: float = o.get("lit", 0.25)
	var win_n: int = o.get("win", maxi(2, int(w / 1.7)))
	var shop: bool = o.get("shop", false)
	var has_door: bool = o.get("door", true)
	var wo := {"trim_c": o.get("trim_c", Color(0.97, 0.96, 0.93)), "shutter_c": o.get("shutter_c", Color(0.36, 0.55, 0.50)),
		"door_c": o.get("door_c", Color(0.42, 0.28, 0.2)), "roof_c": roof_c}
	# colombages : poutres sombres sur la façade et les pignons
	if o.get("timber", false):
		var tc := Color(0.36, 0.25, 0.18)
		for fi in 4:
			var fw: float = widths[fi]
			var f: Transform3D = faces[fi]
			for fl in range(1, floors + 1):
				b.box("t:wood_planks:1.2", f, Vector3(fw + 0.04, 0.14, 0.05), Vector3(0, base_h + fh * fl, 0.02), tc)
			for s in [-1.0, 1.0]:
				b.box("t:wood_planks:1.2", f, Vector3(0.14, wall_h, 0.05), Vector3(s * (fw * 0.5 - 0.07), base_h + wall_h * 0.5, 0.02), tc)
			if floors >= 2:
				var nb := maxi(2, int(fw / 1.4))
				for i in range(1, nb):
					b.box("t:wood_planks:1.2", f, Vector3(0.1, fh, 0.045), Vector3(-fw * 0.5 + fw * float(i) / nb, base_h + fh * 1.5, 0.02), tc)
	for fi in 4:
		var f2: Transform3D = faces[fi]
		var fw2: float = widths[fi]
		var n := win_n if fi < 2 else maxi(1, int(fw2 / 2.0))
		for fl in floors:
			var cy := base_h + fh * fl + 1.38
			for i in n:
				var cx2 := -fw2 * 0.5 + fw2 * (i + 0.5) / n
				if fi == 0 and fl == 0:
					if shop:
						continue
					if has_door and absf(cx2 - float(o.get("door_x", 0.0))) < 0.95:
						continue
				var w2 := wo.duplicate()
				w2["lit"] = rng.randf() < lit_p
				w2["flowers"] = fi == 0 and (fl > 0 or rng.randf() < 0.6) and o.get("flower_boxes", true)
				w2["shutters"] = o.get("shutters", true) and fw2 / n > 1.75
				window(b, f2, cx2, cy, 0.78, 1.0, w2)
	var front: Transform3D = faces[0]
	if shop:
		var dx: float = -w * 0.5 + 0.85
		door(b, front, dx, base_h, wo.merged({"canopy": false}))
		# vitrine
		var vw := w - 2.2
		var vx := dx + 0.75 + vw * 0.5
		b.box("flat", front, Vector3(vw + 0.16, 1.6, 0.1), Vector3(vx, base_h + 1.25, 0.03), wo["trim_c"])
		b.box("glass", front, Vector3(vw, 1.44, 0.03), Vector3(vx, base_h + 1.25, 0.08), Color(0.36, 0.48, 0.6))
		b.box("t:wood_planks:1.0", front, Vector3(vw + 0.3, 0.12, 0.3), Vector3(vx, base_h + 0.42, 0.14), Color(0.62, 0.45, 0.3))
		# auvent rayé
		var ac: Color = o.get("awning_c", Color(0.90, 0.36, 0.34))
		var strips := int((w - 0.3) / 0.32)
		var sw := (w - 0.3) / strips
		for i in strips:
			var af := front * Transform3D(Basis(Vector3.RIGHT, 0.42), Vector3(-w * 0.5 + 0.15 + (i + 0.5) * sw, base_h + 2.32, 0.5))
			b.box("flat", af, Vector3(sw, 0.04, 1.15), Vector3.ZERO, ac if i % 2 == 0 else Color(1, 1, 1))
			b.box("flat", front, Vector3(sw, 0.14, 0.03), Vector3(-w * 0.5 + 0.15 + (i + 0.5) * sw, base_h + 2.02, 1.0), ac if i % 2 == 0 else Color(1, 1, 1))
	elif has_door:
		door(b, front, float(o.get("door_x", 0.0)), base_h, wo)
	var sign_t: String = o.get("sign", "")
	if sign_t != "":
		var sw2 := maxf(1.6, sign_t.length() * 0.2 + 0.5)
		var sy := base_h + (2.95 if shop else wall_h - 0.32)
		b.box("t:wood_planks:1.0", front, Vector3(sw2, 0.5, 0.07), Vector3(0, sy, 0.06), Color(0.42, 0.3, 0.22))
		b.box("flat", front, Vector3(sw2 - 0.1, 0.4, 0.02), Vector3(0, sy, 0.1), Color(0.97, 0.94, 0.86))
		var l := Label3D.new()
		l.text = sign_t
		l.font_size = 64
		l.pixel_size = 0.005
		l.outline_size = 0
		l.modulate = Color(0.3, 0.2, 0.14)
		l.transform = front * Transform3D(Basis(), Vector3(0, sy, 0.125))
		root.add_child(l)
	# navigation, caméra et ombre de contact
	var nc := maxi(1, int(round(w / d)))
	for i in nc:
		var lp := Vector3(-w * 0.5 + w * (i + 0.5) / nc, 0, 0)
		WorldBuilder.obs_circle(root, xf * lp, maxf(d, w / nc) * 0.62)
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		var pts: Array = []
		for c in [Vector3(-w * 0.5 - 0.45, 0, -d * 0.5 - 0.45), Vector3(w * 0.5 + 0.45, 0, -d * 0.5 - 0.45), Vector3(w * 0.5 + 0.45, 0, d * 0.5 + 0.45), Vector3(-w * 0.5 - 0.45, 0, d * 0.5 + 0.45)]:
			var wp: Vector3 = xf * c
			pts.append(Vector2(wp.x, wp.z))
		gp.ops.append({"t": "poly", "pts": pts, "ch": 2, "k": 0.6})

## Petit étal de marché : comptoir, toile rayée, caisses.
static func stall(b: MeshBatch, root: Node3D, pos: Vector3, rot_y: float, col: Color, goods: Array = []) -> void:
	var xf := Transform3D(Basis(Vector3.UP, rot_y), pos)
	var wood := Color(0.74, 0.56, 0.38)
	b.box("t:wood_planks:1.0", xf, Vector3(2.0, 0.85, 0.8), Vector3(0, 0.42, 0), wood, 0.18)
	for sx in [-0.95, 0.95]:
		for sz in [-0.38, 0.38]:
			b.box("t:wood_planks:1.0", xf, Vector3(0.07, 2.15, 0.07), Vector3(sx, 1.07, sz), wood.darkened(0.2))
	for i in 6:
		var af := xf * Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(-0.92 + (i + 0.5) * 0.3067, 2.2, 0.05))
		b.box("flat", af, Vector3(0.3067, 0.035, 1.2), Vector3.ZERO, col if i % 2 == 0 else Color(1, 1, 1))
	for i in goods.size():
		var gc: Color = goods[i]
		b.box("t:wood_planks:1.5", xf, Vector3(0.42, 0.14, 0.5), Vector3(-0.7 + i * 0.47, 0.92, 0.05), wood.darkened(0.1))
		for k in 6:
			b.cyl("flat", xf, 0.07, 0.03, 0.1, Vector3(-0.82 + i * 0.47 + (k % 3) * 0.12, 0.98, -0.07 + (k / 3) * 0.2), gc.lightened((k % 2) * 0.1), 6, 0.0, true)
	WorldBuilder.obs_circle(root, pos, 1.0)
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		gp.shade(Vector2(pos.x, pos.z), 1.7, 0.5)
