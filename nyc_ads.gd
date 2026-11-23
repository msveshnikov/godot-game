extends RefCounted
## The ads on the Times Square billboards, painted once at load time into a
## 2048 x 2304 atlas (screen.gdshader samples it):
##   0-15  wide ads, 512 x 256, four per row in the top 1024 px
##   16-31 tall ads, 256 x 512, eight per row below them
##   32-35 ticker strips, 2048 x 64, at the bottom
## Every brand here is made up. Controls are laid out in a SubViewport that is
## drawn once; the picture is copied into a mipmapped texture and the viewport freed.

const FONT_PATH := "res://addons/cogito/Assets/Fonts/Montserrat/Montserrat-Bold.ttf"
const ATLAS := Vector2i(2048, 2304)

const TICKERS := [
	"BREAKING NEWS  +++  TIMES SQUARE BREAKS AWAY FROM MANHATTAN AND DRIFTS OUT TO SEA  +++  FERRIES TO BROOKLYN SUSPENDED  +++  MAYOR: \"IT'S STILL NEW YORK\"  +++  ",
	"[color=#7CFC7C]FIZZ 84.10 +1.2%[/color]   [color=#FF6B6B]NOVA 212.55 -0.4%[/color]   [color=#7CFC7C]ZPPY 41.07 +3.9%[/color]   [color=#7CFC7C]QNTM 1,204.30 +0.8%[/color]   [color=#FF6B6B]POLR 18.22 -2.1%[/color]   [color=#7CFC7C]GACHA 999.99 +12.0%[/color]   [color=#FF6B6B]LUNA 63.40 -0.7%[/color]   ",
	"WELCOME TO TIMES SQUARE  *  THE CROSSROADS OF THE WORLD  *  BROADWAY  *  7TH AVENUE  *  42ND STREET  *  ",
	"GACHA VILLAGE  *  NOW IN NEW YORK  *  PLAY FREE WITH FRIENDS  *  MAXIMS.TOP/VILLAGE  *  ",
]

static var _font: Font


## Paint the atlas and hand it to `material` ("atlas" parameter) when it is ready.
static func bake(host: Node, material: ShaderMaterial) -> void:
	var placeholder := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	placeholder.fill(Color(0.02, 0.02, 0.03))
	material.set_shader_parameter("atlas", ImageTexture.create_from_image(placeholder))
	if DisplayServer.get_name() == "headless":
		return
	_font = load(FONT_PATH) as Font
	var viewport := SubViewport.new()
	viewport.name = "AdAtlas"
	viewport.size = ATLAS
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(viewport)
	var root := Control.new()
	root.size = Vector2(ATLAS)
	viewport.add_child(root)
	_paint(root)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(viewport):
		return
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	if image == null or image.is_empty():
		return
	image.convert(Image.FORMAT_RGBA8)
	image.generate_mipmaps()
	material.set_shader_parameter("atlas", ImageTexture.create_from_image(image))


static func _paint(root: Control) -> void:
	var designs := [
		_fizz, _nova, _starlight, _gacha, _skyline_air, _mega_burger, _aurora, _zippy,
		_polar, _breaking, _quantum, _pixela, _luna, _loves_you, _velvet, _midnight_cats,
	]
	for index in 16:
		var wide := Rect2(Vector2((index % 4) * 512, (index / 4) * 256), Vector2(512, 256))
		designs[index].call(root, wide, false)
		var tall := Rect2(Vector2((index % 8) * 256, 1024 + (index / 8) * 512), Vector2(256, 512))
		designs[(index + 5) % 16].call(root, tall, true)
	for index in TICKERS.size():
		var strip := Rect2(Vector2(0, 2048 + index * 64), Vector2(2048, 64))
		_bg(root, strip, Color(0.02, 0.02, 0.05), Color(0.05, 0.05, 0.12))
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_OFF
		text.clip_contents = true
		text.position = strip.position + Vector2(8, 6)
		text.size = strip.size - Vector2(8, 6)
		text.add_theme_font_override("normal_font", _font)
		text.add_theme_font_size_override("normal_font_size", 40)
		text.add_theme_color_override("default_color", [Color(1, 0.3, 0.25), Color.WHITE, Color(1, 0.85, 0.3), Color(0.5, 1, 0.6)][index])
		var line: String = TICKERS[index]
		text.text = line + line
		root.add_child(text)


