class_name Places
extends RefCounted
## Lieux extérieurs du jeu, construits avec le kit de décor (sols peints, végétation sculptée,
## bâtiments fusionnés, eau, lointains). Les métadonnées de jeu (zones, points d'intérêt, obstacles)
## sont posées sur la racine du lieu, comme attendu par les activités.

const GREENS: Array[Color] = [Color(0.36, 0.60, 0.26), Color(0.40, 0.64, 0.28), Color(0.33, 0.56, 0.25), Color(0.44, 0.62, 0.26)]

static func _green(i: int) -> Color:
	return GREENS[absi(i) % GREENS.size()]

## Fontaine à boire en pierre (vasque + eau).
static func drinking_fountain(b: MeshBatch, root: Node3D, pos: Vector3) -> void:
	var xf := Transform3D(Basis(), pos)
	var st := Color(0.84, 0.82, 0.78)
	b.cyl("t:stone_wall:0.9", xf, 0.3, 0.24, 0.16, Vector3.ZERO, st, 10, 0.2)
	b.cyl("t:stone_wall:0.9", xf, 0.15, 0.12, 0.72, Vector3(0, 0.16, 0), st, 10)
	b.cyl("t:stone_wall:0.9", xf, 0.2, 0.34, 0.16, Vector3(0, 0.86, 0), st, 12)
	b.disc("glass", xf, 0.29, Vector3(0, 1.0, 0), Color(0.45, 0.72, 0.9), 12)
	WorldBuilder.obs_circle(root, pos, 0.34)
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		gp.shade(Vector2(pos.x, pos.z), 0.9, 0.5)

