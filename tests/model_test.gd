extends Node3D
## Rendu de contrôle : 6 races dans plusieurs postures -> capture PNG.
var frames := 0
var pets: Array = []
func _ready() -> void:
	var cam := Camera3D.new(); cam.position = Vector3(0, 1.3, 3.4); cam.fov = 40; add_child(cam); cam.look_at(Vector3(0, 0.25, 0))
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(-0.9, 0.5, 0); sun.shadow_enabled = true; sun.light_energy = 0.5; add_child(sun)
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.75, 0.88, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.9, 0.85, 0.8); env.ambient_light_energy = 0.32; we.environment = env; add_child(we)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(10, 10); g.mesh = pm; g.material_override = PetModel.mat(Color(0.6, 0.8, 0.45)); add_child(g)
	var poses: Array = OS.get_cmdline_user_args()
	var pose: String = poses[0] if poses.size() > 0 else "stand"
	var i := 0
	for b in GameData.BREED_ORDER:
		var m := PetModel.new(); add_child(m)
		m.setup({"breed": b, "palette": 0, "eyes": i % 5, "collar": "collar_red", "accessory": ["bandana", "bow", "hat", "crown", "glasses", "scarf"][i]}, 2)
		m.position = Vector3((i % 3 - 1) * 0.75, 0, -(i / 3) * 0.9)
		m.rotation.y = 0.6
		m.set_posture(pose, 100.0)
		if pose == "walk": m.move_speed = 0.8
		m.expression = "happy" if i % 2 == 0 else "neutral"
		m.tongue_out = 1.0 if i == 0 else 0.0
		pets.append(m); i += 1
func _process(_d: float) -> void:
	frames += 1
	if frames == 30:
		var img := get_viewport().get_texture().get_image()
		var args := OS.get_cmdline_user_args()
		img.save_png("/tmp/claude-0/-home-user-Gamr/c32690a7-dff0-58d8-999f-429837758d0c/scratchpad/model_%s.png" % (args[0] if args.size() > 0 else "stand"))
		get_tree().quit()
