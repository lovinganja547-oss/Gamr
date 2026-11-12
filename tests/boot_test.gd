extends SceneTree
## Lance le jeu par l'écran de chargement, capture pendant et après, mesure la durée.
var n := 0
var t0 := 0
var swapped := -1
var out := OS.get_environment("E2E_OUT")

func _initialize() -> void:
	t0 = Time.get_ticks_msec()
	change_scene_to_file("res://scenes/boot.tscn")

func _process(_d: float) -> bool:
	n += 1
	if n == 12:
		root.get_texture().get_image().save_png(out + "/boot_a.png")
	if swapped < 0 and current_scene != null and current_scene.name == "Main":
		swapped = n
		print("BOOT ms=", Time.get_ticks_msec() - t0, " frames=", n)
	if swapped < 0 and current_scene != null and current_scene.name == "Boot" and int(current_scene.get("_stage")) == 4 and not root.has_meta("b"):
		root.set_meta("b", true)
		root.get_texture().get_image().save_png(out + "/boot_b.png")
	if swapped > 0 and n == swapped + 8:
		root.get_texture().get_image().save_png(out + "/boot_c.png")
		return true
	return n > 3000
