class_name WalkMap
extends Control
## Carte du quartier : on trace la promenade du bout du doigt, de lieu en lieu, le long des rues.
## Le trajet part de la maison et doit y revenir ; sa longueur est limitée par l'endurance.

signal route_changed

const HIT := 52.0          # rayon de capture d'un lieu (pixels)
const MARGIN := 46.0

var route: Array[String] = []
var endurance := 350.0
var _scale := 30.0
var _origin := Vector2.ZERO
var _min := Vector2.ZERO
var _drawing := false
var _deny_t := 0.0
var _deny_pos := Vector2.ZERO
var _icons := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id in GameData.WALK_NODES.keys():
		_icons[id] = UiKit.icon(str(GameData.WALK_NODES[id]["icon"]))
	_icons["lock"] = UiKit.icon("lock")
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for id in GameData.WALK_NODES.keys():
		var p: Vector2 = GameData.WALK_NODES[id]["pos"]
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	_min = mn
	var span := mx - mn
	var avail := size - Vector2(MARGIN, MARGIN) * 2.0
	_scale = minf(avail.x / maxf(span.x, 0.1), avail.y / maxf(span.y, 0.1))
	_origin = Vector2(MARGIN, MARGIN) + (avail - span * _scale) * 0.5
	queue_redraw()

func to_screen(id: String) -> Vector2:
	return _origin + ((GameData.WALK_NODES[id]["pos"] as Vector2) - _min) * _scale

static func node_locked(id: String) -> bool:
	var n: Dictionary = GameData.WALK_NODES[id]
	return n.has("env") and not GameState.env_unlocked(str(n["env"]))

func used() -> float:
	var t := 0.0
	for i in range(1, route.size()):
		t += GameData.walk_edge_len(route[i - 1], route[i])
	return t

func is_complete() -> bool:
	return route.size() >= 3 and route[route.size() - 1] == "home"

func clear_route() -> void:
	route.clear()
	route.append("home")
	route_changed.emit()
	queue_redraw()

func undo() -> void:
	if route.size() > 1:
		route.pop_back()
		route_changed.emit()
		queue_redraw()

## Complète le trajet par le chemin le plus court jusqu'à la maison (si l'endurance suffit).
func auto_return() -> bool:
	if route.is_empty():
		route.append("home")
	var start: String = route[route.size() - 1]
	if start == "home" and route.size() > 1:
		return true
	var dist := {start: 0.0}
	var prev := {}
	var todo: Array = [start]
	while not todo.is_empty():
		var best := 0
		for i in todo.size():
			if dist[todo[i]] < dist[todo[best]]:
				best = i
		var u: String = todo[best]
		todo.remove_at(best)
		if u == "home":
			break
		for v in GameData.walk_neighbors(u):
			if node_locked(v):
				continue
			var nd: float = dist[u] + GameData.walk_edge_len(u, v)
			if not dist.has(v) or nd < dist[v]:
				dist[v] = nd
				prev[v] = u
				if not todo.has(v):
					todo.append(v)
	if not dist.has("home"):
		return false
	if used() + float(dist["home"]) > endurance + 0.01:
		return false
	var back: Array = []
	var c := "home"
	while c != start:
		back.push_front(c)
		c = prev[c]
	for b in back:
		route.append(b)
	route_changed.emit()
	queue_redraw()
	return true

func _nearest(pos: Vector2) -> String:
	var best := ""
	var bd := HIT
	for id in GameData.WALK_NODES.keys():
		var d := pos.distance_to(to_screen(id))
		if d < bd:
			bd = d
			best = id
	return best

## Essaie d'ajouter le lieu sous le doigt (voisin du dernier lieu, débloqué, endurance suffisante).
func _try_add(pos: Vector2) -> void:
	if route.is_empty():
		route.append("home")
	var id := _nearest(pos)
	if id == "":
		return
	var last: String = route[route.size() - 1]
	if id == last or not GameData.walk_neighbors(last).has(id):
		return
	if node_locked(id):
		_deny(pos)
		return
	if used() + GameData.walk_edge_len(last, id) > endurance + 0.01:
		_deny(pos)
		return
	route.append(id)
	Audio.play("tick", 0.05, -6.0)
	route_changed.emit()
	queue_redraw()