## Grande fontaine de place : bassin rond, colonne, vasque, eau animée.
static func plaza_fountain(b: MeshBatch, root: Node3D, pos: Vector3, r: float = 1.5) -> void:
	var xf := Transform3D(Basis(), pos)
	var st := Color(0.86, 0.84, 0.80)
	for i in 20:
		var a := TAU * i / 20.0
		var seg := Transform3D(Basis(Vector3.UP, -a), pos + Vector3(cos(a) * r, 0, sin(a) * r))
		b.box("t:stone_wall:0.8", seg, Vector3(0.3, 0.5, TAU * r / 20.0 + 0.04), Vector3(0, 0.25, 0), st, 0.2)
		b.box("t:stone_wall:0.8", seg, Vector3(0.42, 0.08, TAU * r / 20.0 + 0.05), Vector3(0, 0.54, 0), st.lightened(0.05))
	b.cyl("t:stone_wall:0.8", xf, 0.34, 0.24, 1.25, Vector3.ZERO, st, 10)
	b.cyl("t:stone_wall:0.8", xf, 0.25, 0.72, 0.2, Vector3(0, 1.25, 0), st, 14)
	b.cyl("t:stone_wall:0.8", xf, 0.12, 0.09, 0.45, Vector3(0, 1.45, 0), st, 8)
	b.disc("glass", xf, 0.68, Vector3(0, 1.42, 0), Color(0.5, 0.76, 0.92), 14)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r - 0.12
	cm.bottom_radius = r - 0.12
	cm.height = 0.02
	cm.radial_segments = 28
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = Kit.water_mat({"radius": r - 0.12, "center": Vector2(pos.x, pos.z), "scale": 2.2})
	mi.position = pos + Vector3(0, 0.4, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	WorldBuilder.obs_circle(root, pos, r + 0.2)
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		gp.shade(Vector2(pos.x, pos.z), r + 1.2, 0.5)

## Kiosque à musique : estrade octogonale, colonnes et toit pointu.
static func gazebo(b: MeshBatch, root: Node3D, pos: Vector3) -> void:
	var xf := Transform3D(Basis(), pos)
	var white := Color(0.97, 0.96, 0.93)
	b.cyl("t:wood_planks:0.5", xf, 2.0, 2.0, 0.35, Vector3.ZERO, Color(0.86, 0.78, 0.66), 8, 0.25)
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		var p := Vector3(cos(a) * 1.75, 0.35, sin(a) * 1.75)
		b.cyl("flat", xf, 0.07, 0.06, 2.2, p, white, 6)
		if i != 1:
			var a2 := TAU * (i + 1.5) / 8.0
			var p2 := Vector3(cos(a2) * 1.75, 0.35, sin(a2) * 1.75)
			var mid := (p + p2) * 0.5
			var rf := xf * Transform3D(Basis(Vector3.UP, atan2(-(p2.z - p.z), p2.x - p.x)), mid)
			b.box("flat", rf, Vector3(p.distance_to(p2), 0.06, 0.05), Vector3(0, 0.75, 0), white)
			b.box("flat", rf, Vector3(p.distance_to(p2), 0.06, 0.05), Vector3(0, 0.35, 0), white)
	b.cyl("t:roof_tiles:0.9", xf, 2.3, 0.08, 1.2, Vector3(0, 2.55, 0), Color(0.42, 0.56, 0.52), 8, 0.2, false)
	b.cyl("metal", xf, 0.05, 0.02, 0.5, Vector3(0, 3.7, 0), Color(0.9, 0.78, 0.4), 6)
	WorldBuilder.obs_circle(root, pos, 2.1)
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		gp.disc(Vector2(pos.x, pos.z), 2.6, 0)
		gp.shade(Vector2(pos.x, pos.z), 3.2, 0.55)

## Palmier : tronc courbe et palmes retombantes.
static func palm(b: MeshBatch, root: Node3D, pos: Vector3, h: float, lean: float) -> void:
	var trunk := Color(0.70, 0.56, 0.40)
	var segs := 7
	var top := pos
	for i in segs:
		var t := float(i) / segs
		var p := pos + Vector3(sin(lean) * t * t * h * 0.35, t * h, cos(lean) * t * t * h * 0.15)
		b.cyl("t:bark:0.9", Transform3D(Basis(), p), 0.17 - t * 0.07, 0.16 - t * 0.07, h / segs + 0.03, Vector3.ZERO, trunk.darkened(0.08 * (i % 2)), 8, 0.0, false)
		top = p + Vector3(0, h / segs, 0)
	for k in 9:
		var a := TAU * k / 9.0 + lean
		var g := Color(0.30, 0.56, 0.26).lightened((k % 3) * 0.05)
		var base := Transform3D(Basis(Vector3.UP, a), top)
		b.box("flat", base * Transform3D(Basis(Vector3(0, 0, 1), 0.38), Vector3(0.42, 0.14, 0)), Vector3(0.9, 0.03, 0.34), Vector3.ZERO, g, 0.0, false)
		b.box("flat", base * Transform3D(Basis(Vector3(0, 0, 1), -0.35), Vector3(1.16, 0.16, 0)), Vector3(0.8, 0.03, 0.26), Vector3.ZERO, g.darkened(0.06), 0.0, false)
		b.box("flat", base * Transform3D(Basis(Vector3(0, 0, 1), -0.95), Vector3(1.66, -0.2, 0)), Vector3(0.6, 0.03, 0.15), Vector3.ZERO, g.darkened(0.12), 0.0, false)
	for k in 3:
		b.cyl("flat", Transform3D(Basis(), top + Vector3(cos(k * 2.1) * 0.14, -0.22, sin(k * 2.1) * 0.14)), 0.09, 0.07, 0.16, Vector3.ZERO, Color(0.45, 0.32, 0.2), 6)
	WorldBuilder.obs_circle(root, pos, 0.25)
	var gp: GroundPaint = root.get_meta("ground_paint", null)
	if gp:
		gp.shade(Vector2(top.x, top.z), 1.6, 0.4)

## Champignons de sous-bois.
static func mushrooms(b: MeshBatch, pos: Vector3, n: int, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in n:
		var p := pos + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		var s := rng.randf_range(0.7, 1.3)
		var xf := Transform3D(Basis(), p)
		b.cyl("flat", xf, 0.022 * s, 0.028 * s, 0.1 * s, Vector3.ZERO, Color(0.96, 0.93, 0.86), 6, 0.0, false)
		b.cyl("flat", xf, 0.085 * s, 0.01, 0.06 * s, Vector3(0, 0.09 * s, 0), Color(0.82, 0.26, 0.22) if i % 3 else Color(0.82, 0.6, 0.34), 8, 0.15, false)

## Pont de pierre (axe X local) : tablier et parapets.
static func stone_bridge(b: MeshBatch, root: Node3D, pos: Vector3, rot_y: float, length: float, width: float = 2.2) -> void:
	var xf := Transform3D(Basis(Vector3.UP, rot_y), pos)
	var st := Color(0.84, 0.81, 0.76)
	b.box("t:cobble:0.6", xf, Vector3(length, 0.06, width), Vector3(0, 0.03, 0), Color(0.95, 0.93, 0.9), 0.0, false)
	for s in [-1.0, 1.0]:
		b.box("t:stone_wall:0.7", xf, Vector3(length + 0.4, 0.62, 0.26), Vector3(0, 0.42, s * (width * 0.5 + 0.08)), st, 0.25)
		b.box("t:stone_wall:0.7", xf, Vector3(length + 0.5, 0.08, 0.34), Vector3(0, 0.76, s * (width * 0.5 + 0.08)), st.lightened(0.06))
		for e in [-1.0, 1.0]:
			b.box("t:stone_wall:0.7", xf, Vector3(0.4, 0.95, 0.4), Vector3(e * (length * 0.5 + 0.2), 0.47, s * (width * 0.5 + 0.08)), st, 0.2)
	b.box("t:stone_wall:0.7", xf, Vector3(0.7, 0.5, width + 0.3), Vector3(0, -0.2, 0), st.darkened(0.2), 0.0, false)

## Passerelle en bois (axe X local).
static func wood_bridge(b: MeshBatch, pos: Vector3, rot_y: float, length: float, width: float = 1.7) -> void:
	var xf := Transform3D(Basis(Vector3.UP, rot_y), pos)
	var wood := Color(0.78, 0.60, 0.42)
	var n := int(length / 0.26)
	for i in n:
		b.box("t:wood_planks:0.5", xf, Vector3(0.23, 0.05, width), Vector3(-length * 0.5 + (i + 0.5) * length / n, 0.035, 0), wood.darkened((i % 3) * 0.04), 0.0, false)
	for s in [-1.0, 1.0]:
		b.box("t:wood_planks:0.5", xf, Vector3(length, 0.08, 0.08), Vector3(0, 0.75, s * width * 0.5), wood.darkened(0.12))
		for e in 3:
			b.box("t:wood_planks:0.5", xf, Vector3(0.1, 0.8, 0.1), Vector3(-length * 0.5 + 0.1 + e * (length - 0.2) / 2.0, 0.4, s * width * 0.5), wood.darkened(0.18), 0.15)

## Petits spectateurs colorés (silhouettes simples) sur un gradin.
static func crowd(b: MeshBatch, xf: Transform3D, cols: int, rows: int, step: Vector3, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for row in rows:
		for i in cols:
			if rng.randf() > 0.78:
				continue
			var p := Vector3(-cols * step.x * 0.5 + (i + 0.5) * step.x, row * step.y, -row * step.z)
			var c := Color.from_hsv(rng.randf(), 0.45, 0.9)
			b.cyl("flat", xf, 0.16, 0.13, 0.38, p, c, 6, 0.15, true)
			b.cyl("flat", xf, 0.1, 0.1, 0.2, p + Vector3(0, 0.4, 0), [Color(0.96, 0.82, 0.68), Color(0.82, 0.62, 0.46), Color(0.62, 0.44, 0.32)][rng.randi() % 3], 6)

## Guirlande de fanions entre deux points.
static func bunting(b: MeshBatch, a: Vector3, e: Vector3, n: int = 14) -> void:
	var pal: Array = [Color(0.95, 0.38, 0.36), Color(1.0, 0.82, 0.32), Color(0.38, 0.68, 0.86), Color(0.5, 0.78, 0.48), Color(0.95, 0.6, 0.8)]
	var d := e - a
	var right := Vector3(d.x, 0, d.z).normalized()
	for i in n:
		var t := (i + 0.5) / n
		var p := a.lerp(e, t) - Vector3(0, sin(t * PI) * 0.35, 0)
		var c: Color = pal[i % pal.size()]
		b.tri("flat", p - right * 0.14, p + right * 0.14, p - Vector3(0, 0.3, 0), c, right)
		b.tri("flat", p + right * 0.14, p - right * 0.14, p - Vector3(0, 0.3, 0), c, -right)

# ================================================================== Parc
static func park(r: Node3D, _q: int) -> void:
	r.set_meta("look", "noon")
	var gp := Kit.ground(r, 130.0, {"rect": Rect2(-22, -24, 44, 44), "r": "dirt", "g": "pavers", "uv_r": 0.62, "tint_r": Color(1.0, 0.95, 0.88)})
	var b := MeshBatch.new()
	# Allées de terre battue : grande boucle + accès
	var loop: Array[Vector2] = [Vector2(6.2, 3.2), Vector2(7.6, -1.5), Vector2(6.0, -6.6), Vector2(1.0, -9.8), Vector2(-4.5, -9.0), Vector2(-8.6, -5.5), Vector2(-8.8, 0.6), Vector2(-5.0, 3.6), Vector2(0.5, 4.4)]
	for i in loop.size():
		gp.path(loop[i], loop[(i + 1) % loop.size()], 1.5, 0)
	gp.path(Vector2(6.2, 3.2), Vector2(9.5, 8.0), 1.4, 0)
	# Étang aux nénuphars
	Kit.pond(r, gp, Vector3(-5.5, 0, -1.0), 1.85, {"shallow": Color(0.44, 0.74, 0.78), "deep": Color(0.18, 0.44, 0.58)})
	var pxf := Transform3D(Basis(), Vector3(-5.5, 0.03, -1.0))
	for i in 6:
		var a := i * 1.13
		var pp := Vector3(cos(a) * (0.5 + (i % 3) * 0.35), 0, sin(a) * (0.5 + (i % 2) * 0.5))
		b.disc("flat", pxf, 0.17, pp, Color(0.30, 0.58, 0.28), 8)
		if i % 2 == 0:
			b.cyl("flat", pxf, 0.06, 0.01, 0.07, pp + Vector3(0.03, 0, 0), Color(1.0, 0.78, 0.86), 6, 0.0, false)
	for i in 5:
		Kit.rock(r, Vector3(-5.5 + cos(i * 1.3 + 0.4) * 2.2, 0, -1.0 + sin(i * 1.3 + 0.4) * 2.2), 0.26 + (i % 2) * 0.12, "a" if i % 2 else "b", false)
	# Kiosque, fontaine à boire, bancs, réverbères
	gazebo(b, r, Vector3(9.5, 0, -8.5))
	drinking_fountain(b, r, Vector3(4.6, 0, 1.2))
	r.set_meta("fountain", Vector3(4.6, 0, 1.2))
	Kit.bench(r, Vector3(-3.4, 0, 4.9), PI)
	Kit.bench(r, Vector3(8.9, 0, -1.6), -PI * 0.5)
	Kit.bench(r, Vector3(-9.9, 0, -2.6), PI * 0.5)
	for lp in [Vector3(5.2, 0, 4.2), Vector3(8.4, 0, -5.4), Vector3(-9.6, 0, 1.6), Vector3(-2.0, 0, -10.6)]:
		Kit.lamp(b, r, lp)
	# Arbres : ceinture boisée, zone de lancer dégagée (x de -4 à 4, z de -9 à 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var spots: Array[Vector3] = [Vector3(-11.5, 0, -8.5), Vector3(-12.5, 0, -1.5), Vector3(-11.0, 0, 5.0), Vector3(-6.0, 0, -12.5), Vector3(0.5, 0, -13.5),
		Vector3(6.0, 0, -12.5), Vector3(12.5, 0, -3.5), Vector3(12.0, 0, 3.0), Vector3(-6.5, 0, 7.5), Vector3(3.0, 0, 8.0), Vector3(-15.0, 0, -12.0),
		Vector3(14.5, 0, -11.0), Vector3(-16.0, 0, 3.0), Vector3(16.0, 0, 6.0), Vector3(-1.5, 0, -17.0), Vector3(9.0, 0, -16.0), Vector3(-10.0, 0, -16.0)]
	for i in spots.size():
		Kit.tree(r, spots[i], rng.randf_range(4.4, 6.4), ["a", "b", "c"][i % 3], _green(i), i, spots[i].length() < 14.0)
	for bp in [Vector3(-9.8, 0, -8.2), Vector3(10.6, 0, 0.8), Vector3(-7.6, 0, 5.6), Vector3(4.0, 0, -11.6), Vector3(-10.6, 0, 2.6)]:
		Kit.bush(r, bp, rng.randf_range(0.7, 1.0), _green(int(bp.x)))
	# Massifs de fleurs
	for fc in [Vector2(5.6, -3.4), Vector2(-7.4, -7.4), Vector2(-2.4, 5.6)]:
		gp.soft(fc, 1.3, 0, 0.75)
		Kit.flowers(r, Rect2(fc.x - 0.9, fc.y - 0.9, 1.8, 1.8), 70, int(fc.x * 7.0) + 3)
	# Barrière du parc au loin
	for seg in [[Vector3(-18, 0, -19), Vector3(18, 0, -19)], [Vector3(-18, 0, -19), Vector3(-18, 0, 12)], [Vector3(18, 0, -19), Vector3(18, 0, 12)]]:
		Kit.fence(b, seg[0], seg[1], "rail", Color(0.8, 0.64, 0.46))
	Kit.house(b, r, Vector3(-15.0, 0, -22.5), 0.2, {"w": 5.6, "d": 3.8, "floors": 1, "wall_c": Color(0.96, 0.9, 0.78), "roof_c": Color(0.5, 0.42, 0.4)})
	Kit.house(b, r, Vector3(13.0, 0, -23.0), -0.25, {"w": 5.0, "d": 3.6, "floors": 2, "timber": true, "roof_c": Color(0.76, 0.4, 0.32)})
	b.commit(r)
	var keep := func(p: Vector2) -> bool: return not Rect2(-3.6, -3.1, 7.2, 5.7).has_point(p)
	Kit.grass(r, Rect2(-16, -17, 32, 27), 3200, 21, keep)
	Kit.flowers(r, Rect2(-15, -16, 30, 25), 260, 22, keep)
	Kit.backdrop(r, {"radius": 38.0})
	Kit.ambient(r, "pollen", Rect2(-8, -8, 16, 12))
	r.set_meta("bounds", Rect2(-3.5, -3.0, 7.0, 5.5))
	r.set_meta("walk_area", Rect2(-8, -8, 16, 12))
	r.set_meta("spots_area", Rect2(-4, -3, 8, 5))
	r.set_meta("throw_area", Rect2(-4, -9, 8, 9))

# ================================================================== Forêt
static func forest(r: Node3D, _q: int) -> void:
	r.set_meta("look", "forest")
	r.set_meta("fog_begin", 9.0)
	r.set_meta("fog_end", 52.0)
	var gp := Kit.ground(r, 120.0, {"rect": Rect2(-20, -22, 40, 40), "base": "forest_floor", "r": "dirt", "g": "grass", "uv_base": 0.3, "uv_r": 0.62,
		"tint_r": Color(0.86, 0.78, 0.68), "tint_g": Color(0.8, 0.95, 0.7), "tint_var": Color(0.92, 1.08, 0.86), "macro_amount": 0.36})
	var b := MeshBatch.new()
	# Sentier sinueux et clairières moussues
	var trail: Array[Vector2] = [Vector2(1.6, 10.0), Vector2(0.2, 4.5), Vector2(-0.6, 0.0), Vector2(-0.2, -4.5), Vector2(-1.4, -9.0), Vector2(-0.6, -14.0), Vector2(1.5, -20.0)]
	for i in trail.size() - 1:
		gp.path(trail[i], trail[i + 1], 1.5, 0)
	for mc in [Vector2(-2.6, 1.2), Vector2(2.6, -1.4), Vector2(-4.5, -5.5), Vector2(4.6, 2.6), Vector2(0.5, -11.0)]:
		gp.soft(mc, 2.6, 1, 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < 46 and tries < 400:
		tries += 1
		var p := Vector3(rng.randf_range(-17, 17), 0, rng.randf_range(-19, 9))
		var p2 := Vector2(p.x, p.z)
		if Kit.gp_painted(gp, p2, 0.9) and absf(p.x) < 3.0:
			continue
		if Rect2(-3.6, -3.0, 7.2, 5.8).has_point(p2) or Rect2(-2.4, -9.5, 4.4, 9.8).has_point(p2) or (p.z > 1.5 and absf(p.x) < 6.5):
			continue
		var close := false
		for o in placed:
			if o.distance_to(p2) < 2.1:
				close = true
		if close:
			continue
		placed.append(p2)
		var obstacle := Rect2(-9, -10, 18, 15).has_point(p2)
		if rng.randf() < 0.68:
			Kit.pine(r, p, rng.randf_range(4.6, 7.5), Color(0.20, 0.42, 0.26).lightened(rng.randf() * 0.1), obstacle)
		else:
			Kit.tree(r, p, rng.randf_range(4.8, 6.6), "b" if rng.randf() < 0.5 else "a", Color(0.33, 0.55, 0.26), placed.size(), obstacle)
	Kit.log_prop(r, Vector3(-2.7, 0, -1.7), 0.4, 0.9)
	Kit.log_prop(r, Vector3(2.9, 0, 0.9), -0.9, 0.75)
	Kit.stump(r, Vector3(-3.0, 0, 1.9), 0.9)
	Kit.stump(r, Vector3(3.3, 0, -3.4), 1.1)
	Kit.rock(r, Vector3(2.5, 0, -2.3), 0.55, "a")
	Kit.rock(r, Vector3(-3.3, 0, -0.2), 0.42, "b")
	Kit.rock(r, Vector3(5.2, 0, -6.0), 0.9, "b")
	Kit.rock(r, Vector3(-6.0, 0, 2.0), 0.7, "a")
	for i in 9:
		mushrooms(b, Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-7, 3)), rng.randi_range(2, 4), 500 + i)
	for bp in [Vector3(-5.2, 0, -2.6), Vector3(4.9, 0, 0.6), Vector3(-4.6, 0, 3.2), Vector3(3.6, 0, -8.4)]:
		Kit.bush(r, bp, rng.randf_range(0.6, 0.9), Color(0.26, 0.48, 0.26))
	b.commit(r)
	var keep := func(p: Vector2) -> bool: return not Rect2(-3.3, -2.5, 6.6, 4.8).has_point(p)
	# Fougères (touffes sombres et larges) et herbes de sous-bois
	Kit.grass(r, Rect2(-14, -16, 28, 24), 1500, 61, keep, Color(0.42, 0.62, 0.36), Vector2(1.0, 1.8))
	Kit.grass(r, Rect2(-14, -16, 28, 24), 1400, 62, keep, Color(0.50, 0.66, 0.38), Vector2(0.5, 0.9))
	Kit.flowers(r, Rect2(-10, -12, 20, 18), 120, 63, keep, [Color(1, 1, 1), Color(0.78, 0.66, 1.0), Color(0.62, 0.78, 1.0)])
	Kit.backdrop(r, {"radius": 30.0, "near": Color(0.22, 0.42, 0.26), "far": Color(0.48, 0.66, 0.56), "height": 1.4})
	Kit.ambient(r, "leaves", Rect2(-7, -7, 14, 11), 3.5)
	Kit.ambient(r, "pollen", Rect2(-6, -6, 12, 10))
	r.set_meta("bounds", Rect2(-3.2, -2.6, 6.4, 5.0))
	r.set_meta("walk_area", Rect2(-8, -9, 16, 13))
	r.set_meta("spots_area", Rect2(-3.2, -2.6, 6.4, 4.4))
	r.set_meta("throw_area", Rect2(-1.8, -9, 3.2, 9))

# ================================================================== Plage
static func beach(r: Node3D, _q: int) -> void:
	r.set_meta("look", "golden")
	var gp := Kit.ground(r, 130.0, {"rect": Rect2(-24, -14, 48, 48), "base": "sand", "r": "sand", "g": "grass", "uv_base": 0.3, "uv_r": 0.3,
		"tint_base": Color(1.10, 1.08, 1.06), "tint_var": Color(1.0, 0.97, 0.92), "tint_r": Color(0.80, 0.76, 0.72), "tint_g": Color(0.86, 0.9, 0.62), "macro_amount": 0.2})
	var b := MeshBatch.new()
	# Sable mouillé le long de l'eau, dunes herbeuses à l'arrière
	gp.area(Rect2(-24, -14, 48, 10.6), 0)
	for i in 9:
		gp.soft(Vector2(-20.0 + i * 5.0, 9.5 + sin(i * 1.7) * 1.5), 5.0, 1, 0.95)
	gp.area(Rect2(-24, 12.5, 48, 22), 1)
	Kit.sea(r, Rect2(-70, -74, 140, 70.5), -3.5, {"shallow": Color(0.42, 0.80, 0.84), "deep": Color(0.12, 0.42, 0.70), "scale": 0.8})
	# Parasol et serviettes
	var px := Transform3D(Basis(Vector3(0, 0, 1), 0.09), Vector3(-2.6, 0, -2.0))
	b.cyl("flat", px, 0.03, 0.03, 2.25, Vector3.ZERO, Color(0.96, 0.96, 0.94), 6)
	for i in 10:
		var a0 := TAU * i / 10.0
		var a1 := TAU * (i + 1) / 10.0
		var c := Color(0.94, 0.38, 0.34) if i % 2 == 0 else Color(1.0, 0.98, 0.94)
		var apex := Vector3(0, 2.5, 0)
		var e0 := Vector3(cos(a0) * 1.35, 2.05, sin(a0) * 1.35)
		var e1 := Vector3(cos(a1) * 1.35, 2.05, sin(a1) * 1.35)
		b.tri("flat", px * e1, px * apex, px * e0, c, Vector3.RIGHT)
		b.tri("flat", px * e0, px * apex, px * e1, c.darkened(0.25), Vector3.RIGHT)
	WorldBuilder.obs_circle(r, Vector3(-2.6, 0, -2.0), 0.12)
	gp.shade(Vector2(-2.3, -2.0), 1.7, 0.5)
	var tx := Transform3D(Basis(Vector3.UP, 0.3), Vector3(-1.8, 0.012, -1.5))
	b.box("t:fabric:1.5", tx, Vector3(0.9, 0.02, 1.7), Vector3.ZERO, Color(0.36, 0.62, 0.9), 0.0, false)
	for sx in [-0.3, 0.0, 0.3]:
		b.box("t:fabric:1.5", tx, Vector3(0.12, 0.022, 1.7), Vector3(sx, 0.001, 0), Color(1, 1, 1), 0.0, false)
	# Palmiers
	palm(b, r, Vector3(4.6, 0, -2.4), 3.6, 0.6)
	palm(b, r, Vector3(6.2, 0, 0.6), 4.2, -0.9)
	palm(b, r, Vector3(-5.6, 0, 1.2), 3.9, 2.4)
	palm(b, r, Vector3(-9.5, 0, 4.5), 4.4, 1.0)
	palm(b, r, Vector3(10.5, 0, 5.0), 4.0, -2.0)
	# Rochers, coquillages, château de sable
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 12:
		var north := i % 2 == 0
		var rp := Vector3(rng.randf_range(-11, 11), 0, rng.randf_range(-4.6, -3.3) if north else rng.randf_range(3.4, 6.5))
		Kit.rock(r, rp, rng.randf_range(0.3, 0.75), "a" if i % 3 else "b", not north and rp.z < 5.5, Color(0.86, 0.82, 0.76))
	for i in 26:
		var sp := Vector3(rng.randf_range(-9, 9), 0, rng.randf_range(-3.3, 4.5))
		var sx2 := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), sp)
		b.cyl("flat", sx2, 0.05, 0.012, 0.035, Vector3.ZERO, [Color(1, 0.86, 0.82), Color(1, 0.98, 0.94), Color(0.96, 0.78, 0.62)][i % 3], 6, 0.2, false)
	var cx := Transform3D(Basis(), Vector3(2.2, 0, 1.8))
	var sc := Color(0.92, 0.84, 0.68)
	b.cyl("t:sand:1.0", cx, 0.42, 0.36, 0.3, Vector3.ZERO, sc, 10, 0.15)
	b.cyl("t:sand:1.0", cx, 0.2, 0.17, 0.32, Vector3(0, 0.3, 0), sc, 10)
	for k in 4:
		b.cyl("t:sand:1.0", cx, 0.1, 0.09, 0.42, Vector3(cos(k * PI * 0.5 + 0.8) * 0.36, 0, sin(k * PI * 0.5 + 0.8) * 0.36), sc, 8)
		b.cyl("t:sand:1.0", cx, 0.11, 0.01, 0.12, Vector3(cos(k * PI * 0.5 + 0.8) * 0.36, 0.42, sin(k * PI * 0.5 + 0.8) * 0.36), sc.lightened(0.05), 8, 0.0, false)
	b.box("flat", cx, Vector3(0.02, 0.2, 0.02), Vector3(0, 0.72, 0), Color(0.5, 0.36, 0.26))
	b.box("flat", cx, Vector3(0.14, 0.09, 0.01), Vector3(0.08, 0.78, 0), Color(0.95, 0.38, 0.36))
	WorldBuilder.obs_circle(r, Vector3(2.2, 0, 1.8), 0.48)
	gp.shade(Vector2(2.2, 1.8), 0.9, 0.45)
	# Ponton en bois qui avance dans la mer
	var jx := Transform3D(Basis(), Vector3(9.0, 0, -3.0))
	var wood := Color(0.74, 0.58, 0.42)
	for i in 30:
		b.box("t:wood_planks:0.5", jx, Vector3(1.8, 0.07, 0.3), Vector3(0, 0.42, 0.6 - i * 0.33), wood.darkened((i % 4) * 0.04), 0.0, false)
	for i in 6:
		for s in [-0.85, 0.85]:
			b.cyl("t:bark:0.8", jx, 0.09, 0.08, 1.3, Vector3(s, -0.4, 0.4 - i * 1.9), wood.darkened(0.3), 6)
	WorldBuilder.obs_rect(r, Vector3(9.0, 0, -3.3), 2.0, 1.6)
	# Cabines de plage rayées
	for i in 3:
		var hx := Transform3D(Basis(Vector3.UP, -0.15), Vector3(-10.5 + i * 2.1, 0, 7.4 + i * 0.25))
		var hc: Color = [Color(0.36, 0.68, 0.84), Color(0.96, 0.78, 0.36), Color(0.92, 0.46, 0.44)][i]
		for k in 6:
			b.box("flat", hx, Vector3(0.3, 2.0, 1.7), Vector3(-0.75 + k * 0.3, 1.0, 0), hc if k % 2 == 0 else Color(1, 1, 1), 0.12)
		b.gable_roof("t:roof_tiles:0.9", hx * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), 2.1, 2.2, 0.7, Vector3(0, 2.0, 0), hc.darkened(0.3))
		b.box("t:wood_planks:0.6", hx, Vector3(0.7, 1.6, 0.05), Vector3(0, 0.85, 0.86), Color(0.95, 0.95, 0.92))
		var hp: Vector3 = hx.origin
		gp.shade(Vector2(hp.x, hp.z), 1.9, 0.5)
	# Phare sur son îlot, voilier au large
	var lx := Transform3D(Basis(), Vector3(-17.0, 0, -15.0))
	Kit.rock(r, Vector3(-17.0, -0.3, -15.0), 4.2, "a", false, Color(0.74, 0.72, 0.68))
	for k in 5:
		b.cyl("flat", lx, 1.05 - k * 0.11, 0.94 - k * 0.11, 1.5, Vector3(0, 1.6 + k * 1.5, 0), Color(0.92, 0.3, 0.28) if k % 2 == 0 else Color(0.98, 0.97, 0.94), 12, 0.1, false)
	b.cyl("metal", lx, 0.75, 0.75, 0.12, Vector3(0, 9.1, 0), Color(0.25, 0.27, 0.3), 12)
	b.cyl("emit", lx, 0.42, 0.42, 0.7, Vector3(0, 9.2, 0), Color(1.0, 0.95, 0.75), 10)
	b.cyl("flat", lx, 0.62, 0.05, 0.6, Vector3(0, 9.9, 0), Color(0.86, 0.28, 0.26), 10, 0.0, false)
	var bx := Transform3D(Basis(Vector3.UP, 0.5), Vector3(12.0, 0.05, -22.0))
	b.box("t:wood_planks:0.5", bx, Vector3(2.6, 0.5, 0.9), Vector3(0, 0.2, 0), Color(0.95, 0.94, 0.9), 0.3)
	b.cyl("flat", bx, 0.04, 0.03, 3.2, Vector3(0.1, 0.4, 0), Color(0.6, 0.45, 0.32), 6)
	b.tri("flat", bx * Vector3(0.16, 0.7, 0), bx * Vector3(0.16, 3.5, 0), bx * Vector3(1.5, 0.7, 0), Color(1, 1, 1), Vector3.RIGHT)
	b.tri("flat", bx * Vector3(1.5, 0.7, 0), bx * Vector3(0.16, 3.5, 0), bx * Vector3(0.16, 0.7, 0), Color(0.94, 0.94, 0.96), Vector3.RIGHT)
	b.commit(r)
	# Oyats (herbes de dune) et fleurs de l'arrière-plage
	var dune := func(p: Vector2) -> bool: return p.y > 7.0 + sin(p.x * 0.5) * 1.2
	Kit.grass(r, Rect2(-20, 6, 40, 16), 1500, 31, dune, Color(0.74, 0.80, 0.50), Vector2(0.8, 1.5))
	Kit.flowers(r, Rect2(-18, 9, 36, 12), 120, 32, dune, [Color(1, 0.9, 0.5), Color(1, 1, 1), Color(1, 0.66, 0.7)])
	Kit.backdrop(r, {"radius": 40.0, "near": Color(0.52, 0.64, 0.38), "far": Color(0.78, 0.76, 0.70), "gap_from": 3.25, "gap_to": 6.2, "height": 0.8})
	Kit.ambient(r, "spray", Rect2(-8, -5, 16, 2), 0.6)
	r.set_meta("bounds", Rect2(-3.5, -3.2, 7.0, 5.5))
	r.set_meta("walk_area", Rect2(-9, -3.6, 18, 9))
	r.set_meta("spots_area", Rect2(-4, -3, 8, 5))
	r.set_meta("throw_area", Rect2(-4, -3.8, 8, 3.8))

