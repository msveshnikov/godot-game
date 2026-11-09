extends "res://addons/cogito/CogitoNPC/cogito_npc.gd"

const FOAM_PELLET_SCENE: PackedScene = preload("res://foam_pellet.tscn")
const FOAM_PISTOL_SCENE: PackedScene = preload("res://foam_pistol_model.tscn")
const FOAM_FIRE_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Spray.ogg")

@export var walk_points: Array[Vector3] = []
@export var pause_at_waypoint := 1.5
@export var firing_range := 50.0
@export var fire_interval := 2.2
@export var respawn_delay := 6.0

var _waypoint_index := 0
var _pause_remaining := 0.0
var _route_parent: Node3D
var _attack_timer := 1.0
var _alive := true
var _spawn_transform: Transform3D
var _spawn_collision_layer := 0
var _spawn_collision_mask := 0
var _spawn_process_mode: Node.ProcessMode
var _fire_sound: AudioStreamPlayer3D


func _ready() -> void:
	super._ready()
	add_to_group("villagers")
	_route_parent = get_parent() as Node3D
	if _route_parent == null:
		push_error("Villager walk route requires a Node3D parent.")
		return

	_spawn_transform = global_transform
	_spawn_collision_layer = collision_layer
	_spawn_collision_mask = collision_mask
	_spawn_process_mode = process_mode
	var pistol := FOAM_PISTOL_SCENE.instantiate() as Node3D
	pistol.name = "VillagerFoamPistol"
	pistol.scale = Vector3.ONE * 0.65
	pistol.rotation.y = -PI / 2.0
	hand_slot.add_child(pistol)
	_fire_sound = AudioStreamPlayer3D.new()
	_fire_sound.stream = FOAM_FIRE_SOUND
	_fire_sound.volume_db = -8.0
	add_child(_fire_sound)

	if walk_points.size() > 1 and global_position.distance_to(_route_parent.to_global(walk_points[0])) < 0.8:
		_waypoint_index = 1


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _alive:
		return

	if walk_points.size() < 2:
		_update_attack(delta)
		return

	if _pause_remaining > 0.0:
		_pause_remaining = maxf(_pause_remaining - delta, 0.0)
		_stop_horizontal_motion(delta)
		move_and_slide()
		_update_attack(delta)
		return

	var target_position := _route_parent.to_global(walk_points[_waypoint_index])
	var direction := target_position - global_position
	direction.y = 0.0

	if direction.length() < 0.7:
		_waypoint_index = (_waypoint_index + 1) % walk_points.size()
		_pause_remaining = pause_at_waypoint
		_stop_horizontal_motion(delta)
		move_and_slide()
		_update_attack(delta)
		return

	direction = direction.normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	face_direction(global_position + direction)
	move_and_slide()
	_update_attack(delta)


func _stop_horizontal_motion(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, walk_speed * delta)
	velocity.z = move_toward(velocity.z, 0.0, walk_speed * delta)


func _update_attack(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return

	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or global_position.distance_to(player.global_position) > firing_range:
		return

	_attack_timer = fire_interval
	face_direction(player.global_position)
	var muzzle_position := global_position + Vector3.UP * 1.3
	var target_position := player.global_position + Vector3.UP * 0.45
	var pellet := FOAM_PELLET_SCENE.instantiate() as FoamPellet
	get_tree().current_scene.add_child(pellet)
	pellet.global_position = muzzle_position
	pellet.launch(self, muzzle_position.direction_to(target_position), 18.0, &"player", 26.0)
	_fire_sound.play()


func receive_hit() -> void:
	if not _alive:
		return

	_alive = false
	visible = false
	_fire_sound.stop()
	collision_layer = 0
	collision_mask = 0
	process_mode = Node.PROCESS_MODE_DISABLED
	_set_collision_shapes_disabled(true)
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return

	global_transform = _spawn_transform
	_waypoint_index = 0
	_pause_remaining = pause_at_waypoint
	_attack_timer = 1.0
	collision_layer = _spawn_collision_layer
	collision_mask = _spawn_collision_mask
	_set_collision_shapes_disabled(false)
	visible = true
	_alive = true
	process_mode = _spawn_process_mode


func _set_collision_shapes_disabled(disabled: bool) -> void:
	for collision_shape in find_children("", "CollisionShape3D", true, false):
		(collision_shape as CollisionShape3D).set_deferred("disabled", disabled)
