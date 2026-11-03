class_name PetModel
extends Node3D
## Modèle 3D procédural d'un animal + animation procédurale (IK des pattes,
## postures mélangées, queue, oreilles, yeux, langue, accessoires).
## Le modèle regarde vers +Z.

const WHITE := Color(0.98, 0.96, 0.93)
const PINK := Color(0.95, 0.55, 0.6)
const NOSE := Color(0.13, 0.1, 0.1)

static var _mat_cache := {}
static var _mesh_cache := {}

var breed_id := "labrador"
var bd: Dictionary
var pet_data: Dictionary
var c_main: Color
var c_second: Color
var c_eye: Color
var quality := 1

# Dimensions
var L := 0.27
var bx := 0.3
var by := 0.27
var bz := 0.56
var hr := 0.19
var hx := 0.1
var zf := 0.18
var zr := -0.18
var hy := -0.07

# Nœuds
var body_pivot: Node3D
var head_pivot: Node3D
var jaw: Node3D
var tongue: MeshInstance3D
var eyes: Array[Node3D] = []
var ears: Array[Node3D] = []
var tail_segs: Array[Node3D] = []
var legs: Array[Dictionary] = []
var acc_root: Node3D
var hit_body: StaticBody3D
var hit_head: StaticBody3D
var emote_label: Label3D
var held_anchor: Node3D

# Animation
var posture := "stand"
var _from := {}
var _to := {}
var _cur := {}
var _blend := 1.0
var blend_speed := 4.0
var move_speed := 0.0
var _phase := 0.0
var wag_amp := 0.3
var wag_speed := 8.0
var _wag_amp := 0.3
var expression := "neutral"   # neutral, happy, closed, sad, focus
var tongue_out := 0.0
var _tongue := 0.0
var head_extra := Vector3.ZERO   # pitch, yaw, roll additionnels (inclinaison, regard)
var _head_extra := Vector3.ZERO
var jump_y := 0.0
var shake := 0.0
var sniff := 0.0
var chew := 0.0
var time := 0.0
var _blink_t := 2.0
var _blink := 0.0
var _emote_tw: Tween

func setup(p: Dictionary, q: int = 1) -> void:
	pet_data = p
	breed_id = str(p.get("breed", "labrador"))
	bd = GameData.breed(breed_id)
	quality = q
	var pal: Dictionary = bd["palettes"][clampi(int(p.get("palette", 0)), 0, bd["palettes"].size() - 1)]
	c_main = pal["main"]
	c_second = pal["second"]
	c_eye = GameData.EYE_COLORS[clampi(int(p.get("eyes", 0)), 0, GameData.EYE_COLORS.size() - 1)]
	var s: float = bd["scale"]
	var body: Vector3 = bd["body"]
	bx = body.x; by = body.y; bz = body.z
	L = bd["leg_len"]; hr = bd["head"]
	hx = bx * 0.3; zf = bz * 0.3; zr = -bz * 0.3; hy = -by * 0.26
	scale = Vector3.ONE * s
	_build()
	_cur = _posture_params("stand")
	_from = _cur.duplicate(true)
	_to = _cur.duplicate(true)
	_apply(_cur, 0.0)

func rebuild(p: Dictionary) -> void:
	for ch in get_children():
		ch.queue_free()
	eyes.clear(); ears.clear(); tail_segs.clear(); legs.clear(); lids.clear(); lower_lids.clear(); shell_mats.clear()
	setup(p, quality)

# ================================================================== Couleurs par motif
func col(part: String) -> Color:
	var pat: String = bd["pattern"]
	var pal: Dictionary = bd["palettes"][clampi(int(pet_data.get("palette", 0)), 0, bd["palettes"].size() - 1)]
	match pat:
		"shiba":
			if part in ["belly", "chest", "muzzle", "paws", "tail_tip", "cheeks"]:
				return c_second
		"beagle":
			if part in ["belly", "chest", "muzzle", "paws", "tail_tip", "blaze"]:
				return WHITE
			if part == "saddle" or part == "tail":
				return c_second
			if part == "ears":
				return c_main.darkened(0.15)
		"saddle":
			if part in ["saddle", "muzzle", "tail"]:
				return c_second
			if part == "ears":
				return c_second.lerp(c_main, 0.3)
			if part == "belly":
				return c_main.lightened(0.15)
		"poodle":
			if part == "fluff":
				return c_second
		"tabby":
			if pal.get("points", false):
				if part in ["ears", "muzzle", "paws", "tail", "tail_tip"]:
					return c_second
				if part == "stripe":
					return c_main
			if part == "stripe":
				return c_second
			if part in ["belly", "chest", "muzzle"]:
				return c_main.lightened(0.35)
		_:
			if part == "muzzle":
				return c_main.lerp(c_second, 0.6)
			if part == "belly":
				return c_main.lerp(c_second, 0.5)
	return c_main

