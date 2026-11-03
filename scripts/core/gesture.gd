class_name GestureRecognizer
extends RefCounted
## Reconnaissance de gestes tactiles : directions (U/D/L/R), cercle (O), tape (T) et double tape (TT).

const MIN_LEN := 40.0
const STEP := 28.0
var points: PackedVector2Array = PackedVector2Array()
var _last_tap_ms := -10000
var active := false

func begin(p: Vector2) -> void:
	points = PackedVector2Array([p])
	active = true

func add(p: Vector2) -> void:
	if active and (points.is_empty() or points[points.size() - 1].distance_to(p) >= 4.0):
		points.append(p)

## Termine le geste et retourne sa signature.
func finish() -> String:
	active = false
	var length := 0.0
	for i in range(1, points.size()):
		length += points[i].distance_to(points[i - 1])
	if length < MIN_LEN:
		var now := Time.get_ticks_msec()
		if now - _last_tap_ms < 420:
			_last_tap_ms = -10000
			return "TT"
		_last_tap_ms = now
		return "T"
	if _is_circle(length):
		return "O"
	return classify(points)

static func classify(pts: PackedVector2Array) -> String:
	# Rééchantillonnage
	var rs: Array[Vector2] = [pts[0]]
	var acc := 0.0
	for i in range(1, pts.size()):
		acc += pts[i].distance_to(pts[i - 1])
		if acc >= STEP:
			rs.append(pts[i])
			acc = 0.0
	if rs[rs.size() - 1] != pts[pts.size() - 1]:
		rs.append(pts[pts.size() - 1])
	var dirs: Array[String] = []
	for i in range(1, rs.size()):
		var d := rs[i] - rs[i - 1]
		if d.length() < 6.0:
			continue
		if absf(d.x) > absf(d.y):
			dirs.append("R" if d.x > 0 else "L")
		else:
			dirs.append("D" if d.y > 0 else "U")
	# Compression avec filtrage du bruit (segments isolés ignorés)
	var runs: Array = []
	for d in dirs:
		if runs.is_empty() or runs[runs.size() - 1][0] != d:
			runs.append([d, 1])
		else:
			runs[runs.size() - 1][1] += 1
	var out := ""
	var total := dirs.size()
	for r in runs:
		if r[1] >= 2 or (total <= 3 and r[1] >= 1):
			if out.is_empty() or out[out.length() - 1] != r[0]:
				out += r[0]
	return out

func _is_circle(length: float) -> bool:
	if points.size() < 8:
		return false
	var rect := Rect2(points[0], Vector2.ZERO)
	for p in points:
		rect = rect.expand(p)
	var size := maxf(rect.size.x, rect.size.y)
	if size < 60.0 or minf(rect.size.x, rect.size.y) < size * 0.45:
		return false
	if points[0].distance_to(points[points.size() - 1]) > size * 0.55:
		return false
	var turn := 0.0
	for i in range(2, points.size()):
		var a := points[i - 1] - points[i - 2]
		var b := points[i] - points[i - 1]
		if a.length() > 0.5 and b.length() > 0.5:
			turn += a.angle_to(b)
	return absf(turn) > deg_to_rad(280.0) and length > size * 2.2

static func pretty(g: String) -> String:
	var m := {"U": "↑", "D": "↓", "L": "←", "R": "→", "O": "⟳", "T": "•"}
	if g == "TT":
		return "• •"
	var s := ""
	for c in g:
		s += m.get(c, c)
	return s
