extends Node3D
## Planche de contrôle : tous les accessoires portés par une race (argument), vus de trois quarts.
var ids: Array = []
var idx := -1
var frames := 0
var model: PetModel
var sheet: Image
var breed := "labrador"
var yaw := 0.75
const CELL := 320
const COLS := 8

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		breed = args[0]
	if args.size() > 1:
		yaw = float(args[1])
	var cam := Camera3D.new(); cam.fov = 34; add_child(cam)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(-0.9, 0.5, 0); sun.light_energy = 0.5; add_child(sun)
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.78, 0.9, 0.96)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.9, 0.88, 0.85); env.ambient_light_energy = 0.34; we.environment = env; add_child(we)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(10, 10); g.mesh = pm; g.material_override = PetModel.mat(Color(0.62, 0.8, 0.5)); add_child(g)
	for id in GameData.ITEMS.keys():
		if GameData.ITEMS[id].get("cat", "") == "accessory" and id != "acc_none" and (yaw < 2.0 or str(GameData.ITEMS[id].get("shape", "")) in ["backpack", "saddlebags", "cape", "wings", "balloon", "tutu"]):
			ids.append(id)
	var rows := int(ceil(ids.size() / float(COLS)))
	sheet = Image.create(COLS * CELL, rows * CELL, false, Image.FORMAT_RGB8)
	_next()

func _next() -> void:
	idx += 1
	if model:
		model.queue_free()
		model = null
	if idx >= ids.size():
		sheet.save_png("/tmp/claude-0/-home-user-Gamr/c32690a7-dff0-58d8-999f-429837758d0c/scratchpad/accsheet_%s%s.png" % [breed, "" if yaw < 2.0 else "_back"])
		print("ACC SHEET ", breed, " ", ids.size())
		get_tree().quit()
		return
	model = PetModel.new()
	add_child(model)
	model.setup({"breed": breed, "palette": 0, "eyes": 0, "collar": "collar_red", "accessory": ids[idx]}, 1)
	model.rotation.y = yaw
	model.set_posture("stand", 100.0)
	model.expression = "happy"
	var top := model.top_height()
	var cam := get_viewport().get_camera_3d()
	var mid := Vector3(0.05, top * 0.72, 0)
	cam.position = mid + Vector3(0.9, top * 0.55, 3.1).normalized() * (top * 1.75 + 0.55)
	cam.look_at(mid)
	frames = 0

func _process(_d: float) -> void:
	frames += 1
	if frames == 5 and model:
		var img := get_viewport().get_texture().get_image()
		var s := mini(img.get_width(), img.get_height())
		var sq := img.get_region(Rect2i((img.get_width() - s) / 2, (img.get_height() - s) / 2, s, s))
		sq.resize(CELL, CELL, Image.INTERPOLATE_BILINEAR)
		sq.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(sq, Rect2i(0, 0, CELL, CELL), Vector2i((idx % COLS) * CELL, (idx / COLS) * CELL))
		_next()