# ----------------------------------------------------------------- pieces ----

static func _bg(root: Control, r: Rect2, a: Color, b: Color, vertical := true) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, a)
	gradient.set_color(1, b)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1) if vertical else Vector2(1, 0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.position = r.position
	rect.size = r.size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(rect)


static func _text(root: Control, r: Rect2, text: String, size: int, color: Color, outline := 0, outline_color := Color.BLACK,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var label := Label.new()
	label.text = text
	label.position = r.position
	label.size = r.size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	var settings := LabelSettings.new()
	settings.font = _font
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = outline
	settings.outline_color = outline_color
	settings.line_spacing = -size * 0.15
	label.label_settings = settings
	root.add_child(label)


static func _round(root: Control, r: Rect2, color: Color, radius: float, border := 0, border_color := Color.WHITE) -> void:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	style.anti_aliasing = true
	if border > 0:
		style.set_border_width_all(border)
		style.border_color = border_color
	panel.add_theme_stylebox_override("panel", style)
	panel.position = r.position
	panel.size = r.size
	root.add_child(panel)


static func _circle(root: Control, centre: Vector2, radius: float, color: Color) -> void:
	_round(root, Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color, radius)


static func _poly(root: Control, points: PackedVector2Array, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	polygon.antialiased = true
	root.add_child(polygon)


## Split a design's rect into a picture area and a text area (side by side when wide, stacked when tall).
static func _split(r: Rect2, tall: bool, picture_share := 0.45) -> Array:
	if tall:
		var h := r.size.y * picture_share
		return [Rect2(r.position + Vector2(0, r.size.y - h), Vector2(r.size.x, h)), Rect2(r.position, Vector2(r.size.x, r.size.y - h))]
	var w := r.size.x * picture_share
	return [Rect2(r.position + Vector2(r.size.x - w, 0), Vector2(w, r.size.y)), Rect2(r.position, Vector2(r.size.x - w, r.size.y))]


static func _inset(r: Rect2, by: float) -> Rect2:
	return Rect2(r.position + Vector2.ONE * by, r.size - Vector2.ONE * by * 2.0)


static func _scale(r: Rect2) -> float:
	return minf(r.size.x, r.size.y) / 256.0


# ---------------------------------------------------------------- designs ----

static func _fizz(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.9, 0.05, 0.08), Color(0.55, 0.0, 0.03))
	var s := _scale(r)
	var parts := _split(r, tall, 0.4)
	var pic: Rect2 = parts[0]
	var wave := PackedVector2Array()
	for k in 33:
		var x := r.position.x + r.size.x * k / 32.0
		wave.append(Vector2(x, r.position.y + r.size.y * 0.72 + sin(k * 0.45) * 14.0 * s))
	wave.append(r.end)
	wave.append(Vector2(r.position.x, r.end.y))
	_poly(root, wave, Color(1, 1, 1, 0.9))
	# Bottle: body, shoulders, neck, cap, label.
	var c := pic.get_center()
	var bw := 46.0 * s
	var bh := 170.0 * s
	_round(root, Rect2(c + Vector2(-bw * 0.5, -bh * 0.25), Vector2(bw, bh * 0.75)), Color(0.25, 0.08, 0.05), 14.0 * s)
	_poly(root, PackedVector2Array([c + Vector2(-bw * 0.5, -bh * 0.25), c + Vector2(bw * 0.5, -bh * 0.25), c + Vector2(bw * 0.18, -bh * 0.48), c + Vector2(-bw * 0.18, -bh * 0.48)]), Color(0.25, 0.08, 0.05))
	_round(root, Rect2(c + Vector2(-bw * 0.2, -bh * 0.58), Vector2(bw * 0.4, bh * 0.12)), Color(0.85, 0.85, 0.85), 3.0)
	_round(root, Rect2(c + Vector2(-bw * 0.5, bh * 0.0), Vector2(bw, bh * 0.22)), Color(0.95, 0.1, 0.1), 2.0)
	var text: Rect2 = parts[1]
	_text(root, Rect2(text.position, Vector2(text.size.x, text.size.y * 0.65)), "Fizz", int(96 * s), Color.WHITE, int(6 * s), Color(0.5, 0, 0))
	_text(root, Rect2(text.position + Vector2(0, text.size.y * 0.55), Vector2(text.size.x, text.size.y * 0.3)), "TASTE THE FIZZ!", int(26 * s), Color(1, 0.95, 0.9))


static func _nova(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.02, 0.02, 0.04), Color(0.08, 0.02, 0.15))
	var s := _scale(r)
	var parts := _split(r, tall, 0.45)
	var pic: Rect2 = parts[0]
	var c := pic.get_center()
	_circle(root, c, 95.0 * s, Color(0.45, 0.15, 0.9, 0.35))
	_circle(root, c, 70.0 * s, Color(0.55, 0.25, 1.0, 0.35))
	var phone := Rect2(c - Vector2(42, 85) * s, Vector2(84, 170) * s)
	_round(root, phone, Color(0.12, 0.12, 0.14), 14.0 * s, int(3 * s), Color(0.7, 0.7, 0.75))
	_bg(root, _inset(phone, 7.0 * s), Color(0.1, 0.6, 0.95), Color(0.9, 0.2, 0.7))
	_circle(root, phone.position + Vector2(phone.size.x * 0.5, 14.0 * s), 3.5 * s, Color.BLACK)
	var text: Rect2 = parts[1]
	_text(root, Rect2(text.position, Vector2(text.size.x, text.size.y * 0.6)), "NOVA 12", int(64 * s), Color.WHITE)
	_text(root, Rect2(text.position + Vector2(0, text.size.y * 0.5), Vector2(text.size.x, text.size.y * 0.35)), "The future fits in your hand", int(20 * s), Color(0.8, 0.7, 1.0))


static func _starlight(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.02, 0.03, 0.18), Color(0.12, 0.02, 0.25))
	var s := _scale(r)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 26:
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		_star(root, p, rng.randf_range(3.0, 9.0) * s, Color(1, 0.9, 0.5, rng.randf_range(0.4, 1.0)))
	_star(root, r.position + r.size * Vector2(0.5, 0.22 if tall else 0.2), 26.0 * s, Color(1, 0.85, 0.3))
	_text(root, Rect2(r.position + Vector2(0, r.size.y * 0.25), Vector2(r.size.x, r.size.y * 0.35)), "STARLIGHT", int((54 if tall else 76) * s), Color(1, 0.85, 0.35), int(4 * s), Color(0.4, 0.2, 0))
	_text(root, Rect2(r.position + Vector2(0, r.size.y * 0.55), Vector2(r.size.x, r.size.y * 0.2)), "THE MUSICAL", int(26 * s), Color.WHITE)
	_round(root, Rect2(r.position + r.size * Vector2(0.2, 0.78), r.size * Vector2(0.6, 0.13)), Color(0.85, 0.1, 0.2), 6.0 * s)
	_text(root, Rect2(r.position + r.size * Vector2(0.2, 0.78), r.size * Vector2(0.6, 0.13)), "NOW PLAYING", int(18 * s), Color.WHITE)