# ================================================================== Terrain d'entraînement et de concours
static func center(r: Node3D, _q: int) -> void:
	r.set_meta("look", "afternoon")
	var gp := Kit.ground(r, 120.0, {"rect": Rect2(-20, -22, 40, 40), "r": "pavers", "g": "sand", "uv_g": 0.3, "tint_g": Color(1.08, 1.04, 0.98), "tint_r": Color(0.94, 0.9, 0.86)})
	var b := MeshBatch.new()
	var ac := Vector3(0, 0, -2.5)
	gp.disc(Vector2(ac.x, ac.z), 6.15, 1)
	gp.path(Vector2(0, 3.6), Vector2(0, 9.0), 2.2, 0)
	# Lice blanche à lisse rouge, ouverte côté joueur
	var white := Color(0.98, 0.97, 0.95)
	var n := 36
	for i in n:
		var a := TAU * i / n
		var a1 := TAU * (i + 1) / n
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.34 or absf(wrapf(a1 - PI * 0.5, -PI, PI)) < 0.34:
			continue
		var p0 := ac + Vector3(cos(a) * 6.25, 0, sin(a) * 6.25)
		var p1 := ac + Vector3(cos(a1) * 6.25, 0, sin(a1) * 6.25)
		var seg := Transform3D(Basis(Vector3.UP, atan2(-(p1.z - p0.z), p1.x - p0.x)), (p0 + p1) * 0.5)
		var sl := p0.distance_to(p1)
		b.box("flat", Transform3D(Basis(), p0), Vector3(0.09, 0.7, 0.09), Vector3(0, 0.35, 0), white, 0.15)
		b.box("flat", seg, Vector3(sl, 0.07, 0.05), Vector3(0, 0.32, 0), white)
		b.box("flat", seg, Vector3(sl + 0.02, 0.08, 0.07), Vector3(0, 0.66, 0), Color(0.92, 0.32, 0.3))
	# Tribune couverte et public
	var gx := Transform3D(Basis(), Vector3(0, 0, -10.2))
	for row in 4:
		b.box("t:wood_planks:0.5", gx, Vector3(13.0, 0.45, 0.9), Vector3(0, 0.22 + row * 0.45, -row * 0.9), Color(0.62, 0.72, 0.86), 0.12, false)
	crowd(b, gx * Transform3D(Basis(), Vector3(0, 0.45, 0)), 15, 4, Vector3(0.84, 0.45, 0.9), 5)
	for sx in [-6.5, 0.0, 6.5]:
		b.box("flat", gx, Vector3(0.16, 4.4, 0.16), Vector3(sx, 2.2, -3.4), white, 0.1)
		b.box("flat", gx, Vector3(0.14, 3.2, 0.14), Vector3(sx, 1.6, 0.6), white, 0.1)
	var rf := gx * Transform3D(Basis(Vector3.RIGHT, 0.26), Vector3(0, 3.95, -1.4))
	for i in 13:
		b.box("flat", rf, Vector3(1.04, 0.06, 4.6), Vector3(-6.24 + i * 1.04, 0, 0), Color(0.36, 0.56, 0.78) if i % 2 == 0 else Color(1, 1, 1), 0.0, false)
	WorldBuilder.obs_rect(r, Vector3(0, 0, -11.6), 13.4, 4.4)
	gp.area(Rect2(-7.0, -14.4, 14.0, 5.2), 2)
	bunting(b, Vector3(-7.0, 3.3, -8.6), Vector3(7.0, 3.3, -8.6), 20)
	for sx in [-7.0, 7.0]:
		b.cyl("flat", Transform3D(Basis(), Vector3(sx, 0, -8.6)), 0.06, 0.05, 3.4, Vector3.ZERO, white, 6)
	# Podium, table des juges, panneau
	var pod := Transform3D(Basis(Vector3.UP, -0.5), Vector3(8.6, 0, -5.4))
	for k in 3:
		var h: float = [0.55, 0.38, 0.26][k]
		var x: float = [0.0, -0.9, 0.9][k]
		b.box("flat", pod, Vector3(0.88, h, 0.85), Vector3(x, h * 0.5, 0), [Color(1.0, 0.82, 0.3), Color(0.82, 0.84, 0.88), Color(0.86, 0.58, 0.38)][k], 0.15)
	WorldBuilder.obs_circle(r, Vector3(8.6, 0, -5.4), 1.2)
	gp.shade(Vector2(8.6, -5.4), 1.9, 0.5)
	var jt := Transform3D(Basis(Vector3.UP, 0.5), Vector3(-8.6, 0, -5.4))
	b.box("t:fabric:1.2", jt, Vector3(2.0, 0.8, 0.8), Vector3(0, 0.4, 0), Color(0.36, 0.5, 0.74), 0.2)
	b.box("flat", jt, Vector3(2.1, 0.04, 0.9), Vector3(0, 0.82, 0), Color(0.98, 0.98, 0.96))
	for k in 3:
		b.cyl("metal", jt, 0.06, 0.1, 0.22, Vector3(-0.6 + k * 0.6, 0.84, 0), [Color(1.0, 0.82, 0.3), Color(0.82, 0.84, 0.88), Color(0.86, 0.58, 0.38)][k], 8)
	WorldBuilder.obs_circle(r, Vector3(-8.6, 0, -5.4), 1.2)
	gp.shade(Vector2(-8.6, -5.4), 1.9, 0.5)
	# Club canin, haies et arbres
	Kit.house(b, r, Vector3(-13.0, 0, 1.5), PI * 0.5, {"w": 6.0, "d": 4.0, "floors": 1, "wall_c": Color(0.96, 0.92, 0.84), "roof_c": Color(0.36, 0.52, 0.48), "sign": "CLUB CANIN", "shutter_c": Color(0.36, 0.52, 0.48)})
	Kit.hedge(r, Vector3(9.5, 0, 3.0), Vector3(15.5, 0, 3.0), 1.0)
	Kit.hedge(r, Vector3(10.0, 0, -15.5), Vector3(16.0, 0, -15.5), 1.0)
	var spots: Array[Vector3] = [Vector3(12.5, 0, -1.5), Vector3(13.5, 0, -9.0), Vector3(-12.5, 0, -10.0), Vector3(-10.5, 0, 8.0), Vector3(8.0, 0, 9.5), Vector3(-16.0, 0, -4.0), Vector3(16.0, 0, 6.0), Vector3(0.0, 0, -18.0), Vector3(-9.0, 0, -17.0), Vector3(9.5, 0, -18.5)]
	for i in spots.size():
		Kit.tree(r, spots[i], 4.6 + (i % 3) * 0.7, ["a", "c", "b"][i % 3], _green(i), i + 30, false)
	for lp in [Vector3(-5.6, 0, 4.2), Vector3(5.6, 0, 4.2)]:
		Kit.lamp(b, r, lp)
	b.commit(r)
	var keep := func(p: Vector2) -> bool: return p.distance_to(Vector2(0, -2.5)) > 6.6
	Kit.grass(r, Rect2(-16, -18, 32, 28), 2400, 71, keep)
	Kit.flowers(r, Rect2(-15, -17, 30, 26), 160, 72, keep)
	Kit.backdrop(r, {"radius": 36.0})
	Kit.ambient(r, "pollen", Rect2(-7, -8, 14, 11))
	r.set_meta("bounds", Rect2(-3.5, -4.5, 7.0, 6.5))

