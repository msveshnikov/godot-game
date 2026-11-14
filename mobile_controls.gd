extends CanvasLayer
class_name MobileControls

signal interact_pressed
signal fire_pressed
signal look_delta(delta: Vector2)

const STICK_RADIUS := 72.0
const BUTTON_SIZE := Vector2(92.0, 68.0)

class JoystickVisual extends Control:
	var knob_offset := Vector2.ZERO

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.46
		draw_circle(center, radius, Color(0.08, 0.08, 0.08, 0.38))
		draw_arc(center, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.48), 2.0)
		draw_circle(center + knob_offset, radius * 0.43, Color(0.9, 0.9, 0.9, 0.58))

var movement_direction := Vector2.ZERO
var jump_pressed := false
var run_pressed := false
var _root: Control
var _stick: JoystickVisual
var _buttons: Array[Button] = []
var _fire_button: Button
var _stick_touch := -1
var _look_touch := -1


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_stick = JoystickVisual.new()
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stick)

	var interact_button := _make_button("E")
	interact_button.pressed.connect(func() -> void: interact_pressed.emit())
	var jump_button := _make_button("JUMP")
	jump_button.button_down.connect(func() -> void: jump_pressed = true)
	jump_button.button_up.connect(func() -> void: jump_pressed = false)
	var run_button := _make_button("RUN")
	run_button.button_down.connect(func() -> void: run_pressed = true)
	run_button.button_up.connect(func() -> void: run_pressed = false)
	_fire_button = _make_button("FIRE")
	_fire_button.pressed.connect(func() -> void: fire_pressed.emit())

	_root.resized.connect(_layout_controls)
	_layout_controls()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_touch(event.index, event.position)
		else:
			_end_touch(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _stick_touch:
			_update_stick(event.position)
		elif event.index == _look_touch:
			look_delta.emit(event.relative)


func _make_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.08, 0.08, 0.55)
	normal.set_corner_radius_all(18)
	button.add_theme_stylebox_override("normal", normal)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.28, 0.28, 0.28, 0.78)
	pressed.set_corner_radius_all(18)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", normal)
	_root.add_child(button)
	_buttons.append(button)
	return button


func _layout_controls() -> void:
	if _root == null or _stick == null:
		return

	var screen_size := _root.size
	var radius := minf(STICK_RADIUS, minf(screen_size.x * 0.12, screen_size.y * 0.18))
	var stick_center := Vector2(screen_size.x * 0.2, screen_size.y * 0.79)
	_stick.position = stick_center - Vector2.ONE * radius
	_stick.size = Vector2.ONE * radius * 2.0
	_stick.queue_redraw()

	var button_centers := [
		Vector2(screen_size.x * 0.88, screen_size.y * 0.79),
		Vector2(screen_size.x * 0.72, screen_size.y * 0.79),
		Vector2(screen_size.x * 0.72, screen_size.y * 0.59),
		Vector2(screen_size.x * 0.88, screen_size.y * 0.59),
		Vector2(screen_size.x * 0.88, screen_size.y * 0.39),
	]
	for index in _buttons.size():
		_buttons[index].size = BUTTON_SIZE
		_buttons[index].position = button_centers[index] - BUTTON_SIZE * 0.5


func _begin_touch(index: int, position: Vector2) -> void:
	if _point_over_button(position):
		return

	if _stick_touch == -1 and _is_in_stick_area(position):
		_stick_touch = index
		_update_stick(position)
	elif _look_touch == -1 and position.x >= _root.size.x * 0.48:
		_look_touch = index


func _end_touch(index: int) -> void:
	if index == _stick_touch:
		_stick_touch = -1
		movement_direction = Vector2.ZERO
		_stick.knob_offset = Vector2.ZERO
		_stick.queue_redraw()
	elif index == _look_touch:
		_look_touch = -1


func _is_in_stick_area(position: Vector2) -> bool:
	var center := _stick.position + _stick.size * 0.5
	return position.distance_to(center) <= _stick.size.x * 0.7


func _update_stick(position: Vector2) -> void:
	var center := _stick.position + _stick.size * 0.5
	var offset := position - center
	var radius := _stick.size.x * 0.46
	_stick.knob_offset = offset.limit_length(radius)
	movement_direction = (_stick.knob_offset / radius).limit_length(1.0)
	_stick.queue_redraw()


func _point_over_button(position: Vector2) -> bool:
	for button in _buttons:
		if button.visible and button.get_global_rect().has_point(position):
			return true
	return false