static func _star(root: Control, c: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + k * PI / 5.0
		points.append(c + Vector2(cos(a), sin(a)) * (radius if k % 2 == 0 else radius * 0.42))
	_poly(root, points, color)


static func _gacha(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.1, 0.55, 0.2), Color(0.02, 0.25, 0.1))
	var s := _scale(r)
	var parts := _split(r, tall, 0.4)
	var pic: Rect2 = parts[0]
	var c := pic.get_center()
	# A little crosshair and a villager head.
	_circle(root, c, 58.0 * s, Color(1, 0.85, 0.25))
	_circle(root, c, 50.0 * s, Color(0.1, 0.45, 0.18))
	_circle(root, c + Vector2(0, -8) * s, 22.0 * s, Color(0.95, 0.78, 0.6))
	_round(root, Rect2(c + Vector2(-24, 14) * s, Vector2(48, 30) * s), Color(0.85, 0.2, 0.2), 10.0 * s)
	_round(root, Rect2(c + Vector2(-2, -70) * s, Vector2(4, 140) * s), Color(1, 1, 1, 0.8), 1.0)
	_round(root, Rect2(c + Vector2(-70, -2) * s, Vector2(140, 4) * s), Color(1, 1, 1, 0.8), 1.0)
	var text: Rect2 = parts[1]
	_text(root, Rect2(text.position, Vector2(text.size.x, text.size.y * 0.5)), "GACHA VILLAGE", int(44 * s), Color(1, 0.95, 0.6), int(4 * s), Color(0.05, 0.2, 0.05))
	_text(root, Rect2(text.position + Vector2(0, text.size.y * 0.45), Vector2(text.size.x, text.size.y * 0.25)), "PLAY FREE WITH FRIENDS", int(18 * s), Color.WHITE)
	_text(root, Rect2(text.position + Vector2(0, text.size.y * 0.68), Vector2(text.size.x, text.size.y * 0.25)), "maxims.top/village", int(20 * s), Color(0.6, 1, 0.6))


