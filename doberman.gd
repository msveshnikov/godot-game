extends CharacterBody3D
## Pet dog that follows the player, keeping about `follow_distance` metres away.

@export var follow_distance := 2.0
@export var max_speed := 8.0          ## a bit faster than the player's run speed
@export var acceleration := 12.0
@export var braking := 30.0
@export var turn_speed := 8.0
@export var teleport_distance := 30.0 ## catch up instantly if left far behind

var _player: Node3D
var _anim: AnimationPlayer
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
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

	_update_animation(horizontal.length())


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
