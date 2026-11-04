class_name TugActivity
extends Activity
## Tir à la corde : glisser vers le bas pour tirer ; l'animal tire par à-coups selon
## son énergie et son caractère. Gagner ou perdre rend l'animal heureux.

const DURATION := 25.0
const TOY_LEN := 0.9

var balance := 0.0        # -100 (l'animal gagne) .. 100 (le joueur gagne)
var meter: ProgressBar
var time_left := DURATION
var rope: MeshInstance3D
var handle := Vector3.ZERO
var _pull := 0.0
var _last_y := 0.0
var _holding := false
var _dog_force := 0.0
var _burst_t := 0.0
var strength := 1.0
var start_pos := Vector3.ZERO

func _start() -> void:
	make_top("[i:tug] " + tr("Tir à la corde"))
	info_label.text = tr("Glissez le doigt vers le bas pour tirer !")
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

func handle_input(event: InputEvent) -> bool:
	if finished:
		return false
	if event is InputEventScreenTouch and event.index == 0:
		_holding = event.pressed
		_last_y = event.position.y
		return true
	if event is InputEventScreenDrag and event.index == 0 and _holding:
		var dy: float = event.position.y - _last_y
		_last_y = event.position.y
		if dy > 0.0:
			_pull += dy
		return true
	return false

func _process(delta: float) -> void:
	if finished or pet == null:
		return
	time_left -= delta
	# Force du joueur : glissements récents
	var player_force := minf(_pull / maxf(delta, 0.001) / 900.0, 2.2)
	_pull = 0.0
	# L'animal tire par à-coups
	_burst_t -= delta
	if _burst_t <= 0.0:
		_burst_t = randf_range(0.5, 1.2)
		_dog_force = randf_range(0.35, 1.1) * strength
		if randf() < 0.25:
			pet.voice()
	balance = clampf(balance + (player_force - _dog_force) * 24.0 * delta, -100.0, 100.0)
	meter.value = (balance + 100.0) * 0.5
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