static func _skyline_air(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.25, 0.6, 0.95), Color(0.85, 0.93, 1.0))
	var s := _scale(r)
	var c := r.position + r.size * Vector2(0.7 if not tall else 0.5, 0.35 if not tall else 0.3)
	_circle(root, c + Vector2(-60, 30) * s, 30.0 * s, Color(1, 1, 1, 0.8))
	_circle(root, c + Vector2(-30, 38) * s, 24.0 * s, Color(1, 1, 1, 0.8))
	# Plane: fuselage, wings, tail.
	var k := s * 1.3
	_poly(root, PackedVector2Array([c + Vector2(-70, 0) * k, c + Vector2(60, -6) * k, c + Vector2(72, 0) * k, c + Vector2(60, 6) * k]), Color.WHITE)
	_poly(root, PackedVector2Array([c + Vector2(-5, 0) * k, c + Vector2(20, 0) * k, c + Vector2(-20, 45) * k, c + Vector2(-32, 45) * k]), Color(0.95, 0.95, 0.97))
	_poly(root, PackedVector2Array([c + Vector2(-5, 0) * k, c + Vector2(20, 0) * k, c + Vector2(-20, -45) * k, c + Vector2(-32, -45) * k]), Color(0.85, 0.87, 0.9))
	_poly(root, PackedVector2Array([c + Vector2(-60, 0) * k, c + Vector2(-48, 0) * k, c + Vector2(-66, -22) * k, c + Vector2(-74, -22) * k]), Color(0.9, 0.2, 0.25))
	var text := Rect2(r.position + Vector2(10, r.size.y * (0.5 if tall else 0.45)), Vector2(r.size.x * (1.0 if tall else 0.6) - 10, r.size.y * 0.3))
	_text(root, text, "SKYLINE AIR", int(46 * s), Color(0.05, 0.15, 0.45), 0, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER if tall else HORIZONTAL_ALIGNMENT_LEFT)
	_text(root, Rect2(text.position + Vector2(0, text.size.y * 0.75), text.size), "NEW YORK - ANYWHERE", int(18 * s), Color(0.9, 0.2, 0.25), 0, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER if tall else HORIZONTAL_ALIGNMENT_LEFT)


static func _mega_burger(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(1, 0.78, 0.1), Color(1, 0.5, 0.05))
	var s := _scale(r)
	var parts := _split(r, tall, 0.5)
	var c: Vector2 = (parts[0] as Rect2).get_center()
	var w := 150.0 * s
	_round(root, Rect2(c + Vector2(-w * 0.5, 22 * s), Vector2(w, 26 * s)), Color(0.8, 0.5, 0.2), 12.0 * s)
	_round(root, Rect2(c + Vector2(-w * 0.52, 2 * s), Vector2(w * 1.04, 24 * s)), Color(0.35, 0.18, 0.08), 10.0 * s)
	_round(root, Rect2(c + Vector2(-w * 0.55, -4 * s), Vector2(w * 1.1, 10 * s)), Color(1, 0.85, 0.1), 4.0 * s)
	_round(root, Rect2(c + Vector2(-w * 0.53, -14 * s), Vector2(w * 1.06, 12 * s)), Color(0.3, 0.75, 0.2), 6.0 * s)
	_round(root, Rect2(c + Vector2(-w * 0.5, -20 * s), Vector2(w, 8 * s)), Color(0.85, 0.15, 0.1), 4.0 * s)
	_round(root, Rect2(c + Vector2(-w * 0.5, -66 * s), Vector2(w, 50 * s)), Color(0.85, 0.55, 0.2), 40.0 * s)
	var text: Rect2 = parts[1]
	_text(root, Rect2(text.position, Vector2(text.size.x, text.size.y * 0.6)), "MEGA\nBURGER", int(50 * s), Color(0.7, 0.05, 0.05), int(3 * s), Color.WHITE)
	_circle(root, text.position + text.size * Vector2(0.5, 0.78), 30.0 * s, Color(0.75, 0.05, 0.05))
	_text(root, Rect2(text.position + text.size * Vector2(0.0, 0.66), text.size * Vector2(1.0, 0.25)), "$4.99", int(22 * s), Color.WHITE)


