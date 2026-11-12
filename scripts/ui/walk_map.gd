class_name WalkMap
extends Control
## Carte du quartier : on trace la promenade du bout du doigt, de lieu en lieu, le long des rues.
## Le trajet part de la maison et doit y revenir ; sa longueur est limitée par l'endurance.

signal route_changed

const HIT := 36.0          # rayon de capture d'un lieu (pixels)
const MARGIN := 40.0

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
	clip_contents = true
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

func _pt(p: Vector2) -> Vector2:
	return _origin + (p - _min) * _scale

func _blob(c: Vector2, r: float, col: Color, seed_v: int) -> void:
	# tache organique : quelques disques décalés
	for k in 6:
		var a := k * 1.05 + seed_v
		draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.42, r * (0.62 + 0.12 * sin(k * 2.3 + seed_v)), col)
	draw_circle(c, r * 0.8, col)

func _draw() -> void:
	var font := get_theme_default_font()
	# fond : prairie, mer et sable au nord
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.70, 0.84, 0.56), true)
	for k in 40:
		var gx := fposmod(k * 137.5, size.x)
		var gy := fposmod(k * 91.3, size.y)
		draw_circle(Vector2(gx, gy), 26.0 + (k % 5) * 9.0, Color(0.66, 0.81, 0.52, 0.55) if k % 2 == 0 else Color(0.75, 0.87, 0.60, 0.55))
	var shore := _pt(Vector2(0, GameData.WALK_SHORE_Z + 2.0)).y
	var sand := _pt(Vector2(0, GameData.WALK_SAND_Z)).y
	draw_rect(Rect2(0, 0, size.x, sand), Color(0.95, 0.88, 0.68), true)
	for k in 12:
		draw_circle(Vector2(size.x * (k + 0.5) / 12.0, sand), 22.0 + (k % 3) * 6.0, Color(0.95, 0.88, 0.68))
	draw_rect(Rect2(0, 0, size.x, shore), Color(0.42, 0.72, 0.90), true)
	for k in 9:
		draw_arc(Vector2(size.x * (k + 0.3) / 9.0, shore - 14.0 - (k % 3) * 9.0), 14.0, 0.2, PI - 0.2, 10, Color(1, 1, 1, 0.7), 2.0, true)
	draw_line(Vector2(0, shore), Vector2(size.x, shore), Color(1, 1, 1, 0.85), 3.0, true)
	# zones : forêt, parc, village pavé
	_blob(to_screen("forest") + Vector2(-26, -4), 62.0, Color(0.36, 0.58, 0.36), 1)
	_blob(to_screen("park"), 46.0, Color(0.56, 0.76, 0.44), 2)
	_blob(to_screen("meadow"), 50.0, Color(0.78, 0.88, 0.56), 3)
	for id in ["fountain", "lane", "shop", "bakery", "market", "cafe", "vet"]:
		draw_circle(to_screen(id), 40.0, Color(0.86, 0.82, 0.74, 0.55))
	# rivière et étang
	var rv := GameData.WALK_RIVER
	for i in rv.size() - 1:
		draw_line(_pt(rv[i]), _pt(rv[i + 1]), Color(0.42, 0.72, 0.90), 15.0, true)
		draw_circle(_pt(rv[i + 1]), 7.5, Color(0.42, 0.72, 0.90))
	draw_circle(to_screen("pond") + Vector2(-30, 2), 22.0, Color(0.42, 0.72, 0.90))
	# petits arbres décoratifs
	for k in 26:
		var tp := Vector2(fposmod(k * 211.7 + 40.0, size.x), fposmod(k * 157.3 + 90.0, size.y))
		if tp.y < sand + 20.0:
			continue
		var clear := true
		for id in GameData.WALK_NODES.keys():
			if tp.distance_to(to_screen(id)) < 46.0:
				clear = false
		if clear:
			draw_circle(tp + Vector2(2, 3), 9.0, Color(0.2, 0.3, 0.2, 0.25))
			draw_circle(tp, 9.0, Color(0.40, 0.62, 0.36))
			draw_circle(tp + Vector2(-2, -2), 5.0, Color(0.50, 0.70, 0.42))
	# rues (pavées au village, chemins de terre ailleurs)
	for e in GameData.WALK_EDGES:
		var a := to_screen(e[0])
		var b := to_screen(e[1])
		var village: bool = GameData.WALK_NODES[e[0]].get("zone", "") == "village" and GameData.WALK_NODES[e[1]].get("zone", "") == "village"
		draw_line(a, b, Color(0.45, 0.36, 0.28, 0.35), 17.0 if village else 13.0, true)
		draw_line(a, b, Color(0.94, 0.90, 0.82) if village else Color(0.86, 0.74, 0.56), 13.0 if village else 9.0, true)
		if not village:
			draw_dashed_line(a, b, Color(1, 1, 1, 0.5), 2.0, 8.0)
	# trajet tracé
	for i in range(1, route.size()):
		var a2 := to_screen(route[i - 1])
		var b2 := to_screen(route[i])
		# léger décalage pour distinguer l'aller du retour sur une même rue
		var n := (b2 - a2).orthogonal().normalized() * 4.0
		draw_line(a2 + n, b2 + n, Color(1, 1, 1), 10.0, true)
		draw_line(a2 + n, b2 + n, Color(0.94, 0.40, 0.30), 6.5, true)
		var mid := (a2 + b2) * 0.5 + n
		var dirv := (b2 - a2).normalized()
		draw_colored_polygon(PackedVector2Array([mid + dirv * 9.0, mid - dirv * 5.0 + dirv.orthogonal() * 7.0, mid - dirv * 5.0 - dirv.orthogonal() * 7.0]), Color(0.94, 0.40, 0.30))
	# lieux
	for id in GameData.WALK_NODES.keys():
		var p := to_screen(id)
		var nd: Dictionary = GameData.WALK_NODES[id]
		var locked := node_locked(id)
		var in_route := route.has(id)
		var last: bool = not route.is_empty() and route[route.size() - 1] == id
		var road: bool = nd["kind"] == "road"
		var r := 11.0 if road else (27.0 if id == "home" else 23.0)
		var bg := Color(1, 1, 1) if not locked else Color(0.78, 0.78, 0.78)
		if in_route:
			bg = Color(1.0, 0.92, 0.72)
		draw_circle(p + Vector2(0, 3), r + 3.0, Color(0.25, 0.18, 0.12, 0.35))
		draw_circle(p, r + 3.0, Color(0.94, 0.40, 0.30) if in_route else Color(0.48, 0.36, 0.26))
		draw_circle(p, r, bg)
		if last:
			draw_arc(p, r + 9.0, 0.0, TAU, 32, Color(0.94, 0.40, 0.30), 4.0, true)
		var tex: Texture2D = _icons["lock"] if locked else _icons.get(id)
		if tex and not road:
			var isz := r * 1.45
			draw_texture_rect(tex, Rect2(p - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false)
		if not road and font:
			var txt := tr(str(nd["name"]))
			var fs := 16
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			var tp2 := p + Vector2(-w * 0.5, r + 19.0)
			tp2.x = clampf(tp2.x, 4.0, size.x - w - 4.0)
			draw_string_outline(font, tp2, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(1, 1, 1, 0.92))
			draw_string(font, tp2, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.25, 0.18, 0.12))
	if _deny_t > 0.0:
		draw_arc(_deny_pos, 34.0, 0.0, TAU, 24, Color(0.9, 0.3, 0.3, _deny_t / 0.6), 6.0, true)
