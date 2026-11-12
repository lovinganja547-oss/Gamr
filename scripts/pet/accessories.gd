class_name Accessories
extends RefCounted
## Catalogue d'accessoires : chaque forme est construite sur le bon point d'attache (dessus de la
## tête, yeux, cou, dos) à partir des mesures réelles de l'animal, pour tomber juste sur chaque race.

const GOLD := Color(1.0, 0.82, 0.25)
const SILVER := Color(0.86, 0.88, 0.92)
const WHITE := Color(0.98, 0.98, 0.96)
const FLOWERS: Array[Color] = [Color(1.0, 0.6, 0.72), Color(1, 1, 1), Color(1.0, 0.82, 0.35), Color(0.75, 0.62, 1.0), Color(1.0, 0.5, 0.42)]

static func build(m: PetModel, id: String) -> void:
	var it := GameData.item(id)
	if it.is_empty() or id == "acc_none":
		return
	var shape := str(it.get("shape", id))
	var c: Color = it.get("color", Color.WHITE)
	var c2: Color = it.get("color2", WHITE)
	var hr := m.hr
	# --- points d'attache
	var top := m._pivot(m.head_pivot, Vector3(0, m.top_y, -hr * 0.04), "AccTop")
	var neck := m.acc_root
	var back := m._pivot(m.body_pivot, Vector3(0, m.by * 0.5, 0), "AccBack")
	back.scale = Vector3.ONE * (1.0 + (m.fluff - 1.0) * 0.75)
	var ep := m.eye_pos
	var er := m.eye_r
	match shape:
		# ============================================================ tête
		"hat":
			top.rotation = Vector3(-0.1, 0, 0.05)
			m._cloth(m._cone(hr * 1.22, hr * 1.18, hr * 0.05), c, top, Vector3(0, hr * 0.02, 0))
			m._cloth(m._cone(hr * 1.26, hr * 1.26, hr * 0.03), c.darkened(0.12), top, Vector3(0, hr * 0.01, 0))
			m._cloth(m._cone(hr * 0.62, hr * 0.5, hr * 0.46), c, top, Vector3(0, hr * 0.26, 0))
			m._cloth(m._sphere(), c, top, Vector3(0, hr * 0.48, 0), Vector3(hr * 1.0, hr * 0.22, hr * 1.0))
			m._cloth(m._cone(hr * 0.635, hr * 0.6, hr * 0.13), c2, top, Vector3(0, hr * 0.11, 0))
			_flower(m, top, Vector3(hr * 0.63, hr * 0.14, hr * 0.12), hr * 0.085, WHITE)
		"cap":
			top.position.y -= hr * 0.3
			top.rotation = Vector3(-0.12, 0, 0)
			m._cloth(m._sphere(), c, top, Vector3.ZERO, Vector3(hr * 1.72, hr * 1.0, hr * 1.78))
			m._cloth(m._sphere(), c.darkened(0.18), top, Vector3(0, hr * 0.04, hr * 0.92), Vector3(hr * 1.25, hr * 0.08, hr * 0.95), Vector3(0.12, 0, 0))
			m._cloth(m._sphere(), c2, top, Vector3(0, hr * 0.5, 0), Vector3.ONE * hr * 0.13)
			m._cloth(m._sphere(), c2, top, Vector3(0, hr * 0.22, hr * 0.8), Vector3(hr * 0.32, hr * 0.24, hr * 0.08))
		"beret":
			top.position.x -= hr * 0.12
			top.rotation = Vector3(-0.15, 0, 0.3)
			m._cloth(m._sphere(), c, top, Vector3(0, hr * 0.03, 0), Vector3(hr * 1.5, hr * 0.42, hr * 1.4))
			m._cloth(m._cone(hr * 0.58, hr * 0.6, hr * 0.1), c.darkened(0.2), top, Vector3(hr * 0.08, -hr * 0.09, 0))
			m._cloth(m._cone(hr * 0.02, hr * 0.03, hr * 0.14), c.darkened(0.2), top, Vector3(0, hr * 0.29, 0))
		"party":
			top.position.x += hr * 0.1
			top.rotation = Vector3(-0.1, 0, -0.18)
			m._cloth(m._cone(hr * 0.42, 0.004, hr * 1.0), c, top, Vector3(0, hr * 0.5, 0))
			for k in 3:
				var rr := hr * (0.36 - k * 0.11)
				m._mi(m._torus(rr - hr * 0.035, rr + hr * 0.02), GOLD if k % 2 == 0 else c2, top, Vector3(0, hr * (0.14 + k * 0.27), 0))
			m._ell(c2, top, Vector3(0, hr * 1.02, 0), Vector3.ONE * hr * 0.2)
			m._mi(m._torus(hr * 0.38, hr * 0.46), c2, top, Vector3(0, hr * 0.02, 0))
		"crown":
			m._mi(m._cone(hr * 0.5, hr * 0.54, hr * 0.22), c, top, Vector3(0, hr * 0.1, 0), Vector3.ONE, Vector3.ZERO, 0.25, 0.1, 0.9)
			m._mi(m._torus(hr * 0.47, hr * 0.56), c.lightened(0.1), top, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 0.25, 0.1, 0.9)
			m._cloth(m._sphere(), Color(0.62, 0.14, 0.24), top, Vector3(0, hr * 0.2, 0), Vector3(hr * 0.9, hr * 0.5, hr * 0.9))
			var gems: Array = [Color(0.9, 0.2, 0.3), Color(0.25, 0.55, 0.95), Color(0.3, 0.8, 0.45)]
			for k in 5:
				var a := TAU * k / 5.0
				m._mi(m._cone(hr * 0.1, 0.003, hr * 0.3), c, top, Vector3(sin(a) * hr * 0.5, hr * 0.35, cos(a) * hr * 0.5), Vector3.ONE, Vector3.ZERO, 0.25, 0.1, 0.9)
				m._mi(m._sphere(), WHITE, top, Vector3(sin(a) * hr * 0.5, hr * 0.52, cos(a) * hr * 0.5), Vector3.ONE * hr * 0.09, Vector3.ZERO, 0.15, 0.2, 0.3)
				m._mi(m._sphere(), gems[k % 3], top, Vector3(sin(a + 0.63) * hr * 0.54, hr * 0.1, cos(a + 0.63) * hr * 0.54), Vector3.ONE * hr * 0.11, Vector3.ZERO, 0.08, 0.3, 0.2)
		"tiara":
			top.position.y -= hr * 0.12
			top.position.z += hr * 0.3
			top.rotation = Vector3(-0.3, 0, 0)
			m._mi(m._torus(hr * 0.48, hr * 0.58), c, top, Vector3.ZERO, Vector3(1, 1.6, 1), Vector3.ZERO, 0.2, 0.1, 0.9)
			for k in 5:
				var a2 := (k - 2) * 0.36
				var hh := hr * (0.52 - absf(k - 2) * 0.12)
				m._mi(m._cone(hr * 0.11, 0.003, hh), c, top, Vector3(sin(a2) * hr * 0.53, hh * 0.5, cos(a2) * hr * 0.53), Vector3.ONE, Vector3.ZERO, 0.2, 0.1, 0.9)
				m._mi(m._sphere(), c2 if k == 2 else WHITE, top, Vector3(sin(a2) * hr * 0.55, hh * 0.2, cos(a2) * hr * 0.56), Vector3.ONE * hr * (0.2 if k == 2 else 0.11), Vector3.ZERO, 0.08, 0.3, 0.2)
		"flower_crown", "laurel":
			top.position.y -= hr * 0.08
			top.rotation = Vector3(-0.15, 0, 0)
			m._mi(m._torus(hr * 0.56, hr * 0.68), c.darkened(0.2) if shape == "laurel" else Color(0.36, 0.6, 0.3), top, Vector3.ZERO, Vector3(1, 1.3, 1))
			for k in 10:
				var a3 := TAU * k / 10.0
				var fp := Vector3(sin(a3) * hr * 0.62, hr * 0.03, cos(a3) * hr * 0.62)
				if shape == "flower_crown":
					_flower(m, top, fp + Vector3(0, hr * 0.06, 0), hr * 0.17, FLOWERS[k % FLOWERS.size()], Vector3(-0.9, a3, 0))
				m._ell(c if shape == "laurel" else Color(0.4, 0.66, 0.32), top, Vector3(sin(a3 + 0.3) * hr * 0.65, hr * 0.03, cos(a3 + 0.3) * hr * 0.65), Vector3(hr * 0.38, hr * 0.1, hr * 0.2) if shape == "laurel" else Vector3(hr * 0.24, hr * 0.07, hr * 0.12), Vector3(0, a3 + 0.3, 0.6))
		"bow":
			top.position = Vector3(hr * 0.4, m.top_y - hr * 0.02, hr * 0.05)
			top.rotation = Vector3(0, 0, -0.25)
			_bow(m, top, c, hr * 1.5)
		"tophat":
			top.rotation = Vector3(-0.08, 0, 0.08)
			m._cloth(m._cone(hr * 0.82, hr * 0.82, hr * 0.045), c, top, Vector3(0, hr * 0.02, 0))
			m._cloth(m._cone(hr * 0.5, hr * 0.54, hr * 0.78), c, top, Vector3(0, hr * 0.42, 0))
			m._cloth(m._cone(hr * 0.515, hr * 0.515, hr * 0.14), c2, top, Vector3(0, hr * 0.12, 0))
			m._mi(m._sphere(), GOLD, top, Vector3(0, hr * 0.12, hr * 0.52), Vector3(hr * 0.14, hr * 0.12, hr * 0.05), Vector3.ZERO, 0.25, 0.1, 0.9)
		"cowboy":
			top.rotation = Vector3(-0.1, 0, 0)
			m._cloth(m._sphere(), c, top, Vector3(0, hr * 0.03, 0), Vector3(hr * 2.5, hr * 0.12, hr * 2.0))
			for sx in [-1.0, 1.0]:
				m._cloth(m._sphere(), c, top, Vector3(sx * hr * 1.0, hr * 0.14, 0), Vector3(hr * 0.6, hr * 0.12, hr * 1.7), Vector3(0, 0, sx * 0.55))
			m._cloth(m._sphere(), c, top, Vector3(0, hr * 0.32, 0), Vector3(hr * 1.1, hr * 0.8, hr * 1.25))
			m._cloth(m._sphere(), c.darkened(0.1), top, Vector3(0, hr * 0.62, 0), Vector3(hr * 0.5, hr * 0.14, hr * 1.0))
			m._cloth(m._cone(hr * 0.57, hr * 0.56, hr * 0.1), c2, top, Vector3(0, hr * 0.14, 0))
			m._mi(m._sphere(), GOLD, top, Vector3(0, hr * 0.14, hr * 0.6), Vector3.ONE * hr * 0.12, Vector3.ZERO, 0.25, 0.1, 0.9)
		"beanie":
			top.position.y -= hr * 0.3
			m._cloth(m._sphere(), c, top, Vector3(0, hr * 0.05, 0), Vector3(hr * 1.78, hr * 1.25, hr * 1.82))
			m._cloth(m._torus(hr * 0.72, hr * 0.95), c2, top, Vector3(0, -hr * 0.05, 0), Vector3(1, 1.5, 1.02))
			m._cloth(m._sphere(), c2, top, Vector3(0, hr * 0.72, 0), Vector3.ONE * hr * 0.36)
		"chef":
			m._cloth(m._cone(hr * 0.55, hr * 0.55, hr * 0.42), WHITE, top, Vector3(0, hr * 0.2, 0))
			for k in 5:
				var a4 := TAU * k / 5.0
				m._cloth(m._sphere(), WHITE, top, Vector3(sin(a4) * hr * 0.38, hr * 0.58, cos(a4) * hr * 0.38), Vector3.ONE * hr * 0.6)
			m._cloth(m._sphere(), WHITE, top, Vector3(0, hr * 0.72, 0), Vector3.ONE * hr * 0.7)
		"wizard":
			top.rotation = Vector3(-0.1, 0, 0.1)
			m._cloth(m._cone(hr * 1.05, hr * 1.05, hr * 0.045), c, top, Vector3(0, hr * 0.02, 0))
			m._cloth(m._cone(hr * 0.56, hr * 0.2, hr * 0.7), c, top, Vector3(0, hr * 0.38, 0))
			m._cloth(m._cone(hr * 0.2, 0.004, hr * 0.6), c, top, Vector3(hr * 0.12, hr * 0.95, 0), Vector3.ONE, Vector3(0, 0, -0.45))
			m._cloth(m._cone(hr * 0.575, hr * 0.56, hr * 0.1), c2, top, Vector3(0, hr * 0.1, 0))
			for k in 5:
				var a5 := k * 1.9
				m._mi(m._sphere(), GOLD, top, Vector3(sin(a5) * hr * (0.5 - k * 0.07), hr * (0.25 + k * 0.14), cos(a5) * hr * (0.5 - k * 0.07)), Vector3.ONE * hr * 0.09, Vector3.ZERO, 0.2, 0.2, 0.6)
		"santa":
			top.position.y -= hr * 0.12
			top.rotation = Vector3(-0.1, 0, 0)
			m._cloth(m._cone(hr * 0.7, hr * 0.32, hr * 0.6), c, top, Vector3(0, hr * 0.3, 0))
			m._cloth(m._cone(hr * 0.32, hr * 0.06, hr * 0.6), c, top, Vector3(hr * 0.2, hr * 0.72, 0), Vector3.ONE, Vector3(0, 0, -0.75))
			m._cloth(m._torus(hr * 0.62, hr * 0.84), WHITE, top, Vector3(0, hr * 0.02, 0), Vector3(1, 1.3, 1))
			m._cloth(m._sphere(), WHITE, top, Vector3(hr * 0.5, hr * 0.84, 0), Vector3.ONE * hr * 0.26)
		"bunny":
			_headband(m, top, c2, hr)
			for sx in [-1.0, 1.0]:
				m._cloth(m._sphere(), c, top, Vector3(sx * hr * 0.3, hr * 0.62, 0), Vector3(hr * 0.3, hr * 1.2, hr * 0.16), Vector3(0, 0, -sx * 0.18))
				m._cloth(m._sphere(), Color(1.0, 0.72, 0.8), top, Vector3(sx * hr * 0.3, hr * 0.62, hr * 0.045), Vector3(hr * 0.17, hr * 0.95, hr * 0.1), Vector3(0, 0, -sx * 0.18))
		"antlers":
			_headband(m, top, c2, hr)
			for sx in [-1.0, 1.0]:
				m._mi(m._cone(hr * 0.055, hr * 0.035, hr * 0.75), c, top, Vector3(sx * hr * 0.36, hr * 0.42, 0), Vector3.ONE, Vector3(0, 0, -sx * 0.3))
				m._mi(m._cone(hr * 0.04, hr * 0.015, hr * 0.36), c, top, Vector3(sx * hr * 0.6, hr * 0.56, 0), Vector3.ONE, Vector3(0, 0, -sx * 1.1))
				m._mi(m._cone(hr * 0.04, hr * 0.015, hr * 0.32), c, top, Vector3(sx * hr * 0.34, hr * 0.74, hr * 0.1), Vector3.ONE, Vector3(0.7, 0, sx * 0.2))
				m._mi(m._sphere(), Color(0.9, 0.2, 0.2), top, Vector3(sx * hr * 0.24, hr * 0.06, hr * 0.5), Vector3.ONE * hr * 0.1)
		"sailor":
			top.rotation = Vector3(-0.1, 0, 0.12)
			m._cloth(m._cone(hr * 0.6, hr * 0.66, hr * 0.3), WHITE, top, Vector3(0, hr * 0.16, 0))
			m._cloth(m._sphere(), WHITE, top, Vector3(0, hr * 0.32, 0), Vector3(hr * 1.3, hr * 0.2, hr * 1.3))
			m._cloth(m._torus(hr * 0.62, hr * 0.84), WHITE, top, Vector3(0, hr * 0.04, 0), Vector3(1, 1.6, 1))
			m._cloth(m._cone(hr * 0.635, hr * 0.66, hr * 0.08), c, top, Vector3(0, hr * 0.13, 0))
			m._cloth(m._sphere(), c, top, Vector3(0, hr * 0.42, 0), Vector3.ONE * hr * 0.14)
		"grad":
			top.rotation = Vector3(-0.08, 0.4, 0)
			m._cloth(m._cone(hr * 0.56, hr * 0.6, hr * 0.26), c, top, Vector3(0, hr * 0.1, 0))
			m._cloth(m._box(Vector3(hr * 1.5, hr * 0.05, hr * 1.5)), c, top, Vector3(0, hr * 0.26, 0))
			m._mi(m._sphere(), GOLD, top, Vector3(0, hr * 0.3, 0), Vector3.ONE * hr * 0.1, Vector3.ZERO, 0.25, 0.1, 0.9)
			m._mi(m._cone(hr * 0.012, hr * 0.012, hr * 0.5), GOLD, top, Vector3(hr * 0.4, hr * 0.27, hr * 0.4), Vector3.ONE, Vector3(PI * 0.5, PI * 0.25, 0))
			m._cloth(m._cone(hr * 0.05, hr * 0.02, hr * 0.26), GOLD, top, Vector3(hr * 0.76, hr * 0.12, hr * 0.76))
		"headphones":
			top.position.y -= hr * 0.92
			top.scale = Vector3.ONE * (1.0 + (m.fluff - 1.0) * 0.5)
			m._mi(m._torus(hr * 0.98, hr * 1.08), c.darkened(0.3), top, Vector3.ZERO, Vector3(1, 1, 1), Vector3(PI * 0.5, 0, 0), 0.4, 0.1, 0.2)
			for sx in [-1.0, 1.0]:
				m._mi(m._cone(hr * 0.36, hr * 0.36, hr * 0.2), c, top, Vector3(sx * hr * 0.98, -hr * 0.02, 0), Vector3.ONE, Vector3(0, 0, PI * 0.5), 0.5, 0.1, 0.1)
				m._cloth(m._cone(hr * 0.3, hr * 0.3, hr * 0.08), c2, top, Vector3(sx * hr * 0.86, -hr * 0.02, 0), Vector3.ONE, Vector3(0, 0, PI * 0.5))
		"earflower":
			_flower(m, m.head_pivot, Vector3(hr * 0.62, m.top_y - hr * 0.2, hr * 0.4), hr * 0.3, c)
			m._ell(Color(0.4, 0.66, 0.32), m.head_pivot, Vector3(hr * 0.78, m.top_y - hr * 0.3, hr * 0.3), Vector3(hr * 0.42, hr * 0.12, hr * 0.22), Vector3(0, 0.4, 0.5))
		"viking":
			top.position.y -= hr * 0.32
			m._mi(m._sphere(), c, top, Vector3.ZERO, Vector3(hr * 1.76, hr * 1.12, hr * 1.8), Vector3.ZERO, 0.3, 0.1, 0.8)
			m._mi(m._torus(hr * 0.76, hr * 0.9), GOLD, top, Vector3(0, -hr * 0.02, 0), Vector3(1, 1.4, 1.02), Vector3.ZERO, 0.25, 0.1, 0.9)
			m._mi(m._cone(hr * 0.05, hr * 0.05, hr * 1.1), GOLD, top, Vector3(0, hr * 0.32, hr * 0.02), Vector3(1, 1, 1), Vector3(PI * 0.5, 0, 0), 0.25, 0.1, 0.9)
			for sx in [-1.0, 1.0]:
				m._mi(m._cone(hr * 0.16, hr * 0.1, hr * 0.4), c2, top, Vector3(sx * hr * 0.92, hr * 0.2, 0), Vector3.ONE, Vector3(0, 0, -sx * 1.05))
				m._mi(m._cone(hr * 0.1, 0.004, hr * 0.42), c2, top, Vector3(sx * hr * 1.2, hr * 0.5, 0), Vector3.ONE, Vector3(0, 0, -sx * 0.25))
		"halo":
			var hm := m._mi(m._torus(hr * 0.42, hr * 0.54), c, top, Vector3(0, hr * 0.5, 0), Vector3(1, 1.2, 1))
			hm.material_override = WorldBuilder._emit_mat(c, 1.1)
			hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"pirate":
			top.rotation = Vector3(-0.1, 0, 0)
			m._cloth(m._sphere(), c, top, Vector3(0, hr * 0.16, 0), Vector3(hr * 1.3, hr * 0.8, hr * 1.3))
			m._cloth(m._cone(hr * 0.9, hr * 0.9, hr * 0.05), c, top, Vector3(0, hr * 0.02, 0), Vector3(1.15, 1, 0.8))
			for sz in [-1.0, 1.0]:
				m._cloth(m._sphere(), c, top, Vector3(0, hr * 0.3, sz * hr * 0.4), Vector3(hr * 2.0, hr * 0.86, hr * 0.2), Vector3(-sz * 0.3, 0, 0))
				m._cloth(m._sphere(), c2, top, Vector3(0, hr * 0.56, sz * hr * 0.3), Vector3(hr * 1.6, hr * 0.12, hr * 0.12))
			m._ell(WHITE, top, Vector3(0, hr * 0.36, hr * 0.52), Vector3(hr * 0.3, hr * 0.28, hr * 0.1))
			m._ell(WHITE, top, Vector3(0, hr * 0.22, hr * 0.55), Vector3(hr * 0.18, hr * 0.16, hr * 0.08))
			for sx in [-1.0, 1.0]:
				m._ell(c, top, Vector3(sx * hr * 0.06, hr * 0.37, hr * 0.57), Vector3.ONE * hr * 0.07)
				m._ell(WHITE, top, Vector3(0, hr * 0.17, hr * 0.56), Vector3(hr * 0.5, hr * 0.06, hr * 0.05), Vector3(0, 0, sx * 0.6))
		# ============================================================ yeux
		"glasses":
			var gp := m._pivot(m.head_pivot, Vector3(0, ep.y, ep.z + er * 0.75), "AccEyes")
			var lens := StandardMaterial3D.new()
			var lc: Color = it.get("lens", Color(0.12, 0.14, 0.2, 0.62))
			lens.albedo_color = lc
			lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			lens.roughness = 0.05
			lens.metallic_specular = 0.9
			var lr := er * 1.32
			for sx in [-1.0, 1.0]:
				var lp := Vector3(sx * ep.x, 0, 0)
				var lm := m._mi(m._cone(lr, lr, hr * 0.02), c, gp, lp, Vector3(1, 1, 0.9), Vector3(PI / 2, sx * 0.25, 0))
				lm.material_override = lens
				lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				m._mi(m._torus(lr * 0.94, lr * 1.14), c, gp, lp, Vector3(1, 1, 0.9), Vector3(PI / 2, sx * 0.25, 0), 0.2, 0.1, 0.4)
				m._mi(m._cone(hr * 0.022, hr * 0.022, hr * 0.8), c, gp, Vector3(sx * (ep.x + lr * 1.0), hr * 0.03, -hr * 0.4), Vector3.ONE, Vector3(PI / 2, 0, 0), 0.2, 0.1, 0.4)
			m._mi(m._cone(hr * 0.028, hr * 0.028, maxf(0.01, (ep.x - lr) * 2.0 + hr * 0.08)), c, gp, Vector3(0, hr * 0.04, hr * 0.03), Vector3.ONE, Vector3(0, 0, PI / 2), 0.2, 0.1, 0.4)
		"monocle":
			var mp := m._pivot(m.head_pivot, Vector3(ep.x, ep.y, ep.z + er * 0.8), "AccEyes")
			var ml := m._mi(m._cone(er * 1.3, er * 1.3, hr * 0.015), c, mp, Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0.25, 0))
			var mm := StandardMaterial3D.new()
			mm.albedo_color = Color(0.85, 0.93, 1.0, 0.25)
			mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mm.roughness = 0.03
			mm.metallic_specular = 1.0
			ml.material_override = mm
			m._mi(m._torus(er * 1.24, er * 1.46), c, mp, Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0.25, 0), 0.2, 0.1, 0.9)
			for k in 6:
				m._mi(m._sphere(), c, mp, Vector3(er * 1.3 + k * hr * 0.05, -er * 1.0 - k * k * hr * 0.035, -k * hr * 0.03), Vector3.ONE * hr * 0.045, Vector3.ZERO, 0.2, 0.1, 0.9)
		# ============================================================ cou
		"bandana":
			m._cloth(m._torus(hr * 0.6, hr * 0.84), c, neck, Vector3.ZERO, Vector3(1, 1.2, 1), Vector3(0.75, 0, 0))
			var tip := m._cloth(m._cone(hr * 0.72, 0.004, hr * 1.05), c, neck, Vector3(0, -hr * 0.62, hr * 0.42), Vector3(1, 1, 0.22), Vector3(PI + 0.42, 0, 0))
			tip.name = "Bandana"
			for k in 5:
				m._ell(c2, neck, Vector3((k - 2) * hr * 0.19, -hr * (0.42 + (k % 2) * 0.24), hr * (0.6 - (k % 2) * 0.09)), Vector3.ONE * hr * 0.085)
			for sx in [-1.0, 1.0]:
				m._cloth(m._sphere(), c.darkened(0.12), neck, Vector3(sx * hr * 0.12, hr * 0.35, -hr * 0.62), Vector3(hr * 0.22, hr * 0.12, hr * 0.3), Vector3(0, sx * 0.6, 0))
		"scarf":
			m._cloth(m._torus(hr * 0.58, hr * 0.92), c, neck, Vector3(0, -hr * 0.02, 0), Vector3(1, 1.5, 1), Vector3(0.75, 0, 0))
			for side in 2:
				var px := hr * (0.28 - side * 0.5)
				var ang := 0.25 - side * 0.5
				for k in 4:
					m._cloth(m._sphere(), c if k % 2 == 0 else c2, neck, Vector3(px + k * hr * 0.03 * (1 - side * 2), -hr * (0.42 + k * 0.2), hr * (0.56 - side * 0.05)), Vector3(hr * 0.34, hr * 0.24, hr * 0.14), Vector3(0.3, 0, ang))
				for f in 3:
					m._cloth(m._cone(hr * 0.03, hr * 0.02, hr * 0.14), c.darkened(0.1), neck, Vector3(px + (f - 1) * hr * 0.1 + hr * 0.1 * (1 - side * 2), -hr * 1.18, hr * (0.52 - side * 0.05)), Vector3.ONE, Vector3(0.3, 0, 0))
		"bowtie":
			var bt := m._pivot(neck, Vector3(0, -hr * 0.6, hr * 0.66))
			for sx in [-1.0, 1.0]:
				m._cloth(m._cone(hr * 0.28, hr * 0.07, hr * 0.46), c, bt, Vector3(sx * hr * 0.26, 0, 0), Vector3(1, 1, 0.45), Vector3(0, 0, sx * PI * 0.5))
			m._cloth(m._sphere(), c.lightened(0.25), bt, Vector3.ZERO, Vector3(hr * 0.17, hr * 0.2, hr * 0.15))
		"tie":
			var tp := m._pivot(neck, Vector3(0, -hr * 0.55, hr * 0.64))
			tp.rotation = Vector3(0.35, 0, 0)
			m._cloth(m._sphere(), c.darkened(0.1), tp, Vector3.ZERO, Vector3(hr * 0.26, hr * 0.2, hr * 0.16))
			m._cloth(m._cone(hr * 0.2, hr * 0.1, hr * 0.8), c, tp, Vector3(0, -hr * 0.48, 0), Vector3(1, 1, 0.3))
			m._cloth(m._cone(0.004, hr * 0.2, hr * 0.2), c, tp, Vector3(0, -hr * 0.98, 0), Vector3(1, 1, 0.3))
			for k in 3:
				m._cloth(m._box(Vector3(hr * 0.3, hr * 0.05, hr * 0.02)), c2, tp, Vector3(0, -hr * (0.3 + k * 0.24), hr * 0.045), Vector3.ONE, Vector3(0, 0, 0.5))
		"bell":
			var bl := m._pivot(neck, Vector3(0, -hr * 0.74, hr * 0.6))
			m._mi(m._sphere(), c, bl, Vector3.ZERO, Vector3(hr * 0.42, hr * 0.42, hr * 0.42), Vector3.ZERO, 0.2, 0.2, 0.9)
			m._mi(m._cone(hr * 0.24, hr * 0.2, hr * 0.08), c.darkened(0.15), bl, Vector3(0, -hr * 0.19, 0), Vector3.ONE, Vector3.ZERO, 0.2, 0.2, 0.9)
			m._mi(m._torus(hr * 0.05, hr * 0.09), c, bl, Vector3(0, hr * 0.23, 0), Vector3.ONE, Vector3(PI * 0.5, 0, 0), 0.2, 0.2, 0.9)
			m._ell(Color(0.2, 0.16, 0.12), bl, Vector3(0, -hr * 0.08, hr * 0.19), Vector3(hr * 0.1, hr * 0.2, hr * 0.06))
		"medal":
			for sx in [-1.0, 1.0]:
				m._cloth(m._box(Vector3(hr * 0.16, hr * 0.62, hr * 0.03)), c, neck, Vector3(sx * hr * 0.2, -hr * 0.5, hr * 0.6), Vector3.ONE, Vector3(0.35, 0, sx * 0.45))
			var md := m._pivot(neck, Vector3(0, -hr * 0.86, hr * 0.72))
			m._mi(m._cone(hr * 0.26, hr * 0.26, hr * 0.05), GOLD, md, Vector3.ZERO, Vector3.ONE, Vector3(PI * 0.5 - 0.35, 0, 0), 0.2, 0.2, 0.9)
			m._mi(m._cone(hr * 0.16, hr * 0.16, hr * 0.06), c2, md, Vector3(0, 0, hr * 0.01), Vector3.ONE, Vector3(PI * 0.5 - 0.35, 0, 0), 0.25, 0.2, 0.7)
		"lei", "pearls", "ruff":
			var ring := m._pivot(neck, Vector3(0, -hr * 0.1, hr * 0.02))
			ring.rotation = Vector3(0.75, 0, 0)
			var n := 14 if shape != "ruff" else 16
			for k in n:
				var a7 := TAU * k / n
				var rp := Vector3(sin(a7) * hr * 0.8, 0, cos(a7) * hr * 0.8)
				match shape:
					"lei":
						_flower(m, ring, rp, hr * 0.11, FLOWERS[k % FLOWERS.size()], Vector3(PI * 0.5, 0, 0))
					"pearls":
						m._mi(m._sphere(), c, ring, rp, Vector3.ONE * hr * 0.17, Vector3.ZERO, 0.12, 0.3, 0.3)
					_:
						m._cloth(m._sphere(), c, ring, rp * 1.05, Vector3(hr * 0.3, hr * 0.14, hr * 0.42), Vector3(0, a7, 0))
			if shape == "ruff":
				m._cloth(m._torus(hr * 0.56, hr * 0.8), c2, ring, Vector3.ZERO, Vector3(1, 0.9, 1))
		"tag":
			var tg := m._pivot(neck, Vector3(0, -hr * 0.78, hr * 0.66))
			tg.rotation = Vector3(0.3, 0, 0)
			tg.scale = Vector3.ONE * 1.45
			m._mi(m._cone(hr * 0.1, hr * 0.1, hr * 0.42), c, tg, Vector3.ZERO, Vector3(1, 1, 0.5), Vector3(0, 0, PI * 0.5), 0.2, 0.2, 0.9)
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					m._mi(m._sphere(), c, tg, Vector3(sx * hr * 0.24, sy * hr * 0.07, 0), Vector3(hr * 0.2, hr * 0.2, hr * 0.1), Vector3.ZERO, 0.2, 0.2, 0.9)
			m._mi(m._torus(hr * 0.04, hr * 0.07), SILVER, tg, Vector3(0, hr * 0.17, 0), Vector3.ONE, Vector3(PI * 0.5, 0, 0), 0.2, 0.2, 0.9)
		# ============================================================ dos
		"backpack":
			m._cloth(m._sphere(), c, back, Vector3(0, m.by * 0.26, 0), Vector3(m.bx * 0.8, m.by * 0.8, m.bz * 0.52))
			m._cloth(m._sphere(), c.darkened(0.15), back, Vector3(0, m.by * 0.2, -m.bz * 0.22), Vector3(m.bx * 0.56, m.by * 0.46, m.bz * 0.22))
			m._cloth(m._sphere(), c2, back, Vector3(0, m.by * 0.52, m.bz * 0.02), Vector3(m.bx * 0.66, m.by * 0.2, m.bz * 0.44))
			m._mi(m._sphere(), GOLD, back, Vector3(0, m.by * 0.26, -m.bz * 0.33), Vector3.ONE * m.bx * 0.09, Vector3.ZERO, 0.25, 0.1, 0.85)
			_straps(m, back, c.darkened(0.25))
		"saddlebags":
			for sx in [-1.0, 1.0]:
				m._cloth(m._sphere(), c, back, Vector3(sx * m.bx * 0.5, -m.by * 0.14, 0), Vector3(m.bx * 0.34, m.by * 0.5, m.bz * 0.42))
				m._cloth(m._sphere(), c.darkened(0.15), back, Vector3(sx * m.bx * 0.56, -m.by * 0.02, 0), Vector3(m.bx * 0.3, m.by * 0.18, m.bz * 0.44))
				m._mi(m._sphere(), GOLD, back, Vector3(sx * m.bx * 0.68, -m.by * 0.1, 0), Vector3.ONE * m.bx * 0.08, Vector3.ZERO, 0.25, 0.1, 0.85)
			m._cloth(m._sphere(), c2, back, Vector3(0, m.by * 0.03, 0), Vector3(m.bx * 1.05, m.by * 0.12, m.bz * 0.34))
			_straps(m, back, c.darkened(0.25))
		"cape":
			m._cloth(m._sphere(), c, back, Vector3(0, m.by * 0.02, -m.bz * 0.08), Vector3(m.bx * 1.14, m.by * 0.16, m.bz * 0.86))
			m._cloth(m._sphere(), c, back, Vector3(0, -m.by * 0.2, -m.bz * 0.5), Vector3(m.bx * 1.3, m.by * 0.14, m.bz * 0.56), Vector3(-0.6, 0, 0))
			for sx in [-1.0, 1.0]:
				m._cloth(m._sphere(), c, back, Vector3(sx * m.bx * 0.5, -m.by * 0.2, -m.bz * 0.08), Vector3(m.bx * 0.2, m.by * 0.6, m.bz * 0.8), Vector3(0, 0, -sx * 0.3))
			m._cloth(m._torus(m.hr * 0.56, m.hr * 0.86), c2, neck, Vector3.ZERO, Vector3(1, 1.3, 1), Vector3(0.75, 0, 0))
			m._mi(m._sphere(), GOLD, neck, Vector3(0, -m.hr * 0.5, m.hr * 0.62), Vector3.ONE * m.hr * 0.24, Vector3.ZERO, 0.2, 0.2, 0.9)
		"wings":
			var kind := str(it.get("wing", "angel"))
			for sx in [-1.0, 1.0]:
				var w := m._pivot(back, Vector3(sx * m.bx * 0.22, m.by * 0.06, m.bz * 0.12))
				w.rotation = Vector3(0, -sx * 0.5, -sx * 0.55)
				if kind == "butterfly":
					m._cloth(m._sphere(), c, w, Vector3(sx * m.bx * 0.55, m.by * 0.5, 0), Vector3(m.bx * 0.9, m.by * 1.05, m.bz * 0.05))
					m._cloth(m._sphere(), c2, w, Vector3(sx * m.bx * 0.45, -m.by * 0.25, 0), Vector3(m.bx * 0.8, m.by * 0.8, m.bz * 0.05))
					for k in 3:
						m._ell(WHITE, w, Vector3(sx * m.bx * (0.5 + k * 0.16), m.by * (0.35 + k * 0.22), m.bz * 0.03), Vector3(m.bx * 0.16, m.bx * 0.16, m.bz * 0.03))
					m._cloth(m._sphere(), Color(0.2, 0.16, 0.14), w, Vector3(sx * m.bx * 0.55, m.by * 0.5, 0), Vector3(m.bx * 0.96, m.by * 1.11, m.bz * 0.03))
				else:
					for k in 4:
						m._cloth(m._sphere(), c if k % 2 == 0 else c2, w, Vector3(sx * m.bx * (0.3 + k * 0.2), m.by * (0.55 - k * 0.14), -k * m.bz * 0.02), Vector3(m.bx * 0.36, m.by * (1.1 - k * 0.16), m.bz * 0.07), Vector3(0, 0, -sx * (0.2 + k * 0.28)))
			_straps(m, back, c2.darkened(0.1))
		"balloon":
			var bx2 := m.bx * 0.3
			m._mi(m._cone(0.004, 0.004, m.by * 3.2), WHITE, back, Vector3(bx2, m.by * 1.6, 0), Vector3.ONE, Vector3(0, 0, -0.08))
			m._mi(m._sphere(), c, back, Vector3(bx2 + m.by * 0.27, m.by * 3.7, 0), Vector3(m.hr * 1.9, m.hr * 2.3, m.hr * 1.9), Vector3.ZERO, 0.25, 0.4, 0.1)
			m._mi(m._cone(m.hr * 0.12, 0.004, m.hr * 0.16), c.darkened(0.1), back, Vector3(bx2 + m.by * 0.25, m.by * 3.12, 0))
			m._ell(Color(1, 1, 1, 1), back, Vector3(bx2 + m.by * 0.27 + m.hr * 0.4, m.by * 3.95, m.hr * 0.6), Vector3(m.hr * 0.3, m.hr * 0.5, m.hr * 0.2))
			_straps(m, back, WHITE)
		"tutu":
			var tu := m._pivot(m.body_pivot, Vector3(0, m.by * 0.05, -m.bz * 0.2))
			tu.rotation = Vector3(PI * 0.5 - 0.15, 0, 0)
			for layer in 2:
				var n2 := 14
				for k in n2:
					var a8 := TAU * k / n2 + layer * 0.22
					m._cloth(m._sphere(), c if (k + layer) % 2 == 0 else c2, tu, Vector3(sin(a8) * m.bx * (0.74 + layer * 0.1), cos(a8) * m.by * (0.74 + layer * 0.1), layer * m.bz * 0.07), Vector3(m.bx * 0.56, m.bx * 0.56, m.bz * 0.09), Vector3(0, 0, -a8))
			m._cloth(m._torus(m.bx * 0.42, m.bx * 0.52), c.darkened(0.15), tu, Vector3.ZERO, Vector3(1, 1, m.by / m.bx), Vector3(PI * 0.5, 0, 0))

