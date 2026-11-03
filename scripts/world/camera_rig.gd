class_name CameraRig
extends Node3D
## Caméra orbitale tactile qui suit doucement une cible.

var cam: Camera3D
var target: Node3D
var focus := Vector3(0, 0.35, 0)
var yaw := 0.0
var pitch := -0.32
var distance := 3.2
var min_dist := 1.6
var max_dist := 6.0
var focus_offset := Vector3(0, 0.3, 0)
var follow := true
var _shake := 0.0
var fixed_transform: Variant = null   # Transform3D pour les cadrages imposés
## Décale le sujet vers le haut de l'écran (fraction de la demi-hauteur), pour le garder visible au-dessus des panneaux.
var screen_shift := 0.0
var _shift := 0.0

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
	yaw -= dx * 0.006
	pitch = clampf(pitch - dy * 0.004, -1.1, -0.08)

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
	var want := focus + dir * distance
	cam.global_position = cam.global_position.lerp(want, minf(1.0, delta * 6.0))
	if _shake > 0.0:
		cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake
		_shake = maxf(0.0, _shake - delta * 0.4)
	cam.look_at(focus, Vector3.UP)
	_shift = lerpf(_shift, screen_shift, minf(1.0, delta * 5.0))
	cam.v_offset = -_shift * distance * tan(deg_to_rad(cam.fov * 0.5))

func snap() -> void:
	if follow and target and is_instance_valid(target):
		focus = target.global_position + focus_offset
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	cam.global_position = focus + dir * distance
	cam.look_at(focus, Vector3.UP)

## Position du joueur virtuel (au sol devant la caméra).
func player_ground_pos() -> Vector3:
	var p := cam.global_position
	var f := focus
	var d := Vector3(p.x - f.x, 0, p.z - f.z)
	if d.length() < 0.01:
		d = Vector3(0, 0, 1)
	return f + d.normalized() * minf(distance * 0.55, 1.6) - Vector3(0, f.y, 0)
