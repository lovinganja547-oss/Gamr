class_name CameraRig
extends Node3D
## Caméra orbitale tactile qui suit doucement une cible.

var cam: Camera3D
var target: Node3D
var focus := Vector3(0, 0.35, 0)
var yaw := 0.0
var pitch := -0.32
var distance := 3.2
var min_dist := 1.1
var max_dist := 6.0
var focus_offset := Vector3(0, 0.3, 0)
var follow := true
var _shake := 0.0
var fixed_transform: Variant = null   # Transform3D pour les cadrages imposés
## Décale le sujet vers le haut de l'écran (fraction de la demi-hauteur), pour le garder visible au-dessus des panneaux.
var screen_shift := 0.0
var _shift := 0.0
## Volume que la caméra ne doit pas quitter (pièces fermées) ; taille nulle = libre.
var bounds_box := AABB()

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.05
	cam.far = 80.0
	add_child(cam)
	cam.current = true

func reset_view(dist: float = 3.2, p: float = -0.32, y: float = 0.0) -> void:
	distance = dist
	pitch = p
	yaw = y
	fixed_transform = null
	screen_shift = 0.0

func orbit(dx: float, dy: float) -> void:
	var k := float(GameState.setting("sensitivity")) if GameState.data.has("settings") else 1.0
	yaw -= dx * 0.006 * k
	pitch = clampf(pitch - dy * 0.004 * k, -1.1, -0.08)

func zoom(f: float) -> void:
	distance = clampf(distance * f, min_dist, max_dist)

func shake(a: float = 0.08) -> void:
	_shake = a

func _process(delta: float) -> void:
	if cam == null:
		return
	if fixed_transform is Transform3D:
		cam.global_transform = cam.global_transform.interpolate_with(fixed_transform, minf(1.0, delta * 4.0))
		return
	if follow and target and is_instance_valid(target):
		focus = focus.lerp(target.global_position + focus_offset, minf(1.0, delta * 3.0))
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	var raw := _avoid(focus, dir, distance)
	var want := _clamp_box(raw)
	if follow and raw.distance_to(want) > 0.35:
		# bloquée par un mur : la caméra tourne doucement vers l'intérieur de la pièce
		var c := bounds_box.get_center()
		var to_c := Vector3(c.x - focus.x, 0, c.z - focus.z)
		if to_c.length() > 0.2:
			yaw = lerp_angle(yaw, atan2(to_c.x, to_c.z), minf(1.0, delta * 1.5))
	cam.global_position = cam.global_position.lerp(want, minf(1.0, delta * 6.0))
	if _shake > 0.0 and UiKit.reduce_motion():
		_shake = 0.0
	if _shake > 0.0:
		cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake
		_shake = maxf(0.0, _shake - delta * 0.4)
	cam.look_at(focus, Vector3.UP)
	_shift = lerpf(_shift, screen_shift, minf(1.0, delta * 5.0))
	cam.v_offset = -_shift * distance * tan(deg_to_rad(cam.fov * 0.5))

## Obstacles du lieu (cercles au sol, comme la navigation) : la caméra ne les traverse pas.
var obstacles: Array = []

func _inside_obstacle(p: Vector3) -> bool:
	var q := Vector2(p.x, p.z)
	for o in obstacles:
		if q.distance_to(o["c"]) < float(o["r"]) + 0.35:
			return true
	return false

## Rapproche la caméra du sujet tant qu'elle serait dans un obstacle.
func _avoid(f: Vector3, dir: Vector3, dist: float) -> Vector3:
	var p := f + dir * dist
	if obstacles.is_empty() or not _inside_obstacle(p):
		return p
	var k := 0.9
	while k > 0.3:
		p = f + dir * dist * k
		if not _inside_obstacle(p):
			return p
		k -= 0.1
	return f + dir * dist * 0.3

func _clamp_box(p: Vector3) -> Vector3:
	if bounds_box.size == Vector3.ZERO:
		return p
	var a := bounds_box.position
	var b := bounds_box.end
	return Vector3(clampf(p.x, a.x, b.x), clampf(p.y, a.y, b.y), clampf(p.z, a.z, b.z))

## Distance pour cadrer un sujet de hauteur h et de largeur w (portrait), fill = part de l'écran.
func fit_distance(h: float, w: float, fill: float = 0.75) -> float:
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var tv := tan(deg_to_rad(cam.fov * 0.5))
	var th := tv * aspect
	return maxf(h * 0.5 / (tv * fill), w * 0.5 / (th * fill)) + w * 0.3

## Cadre un animal en entier (taille automatique), avec transition douce.
func frame_pet(pet: Node3D, top: float, length: float, shift: float = 0.0, p: float = -0.3) -> void:
	target = pet
	follow = true
	focus_offset = Vector3(0, top * 0.45, 0)
	distance = clampf(fit_distance(top, length * 1.1, 0.62), min_dist, max_dist)
	pitch = p
	screen_shift = shift
	fixed_transform = null
	# si le cadrage demandé traverse un mur, on se place côté pièce
	var f := pet.global_position + focus_offset
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	var raw := f + dir * distance
	if raw.distance_to(_clamp_box(raw)) > 0.35:
		var c := bounds_box.get_center()
		var to_c := Vector3(c.x - f.x, 0, c.z - f.z)
		if to_c.length() > 0.2:
			yaw = atan2(to_c.x, to_c.z)

func snap() -> void:
	if follow and target and is_instance_valid(target):
		focus = target.global_position + focus_offset
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	cam.global_position = _clamp_box(focus + dir * distance)
	cam.look_at(focus, Vector3.UP)

## Position du joueur virtuel (au sol devant la caméra).
func player_ground_pos() -> Vector3:
	var p := cam.global_position
	var f := focus
	var d := Vector3(p.x - f.x, 0, p.z - f.z)
	if d.length() < 0.01:
		d = Vector3(0, 0, 1)
	return f + d.normalized() * minf(distance * 0.55, 1.6) - Vector3(0, f.y, 0)
