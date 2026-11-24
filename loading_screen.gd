class_name LoadingScreen
extends CanvasLayer
## Full-screen "Loading Times Square..." with the place's picture and a progress
## bar. Sits on the tree's root, so it outlives the menu scene and covers the
## frames where the game scene builds its place; world.gd calls finish() once the
## game is running.

var _label: Label
var _bar: ProgressBar


static func show_for(tree: SceneTree, place: String, picture: Texture2D) -> LoadingScreen:
	var old := tree.root.get_node_or_null("LoadingScreen")
	if old != null:
		old.free()
	var screen := LoadingScreen.new()
	screen.name = "LoadingScreen"
	screen.layer = 100
	tree.root.add_child(screen)
	screen._build(place, picture)
	return screen


## Take it down (from world.gd), fading out.
static func finish_on(tree: SceneTree) -> void:
	var screen := tree.root.get_node_or_null("LoadingScreen")
	if screen != null:
		screen.call("finish")


func _build(place: String, picture: Texture2D) -> void:
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.05, 0.07)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var image := TextureRect.new()
	image.texture = picture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.modulate = Color(0.55, 0.55, 0.6)
	root.add_child(image)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -300.0
	box.offset_right = 300.0
	box.offset_top = -150.0
	box.offset_bottom = -60.0
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)
	_label = Label.new()
	_label.text = "Loading %s..." % place
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", UiTheme.GOLD)
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	_label.add_theme_constant_override("outline_size", 10)
	box.add_child(_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0.0, 14.0)
	_bar.max_value = 1.0
	_bar.show_percentage = false
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	back.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.GOLD
	fill.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("background", back)
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)


func set_progress(value: float) -> void:
	if _bar != null:
		create_tween().tween_property(_bar, "value", clampf(value, 0.0, 1.0), 0.2)


func set_text(text: String) -> void:
	if _label != null:
		_label.text = text


func finish() -> void:
	set_progress(1.0)
	var root := get_child(0) as Control
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_property(root, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
