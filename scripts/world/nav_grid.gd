class_name NavGrid
extends RefCounted
## Grille de navigation 2D (plan XZ) avec A* 8 directions.
## Les obstacles sont des cercles {"c": Vector2, "r": float} ou des rectangles {"rect": Rect2},
## gonflés du rayon de l'animal. Les chemins sont lissés (raccourcis en ligne de vue).

var CELL := 0.12

var area := Rect2()
var w := 0
var h := 0
var blocked := PackedByteArray()
var obstacles: Array = []
var inflate := 0.2

func build(bounds: Rect2, obs: Array, radius: float) -> void:
	area = bounds
	obstacles = obs
	# grands lieux : cellules un peu plus larges pour garder une grille légère
	CELL = clampf(sqrt(bounds.get_area() / 6000.0), 0.1, 0.25 if bounds.get_area() < 1200.0 else 0.4)
	inflate = radius
	w = maxi(2, int(ceil(bounds.size.x / CELL)))
	h = maxi(2, int(ceil(bounds.size.y / CELL)))
	blocked.resize(w * h)
	blocked.fill(0)
	# chaque obstacle ne marque que les cellules de son voisinage (rapide même avec des centaines d'obstacles)
	for o in obs:
		var box: Rect2
		if o.has("rect"):
			box = (o["rect"] as Rect2).grow(radius)
		else:
			var rr := float(o["r"]) + radius
			var c: Vector2 = o["c"]
			box = Rect2(c.x - rr, c.y - rr, rr * 2.0, rr * 2.0)
		var i0 := clampi(int(floor((box.position.x - area.position.x) / CELL)), 0, w - 1)
		var i1 := clampi(int(floor((box.end.x - area.position.x) / CELL)), 0, w - 1)
		var j0 := clampi(int(floor((box.position.y - area.position.y) / CELL)), 0, h - 1)
		var j1 := clampi(int(floor((box.end.y - area.position.y) / CELL)), 0, h - 1)
		if box.end.x < area.position.x or box.end.y < area.position.y or box.position.x > area.end.x or box.position.y > area.end.y:
			continue
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				if blocked[j * w + i] == 1:
					continue
				var p := _center(i, j)
				if o.has("rect"):
					blocked[j * w + i] = 1
				elif p.distance_to(o["c"]) < float(o["r"]) + radius:
					blocked[j * w + i] = 1

func _center(i: int, j: int) -> Vector2:
	return area.position + Vector2((i + 0.5) * CELL, (j + 0.5) * CELL)

## Point bloqué par un obstacle (gonflé) ?
func is_blocked_point(p: Vector2, extra: float = 0.0) -> bool:
	var r := inflate + extra
	for o in obstacles:
		if o.has("rect"):
			if (o["rect"] as Rect2).grow(r).has_point(p):
				return true
		elif p.distance_to(o["c"]) < float(o["r"]) + r:
			return true
	return false

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int((p.x - area.position.x) / CELL), 0, w - 1), clampi(int((p.y - area.position.y) / CELL), 0, h - 1))

func _free(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h and blocked[c.y * w + c.x] == 0

## Point libre le plus proche (recherche en anneaux).
func nearest_free(p: Vector2) -> Vector2:
	var p2 := Vector2(clampf(p.x, area.position.x + CELL * 0.5, area.end.x - CELL * 0.5), clampf(p.y, area.position.y + CELL * 0.5, area.end.y - CELL * 0.5))
	var c := _cell(p2)
	if _free(c) and not is_blocked_point(p2):
		return p2
	var best := p2
	var best_d := INF
	for ring in range(1, maxi(w, h)):
		for dj in range(-ring, ring + 1):
			for di in range(-ring, ring + 1):
				if absi(di) != ring and absi(dj) != ring:
					continue
				var cc := c + Vector2i(di, dj)
				if _free(cc):
					var q := _center(cc.x, cc.y)
					var d := q.distance_to(p2)
					if d < best_d:
						best_d = d
						best = q
		if best_d < INF:
			return best
	return p2

## Ligne de vue libre entre a et b ?
func clear_line(a: Vector2, b: Vector2) -> bool:
	var n := maxi(2, int(a.distance_to(b) / (CELL * 0.5)))
	for k in range(1, n):
		var p := a.lerp(b, float(k) / n)
		if not _free(_cell(p)) or is_blocked_point(p):
			return false
	return true

## Chemin de a vers b (liste de points, b inclus). Vide si impossible.
func find_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	b = nearest_free(b)
	if is_blocked_point(a):
		a = nearest_free(a)
	if clear_line(a, b):
		return PackedVector2Array([b])
	var start := _cell(a)
	var goal := _cell(b)
	var n := w * h
	var g := PackedFloat32Array(); g.resize(n); g.fill(INF)
	var came := PackedInt32Array(); came.resize(n); came.fill(-1)
	var closed := PackedByteArray(); closed.resize(n)
	var open: Array = [[0.0, start.y * w + start.x]]
	g[start.y * w + start.x] = 0.0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var found := false
	var guard := 0
	while not open.is_empty() and guard < 20000:
		guard += 1
		# extraction du minimum (tas binaire simple)
		var cur: int = _pop(open)
		if closed[cur] == 1:
			continue
		closed[cur] = 1
		var cx := cur % w
		var cy := cur / w
		if cx == goal.x and cy == goal.y:
			found = true
			break
		for d in dirs:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni := ny * w + nx
			if blocked[ni] == 1 or closed[ni] == 1:
				continue
			if d.x != 0 and d.y != 0 and (blocked[cy * w + nx] == 1 or blocked[ny * w + cx] == 1):
				continue   # pas de coupe d'angle
			var cost: float = g[cur] + (1.4142 if d.x != 0 and d.y != 0 else 1.0)
			if cost < g[ni]:
				g[ni] = cost
				came[ni] = cur
				var hh := Vector2(nx - goal.x, ny - goal.y).length()
				_push(open, cost + hh, ni)
	if not found:
		return PackedVector2Array()
	var cells: Array[Vector2] = []
	var k := goal.y * w + goal.x
	while k != -1 and k != start.y * w + start.x:
		cells.push_front(_center(k % w, k / w))
		k = came[k]
	cells.append(b)
	# lissage par ligne de vue
	var out := PackedVector2Array()
	var anchor := a
	var i := 0
	while i < cells.size():
		var j := cells.size() - 1
		while j > i and not clear_line(anchor, cells[j]):
			j -= 1
		out.append(cells[j])
		anchor = cells[j]
		i = j + 1
	return out

static func _push(heap: Array, pri: float, v: int) -> void:
	heap.append([pri, v])
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if heap[p][0] <= heap[i][0]:
			break
		var t: Array = heap[p]; heap[p] = heap[i]; heap[i] = t
		i = p

static func _pop(heap: Array) -> int:
	var top: int = heap[0][1]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	var n := heap.size()
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var s := i
		if l < n and heap[l][0] < heap[s][0]:
			s = l
		if r < n and heap[r][0] < heap[s][0]:
			s = r
		if s == i:
			break
		var t: Array = heap[s]; heap[s] = heap[i]; heap[i] = t
		i = s
	return top