## Petite fleur à cinq pétales et cœur jaune.
static func _flower(m: PetModel, parent: Node3D, pos: Vector3, r: float, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var f := m._pivot(parent, pos)
	f.rotation = rot
	for q in 5:
		var b := TAU * q / 5.0
		m._ell(col, f, Vector3(cos(b) * r * 0.8, sin(b) * r * 0.8, 0), Vector3(r * 1.0, r * 1.0, r * 0.5))
	m._ell(Color(1.0, 0.8, 0.25), f, Vector3(0, 0, r * 0.25), Vector3.ONE * r * 0.8)

## Nœud à deux coques avec pans.
static func _bow(m: PetModel, p: Node3D, c: Color, s: float) -> void:
	for sx in [-1.0, 1.0]:
		m._cloth(m._sphere(), c, p, Vector3(sx * s * 0.22, 0, 0), Vector3(s * 0.36, s * 0.27, s * 0.14), Vector3(0, 0, sx * 0.35))
		m._cloth(m._sphere(), c.darkened(0.15), p, Vector3(sx * s * 0.2, 0, s * 0.03), Vector3(s * 0.16, s * 0.12, s * 0.1), Vector3(0, 0, sx * 0.35))
		m._cloth(m._sphere(), c.darkened(0.08), p, Vector3(sx * s * 0.12, -s * 0.2, 0), Vector3(s * 0.12, s * 0.3, s * 0.06), Vector3(0, 0, sx * 0.5))
	m._cloth(m._sphere(), c.lightened(0.15), p, Vector3.ZERO, Vector3.ONE * s * 0.16)

## Serre-tête (support des oreilles de lapin, des bois…).
static func _headband(m: PetModel, top: Node3D, c: Color, hr: float) -> void:
	var hb := m._pivot(top, Vector3(0, -hr * 0.86, 0))
	hb.scale = Vector3.ONE * (1.0 + (m.fluff - 1.0) * 0.5)
	m._cloth(m._torus(hr * 0.9, hr * 0.99), c, hb, Vector3.ZERO, Vector3.ONE, Vector3(PI * 0.5, 0, 0))

## Sangles autour du corps pour tout ce qui se porte sur le dos.
static func _straps(m: PetModel, back: Node3D, c: Color) -> void:
	for zz in [m.bz * 0.16, -m.bz * 0.14]:
		m._cloth(m._torus(m.bx * 0.47, m.bx * 0.55), c, back, Vector3(0, -m.by * 0.44, zz), Vector3(1, 1, m.by / m.bx * 1.05), Vector3(PI * 0.5, 0, 0))
