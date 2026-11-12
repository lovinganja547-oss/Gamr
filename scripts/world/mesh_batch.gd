class_name MeshBatch
extends RefCounted
## Fusionne des centaines de formes simples (murs, toits, poteaux, cadres…) en un seul maillage
## par matière : un bâtiment entier coûte quelques appels de rendu au lieu de plusieurs dizaines.
## Chaque face reçoit de vraies coordonnées de texture (en mètres) et une tangente : les briques
## et les tuiles restent droites quelle que soit l'orientation du bâtiment.
##
## Clés de matière : "t:<texture>:<répétitions par mètre>", "flat" (couleur seule), "glass", "emit".

## Tampons d'une matière (objet : les tableaux compacts sont modifiés en place).
class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var t := PackedFloat32Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var k := 1.0

var _s := {}   # clé -> Surf

func _surf(key: String) -> Surf:
	if not _s.has(key):
		var sf := Surf.new()
		sf.k = _uv_scale(key)
		_s[key] = sf
	return _s[key]

static func _uv_scale(key: String) -> float:
	var parts := key.split(":")
	return float(parts[2]) if parts.size() >= 3 else 1.0

## Quadrilatère p0..p3 donnés dans le sens horaire vu de l'extérieur. u_dir = direction « horizontale »
## de la texture ; la verticale de la texture pointe vers le bas de la face.
func quad(key: String, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, c0: Color, c1: Color, c2: Color, c3: Color, u_dir: Vector3 = Vector3.ZERO) -> void:
	var s := _surf(key)
	var n := (p2 - p0).cross(p1 - p0).normalized()
	var u := u_dir
	if u == Vector3.ZERO:
		u = (p3 - p0).normalized()
	u = (u - n * u.dot(n)).normalized()
	var vdir := u.cross(n).normalized()   # vers le bas de la texture
	var pts := [p0, p1, p2, p0, p2, p3]
	var cols := [c0, c1, c2, c0, c2, c3]
	for i in 6:
		var p: Vector3 = pts[i]
		s.v.append(p)
		s.n.append(n)
		s.uv.append(Vector2(p.dot(u), p.dot(vdir)) * s.k)
		s.c.append(cols[i])
		s.t.append(u.x); s.t.append(u.y); s.t.append(u.z); s.t.append(1.0)

func tri(key: String, p0: Vector3, p1: Vector3, p2: Vector3, col: Color, u_dir: Vector3) -> void:
	var s := _surf(key)
	var n := (p2 - p0).cross(p1 - p0).normalized()
	var u := (u_dir - n * u_dir.dot(n)).normalized()
	var vdir := u.cross(n).normalized()
	for p in [p0, p1, p2]:
		s.v.append(p)
		s.n.append(n)
		s.uv.append(Vector2(p.dot(u), p.dot(vdir)) * s.k)
		s.c.append(col)
		s.t.append(u.x); s.t.append(u.y); s.t.append(u.z); s.t.append(1.0)

## Boîte de taille size centrée en center (repère local de xf). ao : assombrit le bas (ancrage au sol).
func box(key: String, xf: Transform3D, size: Vector3, center: Vector3, col: Color, ao: float = 0.0, skip_bottom: bool = true) -> void:
	var h := size * 0.5
	var lo := col.darkened(ao)
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		if skip_bottom and n.y < -0.5:
			continue
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := center + n * h * n.abs()
		var hu := u * (u.abs().dot(h))
		var hv := v * (v.abs().dot(h))
		# sens horaire vu de l'extérieur : bas-gauche, haut-gauche, haut-droit, bas-droit
		var p0 := xf * (c - hu - hv)
		var p1 := xf * (c - hu + hv)
		var p2 := xf * (c + hu + hv)
		var p3 := xf * (c + hu - hv)
		var c_lo := lo if absf(n.y) < 0.5 else (col if n.y > 0 else lo)
		var c_hi := col if absf(n.y) < 0.5 else c_lo
		quad(key, p0, p1, p2, p3, c_lo, c_hi, c_hi, c_lo, xf.basis * u)

