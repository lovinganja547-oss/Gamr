extends SceneTree
## Planche de contrôle des icônes : godot --headless -s tests/icon_sheet.gd -- sortie.png
func _init() -> void:
	var dir := "res://assets/ui/icons/"
	var files := Array(DirAccess.get_files_at(dir)).filter(func(f): return f.ends_with(".svg"))
	files.sort()
	var cols := 16
	var cell := 96
	var rows := int(ceil(files.size() / float(cols)))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.93, 0.9, 0.85))
	for i in files.size():
		var img := Image.new()
		img.load_svg_from_buffer(FileAccess.get_file_as_bytes(dir + files[i]), 0.66)
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i((i % cols) * cell + 6, (i / cols) * cell + 6))
	sheet.save_png(OS.get_cmdline_user_args()[0])
	print(files.size(), " icônes")
	quit()
