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

static var _icons := {}
static var _font: Font
static var _emoji: Font
static var _theme: Theme

## Icône vectorielle du jeu (assets/ui/icons/<nom>.svg).
static func icon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	var path := "res://assets/ui/icons/%s.svg" % name
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if t == null:
		push_warning("Icône manquante : " + name)
	_icons[name] = t
	return t

## Sépare la balise d'icône de tête « [i:nom] texte » -> [nom, texte]. Les balises internes sont retirées.
static func split_icon(txt: String) -> Array:
	var name := ""
	var t := txt
	if t.begins_with("[i:"):
		var e := t.find("]")
		if e > 3:
			name = t.substr(3, e - 3)
			t = t.substr(e + 1).strip_edges(true, false)
	while t.find("[i:") >= 0:
		var a := t.find("[i:")
		var b := t.find("]", a)
		if b < 0:
			break
		t = t.substr(0, a) + t.substr(b + 1)
	return [name, t.strip_edges()]

static func icon_rect(name: String, sz: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(sz, sz)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Accessibilité : multiplicateur de taille du texte (Normal / Grand / Très grand).
static func ts(size: int) -> int:
	if size >= 56:
		return size
	var lvl := int(GameState.setting("text_scale")) if GameState.data.has("settings") else 0
	return int(round(size * [1.0, 1.12, 1.25][clampi(lvl, 0, 2)]))

static func reduce_motion() -> bool:
	return GameState.data.has("settings") and bool(GameState.setting("reduce_motion"))

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
	var parts := split_icon(txt)
	txt = parts[1]
	l.text = txt
	if parts[0] != "":
		# icône à gauche du texte
		var sz := int(size * 1.25)
		var st := StyleBoxEmpty.new()
		st.content_margin_left = sz + 8
		l.add_theme_stylebox_override("normal", st)
		var ir := icon_rect(parts[0], sz)
		ir.name = "Ico"
		ir.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		ir.position = Vector2(0, -sz * 0.5)
		ir.size = Vector2(sz, sz)
		l.add_child(ir)
		l.custom_minimum_size.y = maxf(l.custom_minimum_size.y, sz)
	size = ts(size)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if txt.length() > 28 else TextServer.AUTOWRAP_OFF
	return l

## Met à jour le texte d'un libellé créé par label(), en gérant la balise d'icône.
static func set_label(l: Label, txt: String) -> void:
	var parts := split_icon(txt)
	l.text = parts[1]
	var ico: TextureRect = l.get_node_or_null("Ico")
	if parts[0] == "":
		if ico:
			ico.queue_free()
			l.remove_theme_stylebox_override("normal")
		return
	var sz := int(l.get_theme_font_size("font_size") * 1.25)
	if ico == null:
		ico = icon_rect(parts[0], sz)
		ico.name = "Ico"
		ico.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		ico.position = Vector2(0, -sz * 0.5)
		ico.size = Vector2(sz, sz)
		l.add_child(ico)
		var st := StyleBoxEmpty.new()
		st.content_margin_left = sz + 8
		l.add_theme_stylebox_override("normal", st)
	ico.texture = icon(parts[0])

static func button(txt: String, cb: Callable, color: Color = C_ACCENT, size: int = 30, min_h: int = 88) -> Button:
	var b := Button.new()
	var parts := split_icon(txt)
	b.text = parts[1]
	if parts[0] != "":
		b.icon = icon(parts[0])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", int(size * 1.4))
		b.add_theme_constant_override("h_separation", 10)
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", ts(size))
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

static func icon_button(icon_name: String, caption: String, cb: Callable, color: Color = Color(1, 1, 1, 0.92), w: int = 120) -> Button:
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
	var i: Control
	if UiKit.icon(icon_name) != null:
		i = icon_rect(icon_name, int(w * 0.5))
		i.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		var il := label(icon_name, int(w * 0.42), C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		il.autowrap_mode = TextServer.AUTOWRAP_OFF
		il.mouse_filter = Control.MOUSE_FILTER_IGNORE
		i = il
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

## Couleur d'état d'un besoin (vert / orange / rouge).
static func need_color(v: float) -> Color:
	if v >= 60.0:
		return Color(0.42, 0.76, 0.42)
	if v >= 30.0:
		return Color(0.97, 0.66, 0.22)
	return Color(0.9, 0.33, 0.3)

## Ligne de besoin : icône, barre colorée selon l'état, pourcentage. Retourne [ligne, barre, pourcentage].
static func need_row(key: String, value: float, icon_sz: int = 30, bar_h: int = 16, font: int = 20, bar_w: int = 0) -> Array:
	var h := hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := icon_rect(GameData.NEED_ICONS[key], icon_sz)
	ic.tooltip_text = TranslationServer.translate(GameData.NEED_NAMES[key])
	h.add_child(ic)
	var b := bar(value, need_color(value), bar_h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if bar_w > 0:
		b.custom_minimum_size.x = bar_w
	else:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(b)
	var pct := label("%d %%" % int(round(value)), font, need_color(value).darkened(0.35), HORIZONTAL_ALIGNMENT_RIGHT)
	pct.custom_minimum_size = Vector2(font * 2.7, 0)
	h.add_child(pct)
	return [h, b, pct]

static func set_need(b: ProgressBar, pct: Label, value: float) -> void:
	b.value = value
	b.add_theme_stylebox_override("fill", sb(need_color(value), 12, 0, Color.TRANSPARENT, false, 0))
	pct.text = "%d %%" % int(round(value))
	pct.add_theme_color_override("font_color", need_color(value).darkened(0.35))

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
