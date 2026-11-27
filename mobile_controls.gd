extends CanvasLayer
class_name MobileControls
## On-screen controls for phones and touch browsers.
## Left part of the screen: a floating stick; pull the thumb past the outer ring to run.
## Right part: drag to look. FIRE sits under the right thumb; hold it to keep firing and
## slide the thumb off it to aim while shooting. WEAPON sits above JUMP, left of FIRE.
## Buttons track their own touch index, so they work together with the stick (multi-touch).

signal swap_pressed
signal look_delta(delta: Vector2)

const STICK_R := 70.0       # ring radius, canvas px
const RUN_AT := 1.3         # finger beyond RUN_AT * STICK_R from where it landed -> run
const DEAD_ZONE := 0.12
const TEXT_COL := Color(1.0, 1.0, 1.0, 0.92)
const BUTTON_SHIFT_WIDTH_RATIO := 1.0 / 15.0

## id, offset of the centre from the bottom-right corner, radius, label
const BUTTONS := [
	{"id": "fire", "off": Vector2(-118, -128), "r": 66.0, "label": "FIRE"},
	{"id": "jump", "off": Vector2(-250, -70), "r": 38.0, "label": "JUMP"},
	{"id": "swap", "off": Vector2(-250, -192), "r": 42.0, "label": "WEAPON"},
]

var movement_direction := Vector2.ZERO
var run_pressed := false
var jump_pressed := false
var fire_held := false
## The weapon in hand ("pistol", "bat", "bazooka", "none"), drawn on the WEAPON button.
var weapon := "pistol"
var loaded := true

var _pad: Control
var _font: Font
var _stick_idx := -1
var _stick_origin := Vector2.ZERO
var _stick_finger := Vector2.ZERO
var _look_idx := -1
var _look_idle := 10.0      # seconds since the look finger last moved
var _held := {}             # touch index -> button id


func _ready() -> void:
	layer = 10
	_font = ThemeDB.fallback_font
	_pad = Control.new()
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	visibility_changed.connect(func() -> void:
		if not visible:
			release_all())


## True while a finger is turning the camera (or did so a moment ago), so the
## automatic camera keeps its hands off.
func is_looking(grace := 0.45) -> bool:
	return _look_idle < grace


func _process(delta: float) -> void:
	_look_idle += delta
	_pad.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_finger_down(event.index, event.position)
		else:
			_finger_up(event.index)
	elif event is InputEventScreenDrag:
		_finger_drag(event.index, event.position, event.relative)


func _center(b: Dictionary) -> Vector2:
	return _pad.size + (b["off"] as Vector2) - Vector2(_pad.size.x * BUTTON_SHIFT_WIDTH_RATIO, 0.0)


func _button_at(p: Vector2) -> String:
	for b in BUTTONS:
		if p.distance_to(_center(b)) <= float(b["r"]) * 1.2:
			return b["id"]
	return ""


func _finger_down(idx: int, p: Vector2) -> void:
	var id := _button_at(p)
	if id != "":
		_held[idx] = id
		match id:
			"fire":
				fire_held = true
				# The firing thumb also aims: slide it and the camera follows.
				if _look_idx < 0:
					_look_idx = idx
					_look_idle = 10.0
			"jump":
				jump_pressed = true
			"swap":
				swap_pressed.emit()
		return
	if p.x < _pad.size.x * 0.45 and p.y > 110.0:
		if _stick_idx < 0:
			_stick_idx = idx
			_stick_origin = p
			_stick_finger = p
			_apply_stick()
	elif _look_idx < 0:
		_look_idx = idx
		_look_idle = 10.0


func _finger_up(idx: int) -> void:
	if _held.has(idx):
		var id: String = _held[idx]
		_held.erase(idx)
		if id == "fire":
			fire_held = _held.values().has("fire")
		elif id == "jump":
			jump_pressed = _held.values().has("jump")
	if idx == _stick_idx:
		_stick_idx = -1
		_apply_stick()
	if idx == _look_idx:
		_look_idx = -1


func _finger_drag(idx: int, p: Vector2, rel: Vector2) -> void:
	if idx == _stick_idx:
		_stick_finger = p
		_apply_stick()
	elif idx == _look_idx:
		_look_idle = 0.0
		look_delta.emit(rel)


func _apply_stick() -> void:
	var v := Vector2.ZERO
	run_pressed = false
	if _stick_idx >= 0:
		var d := _stick_finger - _stick_origin
		var max_d := STICK_R * RUN_AT * 1.25
		if d.length() > max_d:
			# Drag the origin along so the thumb never runs out of room.
			_stick_origin = _stick_finger - d.normalized() * max_d
			d = _stick_finger - _stick_origin
		run_pressed = d.length() > STICK_R * RUN_AT
		v = (d / STICK_R).limit_length(1.0)
		if v.length() < DEAD_ZONE:
			v = Vector2.ZERO
	movement_direction = v


func release_all() -> void:
	_held.clear()
	_stick_idx = -1
	_look_idx = -1
	fire_held = false
	jump_pressed = false
	_apply_stick()


# ---------------------------------------------------------------- drawing
func _draw_pad() -> void:
	var active := _stick_idx >= 0
	var o := _stick_origin if active else Vector2(170.0, _pad.size.y - 160.0)
	var run_col := Color(1.0, 0.8, 0.35, 0.85)
	_pad.draw_circle(o, STICK_R, Color(0.08, 0.08, 0.08, 0.32 if active else 0.18))
	_pad.draw_arc(o, STICK_R, 0.0, TAU, 48, run_col if run_pressed else Color(1, 1, 1, 0.5 if active else 0.28), 3.0, true)
	if active:
		_pad.draw_arc(o, STICK_R * RUN_AT, 0.0, TAU, 48, Color(run_col, 0.85 if run_pressed else 0.3), 2.0, true)
	var knob := o
	if active:
		knob = o + (_stick_finger - _stick_origin).limit_length(STICK_R)
	_pad.draw_circle(knob, 30.0, Color(0.92, 0.92, 0.92, 0.6 if active else 0.3))
	if active and run_pressed:
		_text("RUN", o + Vector2(0, -STICK_R * RUN_AT - 18), 18, Color(run_col, 0.95))

	for b in BUTTONS:
		var c := _center(b)
		var r: float = b["r"]
		var down: bool = _held.values().has(b["id"])
		var fire: bool = b["id"] == "fire"
		var bg := Color(0.5, 0.1, 0.06, 0.62 if down else 0.4) if fire else Color(0.08, 0.08, 0.08, 0.66 if down else 0.42)
		var edge := Color(1, 1, 1, 0.9 if down else 0.55)
		_pad.draw_circle(c, r, bg)
		_pad.draw_arc(c, r, 0.0, TAU, 56, edge, 3.0 if fire else 2.0, true)
		if b["id"] == "swap":
			WeaponIcons.draw(_pad, weapon, c + Vector2(0, -9), 0.95, Color(1, 1, 1, 0.92), Color(0.9, 0.25, 0.15, 1.0 if loaded else 0.0))
			_text(b["label"], c + Vector2(0, 19), 12, TEXT_COL)
			continue
		_text(b["label"], c, 24 if fire else 15, TEXT_COL)


func _text(s: String, center: Vector2, size: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := center + Vector2(-w * 0.5, (_font.get_ascent(size) - _font.get_descent(size)) * 0.5)
	_pad.draw_string(_font, pos + Vector2(1, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * 0.6))
	_pad.draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