# ================================================================== Ressources partagées
static func mat(c: Color, rough: float = 0.85, rim: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f_%.2f" % [c.to_html(), rough, rim, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.5 if metal > 0.0 else 0.12
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.6
	_mat_cache[key] = m
	return m

func _sphere() -> SphereMesh:
	var key := "sphere_%d" % quality
	if not _mesh_cache.has(key):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = [10, 16, 24][quality]
		m.rings = [6, 9, 12][quality]
		_mesh_cache[key] = m
	return _mesh_cache[key]

func _capsule(r: float, h: float) -> CapsuleMesh:
	var key := "cap_%.3f_%.3f_%d" % [r, h, quality]
	if not _mesh_cache.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0 + 0.001)
		m.radial_segments = [8, 12, 16][quality]
		m.rings = [2, 4, 6][quality]
		_mesh_cache[key] = m
	return _mesh_cache[key]

func _cone(r_bot: float, r_top: float, h: float) -> CylinderMesh:
	var key := "cone_%.3f_%.3f_%.3f_%d" % [r_bot, r_top, h, quality]
	if not _mesh_cache.has(key):
		var m := CylinderMesh.new()
		m.bottom_radius = r_bot
		m.top_radius = r_top
		m.height = h
		m.radial_segments = [8, 12, 16][quality]
		m.rings = 1
		_mesh_cache[key] = m
	return _mesh_cache[key]

func _torus(inner: float, outer: float) -> TorusMesh:
	var key := "torus_%.3f_%.3f_%d" % [inner, outer, quality]
	if not _mesh_cache.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = [12, 18, 24][quality]
		m.ring_segments = [6, 8, 10][quality]
		_mesh_cache[key] = m
	return _mesh_cache[key]

