extends Control
## The main menu, the first thing the game shows: the chosen place full-screen
## behind the logo, PLAY / SHOP / SETTINGS / HOW TO PLAY (and QUIT on desktop),
## the player's name and cash, and a card for each place with how many people
## are playing there right now. PLAY puts up a loading screen and builds the
## game scene (node_2d.tscn) for the chosen place.

const GAME_SCENE := "res://node_2d.tscn"
const AMBIENCE := "res://audio/city_hum.wav"
const PLACES := {
	"nyc": "Times Square, New York: the theatre district cut out of Manhattan and set adrift as an island. LED screens on every wall, yellow cabs, the TKTS red steps.",
	"neratovice": "Neratovice, Czechia: an autumn panel-housing estate with loggias, garages, a playground and a walk-in supermarket.",
	"omsk1": "Omsk 1, Siberia: five-storey khrushchyovkas under new red roofs, yards with playgrounds, kindergartens and a school.",
	"omsk2": "Omsk 2, Siberia: a 100 m nine-storey slab, rows of brick garages, a gas station and the old wooden private sector.",
}

var _background: TextureRect
var _background_next: TextureRect
var _name: LineEdit
var _money: Label
var _online: Label
var _about: Label
var _cards := {}
var _layer: CanvasLayer
var _starting := false


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.05, 0.07)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_background = _picture()
	_background_next = _picture()
	_background_next.modulate.a = 0.0
	_shade()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	margin.add_child(columns)
	columns.add_child(_left_column())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(spacer)
	columns.add_child(_right_column())

	var version := Label.new()
	version.text = "v%s  ·  maxims.top/village" % ProjectSettings.get_setting("application/config/version", "2026.11")
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -360.0
	version.offset_top = -26.0
	version.offset_right = -14.0
	version.offset_bottom = -6.0
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)

	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)

	var hum := AudioStreamPlayer.new()
	hum.stream = _looping_wav(AMBIENCE)
	hum.volume_db = -20.0
	hum.bus = &"Ambience"
	hum.autoplay = true
	add_child(hum)

	Game.money_changed.connect(func(value: int) -> void: _money.text = "$ %d" % value)
	_select(Net.location, true)


func _process(_delta: float) -> void:
	if Net.online:
		var others := Net.player_count() - 1
		_online.text = "●  Online  ·  %s" % ("nobody else here yet" if others == 0 else "%d other player%s here" % [others, "" if others == 1 else "s"])
		_online.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	else:
		_online.text = "●  Connecting..."
		_online.add_theme_color_override("font_color", Color(1.0, 0.7, 0.45))


## Android's back button: close whatever is open over the menu, else leave the game.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or not is_inside_tree():
		return
	if _layer.get_child_count() > 0:
		for child in _layer.get_children():
			child.queue_free()
	else:
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if _layer.get_child_count() == 0 and not _name.has_focus():
			_play()


# ---------------------------------------------------------------- layout ----

func _left_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(360.0, 0.0)
	column.add_theme_constant_override("separation", 12)
	var logo := Label.new()
	logo.text = "SMASH\nATLAS"
	logo.add_theme_font_size_override("font_size", 76)
	logo.add_theme_constant_override("line_spacing", -22)
	logo.add_theme_color_override("font_color", UiTheme.GOLD)
	logo.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02))
	logo.add_theme_constant_override("outline_size", 14)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	logo.add_theme_constant_override("shadow_offset_x", 4)
	logo.add_theme_constant_override("shadow_offset_y", 5)
	column.add_child(logo)
	var tagline := Label.new()
	tagline.text = "Real streets. Real chaos."
	tagline.add_theme_font_size_override("font_size", 20)
	tagline.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	tagline.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	tagline.add_theme_constant_override("outline_size", 6)
	column.add_child(tagline)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	var play := _menu_button("PLAY", _play, 74.0)
	play.theme_type_variation = &"PrimaryButton"
	play.add_theme_font_size_override("font_size", 34)
	column.add_child(play)
	column.add_child(_menu_button("SHOP", func() -> void: Shop.open(_layer)))
	column.add_child(_menu_button("SETTINGS", func() -> void: SettingsPanel.open(_layer)))
	column.add_child(_menu_button("HOW TO PLAY", _how_to_play))
	if not (OS.has_feature("web") or OS.has_feature("mobile")):
		column.add_child(_menu_button("QUIT", func() -> void: get_tree().quit()))
	var bottom_gap := Control.new()
	bottom_gap.custom_minimum_size = Vector2(0.0, 6.0)
	column.add_child(bottom_gap)
	return column


