extends CharacterBody3D
## Pet dog that follows the player, keeping about `follow_distance` metres away.

@export var follow_distance := 2.0
@export var max_speed := 8.0          ## a bit faster than the player's run speed
@export var acceleration := 12.0
@export var braking := 30.0
@export var turn_speed := 8.0
@export var teleport_distance := 30.0 ## catch up instantly if left far behind

const BARK_SOUNDS: Array[AudioStream] = [
	preload("res://doberman_bark_1.wav"),
	preload("res://doberman_bark_2.wav"),
	preload("res://doberman_bark_3.wav"),
	preload("res://doberman_bark_4.wav"),
]

@export var idle_bark_interval := Vector2(6.0, 15.0)  ## random seconds between barks while resting
@export var run_bark_interval := Vector2(2.5, 6.0)    ## barks more often while chasing
@export var bark_on_chase_chance := 0.5              ## chance to bark when the player runs off

var _player: Node3D
var _anim: AnimationPlayer
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bark_player: AudioStreamPlayer3D
var _bark_timer := 0.0
var _was_running := false


func _ready() -> void:
	_bark_player = AudioStreamPlayer3D.new()
	_bark_player.position = Vector3(0.0, 0.85, 0.0)
	_bark_player.unit_size = 6.0
	_bark_player.volume_db = -2.0
	add_child(_bark_player)
	_bark_timer = randf_range(2.0, idle_bark_interval.x)

	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for anim_name in ["Idle", "Run"]:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_anim.play("Idle")


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist > teleport_distance:
		var back := _player.global_transform.basis.z.normalized()
		global_position = _player.global_position + back * follow_distance
		global_position.y = _player.global_position.y
		velocity = Vector3.ZERO
		return

	# Desired speed grows with how far beyond the follow distance we are.
	var target_speed := 0.0
	if dist > follow_distance:
		target_speed = clampf((dist - follow_distance) * 6.0, 0.0, max_speed)
		if target_speed < 0.6:
			target_speed = 0.0

	var dir := to_player / dist if dist > 0.001 else Vector3.ZERO
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var desired := dir * target_speed
	var rate := acceleration if desired.length() > horizontal.length() else braking
	horizontal = horizontal.move_toward(desired, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	# Face the player (when moving, face the movement direction).
	var face_dir := horizontal if horizontal.length() > 0.3 else to_player
	if face_dir.length() > 0.05:
		var target_yaw := atan2(-face_dir.x, -face_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

	var speed := horizontal.length()
	_update_animation(speed)
	_update_barking(delta, speed > 0.5)


func _update_barking(delta: float, running: bool) -> void:
	if running and not _was_running and randf() < bark_on_chase_chance:
		bark()
	_was_running = running

	_bark_timer -= delta
	if _bark_timer <= 0.0:
		bark()


func bark() -> void:
	var interval := run_bark_interval if _was_running else idle_bark_interval
	_bark_timer = randf_range(interval.x, interval.y)
	if _bark_player.playing:
		return
	_bark_player.stream = BARK_SOUNDS.pick_random()
	_bark_player.pitch_scale = randf_range(0.92, 1.08)
	_bark_player.play()


func _update_animation(speed: float) -> void:
	if _anim == null:
		return
	if speed > 0.5:
		if _anim.current_animation != "Run":
			_anim.play("Run", 0.2)
		_anim.speed_scale = clampf(speed / 6.0, 0.6, 1.4)
	else:
		if _anim.current_animation != "Idle":
			_anim.play("Idle", 0.3)
		_anim.speed_scale = 1.0