# ================================================================== Refuge
static func shelter(r: Node3D, _q: int) -> void:
	r.set_meta("look", "morning")
	var gp := Kit.ground(r, 110.0, {"rect": Rect2(-18, -18, 36, 36), "r": "pavers", "g": "dirt", "tint_r": Color(0.96, 0.92, 0.86)})
	var b := MeshBatch.new()
	gp.area(Rect2(-7.2, -4.2, 14.4, 5.4), 0)
	gp.path(Vector2(0, 1.0), Vector2(0, 8.0), 2.0, 0)
	Kit.house(b, r, Vector3(0, 0, -6.4), 0.0, {"w": 13.6, "d": 4.2, "floors": 1, "wall_c": Color(0.98, 0.92, 0.82), "roof_c": Color(0.40, 0.60, 0.52),
		"shutter_c": Color(0.40, 0.60, 0.52), "sign": "REFUGE DES PATTES DOUCES", "win": 6, "door_c": Color(0.86, 0.5, 0.36), "lit": 0.5})
	# Enclos individuels : cloisons basses et tapis
	var white := Color(0.96, 0.96, 0.94)
	for i in 7:
		var x := -4.5 + i * 1.5
		var xf := Transform3D(Basis(), Vector3(x, 0, -2.9))
		for k in 5:
			b.box("flat", xf, Vector3(0.05, 0.62, 0.05), Vector3(0, 0.31, -0.7 + k * 0.35), white, 0.12)
		b.box("flat", xf, Vector3(0.06, 0.06, 1.6), Vector3(0, 0.62, 0), white)
		b.box("flat", xf, Vector3(0.05, 0.05, 1.6), Vector3(0, 0.3, 0), white)
	for i in 6:
		var mx := Transform3D(Basis(), Vector3(-3.75 + i * 1.5, 0.012, -3.2))
		b.disc("t:fabric:2.0", mx, 0.42, Vector3.ZERO, [Color(0.98, 0.84, 0.42), Color(0.6, 0.8, 0.9), Color(0.96, 0.66, 0.6)][i % 3], 16)
		b.disc("t:fabric:2.0", mx, 0.3, Vector3(0, 0.004, 0), Color(1.0, 0.97, 0.9), 16)
	Kit.bush(r, Vector3(-7.6, 0, -2.4), 0.9)
	Kit.bush(r, Vector3(7.6, 0, -2.4), 0.9)
	Kit.tree(r, Vector3(-9.5, 0, -6.5), 5.4, "a", _green(0), 9, false)
	Kit.tree(r, Vector3(9.5, 0, -6.0), 5.0, "b", _green(1), 10, false)
	Kit.tree(r, Vector3(-12.0, 0, 3.0), 5.6, "c", _green(2), 11, false)
	Kit.tree(r, Vector3(12.5, 0, 2.0), 5.2, "a", _green(3), 12, false)
	Kit.fence(b, Vector3(-12, 0, 5.5), Vector3(-1.4, 0, 5.5), "picket")
	Kit.fence(b, Vector3(1.4, 0, 5.5), Vector3(12, 0, 5.5), "picket")
	Kit.lamp(b, r, Vector3(-1.9, 0, 5.0))
	Kit.lamp(b, r, Vector3(1.9, 0, 5.0))
	b.commit(r)
	var keep := func(p: Vector2) -> bool: return not Rect2(-7.4, -4.4, 14.8, 5.9).has_point(p)
	Kit.grass(r, Rect2(-14, -4, 28, 14), 1800, 41, keep)
	Kit.flowers(r, Rect2(-13, -3, 26, 12), 180, 42, keep)
	Kit.flowers(r, Rect2(-7.0, 1.3, 14.0, 0.9), 90, 43)
	Kit.backdrop(r, {"radius": 34.0})
	r.set_meta("bounds", Rect2(-5.0, -3.0, 10.0, 4.0))

