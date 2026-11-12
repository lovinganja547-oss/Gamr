class_name Boot
extends Control
## Écran de chargement : charge une seule fois toutes les ressources (textures, modèles, sons,
## icônes, shaders), les garde en mémoire, précompile les shaders, puis lance le jeu.

const MAIN_SCENE := "res://scenes/main.tscn"
const EXTS: Array[String] = ["png", "jpg", "svg", "res", "wav", "ogg", "gdshader", "woff"]
const DIRS: Array[String] = ["res://assets/textures", "res://assets/models", "res://assets/shaders", "res://assets/ui", "res://assets/audio"]
const BUDGET_MS := 14
const MIN_TIME := 1.2
const TIPS: Array[String] = [
	"Un animal propre et brossé gagne plus de points en concours.",
	"Dessinez votre trajet sur la carte : plus il est long, plus la balade rapporte.",
	"La boutique et la revente se trouvent en ville, pendant la balade.",
	"Répétez un ordre plusieurs jours de suite pour qu'il soit retenu.",
	"Pensez au shampooing avant de lancer un bain.",
	"Les missions de la semaine rapportent les plus belles récompenses.",
]

## Ressources conservées pendant toute la partie : plus aucun chargement disque en jeu.
static var keep: Dictionary = {}

var _queue: Array[String] = []
var _total := 1
var _done := 0
var _shown := 0.0
var _time := 0.0
var _stage := 0
var _frames := 0
var _bar: ProgressBar
var _pct: Label
var _warm: SubViewport
var _main: PackedScene

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/loading_bg.jpg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 50
	v.offset_right = -50
	v.offset_top = 70
	v.offset_bottom = -70
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 384)
	v.add_child(logo)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var tip := UiKit.label(tr(TIPS[randi() % TIPS.size()]), 26, Color(1, 0.97, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.05, 0.9))
	tip.add_theme_constant_override("outline_size", 8)
	v.add_child(tip)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 38)
	_bar.max_value = 1.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.1, 0.05, 0.6)
	track.set_corner_radius_all(19)
	track.set_border_width_all(4)
	track.border_color = Color(1, 0.96, 0.88)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.99, 0.62, 0.3)
	fill.set_corner_radius_all(15)
	fill.set_border_width_all(4)
	fill.border_color = Color(0, 0, 0, 0)
	_bar.add_theme_stylebox_override("background", track)
	_bar.add_theme_stylebox_override("fill", fill)
	v.add_child(_bar)
	_pct = UiKit.label("", 24, Color(1, 0.97, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	_pct.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.05, 0.9))
	_pct.add_theme_constant_override("outline_size", 8)
	v.add_child(_pct)
	for d in DIRS:
		_collect(d)
	_queue.reverse()
	_total = _queue.size() + 3

## Liste récursive ; dans un export les fichiers apparaissent sous la forme « x.png.import » ou « x.res.remap ».
func _collect(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for sub in da.get_directories():
		_collect(dir + "/" + sub)
	var seen := {}
	for f in da.get_files():
		var n := f.trim_suffix(".import").trim_suffix(".remap")
		if seen.has(n) or not EXTS.has(n.get_extension().to_lower()):
			continue
		seen[n] = true
		_queue.append(dir + "/" + n)

func _process(delta: float) -> void:
	_time += delta
	match _stage:
		0:
			var t0 := Time.get_ticks_msec()
			while not _queue.is_empty() and Time.get_ticks_msec() - t0 < BUDGET_MS:
				var p: String = _queue.pop_back()
				if not keep.has(p) and ResourceLoader.exists(p):
					var r := load(p)
					if r != null:
						keep[p] = r
				_done += 1
			if _queue.is_empty():
				_stage = 1
		1:
			_build_warmup()
			_done += 1
			_stage = 2
		2:
			# quelques images pour que le pilote compile réellement les programmes
			_frames += 1
			if _frames >= 4:
				_warm.queue_free()
				_warm = null
				_done += 1
				_stage = 3
		3:
			_main = load(MAIN_SCENE)
			keep[MAIN_SCENE] = _main
			_done += 1
			_stage = 4
		4:
			if _time >= MIN_TIME and _shown > 0.995:
				_stage = 5
				get_tree().change_scene_to_packed(_main)
	var target := clampf(float(_done) / float(_total), 0.0, 1.0)
	_shown = minf(target, _shown + delta * 1.6) if _stage < 4 else minf(1.0, _shown + delta * 2.5)
	_bar.value = _shown
	_pct.text = tr("Chargement… %d %%") % int(round(_shown * 100.0))

## Dessine une fois chaque shader et un animal complet dans une petite cible hors écran :
## les programmes sont compilés ici plutôt qu'à leur première apparition en jeu.
func _build_warmup() -> void:
	_warm = SubViewport.new()
	_warm.size = Vector2i(96, 96)
	_warm.own_world_3d = true
	_warm.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_warm)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.6, 4.0)
	_warm.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.4, 0)
	sun.shadow_enabled = int(GameState.setting("quality")) >= 1
	_warm.add_child(sun)
	var x := -1.6
	for p in keep:
		var sh := keep[p] as Shader
		if sh == null or sh.get_mode() != Shader.MODE_SPATIAL:
			continue
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.3, 0.3)
		mi.mesh = qm
		var sm := ShaderMaterial.new()
		sm.shader = sh
		mi.material_override = sm
		mi.position = Vector3(x, 1.4, 0)
		x += 0.4
		_warm.add_child(mi)
	var breed := "labrador"
	var pet: Dictionary = GameState.active_pet() if GameState.has_save() else {}
	if GameData.BREEDS.has(str(pet.get("breed", ""))):
		breed = str(pet["breed"])
	var model := PetModel.new()
	_warm.add_child(model)
	model.setup({"breed": breed, "palette": int(pet.get("palette", 0)), "eyes": int(pet.get("eyes", 0)), "collar": str(pet.get("collar", "collar_red")), "accessory": str(pet.get("accessory", "acc_none"))}, 1)