## Toit à deux pans : faîte le long de l'axe X local, base w × d posée à base_y, hauteur h.
func gable_roof(key: String, xf: Transform3D, w: float, d: float, h: float, base: Vector3, col: Color, thick: float = 0.08) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var ridge_l := base + Vector3(-hw, h, 0)
	var ridge_r := base + Vector3(hw, h, 0)
	var ux := xf.basis * Vector3(1, 0, 0)
	var dark := col.darkened(0.12)
	# pan avant (+Z) puis pan arrière (-Z) ; la texture « descend » la pente
	quad(key, xf * (base + Vector3(-hw, 0, hd)), xf * ridge_l, xf * ridge_r, xf * (base + Vector3(hw, 0, hd)), dark, col, col, dark, ux)
	quad(key, xf * (base + Vector3(hw, 0, -hd)), xf * ridge_r, xf * ridge_l, xf * (base + Vector3(-hw, 0, -hd)), dark, col, col, dark, -ux)
	# dessous (visible sous le débord) et rives
	var under := col.darkened(0.45)
	var t := Vector3(0, -thick, 0)
	quad("flat", xf * (base + Vector3(-hw, 0, hd) + t), xf * (base + Vector3(hw, 0, hd) + t), xf * (ridge_r + t), xf * (ridge_l + t), under, under, under, under)
	quad("flat", xf * (base + Vector3(hw, 0, -hd) + t), xf * (base + Vector3(-hw, 0, -hd) + t), xf * (ridge_l + t), xf * (ridge_r + t), under, under, under, under)
	var edge := col.darkened(0.3)
	for sz in [1.0, -1.0]:
		var a := base + Vector3(-hw, 0, hd * sz)
		var b := base + Vector3(hw, 0, hd * sz)
		if sz > 0:
			quad("flat", xf * (a + t), xf * a, xf * b, xf * (b + t), edge, edge, edge, edge)
		else:
			quad("flat", xf * (b + t), xf * b, xf * a, xf * (a + t), edge, edge, edge, edge)

## Pignons triangulaires (murs sous le toit), aux extrémités ±X.
func gable_ends(key: String, xf: Transform3D, w: float, d: float, h: float, base_y: float, col: Color) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var uz := xf.basis * Vector3(0, 0, 1)
	tri(key, xf * Vector3(hw, base_y, hd), xf * Vector3(hw, base_y + h, 0), xf * Vector3(hw, base_y, -hd), col, -uz)
	tri(key, xf * Vector3(-hw, base_y, -hd), xf * Vector3(-hw, base_y + h, 0), xf * Vector3(-hw, base_y, hd), col, uz)

## Cylindre ou cône tronqué vertical (base au point base).
func cyl(key: String, xf: Transform3D, r_bot: float, r_top: float, h: float, base: Vector3, col: Color, seg: int = 10, ao: float = 0.0, cap: bool = true) -> void:
	var lo := col.darkened(ao)
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := base + d0 * r_bot
		var b1 := base + d1 * r_bot
		var t0 := base + d0 * r_top + Vector3(0, h, 0)
		var t1 := base + d1 * r_top + Vector3(0, h, 0)
		var u := xf.basis * (d0 - d1).normalized()
		quad(key, xf * b1, xf * t1, xf * t0, xf * b0, lo, col, col, lo, u)
		if cap and r_top > 0.001:
			var top := base + Vector3(0, h, 0)
			tri(key, xf * t1, xf * top, xf * t0, col, xf.basis * Vector3(1, 0, 0))

## Disque horizontal (dessus de table, dalle ronde…).
func disc(key: String, xf: Transform3D, r: float, center: Vector3, col: Color, seg: int = 16) -> void:
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		tri(key, xf * (center + Vector3(cos(a1), 0, sin(a1)) * r), xf * center, xf * (center + Vector3(cos(a0), 0, sin(a0)) * r), col, xf.basis * Vector3(1, 0, 0))

func is_empty() -> bool:
	return _s.is_empty()

## Crée le maillage final (une surface par matière).
func commit(parent: Node3D, shadows: bool = true, name: String = "Batch") -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var mats: Array = []
	for key in _s.keys():
		var s: Surf = _s[key]
		if s.v.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s.v
		arr[Mesh.ARRAY_NORMAL] = s.n
		arr[Mesh.ARRAY_TANGENT] = s.t
		arr[Mesh.ARRAY_TEX_UV] = s.uv
		arr[Mesh.ARRAY_COLOR] = s.c
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mats.append(Kit.batch_material(str(key)))
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	for i in mats.size():
		mi.set_surface_override_material(i, mats[i])
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_s.clear()
	return mi
