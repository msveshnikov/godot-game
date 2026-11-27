extends Control
## The main menu, the first thing the game shows: the chosen place full-screen
## behind the logo, PLAY / SHOP / SETTINGS / HOW TO PLAY (and QUIT on desktop),
## the top ten players, the player's name and cash, and a card for each place.
## PLAY puts up a loading screen and builds the
## game scene (node_2d.tscn) for the chosen place.

const GAME_SCENE := "res://node_2d.tscn"
const AMBIENCE := "res://audio/city_hum.wav"
const PODIUM_COLORS := [UiTheme.GOLD, Color(0.82, 0.87, 0.93), Color(0.91, 0.65, 0.43)]
const PLACES := {
	"nyc": "Times Square, New York: the theatre district cut out of Manhattan and set adrift as an island. LED screens on every wall, yellow cabs, the TKTS red steps.",
	"moscow": "Red Square, Moscow: a cobblestone plaza between the Kremlin wall and GUM, with St. Basil’s Cathedral and green-uniformed guards.",
	"neratovice": "Neratovice, Czechia: an autumn panel-housing estate with loggias, garages, a playground and a walk-in supermarket.",
	"omsk1": "Omsk 1, Siberia: five-storey khrushchyovkas under new red roofs, yards with playgrounds, kindergartens and a school.",
	"omsk2": "Omsk 2, Siberia: panel blocks, brick garages and wooden houses, with connected streets as far as 10th Cheredovaya Street and No. 23.",
	"paris": "Paris: the Grévin and covered passages, the Moulin Rouge windmill and the domes of Sacré-Cœur above Montmartre.",
	"dublin": "Dublin: the granite paving and shopfronts of Grafton Street, Bewley’s café, Harry Street and St Stephen’s Green.",
}

var _background: TextureRect
var _background_next: TextureRect
var _name: LineEdit
var _money: Label
var _online: Label
var _about: Label
var _cards := {}
var _leaderboard_rows: VBoxContainer
var _leaderboard_status: Label
var _leaderboard_timeout: Timer
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
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	margin.add_child(columns)
	columns.add_child(_left_column())
	columns.add_child(_leaderboard_column())
	columns.add_child(_right_column())
	resized.connect(_fit_menu.bind(margin))
	margin.minimum_size_changed.connect(_fit_menu.bind(margin))
	_fit_menu(margin)

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
	Net.location_changed.connect(_show_location)
	Net.location_access_changed.connect(_refresh_access)
	_leaderboard_timeout = Timer.new()
	_leaderboard_timeout.one_shot = true
	_leaderboard_timeout.wait_time = 4.0
	_leaderboard_timeout.timeout.connect(_leaderboard_unavailable)
	add_child(_leaderboard_timeout)
	Net.connection_changed.connect(_refresh_leaderboard)
	Net.leaderboard_received.connect(_show_leaderboard_rows)
	if Net.online:
		_refresh_leaderboard(true)
	else:
		_leaderboard_timeout.start()
	_show_location(true)
	_refresh_access()


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

func _fit_menu(margin: MarginContainer) -> void:
	var minimum := margin.get_combined_minimum_size()
	var fit := minf(1.0, minf(size.x / minimum.x, size.y / minimum.y))
	if fit > 0.0:
		margin.scale = Vector2.ONE * fit
		margin.size = size / fit


func _left_column() -> Control:
	var column := VBoxContainer.new()
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


func _leaderboard_column() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.name = "Leaderboard"
	panel.custom_minimum_size.x = 300.0
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	content.add_child(UiTheme.heading("TOP 10 PLAYERS", 24))
	_leaderboard_status = UiTheme.heading("Loading leaderboard…", 16)
	_leaderboard_status.add_theme_color_override("font_color", UiTheme.DIM)
	content.add_child(_leaderboard_status)
	_leaderboard_rows = VBoxContainer.new()
	_leaderboard_rows.add_theme_constant_override("separation", 3)
	content.add_child(_leaderboard_rows)
	return column


func _leaderboard_row(rank: String, player: String, points: String, accent: Color, fill: Color, font_size: int) -> Control:
	var row := PanelContainer.new()
	var band := StyleBoxFlat.new()
	band.bg_color = fill
	band.set_corner_radius_all(5)
	band.content_margin_left = 8.0
	band.content_margin_right = 8.0
	band.content_margin_top = 3.0
	band.content_margin_bottom = 3.0
	row.add_theme_stylebox_override("panel", band)
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 8)
	row.add_child(cells)
	var position_label := UiTheme.heading(rank, font_size)
	position_label.custom_minimum_size.x = 26.0
	position_label.add_theme_color_override("font_color", accent)
	cells.add_child(position_label)
	var player_label := Label.new()
	player_label.text = player
	player_label.add_theme_font_size_override("font_size", font_size)
	player_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cells.add_child(player_label)
	var points_label := UiTheme.heading(points, font_size)
	points_label.add_theme_color_override("font_color", accent)
	cells.add_child(points_label)
	return row


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
	card.custom_minimum_size = Vector2(262.0, 94.0)
	card.clip_contents = true
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0)
		box.set_corner_radius_all(10)
		box.border_color = UiTheme.GOLD if state.begins_with("pressed") or state == "hover_pressed" else (Color(1, 1, 1, 0.6) if state == "hover" else Color(1, 1, 1, 0.18))
		box.set_border_width_all(4 if state.contains("pressed") else 2)
		card.add_theme_stylebox_override(state, box)
	var picture := TextureRect.new()
	picture.name = "Picture"
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
	var locked := Label.new()
	locked.name = "Locked"
	locked.text = "10,000 pts"
	locked.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	locked.offset_left = -95
	locked.offset_top = 7
	locked.offset_right = -12
	locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	locked.add_theme_color_override("font_color", UiTheme.GOLD)
	locked.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.04))
	locked.add_theme_constant_override("outline_size", 8)
	locked.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(locked)
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

