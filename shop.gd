class_name Shop
extends ColorRect
## The shop, opened from the start and game-over screens: spend the money smashed
## up in the world (game_state.gd) on the character's looks. The character turns
## slowly on the left; every item is a button on the right: bought ones are put on
## at once, ones you can't afford yet are tried on so you can see them.

const MODEL_SCENE: PackedScene = preload("res://main_player.glb")
const MODEL_ANIMATOR = preload("res://player_model_animator.gd")
const PREVIEW_BODY = preload("res://preview_body.gd")
const PURCHASE_SOUND: AudioStream = preload("res://audio/purchase.wav")
const GOLD := Color(1.0, 0.82, 0.25)

var _game: Node
var _panel: PanelContainer
var _money: Label
var _note: Label
var _items: VBoxContainer
var _turntable: Node3D
var _model: Node3D
var _try_on := {}
var _sound: AudioStreamPlayer


## Open the shop on top of `layer`; `closed` runs when it is shut.
static func open(layer: CanvasLayer, closed := Callable()) -> Shop:
	var shop := Shop.new()
	layer.add_child(shop)
	if closed.is_valid():
		shop.tree_exited.connect(closed)
	return shop


func _ready() -> void:
	_game = get_tree().root.get_node("Game")
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.02, 0.035, 0.05, 0.9)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sound = AudioStreamPlayer.new()
	_sound.stream = PURCHASE_SOUND
	_sound.volume_db = -6.0
	add_child(_sound)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.13, 0.16, 0.98)
	style.border_color = Color(0.76, 0.57, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	margin.add_child(columns)

	columns.add_child(_build_preview())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	var head := HBoxContainer.new()
	right.add_child(head)
	var title := Label.new()
	title.text = "SHOP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.54))
	head.add_child(title)
	_money = Label.new()
	_money.add_theme_font_size_override("font_size", 28)
	_money.add_theme_color_override("font_color", GOLD)
	head.add_child(_money)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_items = VBoxContainer.new()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items.add_theme_constant_override("separation", 6)
	scroll.add_child(_items)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	right.add_child(bottom)
	_note = Label.new()
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 16)
	_note.add_theme_color_override("font_color", Color(0.85, 0.88, 0.85))
	_note.text = "Smash cars and shop windows for cash."
	bottom.add_child(_note)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(160.0, 52.0)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(queue_free)
	bottom.add_child(back)

	_game.connect("money_changed", _on_money)
	_refresh()
	_fit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()


func _process(delta: float) -> void:
	_fit()
	if _turntable != null:
		_turntable.rotation.y += delta * 0.6


## Panel as large as the screen allows, up to 1000 x 620.
func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var gap := 10.0
	var size_now := Vector2(minf(view.x - 2.0 * gap, 1000.0), minf(view.y - 2.0 * gap, 620.0))
	var at := (view - size_now) * 0.5
	if _panel.position != at or _panel.size != size_now:
		_panel.position = at
		_panel.size = size_now


## The character on a turntable, in a little world of its own.
func _build_preview() -> Control:
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.custom_minimum_size = Vector2(260.0, 0.0)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	frame.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(150.0), 0.0)
	sun.light_energy = 1.3
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 32.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.2, -4.2), Vector3(0.0, 0.98, 0.0))
	_turntable = PREVIEW_BODY.new()
	_turntable.rotation.y = 0.5
	viewport.add_child(_turntable)
	_model = MODEL_SCENE.instantiate() as Node3D
	_model.set_script(MODEL_ANIMATOR)
	_model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	_turntable.add_child(_model)
	_model.call("set_weapon", "none")
	return frame


func _refresh() -> void:
	_on_money(int(_game.get("money")))
	for child in _items.get_children():
		child.free()
	var look: Dictionary = (_game.get("look") as Dictionary).duplicate()
	for slot in _const("SLOTS"):
		var heading := Label.new()
		heading.text = str(_const("SLOT_NAMES")[slot])
		heading.add_theme_font_size_override("font_size", 18)
		heading.add_theme_color_override("font_color", Color(1.0, 0.86, 0.54))
		_items.add_child(heading)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		_items.add_child(row)
		for entry in _const("ITEMS")[slot]:
			var id: String = entry["id"]
			if not _game.call("is_available", slot, id):
				continue
			row.add_child(_item_button(slot, entry, look[slot] == id))
	var shown := look.duplicate()
	for slot in _try_on:
		shown[slot] = _try_on[slot]
	_model.call("apply_look", shown)


func _item_button(slot: String, entry: Dictionary, worn: bool) -> Button:
	var id: String = entry["id"]
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(118.0, 50.0)
	button.add_theme_font_size_override("font_size", 16)
	var owned: bool = _game.call("is_owned", slot, id)
	var price := int(entry["price"])
	if worn:
		button.text = "%s\nWORN" % entry["name"]
	elif owned:
		button.text = "%s\nOWNED" % entry["name"]
	else:
		button.text = "%s\n$%d" % [entry["name"], price]
	if worn:
		var lit := StyleBoxFlat.new()
		lit.bg_color = Color(0.76, 0.57, 0.3)
		lit.set_corner_radius_all(8)
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, lit)
		button.add_theme_color_override("font_color", Color(0.08, 0.1, 0.12))
		button.add_theme_color_override("font_hover_color", Color(0.08, 0.1, 0.12))
	elif not owned and price > int(_game.get("money")):
		button.add_theme_color_override("font_color", Color(0.7, 0.62, 0.55))
	var swatch: Variant = _game.call("item_color", slot, id)
	if swatch is Color:
		var dot := ColorRect.new()
		dot.color = swatch
		dot.custom_minimum_size = Vector2(10.0, 10.0)
		dot.position = Vector2(6.0, 6.0)
		dot.size = Vector2(10.0, 10.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(dot)
	button.pressed.connect(_on_item.bind(slot, id))
	return button


func _on_item(slot: String, id: String) -> void:
	var owned: bool = _game.call("is_owned", slot, id)
	var price := int((_game.call("item", slot, id) as Dictionary).get("price", 0))
	if _game.call("buy_or_wear", slot, id):
		_try_on.erase(slot)
		if not owned:
			_sound.play()
			_note.text = "Bought it!"
		else:
			_note.text = ""
	else:
		_try_on[slot] = id
		_note.text = "Trying it on: $%d more to buy it." % (price - int(_game.get("money")))
	_refresh()


func _const(name: String) -> Variant:
	return (_game.get_script() as Script).get_script_constant_map()[name]


func _on_money(value: int) -> void:
	_money.text = "$ %d" % value
