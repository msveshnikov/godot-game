extends CharacterBody3D

const FOAM_PELLET_SCENE: PackedScene = preload("res://foam_pellet.tscn")
const FOAM_FIRE_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Spray.ogg")
const MOBILE_CONTROLS_SCRIPT = preload("res://mobile_controls.gd")
const BAT_HIT_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Kenney/Impacts/impactPlank_medium_000.ogg")
const BAT_RANGE := 2.6
const BAT_HIT_DELAY := 0.24 # from the start of the swing to the moment the bat comes down
const BAT_COOLDOWN := 0.62
const WEAPONS := ["pistol", "bat", "none"]
const WEAPON_NAMES := {"pistol": "Foam pistol", "bat": "Baseball bat", "none": "Hands"}
const MAX_HEALTH := 100
const PLAYER_PROJECTILE_DAMAGE := 25.0
const RUN_FOOTSTEP_SOUNDS: Array[AudioStream] = [
	preload("res://addons/cogito/Assets/Audio/Kenney/Footsteps/footstep00.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Footsteps/footstep01.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Footsteps/footstep02.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Footsteps/footstep03.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Footsteps/footstep04.ogg"),
]
const WALK_FOOTSTEP_INTERVAL := 0.48
const RUN_FOOTSTEP_INTERVAL := 0.3
## Open paved spots around the estate (game x, z) where players appear, picked at
## random: the sidewalk in front of the home block's entrances (939 first), the
## yard behind it and Za Jednotou. Facing +Z looks at the home block.
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(-8.9, -12.6), Vector2(9.0, -12.6), Vector2(-26.8, -12.6),
	Vector2(26.9, -12.6), Vector2(-44.6, -12.6), Vector2(44.8, -12.6),
	Vector2(-5.0, 19.9), Vector2(35.0, 19.9), Vector2(-35.0, 19.9),
	Vector2(-15.0, 59.8), Vector2(25.0, 59.8),
]

@export var walk_speed := 4.5
@export var run_speed := 7.5
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.0025
@export var invert_mouse_y := false

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var interact_ray: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/InteractRay
@onready var model: Node3D = $MainPlayerModel # player_model_animator.gd: holds the pistol
@onready var hud: CanvasLayer = $HUD

var has_gun := true
## Held weapon: "pistol", "bat" or "none" (hands empty: people stop running away).
var weapon := "pistol"
var health := MAX_HEALTH
var _can_fire := true
var _shot_pending := false
var _aim_target := Vector3.ZERO
var _game_started := false
var _game_over := false
var _fire_sound: AudioStreamPlayer
var _footstep_sound: AudioStreamPlayer
var _footstep_timer := 0.0
var _mobile_controls: MobileControls
var _health_label: Label
var _weapon_label: Label
var _bat_sound: AudioStreamPlayer
var _start_screen: Control
var _game_over_screen: Control
var _name_edit: LineEdit


func _ready() -> void:
	add_to_group("player")
	_move_to_random_spawn()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _is_touch_device():
		_mobile_controls = MOBILE_CONTROLS_SCRIPT.new()
		add_child(_mobile_controls)
		_mobile_controls.interact_pressed.connect(_interact)
		_mobile_controls.fire_pressed.connect(_attack)
		_mobile_controls.swap_pressed.connect(func() -> void: _cycle_weapon(1))
		_mobile_controls.look_delta.connect(_apply_look_delta)
	_fire_sound = AudioStreamPlayer.new()
	_fire_sound.name = "FoamFireSound"
	_fire_sound.stream = FOAM_FIRE_SOUND
	_fire_sound.volume_db = -4.0
	add_child(_fire_sound)
	_bat_sound = AudioStreamPlayer.new()
	_bat_sound.name = "BatHitSound"
	_bat_sound.stream = BAT_HIT_SOUND
	add_child(_bat_sound)
	_footstep_sound = AudioStreamPlayer.new()
	_footstep_sound.name = "RunFootsteps"
	_footstep_sound.volume_db = -2.0
	add_child(_footstep_sound)
	_setup_game_ui()
	_update_health_ui()


## True while this player is in the world and can be targeted (not on the start or game-over screen).
func is_playing() -> bool:
	return _game_started and not _game_over


## People run away from a player holding a pistol or a bat.
func is_armed() -> bool:
	return weapon != "none"


func set_weapon(value: String) -> void:
	if not WEAPONS.has(value) or value == weapon:
		return
	weapon = value
	_shot_pending = false
	model.call("set_weapon", weapon)
	_update_weapon_ui()


func _cycle_weapon(step: int) -> void:
	set_weapon(WEAPONS[(WEAPONS.find(weapon) + step + WEAPONS.size()) % WEAPONS.size()])


func _is_touch_device() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available()


