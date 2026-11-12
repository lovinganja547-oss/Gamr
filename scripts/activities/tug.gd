class_name TugActivity
extends Activity
## Tir à la corde : glisser vers le bas pour tirer ; l'animal tire par à-coups selon
## son énergie et son caractère. Gagner ou perdre rend l'animal heureux.

const DURATION := 50.0
const TOY_LEN := 0.9

var balance := 0.0        # -100 (l'animal gagne) .. 100 (le joueur gagne)
var meter: ProgressBar
var time_left := DURATION
var rope: MeshInstance3D
var handle := Vector3.ZERO
var _power := 0.0          # force du joueur : chaque coup de doigt vers le bas l'augmente, elle retombe doucement
var _last_y := 0.0
var _holding := false
var _dog_force := 0.0
var _burst_t := 0.0
var _dog_rest := false     # l'animal reprend son souffle : c'est le moment de tirer
var phase_label: Label
# Direction : l'animal tire d'un côté, il faut tirer dans le sens indiqué pour être efficace
const DIR_ANGLES: Array[float] = [-0.65, 0.0, 0.65]
var dir_idx := 1
var _dir_t := 0.0
var dir_boxes: Array[PanelContainer] = []
# Prise : chaque traction fatigue la main ; à zéro la corde glisse
var grip := 100.0
var grip_bar: ProgressBar
var _idle_t := 0.0
var _slip_t := 0.0
var strength := 1.0
var start_pos := Vector3.ZERO

