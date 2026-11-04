class_name CuddleActivity
extends Activity
## Moment câlin (détente) : l'animal vient se blottir ; garder le doigt posé sur lui
## remplit la jauge de tendresse. Repose un peu et renforce le lien.

const NEEDED := 6.0

var meter: ProgressBar
var held := 0.0
var _touching := false
var _heart_t := 0.0
var _arrived := false

func _start() -> void:
	make_top("[i:cuddle] " + tr("Câlin avec %s") % pet_name())
	info_label.text = tr("Gardez le doigt posé sur votre compagnon.")
	var bb := bottom_bar()
	var pv := UiKit.panel(14)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter = UiKit.bar(0, Color(0.95, 0.5, 0.7), 26)
	pv.add_child(meter)
	bb.add_child(pv)
	var spot := pet.player_pos + Vector3(0, 0, -0.55)
	pet.state = "idle"
	pet.walk_to(spot, 1.0, func():
		pet.face(pet.player_pos)
		var temper: String = pet.pet.get("temperament", "")
		pet.model.set_posture("lie" if temper != "energique" else "sit", 2.5)
		pet.state = "action"
		pet.model.expression = "happy"
		_arrived = true)
	main.cam_rig.target = pet
	main.cam_rig.follow = true
	main.cam_rig.screen_shift = 0.2

func can_recenter() -> bool:
	return true

func handle_input(event: InputEvent) -> bool:
	if finished:
		return false
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			_touching = main.hit_part(main.raycast(event.position, 2)) != ""
		else:
			_touching = false
		return true
	if event is InputEventScreenDrag and event.index == 0:
		_touching = main.hit_part(main.raycast(event.position, 2)) != ""
		return true
	return false

func _process(delta: float) -> void:
	if finished or not _arrived:
		return
	if _touching:
		held = minf(NEEDED, held + delta)
		meter.value = held / NEEDED * 100.0
		pet.model.expression = "closed"
		pet.model.wag_amp = 0.6
		pet.model.head_extra.z = sin(Time.get_ticks_msec() * 0.002) * 0.2
		_heart_t -= delta
		if _heart_t <= 0.0:
			_heart_t = 0.7
			pet.model.hearts(1)
			if randf() < 0.4:
				pet.happy_sound()
		if held >= NEEDED:
			_finish()
	else:
		pet.model.expression = "happy"
		pet.model.head_extra.z = lerpf(pet.model.head_extra.z, 0.0, delta * 3.0)

func _finish() -> void:
	finished = true
	GameState.change_need("affection", 25.0)
	GameState.change_need("mood", 10.0)
	GameState.change_need("energy", 6.0)
	GameState.add_relation(6)
	GameState.inc_stat("cuddle", 1)
	var xp := 6
	var lines: Array = [tr("%s est tout apaisé.") % pet_name()]
	if not GameState.reward_ok("cuddle", 1.0):
		xp = 0
	show_results("[i:cuddle] " + tr("Moment de tendresse"), lines, 0, xp)
