class_name SettingsPanel
extends ColorRect
## Settings, opened from the main menu and the pause menu: graphics (a quality
## preset, render scale, shadows, fullscreen), sound (volume, city ambience) and
## controls (look sensitivity, invert Y). Every change applies at once and is
## saved by settings.gd.

var _settings: Node
var _panel: PanelContainer
var _quality_buttons := {}
var _scale_slider: HSlider
var _scale_value: Label
var _shadows: CheckButton


static func open(layer: Node, closed := Callable()) -> SettingsPanel:
	var panel := SettingsPanel.new()
	layer.add_child(panel)
	if closed.is_valid():
		panel.tree_exited.connect(closed)
	return panel


func _ready() -> void:
	_settings = get_tree().root.get_node("Settings")
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.02, 0.035, 0.05, 0.88)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_panel = PanelContainer.new()
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(UiTheme.heading("SETTINGS", 32))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 12)
	scroll.add_child(rows)

	rows.add_child(UiTheme.heading("Graphics"))
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 10)
	for entry in [["low", "Low"], ["medium", "Medium"], ["high", "High"]]:
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(120.0, 48.0)
		button.pressed.connect(_on_quality.bind(entry[0]))
		presets.add_child(button)
		_quality_buttons[entry[0]] = button
	rows.add_child(_row("Quality", presets))
	_scale_slider = _slider(50.0, 100.0, 5.0, _settings.get("render_scale") * 100.0)
	if Settings.uses_lightweight_city_rendering():
		_scale_slider.tooltip_text = "3D resolution in this city is capped at %d%%." % roundi(Settings.city_render_scale_limit() * 100.0)
	_scale_value = Label.new()
	_scale_value.custom_minimum_size = Vector2(64.0, 0.0)
	_scale_slider.value_changed.connect(func(v: float) -> void:
		_scale_value.text = "%d%%" % int(v)
		_settings.call("set_value", "render_scale", v / 100.0))
	var scale_box := HBoxContainer.new()
	scale_box.add_child(_scale_slider)
	scale_box.add_child(_scale_value)
	_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(_row("Render scale", scale_box))
	_shadows = _toggle(_settings.get("shadows"), func(on: bool) -> void: _settings.call("set_value", "shadows", on))
	rows.add_child(_row("Shadows", _shadows))
	if _settings.call("can_fullscreen"):
		rows.add_child(_row("Fullscreen", _toggle(_settings.get("fullscreen"), func(on: bool) -> void: _settings.call("set_value", "fullscreen", on))))

	rows.add_child(UiTheme.heading("Sound"))
	rows.add_child(_row("Volume", _percent_slider("volume")))
	rows.add_child(_row("City ambience", _percent_slider("ambience")))

	rows.add_child(UiTheme.heading("Controls"))
	var look := _slider(30.0, 250.0, 10.0, _settings.get("look_sensitivity") * 100.0)
	var look_value := Label.new()
	look_value.custom_minimum_size = Vector2(64.0, 0.0)
	look_value.text = "%d%%" % int(look.value)
	look.value_changed.connect(func(v: float) -> void:
		look_value.text = "%d%%" % int(v)
		_settings.call("set_value", "look_sensitivity", v / 100.0))
	var look_box := HBoxContainer.new()
	look.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	look_box.add_child(look)
	look_box.add_child(look_value)
	rows.add_child(_row("Look sensitivity", look_box))
	rows.add_child(_row("Invert look up/down", _toggle(_settings.get("invert_y"), func(on: bool) -> void: _settings.call("set_value", "invert_y", on))))

	var privacy := LinkButton.new()
	privacy.text = "Privacy Policy"
	privacy.uri = "https://maxims.top/village/privacy.html"
	privacy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(privacy)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(180.0, 52.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(queue_free)
	column.add_child(back)
	_refresh()
	UiTheme.fit(_panel, Vector2(760.0, 640.0))


func _process(_delta: float) -> void:
	UiTheme.fit(_panel, Vector2(760.0, 640.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()


func _on_quality(id: String) -> void:
	_settings.call("set_quality", id)
	_refresh()


## Buttons and sliders back in step with the settings (a preset changes several).
func _refresh() -> void:
	var quality: String = _settings.get("quality")
	for id in _quality_buttons:
		(_quality_buttons[id] as Button).set_pressed_no_signal(id == quality)
	_scale_slider.set_value_no_signal(float(_settings.get("render_scale")) * 100.0)
	_scale_value.text = "%d%%" % int(_scale_slider.value)
	_shadows.set_pressed_no_signal(bool(_settings.get("shadows")))


func _row(title: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(200.0, 0.0)
	label.add_theme_font_size_override("font_size", 19)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _slider(low: float, high: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(180.0, 36.0)
	slider.focus_mode = Control.FOCUS_NONE
	return slider


func _percent_slider(key: String) -> Control:
	var slider := _slider(0.0, 100.0, 5.0, float(_settings.get(key)) * 100.0)
	var value := Label.new()
	value.custom_minimum_size = Vector2(64.0, 0.0)
	value.text = "%d%%" % int(slider.value)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % int(v)
		_settings.call("set_value", key, v / 100.0))
	var box := HBoxContainer.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(slider)
	box.add_child(value)
	return box


func _toggle(on: bool, changed: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.button_pressed = on
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(changed)
	return toggle