func _refresh_access() -> void:
	for id in _cards:
		var allowed := Net.can_visit(id)
		var card: Button = _cards[id]
		card.get_node("Locked").visible = not allowed
		card.get_node("Picture").modulate = Color.WHITE if allowed else Color(0.57, 0.57, 0.57)
	Net.restore_location()


func _select(id: String) -> void:
	_save_name()
	if not Net.set_location(id):
		(_cards[id] as Button).set_pressed_no_signal(false)
		_about.text = "%s Unlocks at 10,000 leaderboard points." % PLACES[id]
	elif id == Net.location:
		(_cards[id] as Button).set_pressed_no_signal(true)
		_about.text = PLACES[id]


## Light the selected card and fade in the picture of the current room.
func _show_location(instant := false) -> void:
	var id := Net.location
	for key in _cards:
		(_cards[key] as Button).set_pressed_no_signal(key == id)
	_about.text = PLACES.get(id, "")
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
	var controls := "Left thumb: walk, pull further to run.  Right thumb: look.\nFIRE shoots or swings, WEAPON (or a tap on the weapon slots) changes pistol / bat / hands / bazooka, JUMP jumps." if touch else \
		"WASD move  ·  Shift run  ·  Space jump  ·  Mouse look\nClick or Q: fire or swing  ·  1 pistol  2 bat  3 hands  4 bazooka (or the mouse wheel)  ·  Esc: pause"
	var text := "[b]Smash things, get paid.[/b] Dent cars with the bat, crack and smash shop windows, shoot a car to blow it up. Gold coins pop out: walk over them. Spend the cash in the SHOP on new clothes, caps and shades.\n\n" + \
		"[b]Bazooka.[/b] Buy it in the SHOP for $1000, then $100 a rocket, five at most. One rocket takes out every car around, blows the shop windows in, knocks holes in buildings (skyscrapers too) and leaves craters in the street.\n\n" + \
		"[b]Mind the heat.[/b] Every act of violence fills the heat meter; it cools down if you behave. When it tops out, a patrol car comes with two officers, and they shoot back hard. Take both down to clear the heat and grab their $150, or run far enough to lose them. Die and you drop a quarter of your cash.\n\n" + \
		"[b]Play together.[/b] Everyone who picks the same place is in the same world: you see each other, and you can shoot each other (a headshot kills).\n\n[b]Controls[/b]\n" + controls
	_menu_text("HOW TO PLAY", text)


func _refresh_leaderboard(is_online: bool) -> void:
	if not is_online or not Net.ranking_available:
		_leaderboard_timeout.stop()
		_leaderboard_unavailable()
		return
	if _leaderboard_status.visible:
		_leaderboard_status.text = "Loading leaderboard…"
		_leaderboard_timeout.start()
	Net.request_leaderboard()


func _leaderboard_unavailable() -> void:
	if _leaderboard_status.visible:
		_leaderboard_status.text = "Leaderboard unavailable"


func _show_leaderboard_rows(rows: Array) -> void:
	_leaderboard_timeout.stop()
	for child in _leaderboard_rows.get_children():
		_leaderboard_rows.remove_child(child)
		child.queue_free()
	_leaderboard_status.visible = rows.is_empty()
	if rows.is_empty():
		_leaderboard_status.text = "No scores yet"
		return
	_leaderboard_rows.add_child(_leaderboard_row("#", "PLAYER", "POINTS", UiTheme.DIM, Color.TRANSPARENT, 14))
	for index in mini(rows.size(), 10):
		var row: Dictionary = rows[index]
		var accent: Color = PODIUM_COLORS[index] if index < PODIUM_COLORS.size() else UiTheme.DIM
		var fill := Color(UiTheme.GOLD, 0.11) if index == 0 else Color(1.0, 1.0, 1.0, 0.035 if index % 2 else 0.065)
		_leaderboard_rows.add_child(_leaderboard_row(str(index + 1), row["name"], str(int(row["score"])), accent, fill, 18))


func _menu_text(title: String, text: String) -> void:
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
	column.add_child(UiTheme.heading(title, 32))
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
	if not Net.set_location(Net.location):
		_starting = false
		return
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
