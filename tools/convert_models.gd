extends SceneTree
## Convertit assets/models/**/*.bin (sortie de gen_models.py) en ArrayMesh .res.
## Usage : godot --headless --path . -s tools/convert_models.gd
func _init() -> void:
	var root := "res://assets/models"
	var n := 0
	for breed in DirAccess.get_directories_at(root):
		var dir := root + "/" + breed
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".bin"):
				continue
			var bytes := FileAccess.get_file_as_bytes(dir + "/" + f)
			var nv := bytes.decode_s32(0)
			var ni := bytes.decode_s32(4)
			var fl := bytes.slice(8, 8 + nv * 40).to_float32_array()
			var idx := bytes.slice(8 + nv * 40, 8 + nv * 40 + ni * 4).to_int32_array()
			var pos := PackedVector3Array(); pos.resize(nv)
			var nrm := PackedVector3Array(); nrm.resize(nv)
			var col := PackedColorArray(); col.resize(nv)
			for i in nv:
				var o := i * 10
				pos[i] = Vector3(fl[o], fl[o + 1], fl[o + 2])
				nrm[i] = Vector3(fl[o + 3], fl[o + 4], fl[o + 5])
				col[i] = Color(fl[o + 6], fl[o + 7], fl[o + 8], fl[o + 9])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = pos
			arr[Mesh.ARRAY_NORMAL] = nrm
			arr[Mesh.ARRAY_COLOR] = col
			arr[Mesh.ARRAY_INDEX] = idx
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var out := dir + "/" + f.get_basename() + ".res"
			ResourceSaver.save(m, out, ResourceSaver.FLAG_COMPRESS)
			DirAccess.remove_absolute(dir + "/" + f)
			n += 1
	print("meshes converties : ", n)
	quit()
