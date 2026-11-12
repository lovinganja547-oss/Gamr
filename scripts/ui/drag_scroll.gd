class_name DragScroll
extends ScrollContainer
## Zone défilante au doigt : les boutons et cadres qu'elle contient laissent passer le geste,
## sinon un glissé commencé sur un bouton ne ferait jamais défiler la liste.

var _start := Vector2.INF
var _cancelled := false

## Dès que le doigt glisse, l'appui en cours sur un bouton est annulé : faire défiler
## la liste ne déclenche jamais un achat ou une vente par accident.
func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and is_visible_in_tree() and get_global_rect().has_point(e.position):
			_start = e.position
			_cancelled = false
		else:
			_start = Vector2.INF
	elif e is InputEventScreenDrag and _start != Vector2.INF and not _cancelled and e.position.distance_to(_start) > float(scroll_deadzone):
		_cancelled = true
		for n in find_children("*", "BaseButton", true, false):
			var bt := n as BaseButton
			if bt.is_visible_in_tree() and not bt.disabled and bt.get_global_rect().has_point(_start):
				# désactiver un instant efface l'appui en cours sans émettre « pressed »
				bt.disabled = true
				bt.set_deferred("disabled", false)

func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_on_node):
		get_tree().node_added.connect(_on_node)
	_pass_all(self)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node):
		get_tree().node_added.disconnect(_on_node)

func _on_node(n: Node) -> void:
	if n is Control and n != self and is_ancestor_of(n):
		_pass(n)

func _pass_all(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			_pass(c)
		_pass_all(c)

func _pass(c: Control) -> void:
	# les réglettes, champs de texte et listes imbriquées gardent leur propre geste
	if c is Slider or c is LineEdit or c is TextEdit or c is ScrollContainer or c is ScrollBar:
		return
	if c.mouse_filter == Control.MOUSE_FILTER_STOP:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