func _deny(pos: Vector2) -> void:
	if _deny_t > 0.0:
		return
	_deny_t = 0.6
	_deny_pos = pos
	Audio.play("fail", 0.0, -8.0)
	queue_redraw()

func _process(delta: float) -> void:
	if _deny_t > 0.0:
		_deny_t = maxf(0.0, _deny_t - delta)
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.index == 0:
		_drawing = event.pressed
		if event.pressed:
			_try_add(event.position)
		accept_event()
	elif event is InputEventScreenDrag and event.index == 0 and _drawing:
		_try_add(event.position)
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.78, 0.88, 0.66), true)
	# eau au nord (plage)
	var bp := to_screen("beach")
	draw_rect(Rect2(0, 0, size.x, maxf(0.0, bp.y - 26.0)), Color(0.55, 0.78, 0.95), true)
	draw_circle(bp, 40.0, Color(0.93, 0.86, 0.62))
	draw_circle(to_screen("forest"), 54.0, Color(0.42, 0.62, 0.38))
	draw_circle(to_screen("park"), 50.0, Color(0.6, 0.8, 0.48))
	# rues
	for e in GameData.WALK_EDGES:
		var a := to_screen(e[0])
		var b := to_screen(e[1])
		draw_line(a, b, Color(0.93, 0.89, 0.8), 22.0, true)
		draw_line(a, b, Color(0.82, 0.76, 0.64), 2.0, true)
	# trajet tracé
	var seg_used := 0.0
	for i in range(1, route.size()):
		var a2 := to_screen(route[i - 1])
		var b2 := to_screen(route[i])
		# léger décalage pour distinguer l'aller du retour sur une même rue
		var n := (b2 - a2).orthogonal().normalized() * 5.0
		draw_line(a2 + n, b2 + n, Color(0.92, 0.42, 0.3), 9.0, true)
		seg_used += GameData.walk_edge_len(route[i - 1], route[i])
		var mid := (a2 + b2) * 0.5 + n
		draw_circle(mid, 5.0, Color(1, 1, 1))
	# lieux
	var font := get_theme_default_font()
	for id in GameData.WALK_NODES.keys():
		var p := to_screen(id)
		var nd: Dictionary = GameData.WALK_NODES[id]
		var locked := node_locked(id)
		var in_route := route.has(id)
		var last: bool = not route.is_empty() and route[route.size() - 1] == id
		var r := 30.0 if nd["kind"] != "road" else 18.0
		var bg := Color(1, 1, 1) if not locked else Color(0.75, 0.75, 0.75)
		if in_route:
			bg = Color(1, 0.93, 0.75)
		draw_circle(p, r + 4.0, Color(0.35, 0.25, 0.18, 0.55))
		draw_circle(p, r, bg)
		if last:
			draw_arc(p, r + 9.0, 0.0, TAU, 32, Color(0.92, 0.42, 0.3), 5.0, true)
		var tex: Texture2D = _icons["lock"] if locked else _icons.get(id)
		if tex and nd["kind"] != "road":
			draw_texture_rect(tex, Rect2(p - Vector2(22, 22), Vector2(44, 44)), false)
		if nd["kind"] != "road" and font:
			var txt := tr(str(nd["name"]))
			var fs := 20
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			var tp := p + Vector2(-w * 0.5, r + 24.0)
			tp.x = clampf(tp.x, 4.0, size.x - w - 4.0)
			draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(1, 1, 1, 0.9))
			draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.25, 0.18, 0.12))
	if _deny_t > 0.0:
		draw_arc(_deny_pos, 34.0, 0.0, TAU, 24, Color(0.9, 0.3, 0.3, _deny_t / 0.6), 6.0, true)
