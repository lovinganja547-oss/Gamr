extends Node
## Compile tous les scripts du projet et signale les erreurs.
func _ready() -> void:
	var files: Array[String] = []
	_scan("res://scripts", files)
	_scan("res://tests", files)
	var bad := 0
	for f in files:
		var s: Script = load(f)
		if s == null or not s.can_instantiate():
			print("ECHEC: ", f); bad += 1
	print("SCRIPTS: %d, ECHECS: %d" % [files.size(), bad])
	get_tree().quit(1 if bad > 0 else 0)
func _scan(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null: return
	for f in d.get_files():
		if f.ends_with(".gd"): out.append(dir + "/" + f)
	for sub in d.get_directories(): _scan(dir + "/" + sub, out)
