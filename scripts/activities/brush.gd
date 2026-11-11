class_name BrushActivity
extends Activity
## Brossage (activité calme) : brosser chaque zone du pelage ; les poils morts tombent,
## le pelage redevient brillant. Récompense une fois toutes les 3 h.

const ZONES := {"head": "Tête", "back": "Dos", "legs": "Ventre et pattes", "tail": "Queue"}
const NEEDED := 8.0

var done := {"head": 0.0, "back": 0.0, "legs": 0.0, "tail": 0.0}
var bars := {}
var brush_ui: TextureRect
var finish_btn: Button
var _brushing := false
var _acc := 0.0
var fur_bits: Array[Node3D] = []

func _start() -> void:
	make_top("[i:brush] " + tr("Brossage de %s") % pet_name())
	info_label.text = tr("Brossez l'animal du doigt. Glissez à côté pour tourner, ou touchez une zone.")
	var bb := bottom_bar()
	var pv := UiKit.panel(14)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vv := UiKit.vbox(6)
	var zp := care_zone_panel(ZONES, Color(0.95, 0.75, 0.45))
	bars = zp["bars"]
	vv.add_child(zp["grid"])
	finish_btn = UiKit.button("[i:check] " + tr("Terminer"), _finish, UiKit.C_ACCENT2, 26, 80)
	finish_btn.disabled = true
	vv.add_child(finish_btn)
	pv.add_child(vv)
	bb.add_child(pv)
	brush_ui = UiKit.icon_rect("brush", 96)
	brush_ui.visible = false
	ui.add_child(brush_ui)
	care_setup()
	pet.face(pet.player_pos)
	pet.model.set_posture("stand", 3.0)   # debout : toutes les zones restent accessibles
	pet.state = "action"
	care_view("back")

func can_recenter() -> bool:
	return true

func recenter() -> void:
	care_view("back")

func handle_input(event: InputEvent) -> bool:
	if finished:
		return false
	if event is InputEventScreenTouch and event.index == 0:
		brush_ui.visible = event.pressed and not main.raycast(event.position, 2).is_empty()
		brush_ui.position = event.position - Vector2(48, 70)
	elif event is InputEventScreenDrag and event.index == 0 and brush_ui.visible:
		brush_ui.position = event.position - Vector2(48, 70)
		brush_ui.rotation = clampf(event.relative.x * 0.02, -0.4, 0.4)
	return care_input(event, _rub)

func _rub(event: InputEventScreenDrag, hit: Dictionary) -> void:
	_acc += event.relative.length()
	if _acc < 36.0:
		return
	_acc = 0.0
	var z := care_zone(hit)
	done[z] = minf(NEEDED, done[z] + 1.0)
	(bars[z] as ProgressBar).value = done[z] / NEEDED * 100.0
	_fur_bit(hit["position"])
	pet.model.expression = "closed" if randf() < 0.5 else "happy"
	pet.model.wag_amp = 0.5
	if randf() < 0.2:
		pet.model.hearts(1)
	if randf() < 0.25:
		Audio.play("whoosh", 0.2, -16.0, 1.6)
	finish_btn.disabled = progress() < 0.5
	info_label.text = tr("Pelage brossé : %d %%") % int(progress() * 100.0)

func progress() -> float:
	var t := 0.0
	for z in done.keys():
		t += done[z] / NEEDED
	return t / done.size()

## Touffe de poils qui tombe au sol.
func _fur_bit(p: Vector3) -> void:
	if fur_bits.size() > 40:
		return
	var b := WorldBuilder.ball(main.world, 0.018, p, pet.model.c_main.lightened(0.15), Vector3(1.6, 0.5, 1.0), 6)
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fur_bits.append(b)
	var tw := b.create_tween()
	tw.tween_property(b, "position", Vector3(p.x + randf_range(-0.1, 0.1), 0.01, p.z + randf_range(-0.1, 0.1)), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _finish() -> void:
	if finished:
		return
	var q := progress()
	pet.model.set_dirt(pet.model.dirt * (1.0 - q * 0.6))
	GameState.change_need("clean", 12.0 * q)
	GameState.change_need("mood", 8.0 * q)
	GameState.change_need("affection", 12.0 * q)
	GameState.change_need("health", 2.0)
	GameState.add_relation(int(4 * q) + 1)
	GameState.inc_stat("brush", 1)
	pet.model.emote("emo_sparkle")
	var xp := int(round(14.0 * q))
	var coins := int(round(4.0 * q))
	var lines: Array = [tr("%s a un pelage tout doux.") % pet_name()]
	if not GameState.reward_ok("brush", 3.0):
		xp = 0
		coins = 0
		lines.append(tr("Déjà brossé récemment : pas de récompense cette fois."))
	show_results("[i:brush] " + tr("Brossage terminé"), lines, coins, xp)

func _exit_tree() -> void:
	super._exit_tree()
	care_teardown()
	for b in fur_bits:
		if is_instance_valid(b):
			b.queue_free()