static func _aurora(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.35, 0.1, 0.55), Color(0.05, 0.55, 0.6), false)
	var s := _scale(r)
	var parts := _split(r, tall, 0.45)
	var c: Vector2 = (parts[0] as Rect2).get_center()
	_round(root, Rect2(c + Vector2(-22, -100) * s, Vector2(44, 200) * s), Color(0.15, 0.15, 0.18), 10.0 * s)
	_circle(root, c, 58.0 * s, Color(0.85, 0.85, 0.9))
	_circle(root, c, 50.0 * s, Color(0.05, 0.05, 0.08))
	_round(root, Rect2(c + Vector2(-2, -42) * s, Vector2(4, 42) * s), Color.WHITE, 2.0)
	_round(root, Rect2(c + Vector2(-2, -2) * s, Vector2(32, 4) * s), Color(1, 0.4, 0.6), 2.0)
	var text: Rect2 = parts[1]
	_text(root, Rect2(text.position, Vector2(text.size.x, text.size.y * 0.6)), "AURORA", int(56 * s), Color.WHITE)
	_text(root, Rect2(text.position + Vector2(0, text.size.y * 0.5), Vector2(text.size.x, text.size.y * 0.3)), "Time, reimagined.", int(22 * s), Color(0.85, 1, 0.95))


static func _zippy(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(1, 0.45, 0.05), Color(0.95, 0.2, 0.1), false)
	var s := _scale(r)
	var parts := _split(r, tall, 0.5)
	var c: Vector2 = (parts[0] as Rect2).get_center()
	var k := s * 1.2
	_poly(root, PackedVector2Array([
		c + Vector2(-80, 20) * k, c + Vector2(-70, -20) * k, c + Vector2(-30, -28) * k, c + Vector2(0, -10) * k,
		c + Vector2(50, -5) * k, c + Vector2(80, 10) * k, c + Vector2(80, 25) * k, c + Vector2(-80, 30) * k]), Color.WHITE)
	_poly(root, PackedVector2Array([c + Vector2(-80, 24) * k, c + Vector2(80, 19) * k, c + Vector2(80, 30) * k, c + Vector2(-80, 32) * k]), Color(0.1, 0.1, 0.1))
	_poly(root, PackedVector2Array([c + Vector2(-40, 5) * k, c + Vector2(30, -2) * k, c + Vector2(-20, 15) * k]), Color(1, 0.45, 0.05))
	var text: Rect2 = parts[1]
	_text(root, Rect2(text.position, Vector2(text.size.x, text.size.y * 0.6)), "ZIPPY", int(72 * s), Color.WHITE, int(4 * s), Color(0.4, 0.05, 0))
	_text(root, Rect2(text.position + Vector2(0, text.size.y * 0.52), Vector2(text.size.x, text.size.y * 0.3)), "JUST RUN.", int(28 * s), Color(0.1, 0.1, 0.1))


static func _polar(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.6, 0.92, 1.0), Color(0.2, 0.6, 0.95))
	var s := _scale(r)
	var parts := _split(r, tall, 0.45)
	var c: Vector2 = (parts[0] as Rect2).get_center()
	_poly(root, PackedVector2Array([c + Vector2(-34, 0) * s, c + Vector2(34, 0) * s, c + Vector2(0, 95) * s]), Color(0.85, 0.6, 0.3))
	_circle(root, c + Vector2(-16, -12) * s, 30.0 * s, Color(1, 0.75, 0.85))
	_circle(root, c + Vector2(18, -14) * s, 28.0 * s, Color(1, 0.98, 0.9))
	_circle(root, c + Vector2(0, -48) * s, 28.0 * s, Color(0.5, 0.3, 0.2))
	var text: Rect2 = parts[1]
	_text(root, Rect2(text.position, Vector2(text.size.x, text.size.y * 0.6)), "POLAR", int(66 * s), Color.WHITE, int(5 * s), Color(0.1, 0.3, 0.6))
	_text(root, Rect2(text.position + Vector2(0, text.size.y * 0.5), Vector2(text.size.x, text.size.y * 0.3)), "stay cool", int(26 * s), Color(0.05, 0.2, 0.45))


