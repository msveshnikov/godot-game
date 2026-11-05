extends CharacterBody3D

const FOAM_PELLET_SCENE: PackedScene = preload("res://foam_pellet.tscn")
const FOAM_FIRE_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Spray.ogg")

@export var walk_speed := 4.5
@export var run_speed := 7.5
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.0025

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var fruit_counter: Label = $HUD/FruitCounter
@onready var gun_status: Label = $HUD/GunStatus
@onready var gun_muzzle: Marker3D = $Camera3D/GunMuzzle

var fruits_taken := 0
var has_gun := false
var _can_fire := true
var _fire_sound: AudioStreamPlayer


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_fire_sound = AudioStreamPlayer.new()
	_fire_sound.name = "FoamFireSound"
	_fire_sound.stream = FOAM_FIRE_SOUND
	_fire_sound.volume_db = -4.0
	add_child(_fire_sound)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		if has_gun:
			_fire_foam_pellet()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if has_gun:
			_fire_foam_pellet()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if interact_ray.is_colliding():
			var target := interact_ray.get_collider()
			if target.has_method("interact"):
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
	gun_status.text = "Foam pistol: Collected (Q/click to fire)"


func _fire_foam_pellet() -> void:
	if not _can_fire:
		return

	_can_fire = false
	var pellet := FOAM_PELLET_SCENE.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(pellet)
	pellet.add_collision_exception_with(self)
	pellet.global_position = gun_muzzle.global_position
	pellet.global_basis = camera.global_basis
	pellet.linear_velocity = -camera.global_basis.z * 18.0
	_fire_sound.play()
	await get_tree().create_timer(0.25).timeout
	_can_fire = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity

	var input_direction := Vector2.ZERO
	input_direction.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	input_direction.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	input_direction = input_direction.normalized()

	var direction := transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)
	direction.y = 0.0
	direction = direction.normalized()
	var speed := run_speed if Input.is_physical_key_pressed(KEY_SHIFT) else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()