func _mi(mesh: Mesh, c: Color, parent: Node3D, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO, rough: float = 0.85, rim: float = 0.12, metal: float = 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat(c, rough, rim, metal)
	m.position = pos
	m.scale = scl
	m.rotation = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m

func _ell(c: Color, parent: Node3D, pos: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _mi(_sphere(), c, parent, pos, size, rot)

func _pivot(parent: Node3D, pos: Vector3, n: String = "") -> Node3D:
	var p := Node3D.new()
	p.position = pos
	if n != "":
		p.name = n
	parent.add_child(p)
	return p

# ================================================================== Construction
static var _res_cache := {}
static var _meta_cache := {}
var fur_mat: ShaderMaterial
var shell_mats := {}
var lower_lids: Array[Node3D] = []
var lids: Array[Node3D] = []
var meta := {}

## Maillage sculpté (généré par tools/gen_models.py).
func _part(nm: String) -> Mesh:
	var q := "hi" if quality >= 2 else "lo"
	var path := "res://assets/models/%s/%s_%s.res" % [breed_id, nm, q]
	if _res_cache.has(path):
		return _res_cache[path]
	var m: Mesh = load(path) if ResourceLoader.exists(path) else null
	if m == null:
		push_error("Maillage manquant : " + path)
	_res_cache[path] = m
	return m

func _load_meta() -> Dictionary:
	if _meta_cache.has(breed_id):
		return _meta_cache[breed_id]
	var d := {}
	var path := "res://assets/models/%s/meta.json" % breed_id
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			d = parsed
	_meta_cache[breed_id] = d
	return d

func _v3(key: String, def: Vector3) -> Vector3:
	var a: Variant = meta.get(key)
	if a is Array and a.size() == 3:
		return Vector3(a[0], a[1], a[2])
	return def

func _make_fur_mat() -> void:
	fur_mat = ShaderMaterial.new()
	fur_mat.shader = load("res://assets/shaders/fur.gdshader")
	var pal: Dictionary = bd["palettes"][clampi(int(pet_data.get("palette", 0)), 0, bd["palettes"].size() - 1)]
	var pat: String = bd["pattern"]
	var second := c_second
	var white := WHITE
	if pat == "shiba":
		white = c_second
	var points: bool = pal.get("points", false)
	fur_mat.set_shader_parameter("c_main", c_main)
	fur_mat.set_shader_parameter("c_second", second)
	fur_mat.set_shader_parameter("c_white", white)
	fur_mat.set_shader_parameter("c_points", c_second)
	fur_mat.set_shader_parameter("pattern_on", 0.0 if points else 1.0)
	fur_mat.set_shader_parameter("points_on", 1.0 if points else 0.0)
	fur_mat.set_shader_parameter("fur_strength", 0.6 if pat == "poodle" else 0.45)

func _fur(nm: String, parent: Node3D, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _part(nm)
	mi.material_override = fur_mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_add_shells(mi, nm)
	return mi

## Nombre de couches de poils selon la qualité graphique.
func shell_count() -> int:
	return [4, 7, 10][clampi(quality, 0, 2)]

func _shell_mats(head: bool) -> Array:
	var key := "head" if head else "body"
	if shell_mats.has(key):
		return shell_mats[key]
	var pat: String = bd["pattern"]
	var length := {"poodle": 0.016, "shepherd": 0.014, "shiba": 0.013, "cat": 0.009, "beagle": 0.007, "solid": 0.009}.get(pat, 0.01) as float
	if head:
		length *= 0.6
	var arr: Array = []
	var n := shell_count()
	var sh: Shader = load("res://assets/shaders/fur_shell.gdshader")
	for i in n:
		var m := ShaderMaterial.new()
		m.shader = sh
		for k in ["c_main", "c_second", "c_white", "c_points", "pattern_on", "points_on"]:
			m.set_shader_parameter(k, fur_mat.get_shader_parameter(k))
		m.set_shader_parameter("layer", float(i + 1) / float(n))
		m.set_shader_parameter("fur_len", length)
		m.set_shader_parameter("density", 190.0 if pat == "poodle" else 250.0)
		m.set_shader_parameter("curl", 0.6 if pat == "poodle" else 0.0)
		if head:
			var e := _v3("eye", Vector3(hr * 0.4, hr * 0.12, hr * 0.76))
			m.set_shader_parameter("hole_a", e)
			m.set_shader_parameter("hole_b", Vector3(-e.x, e.y, e.z))
			var sn: Vector2 = bd["snout"]
			m.set_shader_parameter("hole_c", _v3("nose", Vector3(0, -hr * 0.28 + sn.y * 0.45, hr * 0.78 + sn.x * 1.1)))
			m.set_shader_parameter("hole_r", float(meta.get("eye_r", hr * 0.2)) * 1.2)
			m.set_shader_parameter("comb", Vector3(0, -0.2, -0.6))
		m.render_priority = i
		arr.append(m)
	shell_mats[key] = arr
	return arr

func _add_shells(base: MeshInstance3D, nm: String) -> void:
	if nm == "nose" or nm.begins_with("ear_inner"):
		return
	var mats := _shell_mats(nm == "head")
	# les couches utilisent toujours le maillage léger (performances)
	var q_save := quality
	quality = 0
	var light := _part(nm)
	quality = q_save
	for m in mats:
		var s := MeshInstance3D.new()
		s.mesh = light if light else base.mesh
		s.material_override = m
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		base.add_child(s)

func _hemi(r: float) -> SphereMesh:
	var key := "hemi_%.3f_%d" % [r, quality]
	if not _mesh_cache.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r
		m.is_hemisphere = true
		m.radial_segments = [12, 18, 24][quality]
		m.rings = [4, 6, 8][quality]
		_mesh_cache[key] = m
	return _mesh_cache[key]

func _build() -> void:
	var cat: bool = bd["species"] == "cat"
	meta = _load_meta()
	_make_fur_mat()
	lids.clear()
	body_pivot = _pivot(self, Vector3(0, L, 0), "Body")
	_fur("torso", body_pivot)
	var neck_base := Vector3(0, by * 0.28, bz * 0.38)
	var head_pos := Vector3(0, by * 0.3 + hr * 1.05, bz * 0.46 + hr * 0.35)
	if cat:
		head_pos = Vector3(0, by * 0.3 + hr * 0.95, bz * 0.44 + hr * 0.3)
	# Collier
	var collar_it := GameData.item(str(pet_data.get("collar", "collar_red")))
	var cc: Color = collar_it.get("color", Color.RED)
	var collar_pos := neck_base.lerp(head_pos, 0.5)
	var collar := _mi(_torus(hr * 0.62, hr * 0.8), cc, body_pivot, collar_pos, Vector3(1, 1, 1), Vector3(0.75, 0, 0), 0.5, 0.1, 0.6 if collar_it.get("metal", false) else 0.0)
	collar.name = "Collar"
	_mi(_sphere(), Color(0.95, 0.8, 0.3), body_pivot, collar_pos + Vector3(0, -hr * 0.58, hr * 0.52), Vector3.ONE * hr * 0.26, Vector3.ZERO, 0.25, 0.1, 0.85)
	acc_root = _pivot(body_pivot, collar_pos, "AccNeck")
	# Tête sculptée
	head_pivot = _pivot(body_pivot, head_pos, "Head")
	_fur("head", head_pivot)
	var sn: Vector2 = bd["snout"]
	var snout_c := Vector3(0, -hr * 0.28, hr * 0.78 + sn.x * 0.35)
	if cat:
		snout_c = Vector3(0, -hr * 0.32, hr * 0.8)
	var nose := MeshInstance3D.new()
	nose.mesh = _part("nose")
	nose.material_override = mat(PINK.darkened(0.15) if cat else NOSE, 0.25, 0.25)
	nose.position = _v3("nose", snout_c + Vector3(0, sn.y * 0.45, sn.x * 0.78))
	head_pivot.add_child(nose)
	if cat:
		for sx in [-1.0, 1.0]:
			for k in 3:
				var w := _mi(_cone(0.0025, 0.0012, hr * 1.25), Color(0.97, 0.97, 0.97), head_pivot,
					Vector3(sx * hr * 0.55, -hr * 0.3 + (k - 1) * hr * 0.06, hr * 0.82), Vector3.ONE,
					Vector3(0, 0, sx * (PI / 2 - 0.12 + (k - 1) * 0.13)), 0.5, 0.0)
				w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Mâchoire + langue
	jaw = _pivot(head_pivot, snout_c + Vector3(0, -sn.y * 0.6, -sn.x * 0.2), "Jaw")
	tongue = _ell(PINK, jaw, Vector3(0, -sn.y * 0.15, sn.x * 0.6), Vector3(sn.y * 0.75, sn.y * 0.18, sn.x * 0.9))
	tongue.material_override = mat(PINK, 0.35, 0.1)
	tongue.visible = false
	held_anchor = _pivot(head_pivot, snout_c + Vector3(0, -sn.y * 0.7, sn.x * 0.75), "Mouth")
	# Yeux : globe, iris, pupille, reflets, paupière
	var er: float = float(meta.get("eye_r", hr * 0.2))
	var ep0 := _v3("eye", Vector3(hr * 0.4, hr * 0.12, hr * 0.76))
	var lid_c := c_second if bd["pattern"] == "shiba" else c_main
	if bd["pattern"] == "saddle":
		lid_c = c_main.lerp(c_second, 0.5)
	for sx in [-1.0, 1.0]:
		var e := _pivot(head_pivot, Vector3(sx * ep0.x, ep0.y, ep0.z), "Eye")
		e.rotation = Vector3(0, sx * 0.3, 0)
		e.scale = Vector3(1, 1, 0.62)
		_mi(_sphere(), c_eye.darkened(0.62), e, Vector3.ZERO, Vector3.ONE * er * 2.0, Vector3.ZERO, 0.12, 0.0)
		_mi(_sphere(), c_eye, e, Vector3(0, 0, er * 0.55), Vector3(er * 1.78, er * 1.82, er * 0.95), Vector3.ZERO, 0.15, 0.0)
		_mi(_sphere(), Color(0.02, 0.02, 0.03), e, Vector3(0, 0, er * 0.86), Vector3(er * 0.78, er * (0.95 if cat else 0.82), er * 0.4), Vector3.ZERO, 0.1, 0.0)
		var hl := _mi(_sphere(), Color.WHITE, e, Vector3(er * 0.3, er * 0.38, er * 0.92), Vector3.ONE * er * 0.46, Vector3.ZERO, 0.1, 0.0)
		hl.material_override = _glow_mat()
		var hl2 := _mi(_sphere(), Color.WHITE, e, Vector3(-er * 0.28, -er * 0.3, er * 0.95), Vector3.ONE * er * 0.2, Vector3.ZERO, 0.1, 0.0)
		hl2.material_override = _glow_mat()
		var lid := _pivot(e, Vector3.ZERO, "Lid")
		var lm := _mi(_hemi(er * 1.13), lid_c, lid, Vector3.ZERO, Vector3(1, 1, 1), Vector3.ZERO, 0.9, 0.1)
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lids.append(lid)
		var low := _pivot(e, Vector3.ZERO, "LowerLid")
		var lw := _mi(_hemi(er * 1.12), lid_c, low, Vector3.ZERO, Vector3(1, 1, 1), Vector3.ZERO, 0.9, 0.1)
		lw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		low.rotation.x = PI + 0.95
		lower_lids.append(low)
		eyes.append(e)
	# Oreilles
	var es: float = bd["ear_size"]
	var et := str(bd["ear"])
	for sx in [-1.0, 1.0]:
		var ep := _pivot(head_pivot, Vector3(sx * hr * 0.8, hr * 0.5, -hr * 0.02), "Ear")
		if et == "pointy" or et == "cat":
			ep.position = Vector3(sx * hr * 0.46, hr * 0.66, -hr * 0.02)
		ep.set_meta("side", sx)
		var suffix := "" if sx < 0.0 else "_r"
		_fur("ear" + suffix, ep)
		if et == "pointy" or et == "cat":
			var inner := MeshInstance3D.new()
			inner.mesh = _part("ear_inner" + suffix)
			inner.material_override = mat(PINK.lightened(0.15), 0.8, 0.1)
			ep.add_child(inner)
		ears.append(ep)
	_build_tail()
	# Pattes

	var defs := [[-1.0, true], [1.0, true], [-1.0, false], [1.0, false]]
	for dd in defs:
		var sx: float = dd[0]
		var front: bool = dd[1]
		var hip_local := Vector3(sx * hx, hy, zf if front else zr)
		var hip := _pivot(body_pivot, hip_local, "Leg")
		var a := L * 0.52
		var bl := L * 0.5
		var tag := "front" if front else "rear"
		_fur("leg_upper_" + tag, hip)
		var knee := _pivot(hip, Vector3(0, -a, 0), "Knee")
		_fur("leg_lower_" + tag, knee)
		legs.append({"hip": hip, "knee": knee, "a": a, "b": bl, "front": front, "side": sx, "local": hip_local})
	_build_accessory()
	# Zones de toucher
	hit_body = StaticBody3D.new()
	hit_body.collision_layer = 2
	hit_body.set_meta("part", "body")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = maxf(bx, by) * 0.62
	cap.height = bz * 1.1
	cs.shape = cap
	cs.rotation = Vector3(PI / 2, 0, 0)
	hit_body.add_child(cs)
	body_pivot.add_child(hit_body)
	hit_head = StaticBody3D.new()
	hit_head.collision_layer = 2
	hit_head.set_meta("part", "head")
	var cs2 := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = hr * 1.35
	cs2.shape = sph
	hit_head.add_child(cs2)
	head_pivot.add_child(hit_head)
	emote_label = Label3D.new()
	emote_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	emote_label.font = UiKit.emoji_font()
	emote_label.font_size = 96
	emote_label.pixel_size = 0.0035
	emote_label.outline_size = 0
	emote_label.no_depth_test = true
	emote_label.position = Vector3(0, L + by + hr * 2.6, 0)
	emote_label.modulate = Color(1, 1, 1, 0)
	add_child(emote_label)

static var _glow: StandardMaterial3D
static func _glow_mat() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.albedo_color = Color.WHITE
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _glow

func _build_tail() -> void:
	var tail_root := _pivot(body_pivot, Vector3(0, by * 0.18, -bz * 0.45), "Tail")
	var n := int(meta.get("tail_segments", 3))
	var seg_len := float(meta.get("tail_len", 0.07))
	var parent: Node3D = tail_root
	for i in n:
		var seg := _pivot(parent, Vector3.ZERO if i == 0 else Vector3(0, 0, -seg_len), "TailSeg")
		_fur("tail_%d" % i, seg)
		tail_segs.append(seg)
		parent = seg
	tail_root.set_meta("type", bd["tail"])

func _build_accessory() -> void:
	var id := str(pet_data.get("accessory", "acc_none"))
	var it := GameData.item(id)
	var c: Color = it.get("color", Color.WHITE)
	match id:
		"bandana":
			var m := _mi(_cone(hr * 0.75, 0.005, hr * 0.9), c, acc_root, Vector3(0, -hr * 0.35, hr * 0.3), Vector3(1, 1, 0.25), Vector3(PI + 0.5, 0, 0), 0.9, 0.1)
			m.name = "Bandana"
		"scarf":
			_mi(_torus(hr * 0.62, hr * 0.9), c, acc_root, Vector3(0, -hr * 0.05, 0), Vector3(1, 1.4, 1), Vector3(0.75, 0, 0), 0.9, 0.1)
			_ell(c, acc_root, Vector3(hr * 0.3, -hr * 0.6, hr * 0.5), Vector3(hr * 0.35, hr * 0.9, hr * 0.15), Vector3(0.3, 0, 0.2))
		"bow":
			var p := _pivot(head_pivot, Vector3(hr * 0.35, hr * 0.85, 0.0))
			for sx in [-1.0, 1.0]:
				_ell(c, p, Vector3(sx * hr * 0.2, 0, 0), Vector3(hr * 0.35, hr * 0.25, hr * 0.12), Vector3(0, 0, sx * 0.4))
			_ell(c.darkened(0.2), p, Vector3.ZERO, Vector3.ONE * hr * 0.14)
		"hat":
			var p2 := _pivot(head_pivot, Vector3(0, hr * 0.85, -hr * 0.05))
			_mi(_cone(hr * 1.2, hr * 1.2, hr * 0.06), c, p2, Vector3.ZERO, Vector3.ONE, Vector3(-0.1, 0, 0), 0.95, 0.1)
			_mi(_cone(hr * 0.6, hr * 0.5, hr * 0.5), c, p2, Vector3(0, hr * 0.25, 0), Vector3.ONE, Vector3(-0.1, 0, 0), 0.95, 0.1)
			_mi(_cone(hr * 0.61, hr * 0.61, hr * 0.12), Color(0.9, 0.35, 0.35), p2, Vector3(0, hr * 0.08, 0), Vector3.ONE, Vector3(-0.1, 0, 0), 0.8, 0.1)
		"crown":
			var p3 := _pivot(head_pivot, Vector3(0, hr * 0.9, 0))
			_mi(_cone(hr * 0.5, hr * 0.55, hr * 0.25), c, p3, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 0.3, 0.1, 0.9)
			for k in 5:
				var a := TAU * k / 5.0
				_mi(_cone(hr * 0.1, 0.003, hr * 0.3), c, p3, Vector3(sin(a) * hr * 0.5, hr * 0.25, cos(a) * hr * 0.5), Vector3.ONE, Vector3.ZERO, 0.3, 0.1, 0.9)
			_ell(Color(0.9, 0.2, 0.3), p3, Vector3(0, hr * 0.05, hr * 0.53), Vector3.ONE * hr * 0.12).material_override = mat(Color(0.9, 0.2, 0.3), 0.1, 0.0)
		"glasses":
			var p4 := _pivot(head_pivot, Vector3(0, hr * 0.12, hr * 0.92))
			for sx in [-1.0, 1.0]:
				_mi(_cone(hr * 0.27, hr * 0.27, hr * 0.05), c, p4, Vector3(sx * hr * 0.4, 0, 0), Vector3.ONE, Vector3(PI / 2, 0, 0), 0.15, 0.0, 0.3)
			_mi(_cone(hr * 0.03, hr * 0.03, hr * 0.3), c, p4, Vector3(0, hr * 0.05, 0), Vector3.ONE, Vector3(0, 0, PI / 2), 0.2, 0.0)

# ================================================================== Postures
func _bxf(h: float, pitch: float, roll: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch, 0, roll)), Vector3(0, h, 0))

## Hauteur du corps pour que le point local p soit à la hauteur y_target.
func _h_for(p: Vector3, pitch: float, y_target: float) -> float:
	return y_target - (p.y * cos(pitch) - p.z * sin(pitch))

func _posture_params(nm: String) -> Dictionary:
	var stand_h := L * 0.97 - hy
	var d := {"h": stand_h, "pitch": 0.0, "roll": 0.0, "hp": 0.0, "hy": 0.0, "hr": 0.0, "tail": 0.5, "ears": 0.0,
		"feet": [Vector3(-hx, 0, zf), Vector3(hx, 0, zf), Vector3(-hx, 0, zr), Vector3(hx, 0, zr)]}
	var hipF := Vector3(0, hy, zf)
	var hipR := Vector3(0, hy, zr)
	match nm:
		"sit":
			var p := -0.6
			var h := _h_for(hipF, p, L * 0.97)
			var xf := _bxf(h, p, 0)
			var rf := xf * hipR
			var ff := xf * hipF
			d.merge({"h": h, "pitch": p, "hp": 0.45, "tail": 0.0}, true)
			d["feet"] = [Vector3(-hx, 0, ff.z + 0.02), Vector3(hx, 0, ff.z + 0.02), Vector3(-hx * 1.2, 0, rf.z + L * 0.45), Vector3(hx * 1.2, 0, rf.z + L * 0.45)]
		"lie", "sleep":
			var h2 := by * 0.5 - hy * 0.2
			d.merge({"h": h2, "pitch": 0.04, "hp": 0.15, "tail": -0.2}, true)
			d["feet"] = [Vector3(-hx * 0.8, 0, zf + L * 1.0), Vector3(hx * 0.8, 0, zf + L * 1.0), Vector3(-hx * 1.6, 0, zr + L * 0.7), Vector3(hx * 1.6, 0, zr + L * 0.7)]
			if nm == "sleep":
				d.merge({"roll": 0.12, "hp": 0.55, "hy": 0.35, "hr": 0.25, "tail": -0.5, "ears": -0.6}, true)
		"beg":
			var p3 := -1.15
			var h3 := _h_for(hipR, p3, L * 0.3)
			var xf3 := _bxf(h3, p3, 0)
			var rf3 := xf3 * hipR
			var paw_l := xf3 * Vector3(-hx, hy - L * 0.3, zf + L * 0.45)
			var paw_r := xf3 * Vector3(hx, hy - L * 0.3, zf + L * 0.45)
			d.merge({"h": h3, "pitch": p3, "hp": 1.05, "tail": -0.3, "ears": 0.5}, true)
			d["feet"] = [paw_l, paw_r, Vector3(-hx * 1.3, 0, rf3.z + L * 0.5), Vector3(hx * 1.3, 0, rf3.z + L * 0.5)]
		"paw":
			d = _posture_params("sit")
			var xf4 := _bxf(d["h"], d["pitch"], 0)
			d["feet"][1] = xf4 * Vector3(hx * 1.1, hy + L * 0.1, zf + L * 0.95)
			d["hr"] = -0.15
			d["ears"] = 0.3
		"bow":
			var p5 := 0.38
			var h5 := _h_for(hipR, p5, L * 0.97)
			var xf5 := _bxf(h5, p5, 0)
			var ff5 := xf5 * hipF
			d.merge({"h": h5, "pitch": p5, "hp": -0.65, "tail": 1.1, "ears": 0.6}, true)
			d["feet"] = [Vector3(-hx * 1.2, 0, ff5.z + L * 0.8), Vector3(hx * 1.2, 0, ff5.z + L * 0.8), Vector3(-hx, 0, zr), Vector3(hx, 0, zr)]
		"jump":
			var xf6 := _bxf(stand_h, -0.15, 0)
			d.merge({"pitch": -0.15, "tail": 0.9, "ears": -0.3}, true)
			d["feet"] = [xf6 * Vector3(-hx, hy - L * 0.5, zf + L * 0.35), xf6 * Vector3(hx, hy - L * 0.5, zf + L * 0.35),
				xf6 * Vector3(-hx, hy - L * 0.5, zr - L * 0.35), xf6 * Vector3(hx, hy - L * 0.5, zr - L * 0.35)]
		"eat":
			d.merge({"hp": 0.95, "pitch": 0.08, "tail": 0.6}, true)
			d["h"] = _h_for(hipR, 0.08, L * 0.97)
		"sniff":
			d.merge({"hp": 0.8, "pitch": 0.05, "tail": 0.7, "ears": 0.2}, true)
		"stretch":
			d = _posture_params("bow")
			d["hp"] = -0.9
			d["tail"] = 0.6
		"sad":
			d.merge({"hp": 0.35, "tail": -0.4, "ears": -0.8}, true)
		"alert":
			d.merge({"hp": -0.25, "tail": 0.9, "ears": 1.0}, true)
		"stand_up":
			var p7 := -0.95
			var h7 := _h_for(hipR, p7, L * 0.97)
			var xf7 := _bxf(h7, p7, 0)
			d.merge({"h": h7, "pitch": p7, "hp": 0.8, "tail": 0.6, "ears": 0.6}, true)
			d["feet"] = [xf7 * Vector3(-hx, hy - L * 0.4, zf + L * 0.3), xf7 * Vector3(hx, hy - L * 0.4, zf + L * 0.3),
				Vector3(-hx, 0, (xf7 * hipR).z), Vector3(hx, 0, (xf7 * hipR).z)]
	return d

func set_posture(nm: String, speed: float = 4.0) -> void:
	if nm == posture and _blend >= 1.0:
		return
	posture = nm
	_from = _cur.duplicate(true)
	_to = _posture_params(nm)
	_blend = 0.0
	blend_speed = speed

func _lerp_params(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in a.keys():
		if k == "feet":
			var fa: Array = a["feet"]
			var fb: Array = b["feet"]
			out["feet"] = [fa[0].lerp(fb[0], t), fa[1].lerp(fb[1], t), fa[2].lerp(fb[2], t), fa[3].lerp(fb[3], t)]
		else:
			out[k] = lerpf(a[k], b[k], t)
	return out

# ================================================================== Boucle d'animation
func _process(delta: float) -> void:
	if not is_visible_in_tree() or body_pivot == null:
		return
	time += delta
	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta * blend_speed)
		var t := _blend * _blend * (3.0 - 2.0 * _blend)
		_cur = _lerp_params(_from, _to, t)
	_apply(_cur, delta)

func _apply(p: Dictionary, delta: float) -> void:
	var moving := move_speed > 0.03 and posture in ["stand", "alert", "sad", "sniff"]
	var stride := L * (0.55 + clampf(move_speed, 0.0, 3.0) * 0.18)
	if moving:
		_phase = fmod(_phase + delta * move_speed / maxf(stride, 0.05) * PI, TAU)
	var bob := sin(_phase * 2.0) * 0.012 * clampf(move_speed, 0.0, 1.5) if moving else 0.0
	var breathe := sin(time * (2.0 if posture != "sleep" else 1.0)) * 0.006
	var sh := sin(time * 40.0) * 0.25 * shake
	body_pivot.position = Vector3(0, p["h"] + bob + breathe + jump_y, 0)
	body_pivot.rotation = Vector3(p["pitch"] + (sin(_phase * 2.0) * 0.03 if moving else 0.0), 0, p["roll"] + sh)
	# Tête
	_head_extra = _head_extra.lerp(head_extra, minf(1.0, delta * 6.0))
	var sniff_bob := sin(time * 18.0) * 0.06 * sniff
	head_pivot.rotation = Vector3(-p["pitch"] * 0.85 + p["hp"] + _head_extra.x + sniff_bob, p["hy"] + _head_extra.y, p["hr"] + _head_extra.z - sh * 0.6)
	jaw.rotation.x = (sin(time * 14.0) * 0.5 + 0.5) * 0.35 * chew + _tongue * 0.18
	# Langue
	_tongue = lerpf(_tongue, tongue_out, minf(1.0, delta * 5.0))
	tongue.visible = _tongue > 0.05
	if tongue.visible:
		tongue.scale.z = (bd["snout"] as Vector2).x * 0.9 * (0.5 + _tongue * 0.6 + sin(time * 9.0) * 0.08 * _tongue)
	# Yeux / clignement
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink = 1.0
		_blink_t = randf_range(2.0, 5.0)
	_blink = maxf(0.0, _blink - delta * 7.0)
	var open := 1.0
	var ey := 0.0
	match expression:
		"happy": open = 0.95; ey = 0.012
		"closed": open = 0.08
		"sad": open = 0.6; ey = -0.008
		"focus": open = 0.85
	if expression != "closed":
		open *= 1.0 - _blink * 0.92
	# paupière haute : au repos elle couvre le haut de l'œil (regard doux)
	for lid in lids:
		lid.rotation.x = lerpf(PI * 0.52, -0.78, clampf(open, 0.0, 1.0))
	# paupière basse : remonte quand l'animal est content (yeux plissés)
	var low_a := 0.95
	match expression:
		"happy": low_a = 0.62
		"closed": low_a = 0.6
		"sad": low_a = 1.1
	for low in lower_lids:
		low.rotation.x = lerp_angle(low.rotation.x, PI + low_a, minf(1.0, delta * 8.0))
	# Oreilles
	var perk: float = p["ears"]
	for ep in ears:
		var sx: float = ep.get_meta("side")
		var et: String = bd["ear"]
		if et == "pointy" or et == "cat":
			ep.rotation = Vector3(-0.1 - perk * 0.15, 0, sx * (-0.35 - maxf(0.0, -perk) * 0.6 + sin(time * 3.0 + sx) * 0.02))
		else:
			ep.rotation = Vector3(-perk * 0.25 + sin(time * 2.0) * 0.03 + bob * 4.0, 0, sx * (0.25 + perk * 0.25))
	# Queue
	_wag_amp = lerpf(_wag_amp, wag_amp, minf(1.0, delta * 4.0))
	var tt: String = bd["tail"]
	for i in tail_segs.size():
		var s := tail_segs[i]
		var w := sin(time * wag_speed - i * 0.7) * _wag_amp * (0.6 if i == 0 else 0.45)
		var up := 0.0
		if i == 0:
			up = float(p["tail"]) * (0.4 if tt == "bushy" else 1.0) + (-0.55 if tt == "bushy" else 0.0)
			if tt == "curl":
				up += 1.0
		else:
			match tt:
				"curl": up = 0.85
				"cat": up = 0.3 * sin(time * 1.3 + i) + (0.25 if i == 1 else 0.0)
				"bushy": up = 0.12
				"whip": up = 0.1
				_: up = 0.05
		s.rotation = Vector3(up, w, 0)
	# Pattes (IK)
	var bx_inv := body_pivot.transform.affine_inverse()
	var feet: Array = p["feet"]
	for i in 4:
		var lg: Dictionary = legs[i]
		var target: Vector3 = feet[i]
		if moving and target.y < 0.02:
			var off := 0.0 if i == 0 or i == 3 else PI
			var ph := fmod(_phase + off, TAU)
			var lift := L * 0.28 * clampf(move_speed, 0.3, 1.5)
			if ph < PI:
				target.z += lerpf(stride * 0.5, -stride * 0.5, ph / PI)
			else:
				target.z += lerpf(-stride * 0.5, stride * 0.5, (ph - PI) / PI)
				target.y += sin(ph - PI) * lift
		if jump_y > 0.01 and posture != "jump":
			target.y += jump_y
		_ik(lg, bx_inv * target)

func _ik(lg: Dictionary, t_local: Vector3) -> void:
	var hip_l: Vector3 = lg["local"]
	var d := t_local - hip_l
	var dy := d.y
	var dz := d.z
	var a: float = lg["a"]
	var b: float = lg["b"]
	var dist := clampf(sqrt(dy * dy + dz * dz), 0.02, a + b - 0.002)
	var theta := atan2(dz, -dy)
	var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var cos_b := clampf((b * b + dist * dist - a * a) / (2.0 * b * dist), -1.0, 1.0)
	var alpha := acos(cos_a)
	var beta := acos(cos_b)
	var s := -1.0 if lg["front"] else 1.0
	var th_u := theta + s * alpha
	var th_l := theta - s * beta
	(lg["hip"] as Node3D).rotation = Vector3(-th_u, 0, 0)
	(lg["knee"] as Node3D).rotation = Vector3(th_u - th_l, 0, 0)

# ================================================================== Effets
func emote(txt: String, dur: float = 1.4) -> void:
	if emote_label == null:
		return
	if _emote_tw and _emote_tw.is_valid():
		_emote_tw.kill()
	emote_label.text = txt
	var base_y := L + by + hr * 2.6
	emote_label.position.y = base_y
	emote_label.modulate = Color(1, 1, 1, 0)
	_emote_tw = create_tween()
	_emote_tw.tween_property(emote_label, "modulate:a", 1.0, 0.15)
	_emote_tw.parallel().tween_property(emote_label, "position:y", base_y + 0.12, dur)
	_emote_tw.tween_property(emote_label, "modulate:a", 0.0, 0.25)

var dirt := 0.0
## Saleté visible sur le pelage (0..1).
func set_dirt(d: float) -> void:
	d = clampf(d, 0.0, 1.0)
	if absf(d - dirt) < 0.01 and fur_mat and fur_mat.get_shader_parameter("dirt") != null:
		return
	dirt = d
	if fur_mat:
		fur_mat.set_shader_parameter("dirt", d)
	for key in shell_mats.keys():
		for m in shell_mats[key]:
			(m as ShaderMaterial).set_shader_parameter("dirt", d)

## Distance du centre de l'animal au bout du museau.
func head_reach() -> float:
	return (bz * 0.46 + hr * 1.35 + (bd["snout"] as Vector2).x) * scale.x

func body_length() -> float:
	return (bz * 1.1 + hr * 1.4) * scale.x

func top_height() -> float:
	return (L + by + hr * 2.4) * scale.y