func _menu_button(text: String, action: Callable, height := 52.0) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(320.0, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if height < 60.0 else HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	return button


func _right_column() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(536.0, 0.0)

	# Who's playing: name, cash, who else is online.
	var card := PanelContainer.new()
	column.add_child(card)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	card.add_child(inside)
	var top := HBoxContainer.new()
	inside.add_child(top)
	var who := UiTheme.heading("PLAYER", 18)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	_money = Label.new()
	_money.text = "$ %d" % Game.money
	_money.add_theme_font_size_override("font_size", 24)
	_money.add_theme_color_override("font_color", UiTheme.GOLD)
	top.add_child(_money)
	_name = LineEdit.new()
	_name.text = Net.player_name
	_name.placeholder_text = "Your name"
	_name.max_length = 16
	_name.custom_minimum_size = Vector2(0.0, 48.0)
	_name.text_submitted.connect(func(_t: String) -> void:
		_save_name()
		_name.release_focus())
	_name.focus_exited.connect(_save_name)
	inside.add_child(_name)
	_online = Label.new()
	_online.add_theme_font_size_override("font_size", 15)
	inside.add_child(_online)

	# Where.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var heading := UiTheme.heading("CHOOSE A PLACE", 18)
	heading.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	heading.add_theme_constant_override("outline_size", 6)
	column.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for entry in Net.LOCATIONS:
		grid.add_child(_place_card(entry["id"], entry["name"]))
	_about = Label.new()
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.custom_minimum_size = Vector2(0.0, 44.0)
	_about.add_theme_font_size_override("font_size", 15)
	_about.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_about.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_about.add_theme_constant_override("outline_size", 5)
	column.add_child(_about)
	return column


## A place to pick: its picture with the name on a band across the bottom.
func _place_card(id: String, title: String) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(262.0, 120.0)
	card.clip_contents = true
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0)
		box.set_corner_radius_all(10)
		box.border_color = UiTheme.GOLD if state.begins_with("pressed") or state == "hover_pressed" else (Color(1, 1, 1, 0.6) if state == "hover" else Color(1, 1, 1, 0.18))
		box.set_border_width_all(4 if state.contains("pressed") else 2)
		card.add_theme_stylebox_override(state, box)
	var picture := TextureRect.new()
	picture.texture = load("res://assets/ui/place_%s.webp" % id)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Inset, so the button's border (gold when picked) shows round the picture.
	picture.offset_left = 4.0
	picture.offset_top = 4.0
	picture.offset_right = -4.0
	picture.offset_bottom = -4.0
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(picture)
	card.move_child(picture, 0)
	var band := ColorRect.new()
	band.color = Color(0.02, 0.03, 0.04, 0.72)
	band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -38.0
	band.offset_left = 4.0
	band.offset_right = -4.0
	band.offset_bottom = -4.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(band)
	var label := Label.new()
	label.text = title
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 12.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	band.add_child(label)
	card.pressed.connect(_select.bind(id))
	_cards[id] = card
	return card


func _picture() -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	return picture


## Dark on the left behind the logo and buttons, and along the bottom.
func _shade() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.03, 0.05, 0.88))
	gradient.set_color(1, Color(0.02, 0.03, 0.05, 0.05))
	gradient.add_point(0.45, Color(0.02, 0.03, 0.05, 0.45))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	var left := TextureRect.new()
	left.texture = texture
	left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	var low := Gradient.new()
	low.set_color(0, Color(0.02, 0.03, 0.05, 0.0))
	low.set_color(1, Color(0.02, 0.03, 0.05, 0.75))
	var bottom_texture := GradientTexture2D.new()
	bottom_texture.gradient = low
	bottom_texture.fill_from = Vector2(0.5, 0.45)
	bottom_texture.fill_to = Vector2(0.5, 1.0)
	var bottom := TextureRect.new()
	bottom.texture = bottom_texture
	bottom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)


# --------------------------------------------------------------- actions ----

