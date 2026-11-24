class_name UiTheme
## The look of every menu: dark slate panels with a gold edge, rounded buttons that
## light up gold, gold sliders. Built once in code and shared (main_menu.gd,
## settings_panel.gd, shop.gd, the game's own screens in player_controller.gd).

const PANEL := Color(0.075, 0.115, 0.145, 0.97)
const EDGE := Color(0.76, 0.57, 0.3)
const GOLD := Color(1.0, 0.82, 0.25)
const TITLE := Color(1.0, 0.86, 0.54)
const TEXT := Color(0.92, 0.94, 0.91)
const DIM := Color(0.66, 0.7, 0.7)
const DARK_TEXT := Color(0.07, 0.08, 0.1)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	theme.default_font_size = 20

	var normal := _box(Color(0.12, 0.17, 0.21, 0.95), Color(0.28, 0.34, 0.38), 1, 10)
	var hover := _box(Color(0.17, 0.24, 0.29, 0.98), EDGE, 2, 10)
	var pressed := _box(EDGE, GOLD, 2, 10)
	var disabled := _box(Color(0.1, 0.12, 0.14, 0.7), Color(0.2, 0.22, 0.24), 1, 10)
	for state in [["normal", normal], ["hover", hover], ["pressed", pressed], ["hover_pressed", pressed], ["disabled", disabled], ["focus", StyleBoxEmpty.new()]]:
		theme.set_stylebox(state[0], "Button", state[1])
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", DARK_TEXT)
	theme.set_color("font_hover_pressed_color", "Button", DARK_TEXT)
	theme.set_color("font_disabled_color", "Button", Color(0.45, 0.47, 0.48))
	theme.set_font_size("font_size", "Button", 20)

	# The big call to action.
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", _box(Color(0.86, 0.63, 0.2), GOLD, 2, 12))
	theme.set_stylebox("hover", "PrimaryButton", _box(Color(0.97, 0.74, 0.27), Color(1.0, 0.95, 0.75), 2, 12))
	theme.set_stylebox("pressed", "PrimaryButton", _box(Color(0.7, 0.5, 0.15), GOLD, 2, 12))
	theme.set_color("font_color", "PrimaryButton", DARK_TEXT)
	theme.set_color("font_hover_color", "PrimaryButton", DARK_TEXT)
	theme.set_color("font_pressed_color", "PrimaryButton", DARK_TEXT)
	theme.set_font_size("font_size", "PrimaryButton", 30)

	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, EDGE, 2, 16))
	theme.set_color("font_color", "Label", TEXT)

	var field := _box(Color(0.05, 0.08, 0.1, 0.95), Color(0.3, 0.36, 0.4), 1, 8)
	field.content_margin_left = 12.0
	field.content_margin_right = 12.0
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", _box(Color(0.05, 0.08, 0.1, 0.95), EDGE, 2, 8))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_font_size("font_size", "LineEdit", 22)

	var track := _box(Color(0.05, 0.08, 0.1), Color(0.3, 0.36, 0.4), 1, 4)
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	theme.set_stylebox("slider", "HSlider", track)
	var fill := _box(EDGE, EDGE, 0, 4)
	fill.content_margin_top = 4.0
	fill.content_margin_bottom = 4.0
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(GOLD, GOLD, 0, 4))
	var knob := _circle(GOLD, 22)
	theme.set_icon("grabber", "HSlider", knob)
	theme.set_icon("grabber_highlight", "HSlider", _circle(Color(1.0, 0.95, 0.75), 24))

	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_hover_color", "CheckButton", Color.WHITE)
	theme.set_color("font_pressed_color", "CheckButton", TEXT)
	theme.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		theme.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	var on := _pill(true)
	var off := _pill(false)
	for icon in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
		theme.set_icon(icon, "CheckButton", on)
	for icon in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
		theme.set_icon(icon, "CheckButton", off)

	theme.set_stylebox("scroll", "VScrollBar", _thin(Color(1, 1, 1, 0.06)))
	theme.set_stylebox("grabber", "VScrollBar", _thin(Color(0.76, 0.57, 0.3, 0.6)))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _thin(EDGE))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _thin(GOLD))
	_theme = theme
	return theme


static func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	box.anti_aliasing = true
	return box


## A scroll bar part 8 px wide.
static func _thin(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(4)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


## An on/off switch: a rounded track with the knob at one end.
static func _pill(on: bool) -> ImageTexture:
	var w := 56
	var h := 30
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := EDGE if on else Color(0.22, 0.27, 0.3)
	var knob := Color(1.0, 0.95, 0.8) if on else Color(0.62, 0.66, 0.68)
	var r := h * 0.5
	var knob_x := w - r if on else r
	for y in h:
		for x in w:
			var px := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(px.x, r, w - r)
			var d := px.distance_to(Vector2(cx, r))
			var a := clampf(r - d, 0.0, 1.0)
			var c := Color(track.r, track.g, track.b, a)
			var dk := px.distance_to(Vector2(knob_x, r))
			var ka := clampf(r - 4.0 - dk, 0.0, 1.0)
			c = c.lerp(Color(knob.r, knob.g, knob.b, 1.0), ka)
			image.set_pixel(x, y, c)
	return ImageTexture.create_from_image(image)


static func _circle(color: Color, size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(image)


## A heading in gold.
static func heading(text: String, size := 22) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TITLE)
	return label


## A panel that fits the screen: centred, at most `max_size`, `gap` from the edges.
static func fit(panel: Control, max_size: Vector2, gap := 10.0) -> void:
	var view := panel.get_viewport().get_visible_rect().size
	var size_now := Vector2(minf(view.x - 2.0 * gap, max_size.x), minf(view.y - 2.0 * gap, max_size.y))
	var at := (view - size_now) * 0.5
	if panel.position != at or panel.size != size_now:
		panel.position = at
		panel.size = size_now