# ================================================================== Grand pré (jeu de balle)
static func field(r: Node3D, _q: int) -> void:
	r.set_meta("look", "noon")
	var gp := Kit.ground(r, 150.0, {"rect": Rect2(-30, -40, 60, 60), "r": "dirt", "g": "dirt", "macro_amount": 0.36})
	var b := MeshBatch.new()
	var hw := 15.0
	var z0 := -24.0
	var z1 := 6.0
	gp.soft(Vector2(0, 2.4), 2.0, 0, 0.8)   # terre battue à l'endroit du lanceur
	var fc := Color(0.80, 0.64, 0.46)
	Kit.fence(b, Vector3(-hw, 0, z0), Vector3(hw, 0, z0), "rail", fc)
	Kit.fence(b, Vector3(-hw, 0, z1), Vector3(hw, 0, z1), "rail", fc)
	Kit.fence(b, Vector3(-hw, 0, z1), Vector3(-hw, 0, z0), "rail", fc)
	Kit.fence(b, Vector3(hw, 0, z0), Vector3(hw, 0, z1), "rail", fc)
	r.set_meta("fence", Rect2(-hw, z0, hw * 2.0, z1 - z0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in 26:
		var pos := Vector3.ZERO
		match i % 3:
			0: pos = Vector3(rng.randf_range(-hw - 8.0, hw + 8.0), 0, z0 - rng.randf_range(2.5, 9.0))
			1: pos = Vector3(-hw - rng.randf_range(2.5, 8.0), 0, rng.randf_range(z0, z1))
			_: pos = Vector3(hw + rng.randf_range(2.5, 8.0), 0, rng.randf_range(z0, z1))
		Kit.tree(r, pos, rng.randf_range(4.8, 7.0), ["a", "b", "c"][i % 3], _green(i), i, false)
	# Grange rouge et meules de foin : repères au loin
	Kit.house(b, r, Vector3(-22.0, 0, -30.0), 0.5, {"w": 8.0, "d": 6.0, "floors": 2, "wall": "t:wood_planks:0.8", "wall_c": Color(0.92, 0.42, 0.36),
		"roof_c": Color(0.42, 0.38, 0.40), "trim_c": Color(0.98, 0.96, 0.92), "shutters": false, "chimney": false, "flower_boxes": false, "win": 3})
	for hp in [Vector3(-9.0, 0, -27.5), Vector3(-6.5, 0, -28.5), Vector3(18.5, 0, -12.0), Vector3(19.5, 0, -9.5), Vector3(-18.5, 0, -4.0)]:
		var hxf := Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5).rotated(Vector3.UP, hp.x), hp + Vector3(0.6, 0.65, 0))
		b.cyl("t:fabric:0.8", hxf, 0.65, 0.65, 1.2, Vector3.ZERO, Color(0.92, 0.80, 0.44), 12, 0.1)
		gp.shade(Vector2(hp.x, hp.z), 1.4, 0.5)
	for i in 4:
		Kit.bush(r, Vector3(-hw + 1.2 + i * 9.2, 0, z1 + 1.6), 0.95, _green(i), false)
	b.commit(r)
	var keep := func(p: Vector2) -> bool: return p.distance_to(Vector2(0, 2.4)) > 1.6
	Kit.grass(r, Rect2(-18, -28, 36, 36), 4200, 31, keep)
	Kit.flowers(r, Rect2(-17, -27, 34, 34), 520, 32, keep)
	Kit.backdrop(r, {"radius": 46.0})
	Kit.ambient(r, "pollen", Rect2(-8, -10, 16, 14))
	r.set_meta("bounds", Rect2(-hw + 0.4, z0 + 0.4, hw * 2.0 - 0.8, z1 - z0 - 0.8))
	r.set_meta("throw_area", Rect2(-hw + 1.0, z0 + 1.0, hw * 2.0 - 2.0, z1 - z0 - 4.0))

# ================================================================== Quartier des promenades
static func _n(id: String) -> Vector3:
	var p: Vector2 = GameData.WALK_NODES[id]["pos"]
	return Vector3(p.x, 0, p.y)