func _start() -> void:
	make_top("[i:tug] " + tr("Tir à la corde"))
	info_label.text = tr("Tirez dans le sens de la flèche. Relâchez pour reprendre votre prise.")
	var bb := bottom_bar()
	var pv := UiKit.panel(14)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vv := UiKit.vbox(4)
	var h := UiKit.hbox(6)
	h.add_child(UiKit.label(pet_name(), 22, UiKit.C_SUB))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(UiKit.label(tr("Vous"), 22, UiKit.C_SUB))
	vv.add_child(h)
	meter = UiKit.bar(50, UiKit.C_ACCENT, 26)
	vv.add_child(meter)
	phase_label = UiKit.label("", 26, UiKit.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	vv.add_child(phase_label)
	var dh := UiKit.hbox(8)
	for k in 3:
		var bx := PanelContainer.new()
		bx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bx.custom_minimum_size = Vector2(0, 64)
		var dl := UiKit.label(["[i:left] " + tr("À gauche"), tr("Tout droit"), "[i:right] " + tr("À droite")][k], 22, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		bx.add_child(dl)
		dir_boxes.append(bx)
		dh.add_child(bx)
	vv.add_child(dh)
	var gh := UiKit.hbox(6)
	gh.add_child(UiKit.label(tr("Prise"), 22, UiKit.C_SUB))
	grip_bar = UiKit.bar(100, UiKit.C_ACCENT2, 20)
	grip_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grip_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gh.add_child(grip_bar)
	vv.add_child(gh)
	_show_dir()
	pv.add_child(vv)
	bb.add_child(pv)
	var p := GameState.active_pet()
	var temper: String = p.get("temperament", "")
	strength = 0.8 + float(p["traits"].get("energy", 50)) / 100.0 * 0.5
	if temper in ["joueur", "energique"]:
		strength *= 1.15
	elif temper in ["calme", "timide"]:
		strength *= 0.85
	strength *= lerpf(0.6, 1.0, p["needs"]["energy"] / 100.0)
	start_pos = pet.player_pos + Vector3(0, 0, -TOY_LEN - 0.35)
	if main.nav:
		var f := main.nav.nearest_free(Vector2(start_pos.x, start_pos.z))
		start_pos = Vector3(f.x, 0, f.y)
	pet.position = start_pos
	pet.face(pet.player_pos)
	pet.model.set_posture("bow", 4.0)
	pet.model.expression = "focus"
	pet.model.wag_amp = 0.9
	pet.model.wag_speed = 16.0
	pet.state = "action"
	main.recenter_camera(0.2)
	main.cam_rig.yaw = atan2(pet.player_pos.x - pet.position.x, pet.player_pos.z - pet.position.z) + 0.5
	rope = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.018
	cm.height = 1.0
	cm.radial_segments = 8
	rope.mesh = cm
	rope.material_override = PetModel.mat(Color(0.86, 0.76, 0.5))
	main.world.add_child(rope)
	pet.voice()

func _show_dir() -> void:
	for k in dir_boxes.size():
		var on := k == dir_idx
		dir_boxes[k].add_theme_stylebox_override("panel", UiKit.sb(Color(1.0, 0.86, 0.5) if on else Color(1, 1, 1, 0.55), 18, 3 if on else 0, UiKit.C_ACCENT, false, 6))

func handle_input(event: InputEvent) -> bool:
	if finished:
		return false
	if event is InputEventScreenTouch and event.index == 0:
		_holding = event.pressed
		_last_y = event.position.y
		return true
	if event is InputEventScreenDrag and event.index == 0 and _holding:
		var rel: Vector2 = event.relative
		if rel.y > 0.0 and _slip_t <= 0.0:
			# efficacité selon la direction du geste par rapport à la flèche
			var ang := atan2(rel.x, rel.y)
			var match_k := clampf(1.0 - absf(ang - DIR_ANGLES[dir_idx]) / 0.6, 0.15, 1.0)
			var amount := rel.length()
			_power = minf(_power + amount / 260.0 * match_k, 3.0)
			grip = maxf(0.0, grip - amount / 52.0)
			_idle_t = 0.0
			if grip <= 0.0:
				# la corde glisse des mains : on perd du terrain et il faut reprendre sa prise
				_slip_t = 1.0
				_power = 0.0
				balance = maxf(-100.0, balance - 14.0)
				grip = 35.0
				Audio.play("fail", 0.0, -8.0)
				Audio.vibrate(40)
				big_hint(tr("La corde glisse !"), 0.7, UiKit.C_DANGER)
		return true
	return false

func _process(delta: float) -> void:
	if finished or pet == null:
		return
	time_left -= delta
	_power *= exp(-2.2 * delta)
	_slip_t = maxf(0.0, _slip_t - delta)
	_idle_t += delta
	if _idle_t > 0.22:
		grip = minf(100.0, grip + 34.0 * delta)
	grip_bar.value = grip
	grip_bar.add_theme_stylebox_override("fill", UiKit.sb(UiKit.need_color(grip), 12, 0, Color.TRANSPARENT, false, 0))
	# L'animal change de côté de temps en temps
	_dir_t -= delta
	if _dir_t <= 0.0:
		_dir_t = randf_range(2.2, 3.8)
		var nd := randi() % 3
		if nd == dir_idx:
			nd = (nd + 1 + randi() % 2) % 3
		dir_idx = nd
		_show_dir()
		Audio.play("tick", 0.05, -8.0)
	# Il alterne : il tire fort, puis reprend son souffle
	_burst_t -= delta
	if _burst_t <= 0.0:
		_dog_rest = not _dog_rest
		if _dog_rest:
			_burst_t = randf_range(0.9, 1.5)
			_dog_force = 0.22 * strength
			pet.model.set_posture("stand", 5.0)
			pet.model.tongue_out = 1.0
		else:
			_burst_t = randf_range(1.2, 2.0)
			_dog_force = randf_range(0.6, 1.0) * strength
			pet.model.set_posture("bow", 5.0)
			pet.model.tongue_out = 0.0
			if randf() < 0.4:
				pet.voice()
	var k := 1.4 if _dog_rest else 1.0
	balance = clampf(balance + (_power * k - _dog_force) * 13.0 * delta, -100.0, 100.0)
	meter.value = (balance + 100.0) * 0.5
	phase_label.text = tr("Il souffle : tirez !") if _dog_rest else tr("Il tire fort, tenez bon !")
	phase_label.add_theme_color_override("font_color", UiKit.C_ACCENT2 if _dog_rest else UiKit.C_DANGER)
	pet.model.head_extra.z = lerpf(pet.model.head_extra.z, [0.35, 0.0, -0.35][dir_idx], minf(1.0, delta * 4.0))
	# Animation : l'animal recule ou avance, secoue la tête
	var dir := (pet.player_pos - start_pos).normalized()
	pet.position = start_pos + dir * (balance / 100.0) * 0.35
	pet.model.shake = clampf(_dog_force * 0.25, 0.0, 0.4)
	pet.model.head_extra.y = sin(Time.get_ticks_msec() * 0.02) * 0.25 * _dog_force
	# Corde : de la gueule à la main du joueur
	var a := pet.model.held_anchor.global_position
	var b := Vector3(pet.player_pos.x, 0.55, pet.player_pos.z) + dir * 0.15
	rope.global_position = (a + b) * 0.5
	var len := a.distance_to(b)
	rope.scale = Vector3(1, maxf(len, 0.01), 1)
	if len > 0.01:
		rope.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
		rope.rotate_object_local(Vector3.RIGHT, PI / 2)
	info_label.text = tr("Temps : %d s") % int(maxf(time_left, 0.0))
	if balance >= 100.0 or balance <= -100.0 or time_left <= 0.0:
		_finish()

func _finish() -> void:
	finished = true
	pet.model.shake = 0.0
	pet.model.head_extra.y = 0.0
	pet.model.tongue_out = 0.0
	pet.model.head_extra.z = 0.0
	var won := balance > 0.0
	GameState.spend_energy("tug")
	GameState.change_need("mood", 12.0)
	GameState.change_need("affection", 6.0)
	GameState.add_relation(5)
	GameState.inc_stat("tug", 1)
	pet.model.expression = "happy"
	pet.model.hearts(2)
	pet.play_bow()
	var xp := 10
	var coins := 5
	var lines: Array = [tr("Vous avez gagné la corde !") if won else tr("%s a gagné, quelle fierté !") % pet_name()]
	if not GameState.reward_ok("tug", 0.25):
		xp = 0
		coins = 0
		lines.append(tr("Faites une petite pause avant la prochaine récompense."))
	show_results("[i:tug] " + tr("Tir à la corde"), lines, coins, xp)

func _exit_tree() -> void:
	super._exit_tree()
	if rope and is_instance_valid(rope):
		rope.queue_free()
	if pet:
		pet.model.shake = 0.0