func _process(_delta: float) -> void:
	_aim_target = _get_aim_target()
	model.set("aim_point", _aim_target)
	model.set("has_aim_point", true)
	# The trigger snaps the arm up first; the foam leaves the barrel once it points at the target.
	if _shot_pending and model.call("is_gun_raised"):
		_shot_pending = false
		_launch_pellet()


func _input(event: InputEvent) -> void:
	if not _game_started or _game_over:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_attack()
			KEY_1:
				set_weapon("pistol")
			KEY_2:
				set_weapon("bat")
			KEY_3:
				set_weapon("none")
	elif _mobile_controls == null and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_attack()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_weapon(1)


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look_delta(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()


func _apply_look_delta(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	var vertical_mouse_direction := 1.0 if invert_mouse_y else -1.0
	camera_pivot.rotate_x(relative.y * mouse_sensitivity * vertical_mouse_direction)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(-60.0), deg_to_rad(35.0))


func _interact() -> void:
	if not interact_ray.is_colliding():
		return

	var target := interact_ray.get_collider()
	if not target.has_method("interact"):
		return

	target.call("interact")


## Drop the player at a random open spot in the estate, facing north into it.
## The small jitter keeps two players spawning together from standing inside each other.
func _move_to_random_spawn() -> void:
	var spot: Vector2 = SPAWN_POINTS[randi() % SPAWN_POINTS.size()]
	var jitter := Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
	global_transform = Transform3D(
		Basis(Vector3.UP, PI),
		Vector3(spot.x + jitter.x, 0.9, spot.y + jitter.y)
	)
	camera_pivot.rotation.x = deg_to_rad(-4.6)


## Fire the pistol or swing the bat, whichever is in hand.
func _attack() -> void:
	match weapon:
		"pistol":
			_fire_foam_pellet()
		"bat":
			_swing_bat()


func _swing_bat() -> void:
	if not is_playing() or not _can_fire:
		return
	_can_fire = false
	model.call("swing")
	var net_world := get_tree().current_scene.get_node_or_null("NetWorld")
	if net_world != null:
		net_world.call("broadcast_swing")
	await get_tree().create_timer(BAT_HIT_DELAY).timeout
	_bat_hit()
	await get_tree().create_timer(BAT_COOLDOWN - BAT_HIT_DELAY).timeout
	_can_fire = true


## Knock down every villager within reach in front of the player.
func _bat_hit() -> void:
	if not is_playing():
		return
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var hit_any := false
	for villager in get_tree().get_nodes_in_group("villagers"):
		var body := villager as Node3D
		if not body.call("can_be_hit"):
			continue
		var to_body := body.global_position - global_position
		to_body.y = 0.0
		if to_body.length() > BAT_RANGE:
			continue
		if to_body.length() > 0.4 and forward.dot(to_body.normalized()) < 0.45:
			continue
		body.call("receive_hit", "bat")
		hit_any = true
	if hit_any:
		_bat_sound.pitch_scale = randf_range(0.9, 1.1)
		_bat_sound.play()


func _fire_foam_pellet() -> void:
	if not _game_started or _game_over or weapon != "pistol" or not _can_fire:
		return

	_can_fire = false
	_shot_pending = true
	model.call("raise_gun")
	await get_tree().create_timer(0.25).timeout
	_can_fire = true


func _launch_pellet() -> void:
	if not is_playing():
		return
	var muzzle := model.call("get_muzzle") as Marker3D
	var pellet := FOAM_PELLET_SCENE.instantiate() as FoamPellet
	get_tree().current_scene.add_child(pellet)
	pellet.global_position = muzzle.global_position
	pellet.global_basis = muzzle.global_basis.orthonormalized()
	var shot_direction := muzzle.global_position.direction_to(_aim_target)
	pellet.launch(self, shot_direction, PLAYER_PROJECTILE_DAMAGE, &"villagers")
	var net_world := get_tree().current_scene.get_node_or_null("NetWorld")
	if net_world != null:
		net_world.call("broadcast_shot", muzzle.global_position, shot_direction)
	_fire_sound.play()


func receive_damage(amount: float) -> void:
	if not _game_started or _game_over or amount <= 0.0:
		return

	health = maxi(health - roundi(amount), 0)
	_update_health_ui()
	if health == 0:
		_end_game()


## What the screen centre points at: the first thing the camera ray hits past the player, else far away.
func _get_aim_target() -> Vector3:
	var from := camera.global_position
	var forward := -camera.global_basis.z
	var far_point := from + forward * 120.0
	var query := PhysicsRayQueryParameters3D.create(from, far_point)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or from.distance_to(hit.position) < 4.0:
		return far_point
	return hit.position


func _physics_process(delta: float) -> void:
	if not _game_started or _game_over:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_physical_key_pressed(KEY_SPACE) or (_mobile_controls != null and _mobile_controls.jump_pressed):
		velocity.y = jump_velocity

	var input_direction := Vector2.ZERO
	input_direction.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	input_direction.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	if _mobile_controls != null:
		input_direction += _mobile_controls.movement_direction
	input_direction = input_direction.limit_length(1.0)

	var direction := transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)
	direction.y = 0.0
	direction = direction.normalized()
	var is_running := Input.is_physical_key_pressed(KEY_SHIFT) or (_mobile_controls != null and _mobile_controls.run_pressed)
	var speed := run_speed if is_running else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()
	_update_footsteps(delta, input_direction.length_squared() > 0.0, is_running)


