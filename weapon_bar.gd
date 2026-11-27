class_name WeaponBar
extends Control
## The weapon slots in cycle order, each drawn as its silhouette,
## the one in hand lit up. The bazooka shows its rockets (or a lock and its price
## until it is bought). Keys 1-5 are shown on a keyboard; on a touch screen the
## slots are tapped to pick a weapon (`picked`).

signal picked(kind: String)

const ORDER := ["bat", "pistol", "bazooka", "none", "m4a1"]
const NAMES := {"pistol": "DESERT EAGLE", "bat": "BAT", "none": "HANDS", "bazooka": "BAZOOKA", "m4a1": "M4A1"}
const SLOT := Vector2(84.0, 68.0)
const GAP := 8.0
const GOLD := Color(1.0, 0.82, 0.25)

var current := "pistol"
var owned_bazooka := false
var rockets := 0
var max_rockets := 5
var bazooka_price := 1000
var owned_m4a1 := false
var rounds := 0
var show_keys := true
var _font: Font
var _pop := 0.0 # the slot just picked swells for a moment


static func shortcut_text() -> String:
	var labels := PackedStringArray()
	for i in ORDER.size():
		labels.append("%d %s" % [i + 1, NAMES[ORDER[i]].to_lower()])
	return "  ".join(labels)


func _ready() -> void:
	_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(ORDER.size() * SLOT.x + (ORDER.size() - 1) * GAP, SLOT.y + 8.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_state(weapon: String, has_bazooka: bool, rocket_count: int, has_m4a1 := false, round_count := 0) -> void:
	if weapon != current:
		_pop = 1.0
	current = weapon
	owned_bazooka = has_bazooka
	rockets = rocket_count
	owned_m4a1 = has_m4a1
	rounds = round_count
	queue_redraw()


func _process(delta: float) -> void:
	if _pop > 0.0:
		_pop = maxf(_pop - delta * 5.0, 0.0)
		queue_redraw()


func _slot_rect(i: int) -> Rect2:
	return Rect2(Vector2(i * (SLOT.x + GAP), 4.0), SLOT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in ORDER.size():
			if _slot_rect(i).grow(4.0).has_point(event.position):
				picked.emit(ORDER[i])
				accept_event()
				return


func _draw() -> void:
	for i in ORDER.size():
		var kind: String = ORDER[i]
		var rect := _slot_rect(i)
		var lit := kind == current
		var locked := (kind == "bazooka" and not owned_bazooka) or (kind == "m4a1" and not owned_m4a1)
		if lit and _pop > 0.0:
			rect = rect.grow(3.0 * _pop)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(10)
		box.bg_color = Color(0.1, 0.08, 0.04, 0.78) if lit else Color(0.02, 0.03, 0.05, 0.5)
		box.border_color = GOLD if lit else Color(1, 1, 1, 0.22)
		box.set_border_width_all(3 if lit else 1)
		draw_style_box(box, rect)
		var ink := GOLD if lit else Color(0.92, 0.92, 0.9, 0.82)
		if locked:
			ink = Color(0.7, 0.7, 0.7, 0.35)
		var empty := kind == "bazooka" and rockets <= 0
		var accent := Color(0.85, 0.2, 0.12, 0.0 if empty or locked else 1.0)
		WeaponIcons.draw(self, kind, rect.get_center() + Vector2(0, -7), 1.05 if kind != "none" else 1.0, ink, accent)
		_text(NAMES[kind], Vector2(rect.get_center().x, rect.end.y - 9), 12, ink, true)
		if show_keys:
			_text(str(i + 1), rect.position + Vector2(10, 13), 13, Color(1, 1, 1, 0.55), true)
		if kind == "bazooka":
			if locked:
				_text("$%d" % bazooka_price, rect.position + Vector2(rect.size.x - 24, 13), 12, Color(1, 0.82, 0.25, 0.7), true)
			else:
				_rocket_pips(rect)
		elif kind == "m4a1":
			var count := "$%d" % Game.M4A1_PRICE if locked else str(rounds)
			_text(count, rect.position + Vector2(rect.size.x - 24, 13), 12, GOLD, true)


## The rockets carried, as little pips along the top of the slot.
func _rocket_pips(rect: Rect2) -> void:
	var y := rect.position.y + 9.0
	var x0 := rect.end.x - 10.0 - (max_rockets - 1) * 8.0
	for k in max_rockets:
		var full := k < rockets
		var at := Vector2(x0 + k * 8.0, y)
		if full:
			draw_circle(at, 3.0, Color(0.95, 0.3, 0.15))
		else:
			draw_arc(at, 2.8, 0.0, TAU, 12, Color(1, 1, 1, 0.35), 1.0, true)


func _text(s: String, centre: Vector2, font_size: int, color: Color, centred: bool) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := centre + Vector2(-w * 0.5 if centred else 0.0, (_font.get_ascent(font_size) - _font.get_descent(font_size)) * 0.5)
	draw_string(_font, at + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, color.a * 0.7))
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