static func _breaking(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.03, 0.08, 0.25), Color(0.02, 0.03, 0.1))
	var s := _scale(r)
	_round(root, Rect2(r.position + Vector2(0, r.size.y * 0.12), Vector2(r.size.x, r.size.y * 0.18)), Color(0.85, 0.05, 0.05), 0)
	_text(root, Rect2(r.position + Vector2(0, r.size.y * 0.12), Vector2(r.size.x, r.size.y * 0.18)), "BREAKING NEWS", int(30 * s), Color.WHITE)
	_text(root, Rect2(r.position + Vector2(r.size.x * 0.05, r.size.y * 0.33), Vector2(r.size.x * 0.9, r.size.y * 0.45)),
		"Times Square is now an island" if not tall else "Times Square is now an island", int((26 if tall else 30) * s), Color.WHITE)
	_round(root, Rect2(r.position + Vector2(0, r.size.y * 0.84), Vector2(r.size.x, r.size.y * 0.1)), Color(1, 0.8, 0.1), 0)
	_text(root, Rect2(r.position + Vector2(0, r.size.y * 0.84), Vector2(r.size.x, r.size.y * 0.1)), "LIVE  |  NEW YORK", int(14 * s), Color.BLACK)


static func _quantum(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.02, 0.06, 0.18), Color(0.0, 0.02, 0.08))
	var s := _scale(r)
	var parts := _split(r, tall, 0.4)
	var c: Vector2 = (parts[0] as Rect2).get_center()
	for k in 3:
		_round(root, Rect2(c - Vector2(70, 22) * s, Vector2(140, 44) * s), Color(0, 0, 0, 0), 22.0 * s, int(3 * s), Color(0.95, 0.75, 0.3))
		c.y += 0.0
	_circle(root, c, 12.0 * s, Color(0.95, 0.75, 0.3))
	_round(root, Rect2(c - Vector2(22, 70) * s, Vector2(44, 140) * s), Color(0, 0, 0, 0), 22.0 * s, int(3 * s), Color(0.95, 0.75, 0.3))
	var text: Rect2 = parts[1]
	_text(root, Rect2(text.position, Vector2(text.size.x, text.size.y * 0.6)), "QUANTUM\nBANK", int(42 * s), Color(0.95, 0.8, 0.4))
	_text(root, Rect2(text.position + Vector2(0, text.size.y * 0.6), Vector2(text.size.x, text.size.y * 0.3)), "Banking at the speed of light", int(16 * s), Color(0.8, 0.85, 1.0))


static func _pixela(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.02, 0.02, 0.02), Color(0.06, 0.06, 0.08))
	var s := _scale(r)
	var colors := [Color(1, 1, 1), Color(1, 0.9, 0.1), Color(0.1, 0.9, 0.95), Color(0.1, 0.9, 0.2), Color(0.95, 0.1, 0.9), Color(0.95, 0.1, 0.1), Color(0.1, 0.2, 0.95)]
	var bars := Rect2(r.position + r.size * Vector2(0.08, 0.1), r.size * Vector2(0.84, 0.5))
	for k in colors.size():
		_round(root, Rect2(bars.position + Vector2(bars.size.x * k / colors.size(), 0), Vector2(bars.size.x / colors.size() + 1, bars.size.y)), colors[k], 0)
	_text(root, Rect2(r.position + r.size * Vector2(0, 0.62), r.size * Vector2(1, 0.22)), "PIXELA 8K", int(52 * s), Color.WHITE)
	_text(root, Rect2(r.position + r.size * Vector2(0, 0.82), r.size * Vector2(1, 0.14)), "See every pixel", int(18 * s), Color(0.7, 0.7, 0.75))