func _update_footsteps(delta: float, has_movement_input: bool, is_running: bool) -> void:
	if not has_movement_input or not is_on_floor() or Vector2(velocity.x, velocity.z).length_squared() < 0.01:
		_footstep_timer = 0.0
		return

	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return

	_footstep_sound.stream = RUN_FOOTSTEP_SOUNDS[randi_range(0, RUN_FOOTSTEP_SOUNDS.size() - 1)]
	_footstep_sound.pitch_scale = randf_range(0.94, 1.06)
	_footstep_sound.play()
	_footstep_timer = RUN_FOOTSTEP_INTERVAL if is_running else WALK_FOOTSTEP_INTERVAL


func _setup_game_ui() -> void:
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.layer = 20
	_health_label = _make_hud_label("Health: %d / %d" % [MAX_HEALTH, MAX_HEALTH], 24.0, 58.0, 22)
	_weapon_label = _make_hud_label("", 58.0, 90.0, 18)
	_update_weapon_ui()
	_start_screen = _make_game_screen(
		"GACHA VILLAGE",
		"Na Skalkách, Neratovice. The villagers carry pistols but won't shoot; they run when they see you armed.\nPlay together: open the same game on another device.\n\nWASD move  |  Shift run  |  Space jump  |  Mouse look\nQ / click: fire or swing  |  1 pistol  2 bat  3 hands (or mouse wheel)\nThe supermarket by the playground is open.",
		"START GAME",
		_start_game,
		true
	)
	_game_over_screen = _make_game_screen(
		"GAME OVER",
		"The villagers got you.",
		"RESPAWN",
		_restart_game
	)
	_game_over_screen.hide()


func _make_hud_label(label_text: String, top: float, bottom: float, font_size: int) -> Label:
	var label := Label.new()
	label.offset_left = 24.0
	label.offset_top = top
	label.offset_right = 340.0
	label.offset_bottom = bottom
	label.text = label_text
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.75, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04, 1.0))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", font_size)
	hud.add_child(label)
	return label


func _make_game_screen(title_text: String, message: String, button_text: String, action: Callable, with_name := false) -> Control:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.045, 0.065, 0.84)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 420.0 if with_name else 360.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.13, 0.16, 0.98)
	panel_style.border_color = Color(0.76, 0.57, 0.3, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 18)
	margin.add_child(contents)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.54, 1.0))
	title.add_theme_font_size_override("font_size", 36)
	contents.add_child(title)

	var description := Label.new()
	description.text = message
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_color_override("font_color", Color(0.91, 0.94, 0.91, 1.0))
	description.add_theme_font_size_override("font_size", 18)
	contents.add_child(description)

	if with_name:
		_name_edit = LineEdit.new()
		_name_edit.text = Net.player_name
		_name_edit.placeholder_text = "Your name"
		_name_edit.max_length = 16
		_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_edit.custom_minimum_size = Vector2(260.0, 44.0)
		_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_name_edit.add_theme_font_size_override("font_size", 20)
		_name_edit.text_submitted.connect(func(_text: String) -> void: _start_game())
		contents.add_child(_name_edit)

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(220.0, 52.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	contents.add_child(button)
	return overlay


func _update_weapon_ui() -> void:
	if _weapon_label != null:
		_weapon_label.text = "%s   [1] pistol  [2] bat  [3] hands" % WEAPON_NAMES[weapon]


func _update_health_ui() -> void:
	if _health_label == null:
		return
	_health_label.text = "Health: %d / %d" % [health, MAX_HEALTH]
	_health_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.94, 0.75, 1.0) if health > 30 else Color(1.0, 0.35, 0.28, 1.0)
	)


func _start_game() -> void:
	if _game_started:
		return
	_game_started = true
	if _name_edit != null:
		Net.set_player_name(_name_edit.text)
		_name_edit.release_focus()
	_start_screen.hide()
	if _mobile_controls == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _end_game() -> void:
	if _game_over:
		return
	_game_over = true
	_game_over_screen.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	velocity = Vector3.ZERO


## Back into the estate at a random spot with full health; the world (and the other players) carry on.
func _restart_game() -> void:
	_move_to_random_spawn()
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	_can_fire = true
	_shot_pending = false
	_update_health_ui()
	_game_over_screen.hide()
	_game_over = false
	if _mobile_controls == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
