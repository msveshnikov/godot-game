extends CharacterBody3D

const FOAM_PELLET_SCENE: PackedScene = preload("res://foam_pellet.tscn")
const FOAM_FIRE_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Spray.ogg")
const MOBILE_CONTROLS_SCRIPT = preload("res://mobile_controls.gd")
const MAX_HEALTH := 100
const MAGAZINE_SIZE := 6
const RELOAD_DURATION := 1.2
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

@export var walk_speed := 4.5
@export var run_speed := 7.5
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.0025
@export var invert_mouse_y := false

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var fruit_counter: Label = $HUD/FruitCounter
@onready var gun_status: Label = $HUD/GunStatus
@onready var held_gun: Node3D = $Camera3D/HeldGunPivot
@onready var gun_muzzle: Marker3D = $Camera3D/HeldGunPivot/HeldPistol/GunMuzzle
@onready var hud: CanvasLayer = $HUD

var fruits_taken := 0
var has_gun := false
var health := MAX_HEALTH
var ammunition := MAGAZINE_SIZE
var _can_fire := true
var _reloading := false
var _game_started := false
var _game_over := false
var _fire_sound: AudioStreamPlayer
var _footstep_sound: AudioStreamPlayer
var _footstep_timer := 0.0
var _mobile_controls: MobileControls
var _health_label: Label
var _ammo_label: Label
var _start_screen: Control
var _game_over_screen: Control


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if OS.has_feature("mobile"):
		_mobile_controls = MOBILE_CONTROLS_SCRIPT.new()
		add_child(_mobile_controls)
		_mobile_controls.interact_pressed.connect(_interact)
		_mobile_controls.fire_pressed.connect(_fire_foam_pellet)
		_mobile_controls.reload_pressed.connect(_reload_gun)
		_mobile_controls.look_delta.connect(_apply_look_delta)
	_fire_sound = AudioStreamPlayer.new()
	_fire_sound.name = "FoamFireSound"
	_fire_sound.stream = FOAM_FIRE_SOUND
	_fire_sound.volume_db = -4.0
	add_child(_fire_sound)
	_footstep_sound = AudioStreamPlayer.new()
	_footstep_sound.name = "RunFootsteps"
	_footstep_sound.volume_db = -2.0
	add_child(_footstep_sound)
	_setup_game_ui()
	_update_health_ui()
	_update_ammo_ui()
	get_tree().paused = true


func _process(_delta: float) -> void:
	held_gun.look_at(_get_aim_target(), Vector3.UP)


func _input(event: InputEvent) -> void:
	if not _game_started or _game_over:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		if has_gun:
			_fire_foam_pellet()
	elif _mobile_controls == null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if has_gun:
			_fire_foam_pellet()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look_delta(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reload_gun()


func _apply_look_delta(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	var vertical_mouse_direction := 1.0 if invert_mouse_y else -1.0
	camera.rotate_x(relative.y * mouse_sensitivity * vertical_mouse_direction)
	camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))


func _interact() -> void:
	if not interact_ray.is_colliding():
		return

	var target := interact_ray.get_collider()
	if not target.has_method("interact"):
		return

	var result: Variant = target.call("interact")
	if result is String and not result.is_empty():
		if target.is_in_group("fruit_pickups"):
			fruits_taken += 1
			fruit_counter.text = "Fruit taken: %d (%s)" % [fruits_taken, result]
		elif target.is_in_group("gun_pickups") or result == "Foam pistol":
			collect_gun()
		else:
			push_warning("Interaction returned an unrecognized collectible: %s" % result)


func collect_gun() -> void:
	has_gun = true
	held_gun.visible = true
	gun_status.text = "Foam pistol: Collected (Q/click fire, R reload)"
	if _mobile_controls != null:
		_mobile_controls.set_fire_visible(true)
		_mobile_controls.set_reload_visible(true)
	_update_ammo_ui()


func _fire_foam_pellet() -> void:
	if not _game_started or _game_over or not has_gun or not _can_fire or _reloading:
		return

	if ammunition <= 0:
		_reload_gun()
		return

	_can_fire = false
	var pellet := FOAM_PELLET_SCENE.instantiate() as FoamPellet
	get_tree().current_scene.add_child(pellet)
	pellet.global_position = gun_muzzle.global_position
	pellet.global_basis = camera.global_basis
	pellet.launch(self, gun_muzzle.global_position.direction_to(_get_aim_target()), PLAYER_PROJECTILE_DAMAGE, &"villagers")
	ammunition -= 1
	_update_ammo_ui()
	_fire_sound.play()
	await get_tree().create_timer(0.25).timeout
	_can_fire = true


func _reload_gun() -> void:
	if not _game_started or _game_over or not has_gun or _reloading or ammunition == MAGAZINE_SIZE:
		return

	_reloading = true
	_update_ammo_ui()
	await get_tree().create_timer(RELOAD_DURATION).timeout
	if not is_inside_tree():
		return
	ammunition = MAGAZINE_SIZE
	_reloading = false
	_update_ammo_ui()


func receive_damage(amount: float) -> void:
	if not _game_started or _game_over or amount <= 0.0:
		return

	health = maxi(health - roundi(amount), 0)
	_update_health_ui()
	if health == 0:
		_end_game()


func _get_aim_target() -> Vector3:
	return camera.global_position - camera.global_basis.z * 50.0


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
	_health_label = _make_hud_label("Health: %d / %d" % [MAX_HEALTH, MAX_HEALTH], 96.0, 130.0, 22)
	_ammo_label = _make_hud_label("Ammo: --", 130.0, 164.0, 22)
	_start_screen = _make_game_screen(
		"GACHA VILLAGE",
		"Find the foam pistol and survive the villagers.\n\nWASD move  |  Shift run  |  Space jump\nMouse look  |  E interact  |  Q / click fire\nSix shots per magazine. Press R to reload.",
		"START GAME",
		_start_game
	)
	_game_over_screen = _make_game_screen(
		"GAME OVER",
		"The villagers got you.",
		"PLAY AGAIN",
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


func _make_game_screen(title_text: String, message: String, button_text: String, action: Callable) -> Control:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.045, 0.065, 0.84)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 360.0)
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

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(220.0, 52.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	contents.add_child(button)
	return overlay


func _update_health_ui() -> void:
	if _health_label == null:
		return
	_health_label.text = "Health: %d / %d" % [health, MAX_HEALTH]
	_health_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.94, 0.75, 1.0) if health > 30 else Color(1.0, 0.35, 0.28, 1.0)
	)


func _update_ammo_ui() -> void:
	if _ammo_label == null:
		return
	if not has_gun:
		_ammo_label.text = "Ammo: --"
	elif _reloading:
		_ammo_label.text = "Reloading..."
	else:
		_ammo_label.text = "Ammo: %d / %d" % [ammunition, MAGAZINE_SIZE]


func _start_game() -> void:
	if _game_started:
		return
	_game_started = true
	_start_screen.hide()
	get_tree().paused = false
	if _mobile_controls == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _end_game() -> void:
	if _game_over:
		return
	_game_over = true
	_game_over_screen.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