static func _luna(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.02, 0.02, 0.02), Color(0.05, 0.12, 0.02))
	var s := _scale(r)
	var parts := _split(r, tall, 0.45)
	var c: Vector2 = (parts[0] as Rect2).get_center()
	var can := Rect2(c - Vector2(36, 80) * s, Vector2(72, 160) * s)
	_round(root, can, Color(0.15, 0.15, 0.15), 10.0 * s)
	_round(root, Rect2(can.position + Vector2(0, can.size.y * 0.3), Vector2(can.size.x, can.size.y * 0.4)), Color(0.4, 1.0, 0.1), 2.0)
	_circle(root, can.get_center(), 18.0 * s, Color(0.05, 0.05, 0.05))
	_circle(root, can.get_center() + Vector2(7, -4) * s, 15.0 * s, Color(0.4, 1.0, 0.1))
	var text: Rect2 = parts[1]
	_text(root, Rect2(text.position, Vector2(text.size.x, text.size.y * 0.6)), "LUNA", int(76 * s), Color(0.45, 1, 0.15))
	_text(root, Rect2(text.position + Vector2(0, text.size.y * 0.52), Vector2(text.size.x, text.size.y * 0.3)), "ENERGY", int(30 * s), Color.WHITE)


static func _loves_you(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(1, 1, 1), Color(0.92, 0.92, 0.92))
	var s := _scale(r)
	var c := r.position + r.size * Vector2(0.5, 0.33 if tall else 0.36)
	var k := 1.0 if tall else 0.9
	_circle(root, c + Vector2(-26, -10) * s * k, 32.0 * s * k, Color(0.9, 0.05, 0.15))
	_circle(root, c + Vector2(26, -10) * s * k, 32.0 * s * k, Color(0.9, 0.05, 0.15))
	_poly(root, PackedVector2Array([c + Vector2(-56, 2) * s * k, c + Vector2(56, 2) * s * k, c + Vector2(0, 62) * s * k]), Color(0.9, 0.05, 0.15))
	_text(root, Rect2(r.position + r.size * Vector2(0, 0.62 if tall else 0.66), r.size * Vector2(1, 0.3)), "NEW YORK\nLOVES YOU", int((36 if tall else 30) * s), Color.BLACK)


static func _velvet(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.98, 0.78, 0.7), Color(0.85, 0.45, 0.5), false)
	var s := _scale(r)
	_circle(root, r.position + r.size * Vector2(0.75, 0.3), 70.0 * s, Color(1, 0.95, 0.9, 0.5))
	_circle(root, r.position + r.size * Vector2(0.2, 0.8), 50.0 * s, Color(0.6, 0.2, 0.35, 0.4))
	# A stylised figure: head, long coat.
	var c := r.position + r.size * Vector2(0.72 if not tall else 0.5, 0.55)
	_circle(root, c + Vector2(0, -70) * s, 16.0 * s, Color(0.35, 0.22, 0.18))
	_poly(root, PackedVector2Array([c + Vector2(-14, -52) * s, c + Vector2(14, -52) * s, c + Vector2(34, 80) * s, c + Vector2(-34, 80) * s]), Color(0.45, 0.05, 0.15))
	var text := Rect2(r.position + Vector2(r.size.x * 0.05, r.size.y * (0.05 if tall else 0.2)), Vector2(r.size.x * (0.9 if tall else 0.5), r.size.y * 0.35))
	_text(root, text, "VELVET", int(54 * s), Color(0.3, 0.02, 0.1))
	_text(root, Rect2(text.position + Vector2(0, text.size.y * 0.75), text.size), "FALL COLLECTION", int(16 * s), Color(0.3, 0.02, 0.1))


static func _midnight_cats(root: Control, r: Rect2, tall: bool) -> void:
	_bg(root, r, Color(0.02, 0.02, 0.03), Color(0.05, 0.05, 0.1))
	var s := _scale(r)
	var c := r.position + r.size * Vector2(0.5, 0.38 if tall else 0.42)
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * 42, 0) * s
		_poly(root, PackedVector2Array([e + Vector2(-30, 0) * s, e + Vector2(0, -16) * s, e + Vector2(30, 0) * s, e + Vector2(0, 16) * s]), Color(1, 0.85, 0.1))
		_round(root, Rect2(e - Vector2(3, 14) * s, Vector2(6, 28) * s), Color.BLACK, 3.0)
	_text(root, Rect2(r.position + r.size * Vector2(0, 0.62), r.size * Vector2(1, 0.2)), "MIDNIGHT CATS", int((26 if tall else 40) * s), Color(1, 0.85, 0.1))
	_text(root, Rect2(r.position + r.size * Vector2(0, 0.8), r.size * Vector2(1, 0.14)), "A NEW BROADWAY MUSICAL", int(14 * s), Color(0.8, 0.8, 0.85))
