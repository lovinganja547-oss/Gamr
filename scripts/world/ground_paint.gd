class_name GroundPaint
extends SubViewport
## Masque du sol peint une seule fois par le processeur graphique : chemins (rouge), seconde matière
## comme le sable ou les dalles (vert), ombres de contact sous les arbres et bâtiments (bleu).
## Le shader du sol le lit avec un léger bruit pour des bords naturels.

var rect := Rect2(-20, -20, 40, 40)   # zone du monde couverte (x, z)
var ops: Array = []
var _canvas: Canvas

class Canvas extends Node2D:
	var gp: GroundPaint
	func _draw() -> void:
		var blob: Texture2D = load("res://assets/textures/soft_blob.png")
		for o in gp.ops:
			var col := Color(0, 0, 0, 1)
			col[int(o["ch"])] = float(o.get("k", 1.0))
			match str(o["t"]):
				"line":
					var a := gp.px(o["a"])
					var b := gp.px(o["b"])
					var w: float = float(o["w"]) * gp.ppm()
					draw_line(a, b, col, w, true)
					draw_circle(a, w * 0.5, col)
					draw_circle(b, w * 0.5, col)
				"disc":
					draw_circle(gp.px(o["c"]), float(o["r"]) * gp.ppm(), col)
				"rect":
					var r: Rect2 = o["r"]
					draw_rect(Rect2(gp.px(r.position), r.size * gp.ppm()), col, true)
				"poly":
					var pts := PackedVector2Array()
					for p in o["pts"]:
						pts.append(gp.px(p))
					draw_colored_polygon(pts, col)
				"soft":
					var rr: float = float(o["r"]) * gp.ppm()
					var c := gp.px(o["c"])
					if blob:
						draw_texture_rect(blob, Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, col)

func _init(world_rect: Rect2 = Rect2(-20, -20, 40, 40), res: int = 512) -> void:
	rect = world_rect
	size = Vector2i(res, res)
	transparent_bg = true
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_ONCE
	_canvas = Canvas.new()
	_canvas.gp = self
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_canvas.material = cm
	add_child(_canvas)

func ppm() -> float:
	return float(size.x) / rect.size.x

func px(p: Vector2) -> Vector2:
	return (p - rect.position) / rect.size * Vector2(size)

## Chemin (canal 0) ou bande d'une autre matière entre deux points du monde (x, z).
func path(a: Vector2, b: Vector2, width: float, ch: int = 0) -> void:
	ops.append({"t": "line", "a": a, "b": b, "w": width, "ch": ch})

func disc(c: Vector2, r: float, ch: int = 0) -> void:
	ops.append({"t": "disc", "c": c, "r": r, "ch": ch})

func area(r: Rect2, ch: int = 0) -> void:
	ops.append({"t": "rect", "r": r, "ch": ch})

func poly(pts: Array, ch: int = 0) -> void:
	ops.append({"t": "poly", "pts": pts, "ch": ch})

## Ombre de contact douce (sous un arbre, au pied d'un mur).
func shade(c: Vector2, r: float, strength: float = 0.7) -> void:
	ops.append({"t": "soft", "c": c, "r": r, "ch": 2, "k": strength})

## Tache douce d'une matière (clairière de terre, sable épars).
func soft(c: Vector2, r: float, ch: int = 0, strength: float = 1.0) -> void:
	ops.append({"t": "soft", "c": c, "r": r, "ch": ch, "k": strength})

func refresh() -> void:
	_canvas.queue_redraw()
	render_target_update_mode = SubViewport.UPDATE_ONCE