## Pick a place: its card lit, its picture fading in behind, its room joined.
func _select(id: String, instant := false) -> void:
	for key in _cards:
		(_cards[key] as Button).set_pressed_no_signal(key == id)
	_about.text = PLACES.get(id, "")
	if id != Net.location:
		Net.set_location(id)
	var texture := load("res://assets/ui/place_%s.webp" % id) as Texture2D
	if instant:
		_background.texture = texture
		_drift(_background)
		return
	# The new picture goes on top of the old one and fades in over it.
	_background_next.texture = texture
	_background_next.modulate.a = 0.0
	move_child(_background_next, maxi(_background.get_index(), _background_next.get_index()))
	_drift(_background_next)
	var incoming := _background_next
	_background_next = _background
	_background = incoming
	create_tween().tween_property(incoming, "modulate:a", 1.0, 0.45)


## A slow push in on the picture, like a title sequence.
func _drift(picture: TextureRect) -> void:
	picture.pivot_offset = get_viewport_rect().size * 0.5
	picture.scale = Vector2.ONE * 1.02
	var tween := picture.create_tween().set_loops()
	tween.tween_property(picture, "scale", Vector2.ONE * 1.1, 18.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(picture, "scale", Vector2.ONE * 1.02, 18.0).set_trans(Tween.TRANS_SINE)


static func _looping_wav(path: String) -> AudioStream:
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		return null
	stream = stream.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


func _save_name() -> void:
	Net.set_player_name(_name.text)
	_name.text = Net.player_name


func _how_to_play() -> void:
	var touch := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	var controls := "Left thumb: walk, pull further to run.  Right thumb: look.\nFIRE shoots or swings, SWAP changes pistol / bat / hands, JUMP jumps." if touch else \
		"WASD move  ·  Shift run  ·  Space jump  ·  Mouse look\nClick or Q: fire or swing  ·  1 pistol  2 bat  3 hands (or the mouse wheel)  ·  Esc: pause"
	var text := "[b]Smash things, get paid.[/b] Dent cars with the bat, crack and smash shop windows, shoot a car to blow it up. Gold coins pop out: walk over them. Spend the cash in the SHOP on new clothes, caps and shades.\n\n" + \
		"[b]Mind the heat.[/b] Every act of violence fills the heat meter; it cools down if you behave. When it tops out, a patrol car comes with two officers, and they shoot back hard. Take both down to clear the heat and grab their $150, or run far enough to lose them. Die and you drop a quarter of your cash.\n\n" + \
		"[b]Play together.[/b] Everyone who picks the same place is in the same world: you see each other, and you can shoot each other (a headshot kills).\n\n[b]Controls[/b]\n" + controls
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.035, 0.05, 0.88)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.theme = UiTheme.get_theme() # a CanvasLayer doesn't pass the menu's theme on
	_layer.add_child(overlay)
	var panel := PanelContainer.new()
	overlay.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(UiTheme.heading("HOW TO PLAY", 32))
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.text = text
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 18)
	body.add_theme_font_size_override("bold_font_size", 19)
	body.add_theme_color_override("default_color", UiTheme.TEXT)
	column.add_child(body)
	var back := Button.new()
	back.text = "GOT IT"
	back.custom_minimum_size = Vector2(180.0, 52.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(overlay.queue_free)
	column.add_child(back)
	var fit := func() -> void: UiTheme.fit(panel, Vector2(820.0, 600.0))
	fit.call()
	get_tree().process_frame.connect(fit)
	overlay.tree_exiting.connect(func() -> void: get_tree().process_frame.disconnect(fit))


## Loading screen over everything, then the game scene for the chosen place. The
## loading screen lives on the root, so it stays up while the place is built and
## world.gd takes it down once the game is running.
func _play() -> void:
	if _starting:
		return
	_starting = true
	_save_name()
	var loading := LoadingScreen.show_for(get_tree(), Net.location_name(), load("res://assets/ui/place_%s.webp" % Net.location) as Texture2D)
	ResourceLoader.load_threaded_request(GAME_SCENE)
	while true:
		var progress := []
		var status := ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Could not load the game scene")
			_starting = false
			loading.call("finish")
			return
		if not progress.is_empty():
			loading.call("set_progress", float(progress[0]) * 0.5)
		await get_tree().process_frame
	loading.call("set_progress", 0.55)
	loading.call("set_text", "Building %s..." % Net.location_name())
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene)