static func _river_dist(q: Vector2) -> float:
	var best := INF
	var rv := GameData.WALK_RIVER
	for i in rv.size() - 1:
		var ab := rv[i + 1] - rv[i]
		var t := clampf((q - rv[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, q.distance_to(rv[i] + ab * t))
	return best

## Direction dégagée autour d'un lieu : à l'opposé des rues qui y arrivent.
static func _away(id: String, hint: Vector3 = Vector3(0, 0, 1)) -> Vector3:
	var p: Vector2 = GameData.WALK_NODES[id]["pos"]
	var sum := Vector2.ZERO
	for nb in GameData.walk_neighbors(id):
		sum += ((GameData.WALK_NODES[nb]["pos"] as Vector2) - p).normalized()
	var d := -sum.normalized() if sum.length() > 0.35 else Vector2(hint.x, hint.z).normalized()
	return Vector3(d.x, 0, d.y)

## Emplacement d'un bâtiment près d'un lieu : assez loin des rues et de la rivière. Renvoie [position, rotation].
static func _site(id: String, dist: float, clearance: float, placed: Array, hint: Vector3 = Vector3(0, 0, 1), force_hint: bool = false) -> Array:
	var base := _n(id)
	var dir := hint.normalized() if force_hint else _away(id, hint)
	var best_p := base + dir * (dist + 2.0)
	var best_d := dir
	var best_score := -INF
	for k in 16:
		var ang: float = float((k + 1) / 2) * (PI / 8.0) * (1.0 if k % 2 == 0 else -1.0)
		var d := dir.rotated(Vector3.UP, ang)
		for extra in [0.0, 1.2, 2.4, 3.6]:
			var p: Vector3 = base + d * (dist + extra)
			var p2 := Vector2(p.x, p.z)
			if absf(p.x) > 42.0 or p.z > 31.0 or p.z < -30.5:
				continue
			var margin: float = minf(WorldBuilder._road_dist(p2) - clearance, _river_dist(p2) - clearance - 1.6)
			for o in placed:
				margin = minf(margin, (o as Vector2).distance_to(p2) - clearance * 2.0 - 1.0)
			# à marge égale, on préfère la direction dégagée et la proximité du lieu
			var score: float = minf(margin, 0.0) * 10.0 - absf(ang) * 0.6 - extra * 0.3
			if score > best_score:
				best_score = score
				best_p = p
				best_d = d
	placed.append(Vector2(best_p.x, best_p.z))
	return [best_p, atan2(-best_d.x, -best_d.z)]

static func town(r: Node3D, _q: int) -> void:
	r.set_meta("look", "afternoon")
	r.set_meta("fog_begin", 22.0)
	r.set_meta("fog_end", 130.0)
	var nodes: Dictionary = GameData.WALK_NODES
	var gp := Kit.ground(r, 280.0, {"rect": Rect2(-48, -60, 96, 96), "res": 1024, "r": "cobble", "g": "dirt", "g2": "sand", "g2_z": -32.0,
		"uv_r": 0.5, "uv_g": 0.6, "tint_r": Color(1.0, 0.97, 0.93), "tint_g": Color(0.98, 0.93, 0.86), "tint_g2": Color(1.1, 1.08, 1.04), "macro_amount": 0.34})
	var b := MeshBatch.new()
	var placed: Array = []
	# ---------------------------------------------------------------- rues, places, plage
	for e in GameData.WALK_EDGES:
		var a: Vector2 = nodes[e[0]]["pos"]
		var c: Vector2 = nodes[e[1]]["pos"]
		var village: bool = nodes[e[0]].get("zone", "") == "village" and nodes[e[1]].get("zone", "") == "village"
		gp.path(a, c, 2.1 if village else 1.5, 0 if village else 1)
	for id in nodes.keys():
		var nd: Dictionary = nodes[id]
		var p2: Vector2 = nd["pos"]
		if nd.get("zone", "") == "village":
			gp.disc(p2, 3.6 if id == "fountain" else (1.5 if nd["kind"] == "road" else 2.3), 0)
		else:
			gp.disc(p2, 1.2 if nd["kind"] == "road" else 1.9, 1)
	gp.area(Rect2(-48, -60, 96, 26.6), 1)
	for i in 21:
		gp.soft(Vector2(-46.0 + i * 4.6, -33.2 + sin(i * 1.9) * 0.9), 3.4, 1, 1.0)
	Kit.sea(r, Rect2(-140, -160, 280, 116.5), -43.5, {"shallow": Color(0.40, 0.78, 0.84), "deep": Color(0.12, 0.42, 0.72), "scale": 0.8})
	for i in 24:
		gp.shade(Vector2(-47.0 + i * 4.2, -44.1), 3.0, 0.3)   # sable mouillé près de l'eau
	for i in 60:
		WorldBuilder.obs_circle(r, Vector3(-46.0 + i * 1.55, 0, -44.9), 1.3, false)
	# ---------------------------------------------------------------- rivière et ponts
	var rv := GameData.WALK_RIVER
	var crossings: Array[Vector2] = []
	for e in GameData.WALK_EDGES:
		var a2: Vector2 = nodes[e[0]]["pos"]
		var c2: Vector2 = nodes[e[1]]["pos"]
		for i in rv.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(a2, c2, rv[i], rv[i + 1])
			if hit is Vector2:
				crossings.append(hit)
				var d2 := (c2 - a2).normalized()
				var rot := atan2(-d2.y, d2.x)
				if e[0] == "bridge_n" or e[1] == "bridge_n":
					stone_bridge(b, r, Vector3(hit.x, 0, hit.y), rot, 4.4, 2.3)
				else:
					wood_bridge(b, Vector3(hit.x, 0, hit.y), rot, 4.2)
				gp.path(hit - d2 * 2.4, hit + d2 * 2.4, 1.9, 1)
	var wv := PackedVector3Array()
	var wn := PackedVector3Array()
	for i in rv.size() - 1:
		var a3 := rv[i]
		var c3 := rv[i + 1]
		gp.path(a3, c3, 4.0, 1)
		gp.path(a3, c3, 3.0, 2)
		var nrm := (c3 - a3).orthogonal().normalized() * 1.35
		var pts := [Vector3(a3.x - nrm.x, 0.02, a3.y - nrm.y), Vector3(c3.x - nrm.x, 0.02, c3.y - nrm.y), Vector3(c3.x + nrm.x, 0.02, c3.y + nrm.y), Vector3(a3.x + nrm.x, 0.02, a3.y + nrm.y)]
		for k in [0, 1, 2, 0, 2, 3]:
			wv.append(pts[k]); wn.append(Vector3.UP)
		for k in [0, 2, 1, 0, 3, 2]:
			wv.append(pts[k]); wn.append(Vector3.UP)
		var steps := int(a3.distance_to(c3) / 0.9)
		for s in steps + 1:
			var q2 := a3.lerp(c3, float(s) / maxf(1.0, float(steps)))
			if absf(q2.x) > 46.0:
				continue
			var near_bridge := false
			for cr in crossings:
				if cr.distance_to(q2) < 1.75:
					near_bridge = true
			if not near_bridge:
				WorldBuilder.obs_circle(r, Vector3(q2.x, 0, q2.y), 1.2, false)
	var warr := []
	warr.resize(Mesh.ARRAY_MAX)
	warr[Mesh.ARRAY_VERTEX] = wv
	warr[Mesh.ARRAY_NORMAL] = wn
	var wmesh := ArrayMesh.new()
	wmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, warr)
	var wmi := MeshInstance3D.new()
	wmi.mesh = wmesh
	wmi.material_override = Kit.water_mat({"shallow": Color(0.44, 0.76, 0.82), "deep": Color(0.20, 0.50, 0.68), "scale": 1.6})
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(wmi)
	for i in 24:
		var t := (i + 0.5) / 24.0
		var seg := int(t * (rv.size() - 1))
		var q3 := rv[seg].lerp(rv[seg + 1], t * (rv.size() - 1) - seg)
		var side := 1.0 if i % 2 == 0 else -1.0
		var nrm2 := (rv[seg + 1] - rv[seg]).orthogonal().normalized()
		var rp := q3 + nrm2 * side * (1.5 + (i % 3) * 0.2)
		if absf(rp.x) < 46.0 and WorldBuilder._road_dist(rp) > 1.6:
			Kit.rock(r, Vector3(rp.x, 0, rp.y), 0.3 + (i % 3) * 0.14, "a" if i % 2 else "b", false)
	# ---------------------------------------------------------------- lieux
	var cream := Color(0.98, 0.93, 0.83)
	var s: Array
	# Maison : grande maison à colombages, clôture et boîte aux lettres
	s = _site("home", 5.6, 3.4, placed, Vector3(-1, 0, 0.25), true)   # sur le côté : la caméra reste dehors au départ
	Kit.house(b, r, s[0], s[1], {"w": 6.6, "d": 4.2, "floors": 2, "timber": true, "wall_c": cream, "roof_c": Color(0.80, 0.42, 0.34), "shutter_c": Color(0.33, 0.52, 0.58), "win": 4})
	var hx := Transform3D(Basis(Vector3.UP, s[1]), s[0])
	Kit.fence(b, hx * Vector3(-4.6, 0, 3.2), hx * Vector3(-1.2, 0, 3.2), "picket")
	Kit.fence(b, hx * Vector3(1.2, 0, 3.2), hx * Vector3(4.6, 0, 3.2), "picket")
	b.box("flat", hx, Vector3(0.08, 1.0, 0.08), Vector3(1.6, 0.5, 3.6), Color(0.4, 0.3, 0.24))
	b.box("flat", hx, Vector3(0.3, 0.22, 0.42), Vector3(1.6, 1.1, 3.6), Color(0.9, 0.34, 0.3))
	Kit.flowers(r, Rect2(s[0].x - 4.2, s[0].z - 3.4, 8.4, 1.0), 40, 5)
	# Commerces du village
	var shops := [
		["bakery", "BOULANGERIE", Color(1.0, 0.80, 0.36), "t:plaster:0.4", Color(0.99, 0.92, 0.78), Color(0.72, 0.40, 0.30)],
		["shop", "BOUTIQUE", Color(0.90, 0.36, 0.34), "t:brick:0.7", Color(1.0, 0.96, 0.92), Color(0.44, 0.44, 0.50)],
		["groomer", "TOILETTAGE", Color(0.40, 0.66, 0.86), "t:plaster:0.4", Color(0.90, 0.95, 0.98), Color(0.42, 0.52, 0.62)],
		["cafe", "CAFÉ DES CHIENS", Color(0.44, 0.70, 0.52), "t:plaster:0.4", Color(0.98, 0.90, 0.80), Color(0.60, 0.36, 0.30)],
	]
	for sd in shops:
		s = _site(sd[0], 4.6, 2.8, placed)
		Kit.house(b, r, s[0], s[1], {"w": 5.4, "d": 3.8, "floors": 2, "shop": true, "sign": sd[1], "awning_c": sd[2], "wall": sd[3], "wall_c": sd[4], "roof_c": sd[5], "lit": 0.4})
		var sx := Transform3D(Basis(Vector3.UP, s[1]), s[0])
		if sd[0] == "cafe":
			for k in 2:
				var tp := Vector3(-1.4 + k * 2.8, 0, 3.2)
				b.cyl("flat", sx, 0.05, 0.05, 0.7, tp, Color(0.3, 0.3, 0.32), 6)
				b.cyl("t:wood_planks:0.6", sx, 0.45, 0.45, 0.05, tp + Vector3(0, 0.7, 0), Color(0.9, 0.8, 0.66), 12)
				b.cyl("flat", sx, 0.03, 0.03, 1.5, tp + Vector3(0, 0.75, 0), Color(0.95, 0.95, 0.92), 6)
				b.cyl("flat", sx, 0.95, 0.04, 0.4, tp + Vector3(0, 2.1, 0), Color(0.44, 0.70, 0.52) if k == 0 else Color(1.0, 0.96, 0.9), 10, 0.15, false)
				for c4 in 2:
					b.box("t:wood_planks:0.6", sx, Vector3(0.36, 0.44, 0.36), tp + Vector3(-0.7 + c4 * 1.4, 0.22, 0), Color(0.8, 0.62, 0.44), 0.15)
				var wp: Vector3 = sx * tp
				WorldBuilder.obs_circle(r, wp, 0.6)
				gp.shade(Vector2(wp.x, wp.z), 1.3, 0.45)
		elif sd[0] == "bakery":
			for k in 2:
				b.box("t:wood_planks:0.6", sx, Vector3(0.6, 0.5, 0.5), Vector3(1.3 + k * 0.7, 0.25, 2.5), Color(0.82, 0.64, 0.44), 0.15)
				b.cyl("flat", sx, 0.2, 0.16, 0.14, Vector3(1.3 + k * 0.7, 0.5, 2.5), Color(0.9, 0.72, 0.42), 8)
	# Vétérinaire (croix verte) et école du chiot (petits obstacles)
	s = _site("vet", 4.6, 2.8, placed)
	Kit.house(b, r, s[0], s[1], {"w": 5.6, "d": 3.8, "floors": 1, "wall_c": Color(0.97, 0.98, 0.97), "roof_c": Color(0.36, 0.56, 0.52), "shutter_c": Color(0.36, 0.56, 0.52), "sign": "VÉTÉRINAIRE"})
	var vx := Transform3D(Basis(Vector3.UP, s[1]), s[0] + Vector3(0, 3.55, 0))
	b.box("emit", vx, Vector3(0.75, 0.24, 0.06), Vector3(0, 0, 1.96), Color(0.36, 0.82, 0.5))
	b.box("emit", vx, Vector3(0.24, 0.75, 0.06), Vector3(0, 0, 1.96), Color(0.36, 0.82, 0.5))
	s = _site("school", 4.8, 2.8, placed)
	Kit.house(b, r, s[0], s[1], {"w": 6.0, "d": 3.8, "floors": 1, "wall": "t:brick:0.7", "wall_c": Color(1.0, 0.94, 0.88), "roof_c": Color(0.74, 0.40, 0.32), "sign": "ÉCOLE DU CHIOT", "shutter_c": Color(0.95, 0.9, 0.8)})
	var scx := Transform3D(Basis(Vector3.UP, s[1]), s[0])
	for k in 3:
		b.cyl("flat", scx, 0.14, 0.03, 0.36, Vector3(-2.0 + k * 0.6, 0, 3.4), Color(0.98, 0.56, 0.22), 8, 0.1, false)
	# Fontaine de la place, bancs, marché
	var fo := WorldBuilder._free_offset(_n("fountain"), Vector3(-2.2, 0, 1.6), 2.2)
	var fpos := _n("fountain") + fo
	plaza_fountain(b, r, fpos, 1.25)
	r.set_meta("fountain", fpos)
	placed.append(Vector2(fpos.x, fpos.z))
	var mk := _n("market")
	var mdir := _away("market", Vector3(-1, 0, 0))
	for k in 3:
		var md := mdir.rotated(Vector3.UP, -0.9 + k * 0.9)
		var mp := mk + md * 3.6
		if WorldBuilder._road_dist(Vector2(mp.x, mp.z)) > 1.5:
			Kit.stall(b, r, mp, atan2(-md.x, -md.z), [Color(0.92, 0.38, 0.36), Color(0.40, 0.66, 0.86), Color(1.0, 0.80, 0.36)][k],
				[[Color(0.9, 0.25, 0.22), Color(0.98, 0.7, 0.2), Color(0.5, 0.75, 0.3)], [Color(0.95, 0.85, 0.6), Color(0.8, 0.55, 0.3), Color(0.98, 0.95, 0.9)], [Color(0.85, 0.3, 0.5), Color(0.55, 0.4, 0.8), Color(1.0, 0.9, 0.4)]][k])
			placed.append(Vector2(mp.x, mp.z))
	bunting(b, mk + Vector3(-3.0, 3.0, -2.5), mk + Vector3(3.0, 3.0, 2.5), 16)
	for pp in [mk + Vector3(-3.0, 0, -2.5), mk + Vector3(3.0, 0, 2.5)]:
		if WorldBuilder._road_dist(Vector2(pp.x, pp.z)) > 1.2:
			b.cyl("flat", Transform3D(Basis(), pp), 0.06, 0.05, 3.1, Vector3.ZERO, Color(0.96, 0.95, 0.92), 6)
			WorldBuilder.obs_circle(r, pp, 0.12)
	# Parc à chiens : portail, arbres, bancs (zone de jeu dégagée autour du lieu)
	var pk := _n("park")
	for k in 9:
		var a4 := TAU * k / 9.0 + 0.35
		var tp2 := pk + Vector3(cos(a4) * 5.8, 0, sin(a4) * 5.4 - 1.0)
		if WorldBuilder._road_dist(Vector2(tp2.x, tp2.z)) > 2.0 and _river_dist(Vector2(tp2.x, tp2.z)) > 3.0:
			Kit.tree(r, tp2, 4.8 + (k % 3) * 0.8, ["a", "b", "c"][k % 3], _green(k), k + 40)
			placed.append(Vector2(tp2.x, tp2.z))
	var pdir := _away("park", Vector3(-1, 0, 0))
	Kit.bench(r, pk + pdir.rotated(Vector3.UP, 0.9) * 3.4, atan2(-pdir.x, -pdir.z) + 0.9)
	Kit.signpost(b, r, pk + pdir.rotated(Vector3.UP, -1.2) * 2.6, 0.0, "Parc à chiens")
	# Étang aux canards
	var pn := _n("pond")
	var podir := _away("pond", Vector3(-1, 0, 0.3))
	var pc := pn + podir * 4.6
	Kit.pond(r, gp, pc, 2.8, {"shallow": Color(0.44, 0.74, 0.78), "deep": Color(0.18, 0.44, 0.58)})
	r.set_meta("pond", pc)
	placed.append(Vector2(pc.x, pc.z))
	var dkx := Transform3D(Basis(), pc + Vector3(0, 0.03, 0))
	for k in 4:
		var dp := Vector3(cos(k * 1.7) * (0.8 + k * 0.3), 0, sin(k * 1.7) * (0.8 + k * 0.25))
		var dc := Color(1, 1, 1) if k % 2 == 0 else Color(0.62, 0.48, 0.36)
		b.cyl("flat", dkx, 0.13, 0.09, 0.12, dp, dc, 8, 0.1)
		b.cyl("flat", dkx, 0.06, 0.055, 0.12, dp + Vector3(0.1, 0.1, 0), dc if k % 2 == 0 else Color(0.2, 0.45, 0.32), 6)
		b.box("flat", dkx, Vector3(0.07, 0.025, 0.04), dp + Vector3(0.18, 0.16, 0), Color(1.0, 0.7, 0.2))
	for k in 5:
		Kit.rock(r, pc + Vector3(cos(k * 1.3) * 3.2, 0, sin(k * 1.3) * 3.2), 0.3 + (k % 2) * 0.15, "a" if k % 2 else "b", false)
	Kit.grass(r, Rect2(pc.x - 4.2, pc.z - 4.2, 8.4, 8.4), 260, 77, func(p: Vector2) -> bool: return absf(p.distance_to(Vector2(pc.x, pc.z)) - 3.3) < 0.5, Color(0.5, 0.66, 0.36), Vector2(1.2, 2.0))
	Kit.bench(r, pn + podir.rotated(Vector3.UP, 1.5) * 2.4, atan2(-podir.x, -podir.z) + 1.5)
	# Terrain d'agilité : lice et obstacles
	var ce := _n("center")
	var cdir := _away("center", Vector3(1, 0, 0))
	var cc := ce + cdir * 4.4
	if WorldBuilder._road_dist(Vector2(cc.x, cc.z)) > 2.6:
		gp.disc(Vector2(cc.x, cc.z), 2.8, 1)
		for k in 16:
			var a5 := TAU * k / 16.0
			var a6 := TAU * (k + 1) / 16.0
			var p5 := cc + Vector3(cos(a5) * 2.9, 0, sin(a5) * 2.9)
			var p6 := cc + Vector3(cos(a6) * 2.9, 0, sin(a6) * 2.9)
			b.box("flat", Transform3D(Basis(), p5), Vector3(0.08, 0.66, 0.08), Vector3(0, 0.33, 0), Color(0.98, 0.97, 0.95), 0.15)
			b.box("flat", Transform3D(Basis(Vector3.UP, atan2(-(p6.z - p5.z), p6.x - p5.x)), (p5 + p6) * 0.5), Vector3(p5.distance_to(p6), 0.07, 0.06), Vector3(0, 0.62, 0), Color(0.92, 0.32, 0.3))
			WorldBuilder.obs_circle(r, p5, 0.3)
		for k in 2:
			var hp := Transform3D(Basis(Vector3.UP, 0.6), cc + Vector3(-0.8 + k * 1.6, 0, 0.3 - k * 0.6))
			for sx3 in [-0.45, 0.45]:
				b.box("flat", hp, Vector3(0.06, 0.6, 0.06), Vector3(sx3, 0.3, 0), Color(0.98, 0.97, 0.95))
			b.box("flat", hp, Vector3(0.96, 0.05, 0.05), Vector3(0, 0.42, 0), Color(0.38, 0.62, 0.9) if k == 0 else Color(0.98, 0.78, 0.3))
		placed.append(Vector2(cc.x, cc.z))
	Kit.signpost(b, r, ce + cdir.rotated(Vector3.UP, 1.4) * 2.3, 0.0, "Terrain d'agilité")
	# Salle des concours
	s = _site("comp", 5.6, 3.6, placed)
	Kit.house(b, r, s[0], s[1], {"w": 8.0, "d": 4.6, "floors": 2, "wall_c": Color(0.96, 0.90, 0.80), "roof_c": Color(0.42, 0.44, 0.52), "sign": "CONCOURS", "win": 4, "lit": 0.5, "shutter_c": Color(0.74, 0.36, 0.34)})
	var kx := Transform3D(Basis(Vector3.UP, s[1]), s[0])
	bunting(b, kx * Vector3(-4.0, 3.2, 2.6), kx * Vector3(4.0, 3.2, 2.6), 16)
	for k in 3:
		var ph: float = [0.5, 0.34, 0.24][k]
		b.box("flat", kx, Vector3(0.8, ph, 0.7), Vector3(2.6 + [0.0, -0.8, 0.8][k], ph * 0.5, 3.4), [Color(1.0, 0.82, 0.3), Color(0.82, 0.84, 0.88), Color(0.86, 0.58, 0.38)][k], 0.15)
	var podp: Vector3 = kx * Vector3(2.6, 0, 3.4)
	WorldBuilder.obs_circle(r, podp, 1.2)
	# Ferme : grange rouge, enclos, moutons, meules
	s = _site("farm", 6.0, 3.8, placed)
	Kit.house(b, r, s[0], s[1], {"w": 7.0, "d": 5.0, "floors": 2, "wall": "t:wood_planks:0.8", "wall_c": Color(0.92, 0.42, 0.36), "roof_c": Color(0.42, 0.38, 0.40),
		"shutters": false, "chimney": false, "flower_boxes": false, "win": 3, "door_c": Color(0.96, 0.94, 0.9)})
	var fx := Transform3D(Basis(Vector3.UP, s[1]), s[0])
	var pen: Array[Vector3] = [fx * Vector3(4.2, 0, -1.5), fx * Vector3(8.2, 0, -1.5), fx * Vector3(8.2, 0, 2.5), fx * Vector3(4.2, 0, 2.5)]
	var pen_ok := true
	for pv in pen:
		if WorldBuilder._road_dist(Vector2(pv.x, pv.z)) < 1.3 or _river_dist(Vector2(pv.x, pv.z)) < 2.4:
			pen_ok = false
	if pen_ok:
		for k in 4:
			Kit.fence(b, pen[k], pen[(k + 1) % 4], "rail", Color(0.8, 0.64, 0.46))
			for t2 in 4:
				var op := pen[k].lerp(pen[(k + 1) % 4], t2 / 4.0)
				WorldBuilder.obs_circle(r, op, 0.55)
		for k in 3:
			var sp := fx * Vector3(5.2 + k * 1.0, 0, -0.4 + (k % 2) * 1.6)
			var shx := Transform3D(Basis(Vector3.UP, k * 1.3), sp)
			b.cyl("flat", shx, 0.24, 0.26, 0.3, Vector3(0, 0.22, 0), Color(0.97, 0.96, 0.92), 8, 0.15)
			b.box("flat", shx, Vector3(0.16, 0.16, 0.2), Vector3(0, 0.44, 0.27), Color(0.24, 0.2, 0.2))
			for lg in 4:
				b.box("flat", shx, Vector3(0.05, 0.22, 0.05), Vector3(-0.12 + (lg % 2) * 0.24, 0.11, -0.12 + (lg / 2) * 0.24), Color(0.24, 0.2, 0.2))
		var pcn := (pen[0] + pen[2]) * 0.5
		placed.append(Vector2(pcn.x, pcn.z))
	for k in 2:
		var hb := fx * Vector3(-4.6 - k * 1.5, 0, 0.6 + k * 0.5)
		if WorldBuilder._road_dist(Vector2(hb.x, hb.z)) > 1.6:
			b.cyl("t:fabric:0.8", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5).rotated(Vector3.UP, k * 0.7), hb + Vector3(0.6, 0.6, 0)), 0.6, 0.6, 1.1, Vector3.ZERO, Color(0.92, 0.80, 0.44), 12, 0.1)
			WorldBuilder.obs_circle(r, hb, 0.85)
			gp.shade(Vector2(hb.x, hb.z), 1.3, 0.5)
	# Lisière de la forêt : sapins serrés à l'ouest
	var fn := _n("forest")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var n_pines: int = [16, 26, 36][Kit.q]
	var tries := 0
	var pines := 0
	while pines < n_pines and tries < 400:
		tries += 1
		var a7 := rng.randf() * TAU
		var dd := rng.randf_range(3.2, 15.0)
		var pp2 := fn + Vector3(cos(a7) * dd - 4.0, 0, sin(a7) * dd - 1.0)
		var q4 := Vector2(pp2.x, pp2.z)
		if WorldBuilder._road_dist(q4) < 2.0 or _river_dist(q4) < 3.0 or pp2.z < -31.0 or absf(pp2.x) > 46.0:
			continue
		var close := false
		for o in placed:
			if (o as Vector2).distance_to(q4) < 2.0:
				close = true
		if close:
			continue
		placed.append(q4)
		pines += 1
		if rng.randf() < 0.75:
			Kit.pine(r, pp2, rng.randf_range(4.6, 7.4), Color(0.20, 0.42, 0.26).lightened(rng.randf() * 0.1), pp2.distance_to(fn) < 9.0)
		else:
			Kit.tree(r, pp2, rng.randf_range(4.8, 6.4), "b", Color(0.32, 0.54, 0.26), pines, pp2.distance_to(fn) < 9.0)
	Kit.signpost(b, r, fn + _away("forest").rotated(Vector3.UP, 1.3) * 2.3, 0.0, "Forêt")
	Kit.log_prop(r, fn + _away("forest") * 2.8, 0.6, 0.8)
	# Grand pré : barrière, fleurs, panneau
	var md2 := _n("meadow")
	Kit.signpost(b, r, md2 + _away("meadow", Vector3(1, 0, 0)).rotated(Vector3.UP, 1.4) * 2.4, 0.0, "Grand pré")
	Kit.flowers(r, Rect2(md2.x - 6, md2.z - 4.2, 12, 6.5), 260, 91, func(p: Vector2) -> bool: return WorldBuilder._road_dist(p) > 1.2 and p.y > -31.5)
	# Belvédère : terrasse en bois, longue-vue, banc
	var vp := _n("viewpoint")
	var vdir := _away("viewpoint", Vector3(1, 0, 0))
	var vc := vp + vdir * 3.4
	var vxf := Transform3D(Basis(Vector3.UP, atan2(-vdir.x, -vdir.z)), vc)
	b.box("t:wood_planks:0.5", vxf, Vector3(4.2, 0.08, 3.0), Vector3(0, 0.04, 0), Color(0.82, 0.66, 0.48), 0.0, false)
	for k in 6:
		b.box("t:wood_planks:0.5", vxf, Vector3(0.1, 0.95, 0.1), Vector3(-2.05 + k * 0.82, 0.47, -1.45), Color(0.66, 0.5, 0.36), 0.15)
	b.box("t:wood_planks:0.5", vxf, Vector3(4.2, 0.08, 0.1), Vector3(0, 0.92, -1.45), Color(0.66, 0.5, 0.36))
	b.box("t:wood_planks:0.5", vxf, Vector3(4.2, 0.06, 0.06), Vector3(0, 0.5, -1.45), Color(0.66, 0.5, 0.36))
	b.cyl("metal", vxf, 0.05, 0.04, 1.1, Vector3(1.2, 0.08, -1.0), Color(0.3, 0.32, 0.36), 6)
	b.box("metal", vxf * Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(1.2, 1.25, -1.05)), Vector3(0.14, 0.14, 0.6), Vector3.ZERO, Color(0.82, 0.68, 0.32))
	var rail_a: Vector3 = vxf * Vector3(-2.0, 0, -1.6)
	var rail_b: Vector3 = vxf * Vector3(2.0, 0, -1.6)
	for k in 5:
		WorldBuilder.obs_circle(r, rail_a.lerp(rail_b, k / 4.0), 0.5)
	gp.shade(Vector2(vc.x, vc.z), 3.0, 0.4)
	Kit.rock(r, vc + vdir * 3.0 + Vector3(1.5, 0, 0), 1.2, "b")
	Kit.rock(r, vc + vdir * 2.6 - Vector3(2.0, 0, 0.5), 0.8, "a")
	Kit.signpost(b, r, vp + vdir.rotated(Vector3.UP, -1.4) * 2.2, 0.0, "Belvédère")
	# Plage : palmiers, parasols, cabines
	var bc := _n("beach")
	for k in 5:
		var pa := bc + Vector3(-8.0 + k * 4.2, 0, 2.0 - (k % 2) * 1.2)
		if WorldBuilder._road_dist(Vector2(pa.x, pa.z)) > 2.0 and absf(pa.x - bc.x) > 4.2:
			palm(b, r, pa, 3.8 + (k % 3) * 0.4, k * 1.7)
	for k in 2:
		var ux := Transform3D(Basis(Vector3(0, 0, 1), 0.08), bc + Vector3(-6.5 + k * 13.0, 0, -1.5))
		b.cyl("flat", ux, 0.03, 0.03, 2.2, Vector3.ZERO, Color(0.96, 0.96, 0.94), 6)
		b.cyl("flat", ux, 1.3, 0.04, 0.42, Vector3(0, 2.05, 0), [Color(0.94, 0.38, 0.34), Color(0.36, 0.62, 0.9)][k], 10, 0.2, false)
		var up: Vector3 = ux.origin
		WorldBuilder.obs_circle(r, up, 0.12)
		gp.shade(Vector2(up.x, up.z), 1.6, 0.45)
	for k in 3:
		var cxf := Transform3D(Basis(Vector3.UP, 0.1), bc + Vector3(-15.0 + k * 2.1, 0, 2.6))
		var hc: Color = [Color(0.36, 0.68, 0.84), Color(0.96, 0.78, 0.36), Color(0.92, 0.46, 0.44)][k]
		for st in 6:
			b.box("flat", cxf, Vector3(0.3, 2.0, 1.7), Vector3(-0.75 + st * 0.3, 1.0, 0), hc if st % 2 == 0 else Color(1, 1, 1), 0.12)
		b.gable_roof("t:roof_tiles:0.9", cxf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), 2.1, 2.2, 0.7, Vector3(0, 2.0, 0), hc.darkened(0.3))
		var cp: Vector3 = cxf.origin
		WorldBuilder.obs_circle(r, cp, 1.1)
		gp.shade(Vector2(cp.x, cp.z), 1.9, 0.5)
	# Phare sur ses rochers
	var lh := _n("lighthouse")
	var ldir := _away("lighthouse", Vector3(1, 0, -0.4))
	var lc := lh + ldir * 4.2
	lc.z = minf(lc.z, -41.5)
	Kit.rock(r, lc + Vector3(0, -0.2, 0), 3.4, "a", false, Color(0.76, 0.74, 0.70))
	Kit.rock(r, lc + Vector3(2.2, 0, 0.8), 1.3, "b", false, Color(0.76, 0.74, 0.70))
	Kit.rock(r, lc + Vector3(-2.4, 0, -0.4), 1.5, "a", false, Color(0.76, 0.74, 0.70))
	var lxf := Transform3D(Basis(), lc)
	for k in 5:
		b.cyl("flat", lxf, 0.95 - k * 0.1, 0.85 - k * 0.1, 1.4, Vector3(0, 1.2 + k * 1.4, 0), Color(0.92, 0.3, 0.28) if k % 2 == 0 else Color(0.98, 0.97, 0.94), 12, 0.1, false)
	b.cyl("metal", lxf, 0.7, 0.7, 0.1, Vector3(0, 8.2, 0), Color(0.25, 0.27, 0.3), 12)
	b.cyl("emit", lxf, 0.38, 0.38, 0.65, Vector3(0, 8.3, 0), Color(1.0, 0.95, 0.75), 10)
	b.cyl("flat", lxf, 0.58, 0.05, 0.55, Vector3(0, 8.95, 0), Color(0.86, 0.28, 0.26), 10, 0.0, false)
	WorldBuilder.obs_circle(r, lc, 2.6)
	# ---------------------------------------------------------------- maisons du village, réverbères
	var styles := [
		{"wall_c": Color(0.98, 0.90, 0.76), "roof_c": Color(0.76, 0.40, 0.32)},
		{"wall": "t:brick:0.7", "wall_c": Color(1.0, 0.95, 0.9), "roof_c": Color(0.42, 0.44, 0.50), "shutter_c": Color(0.92, 0.9, 0.84)},
		{"wall_c": Color(0.92, 0.95, 0.90), "roof_c": Color(0.50, 0.42, 0.40), "timber": true, "shutter_c": Color(0.66, 0.34, 0.32)},
		{"wall_c": Color(0.98, 0.86, 0.80), "roof_c": Color(0.70, 0.38, 0.32), "shutter_c": Color(0.30, 0.44, 0.60)},
		{"wall": "t:stone_wall:0.5", "wall_c": Color(0.96, 0.94, 0.9), "roof_c": Color(0.46, 0.44, 0.48), "shutter_c": Color(0.40, 0.56, 0.42)},
	]
	var lots: Array[Vector3] = [Vector3(-15.75, 0, 18.75), Vector3(8.25, 0, 21.75), Vector3(15.75, 0, 19.5), Vector3(24.75, 0, 15.75), Vector3(25.5, 0, 5.25), Vector3(17.25, 0, 1.8),
		Vector3(-17.25, 0, 12.75), Vector3(5.4, 0, 0.9), Vector3(-6.6, 0, 0.3), Vector3(26.25, 0, -4.5), Vector3(-5.4, 0, 10.5), Vector3(15, 0, 5.85), Vector3(-14.25, 0, 24.75), Vector3(19.5, 0, 24.75)]
	for i in lots.size():
		var lp := lots[i]
		var l2 := Vector2(lp.x, lp.z)
		if WorldBuilder._road_dist(l2) < 3.1 or _river_dist(l2) < 4.6:
			continue
		var clash := false
		for o in placed:
			if (o as Vector2).distance_to(l2) < 5.6:
				clash = true
		if clash:
			continue
		placed.append(l2)
		# façade tournée vers la rue la plus proche
		var best_d := Vector2(0, 1)
		var best := INF
		for a8 in 8:
			var dv := Vector2(cos(a8 * PI / 4.0), sin(a8 * PI / 4.0))
			var rd := WorldBuilder._road_dist(l2 + dv * 2.5)
			if rd < best:
				best = rd
				best_d = dv
		var st2: Dictionary = (styles[i % styles.size()] as Dictionary).duplicate()
		st2["w"] = 4.6 + (i % 3) * 0.5
		st2["d"] = 3.6
		st2["floors"] = 1 + (i % 2)
		Kit.house(b, r, lp, atan2(best_d.x, best_d.y), st2)
	for e in GameData.WALK_EDGES:
		if nodes[e[0]].get("zone", "") != "village" or nodes[e[1]].get("zone", "") != "village":
			continue
		var a9: Vector2 = nodes[e[0]]["pos"]
		var c9: Vector2 = nodes[e[1]]["pos"]
		var lp2 := (a9 + c9) * 0.5 + (c9 - a9).orthogonal().normalized() * 1.5
		var lok := WorldBuilder._road_dist(lp2) > 1.3 and _river_dist(lp2) > 2.5
		for o in placed:
			if (o as Vector2).distance_to(lp2) < 2.6:
				lok = false
		if lok:
			Kit.lamp(b, r, Vector3(lp2.x, 0, lp2.y), true)
	# ---------------------------------------------------------------- arbres, buissons, herbe
	var n_trees: int = [22, 40, 54][Kit.q]
	rng.seed = 23
	tries = 0
	var count := 0
	while count < n_trees and tries < 900:
		tries += 1
		var tp3 := Vector2(rng.randf_range(-44, 44), rng.randf_range(-31.0, 31))
		if WorldBuilder._road_dist(tp3) < 2.4 or _river_dist(tp3) < 3.0:
			continue
		if tp3.distance_to(nodes["park"]["pos"]) < 5.0 or tp3.distance_to(nodes["meadow"]["pos"]) < 6.5:
			continue
		var close2 := false
		for o in placed:
			if (o as Vector2).distance_to(tp3) < 4.2:
				close2 = true
		if close2:
			continue
		placed.append(tp3)
		count += 1
		var near := WorldBuilder._road_dist(tp3) < 7.0
		if count % 5 == 0:
			Kit.bush(r, Vector3(tp3.x, 0, tp3.y), rng.randf_range(0.7, 1.0), _green(count), near)
		else:
			Kit.tree(r, Vector3(tp3.x, 0, tp3.y), rng.randf_range(4.6, 6.6), ["a", "b", "c"][count % 3], _green(count), count, near)
	b.commit(r)
	var keep := func(p: Vector2) -> bool: return p.y > -31.2
	Kit.grass(r, Rect2(-46, -31.5, 92, 64), 9000, 51, keep)
	Kit.flowers(r, Rect2(-45, -31, 90, 62), 800, 52, keep)
	Kit.backdrop(r, {"radius": 76.0, "gap_from": 3.5, "gap_to": 5.95})
	r.set_meta("bounds", Rect2(-46, -45, 92, 78))
	r.set_meta("walk_area", Rect2(-46, -45, 92, 78))
