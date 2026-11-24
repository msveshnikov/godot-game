class_name HealthBar
extends Control
## Health as a bar with a heart: green when well, yellow, then red and pulsing
## when low. A hit leaves a pale strip that drains away after it, so it is easy to
## see how much the last hit took.

const WIDTH := 250.0
const HEIGHT := 22.0
const HEART := 30.0

var max_value := 100.0
var value := 100.0
var _shown := 100.0 # the pale "just lost" end, catching up with value
var _font: Font
var _time := 0.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(HEART + 8.0 + WIDTH, HEART)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_health(health: float, most: float) -> void:
	max_value = most
	if health > value:
		_shown = health # healed / respawned: no trail
	value = health
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _shown > value:
		_shown = maxf(_shown - delta * max_value * 0.6, value)
		queue_redraw()
	elif value / max_value <= 0.3:
		queue_redraw() # the heart pulses


func _draw() -> void:
	var share := clampf(value / max_value, 0.0, 1.0)
	var fill := Color(0.3, 0.85, 0.35)
	if share < 0.6:
		fill = Color(0.95, 0.8, 0.2).lerp(Color(0.3, 0.85, 0.35), (share - 0.3) / 0.3) if share > 0.3 else Color(0.95, 0.2, 0.15)
	# The heart, beating when health is low.
	var beat := 1.0
	if share <= 0.3 and share > 0.0:
		beat = 1.0 + 0.12 * maxf(sin(_time * 9.0), 0.0)
	_heart(Vector2(HEART * 0.5, HEART * 0.5), HEART * 0.5 * beat, Color(0.95, 0.2, 0.18))
	var bar := Rect2(Vector2(HEART + 8.0, (HEART - HEIGHT) * 0.5), Vector2(WIDTH, HEIGHT))
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	back.border_color = Color(0.0, 0.0, 0.0, 0.8)
	back.set_border_width_all(2)
	back.set_corner_radius_all(6)
	draw_style_box(back, bar)
	var inner := bar.grow(-3.0)
	var lost := clampf(_shown / max_value, 0.0, 1.0)
	if lost > share:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * lost, inner.size.y)), Color(1.0, 0.95, 0.85, 0.75))
	if share > 0.0:
		var front := StyleBoxFlat.new()
		front.bg_color = fill
		front.set_corner_radius_all(4)
		draw_style_box(front, Rect2(inner.position, Vector2(maxf(inner.size.x * share, 8.0), inner.size.y)))
		# A lighter band on top, for a bit of shape.
		draw_rect(Rect2(inner.position + Vector2(3, 2), Vector2(maxf(inner.size.x * share - 6.0, 0.0), inner.size.y * 0.28)), Color(1, 1, 1, 0.22))
	var text := str(roundi(value))
	var font_size := 16
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(bar.position.x + bar.size.x * 0.5 - w * 0.5, bar.get_center().y + (_font.get_ascent(font_size) - _font.get_descent(font_size)) * 0.5)
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.8))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## Two circles and a point: a heart of half-width `r` round `c`, with an outline.
func _heart(c: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 40:
		var t := TAU * k / 40.0
		# The classic heart curve, scaled to fit.
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(c + Vector2(x, y + 1.5) * (r / 17.0))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_colored_polygon(points, color)
	draw_polyline(outline, Color(0.25, 0.02, 0.02, 0.9), 2.0, true)
	draw_circle(c + Vector2(-r * 0.4, -r * 0.3), r * 0.18, Color(1, 1, 1, 0.45))
