class_name Activity
extends Node
## Base des activités : interface dédiée, sortie, écran de résultats.

var ui: Control
var top_label: Label
var info_label: Label
var main: Main
var pet: PetController
var finished := false
var on_done: Callable = Callable()   # utilisé par les concours : on_done.call(score)

func _ready() -> void:
	main = Main.inst
	pet = main.pet_ctrl
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.safe.add_child(ui)
	if pet:
		pet.interrupt()
		pet.busy = true
	_start()

func _exit_tree() -> void:
	if ui and is_instance_valid(ui):
		ui.queue_free()

func _start() -> void:
	pass

## L'activité autorise-t-elle le bouton de recentrage caméra ?
func can_recenter() -> bool:
	return false

func recenter() -> void:
	main.recenter_camera()

func handle_input(_event: InputEvent) -> bool:
	return false

## Barre du haut : titre + infos + bouton quitter.
func make_top(title: String, show_quit: bool = true) -> VBoxContainer:
	var v := UiKit.vbox(8)
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UiKit.hbox(10)
	var p := UiKit.panel(14)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pv := UiKit.vbox(2)
	top_label = UiKit.label(title, 32)
	pv.add_child(top_label)
	info_label = UiKit.label("", 24, UiKit.C_SUB)
	pv.add_child(info_label)
	p.add_child(pv)
	h.add_child(p)
	if can_recenter():
		var rc := UiKit.button("[i:recenter]", func(): recenter(), UiKit.C_BLUE, 34, 90)
		rc.custom_minimum_size = Vector2(90, 90)
		rc.tooltip_text = tr("Recentrer la caméra")
		h.add_child(rc)
	if show_quit:
		var q := UiKit.button("[i:close]", quit, UiKit.C_DANGER, 34, 90)
		q.custom_minimum_size = Vector2(90, 90)
		h.add_child(q)
	v.add_child(h)
	ui.add_child(v)
	return v

func bottom_bar() -> HBoxContainer:
	var h := UiKit.hbox(10)
	h.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	h.grow_vertical = Control.GROW_DIRECTION_BEGIN
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	ui.add_child(h)
	return h

func big_hint(text: String, dur: float = 1.6, color: Color = Color.WHITE) -> void:
	var l := UiKit.label(text, 64, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0.3, 0.15, 0.05, 0.8))
	l.add_theme_constant_override("outline_size", 16)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.custom_minimum_size = Vector2(680, 0)
	l.position = Vector2(-340, -260)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(l)
	l.pivot_offset = Vector2(340, 40)
	var tw := l.create_tween()
	if not UiKit.reduce_motion():
		l.scale = Vector2(0.5, 0.5)
		tw.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)

func quit() -> void:
	if finished:
		main.end_activity()
		return
	finished = true
	_on_quit()
	if on_done.is_valid():
		on_done.call(0.0)
		return
	main.end_activity()

func _on_quit() -> void:
	pass

## Écran de résultats avec récompenses.
func show_results(title: String, lines: Array, coins: int, xp: int) -> void:
	finished = true
	if coins > 0:
		GameState.add_coins(coins)
		Audio.play("coin")
	if xp > 0:
		GameState.add_xp(xp)
	var v := UiKit.vbox(14)
	for l in lines:
		v.add_child(UiKit.label(str(l), 30))
	if coins > 0 or xp > 0:
		v.add_child(UiKit.label("[i:coin] +%d " % coins + tr("pièces") + "   ·   +%d " % xp + tr("pts d'expérience"), 36, UiKit.C_ACCENT))
	v.add_child(UiKit.button(tr("Continuer"), func():
		main.close_panel(), UiKit.C_ACCENT2, 32, 96))
	main.open_panel(title, v, func(): main.end_activity())
	GameState.save_game()

func pet_name() -> String:
	return str(GameState.active_pet().get("name", ""))
