class_name UiKit
extends RefCounted
## Fabrique d'éléments d'interface (thème, boutons, panneaux, barres).

const C_BG := Color(1.0, 0.97, 0.92)
const C_PANEL := Color(1.0, 0.99, 0.96, 0.97)
const C_TEXT := Color(0.27, 0.2, 0.17)
const C_SUB := Color(0.5, 0.42, 0.38)
const C_ACCENT := Color(0.98, 0.55, 0.35)
const C_ACCENT2 := Color(0.36, 0.7, 0.62)
const C_BLUE := Color(0.38, 0.6, 0.92)
const C_GOLD := Color(0.98, 0.78, 0.25)
const C_DANGER := Color(0.9, 0.4, 0.4)
const C_DISABLED := Color(0.8, 0.77, 0.74)

static var _font: Font
static var _emoji: Font
static var _theme: Theme

static func emoji_font() -> Font:
	if _emoji == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji", "Emoji"])
		var base := FontVariation.new()
		base.base_font = ThemeDB.fallback_font
		base.fallbacks = [sf]
		_emoji = base
	return _emoji

static func font() -> Font:
	if _font == null:
		var fv := FontVariation.new()
		fv.base_font = emoji_font()
		fv.variation_embolden = 0.55
		_font = fv
	return _font

static func sb(c: Color, radius: int = 28, border: int = 0, border_c: Color = Color.TRANSPARENT, shadow: bool = true, pad: int = 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_c
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = true
	if shadow:
		s.shadow_color = Color(0.3, 0.15, 0.05, 0.18)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 4)
	return s

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 30
	t.set_color("font_color", "Label", C_TEXT)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.8))
	t.set_stylebox("normal", "Button", sb(C_ACCENT))
	t.set_stylebox("hover", "Button", sb(C_ACCENT.lightened(0.08)))
	t.set_stylebox("pressed", "Button", sb(C_ACCENT.darkened(0.12), 28, 0, Color.TRANSPARENT, false))
	t.set_stylebox("hover_pressed", "Button", sb(C_ACCENT.darkened(0.12), 28, 0, Color.TRANSPARENT, false))
	t.set_stylebox("disabled", "Button", sb(C_DISABLED, 28, 0, Color.TRANSPARENT, false))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", sb(C_PANEL, 36, 0, Color.TRANSPARENT, true, 24))
	t.set_stylebox("panel", "Panel", sb(C_PANEL, 36))
	var le := sb(Color.WHITE, 22, 3, C_ACCENT, false, 18)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", sb(Color.WHITE, 22, 4, C_ACCENT.darkened(0.15), false, 18))
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("caret_color", "LineEdit", C_ACCENT)
	t.set_font_size("font_size", "LineEdit", 36)
	var bg := sb(Color(0.9, 0.85, 0.8), 14, 0, Color.TRANSPARENT, false, 0)
	var fill := sb(C_ACCENT2, 14, 0, Color.TRANSPARENT, false, 0)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_constant("separation", "VBoxContainer", 14)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "GridContainer", 12)
	t.set_constant("v_separation", "GridContainer", 12)
	t.set_stylebox("slider", "HSlider", sb(Color(0.9, 0.85, 0.8), 10, 0, Color.TRANSPARENT, false, 6))
	t.set_stylebox("grabber_area", "HSlider", sb(C_ACCENT2, 10, 0, Color.TRANSPARENT, false, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", sb(C_ACCENT2, 10, 0, Color.TRANSPARENT, false, 6))
	var grab := _circle_tex(44, C_ACCENT)
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("scroll", "VScrollBar", sb(Color(0, 0, 0, 0.05), 6, 0, Color.TRANSPARENT, false, 2))
	t.set_stylebox("grabber", "VScrollBar", sb(Color(0, 0, 0, 0.2), 6, 0, Color.TRANSPARENT, false, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", sb(Color(0, 0, 0, 0.3), 6, 0, Color.TRANSPARENT, false, 2))
	t.set_stylebox("grabber_pressed", "VScrollBar", sb(Color(0, 0, 0, 0.3), 6, 0, Color.TRANSPARENT, false, 2))
	_theme = t
	return t

static func _circle_tex(sz: int, c: Color) -> Texture2D:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var r := sz / 2.0
	for y in sz:
		for x in sz:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			var cc := c if d < r - 4 else Color.WHITE
			cc.a = a
			img.set_pixel(x, y, cc)
	return ImageTexture.create_from_image(img)

static func label(txt: String, size: int = 30, color: Color = C_TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(txt: String, cb: Callable, color: Color = C_ACCENT, size: int = 30, min_h: int = 88) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", size)
	if color != C_ACCENT:
		b.add_theme_stylebox_override("normal", sb(color))
		b.add_theme_stylebox_override("hover", sb(color.lightened(0.08)))
		b.add_theme_stylebox_override("pressed", sb(color.darkened(0.12), 28, 0, Color.TRANSPARENT, false))
		b.add_theme_stylebox_override("hover_pressed", sb(color.darkened(0.12), 28, 0, Color.TRANSPARENT, false))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Audio.play("click", 0.05, -4.0))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func icon_button(icon: String, caption: String, cb: Callable, color: Color = Color(1, 1, 1, 0.92), w: int = 120) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, w + 10)
	b.focus_mode = Control.FOCUS_NONE
	b.text = ""
	var st := sb(color, 30, 0, Color.TRANSPARENT, true, 6)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", sb(color.lightened(0.05), 30, 0, Color.TRANSPARENT, true, 6))
	b.add_theme_stylebox_override("pressed", sb(color.darkened(0.1), 30, 0, Color.TRANSPARENT, false, 6))
	b.add_theme_stylebox_override("hover_pressed", sb(color.darkened(0.1), 30, 0, Color.TRANSPARENT, false, 6))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := label(icon, int(w * 0.42), C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	i.autowrap_mode = TextServer.AUTOWRAP_OFF
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := label(caption, 21, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	c.autowrap_mode = TextServer.AUTOWRAP_OFF
	c.clip_text = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(i)
	v.add_child(c)
	b.add_child(v)
	b.pressed.connect(func(): Audio.play("click", 0.05, -4.0))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func bar(value: float, color: Color, h: int = 22) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = 100
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, h)
	p.add_theme_stylebox_override("fill", sb(color, 12, 0, Color.TRANSPARENT, false, 0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func panel(pad: int = 24, color: Color = C_PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(color, 36, 0, Color.TRANSPARENT, true, pad))
	return p

static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep: int = 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func spacer(h: int = 10) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

static func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s

static func swatch(c: Color, selected: bool, cb: Callable, sz: int = 76) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.focus_mode = Control.FOCUS_NONE
	var st := sb(c, sz / 2, 6 if selected else 3, C_TEXT if selected else Color(1, 1, 1, 0.9), true, 0)
	for k in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(k, st)
	b.pressed.connect(func(): Audio.play("click", 0.05, -4.0))
	b.pressed.connect(cb)
	return b
