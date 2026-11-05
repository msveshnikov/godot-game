extends "res://addons/cogito/CogitoNPC/cogito_npc.gd"

@export var walk_points: Array[Vector3] = []
@export var pause_at_waypoint := 1.5

var _waypoint_index := 0
var _pause_remaining := 0.0
var _route_parent: Node3D


func _ready() -> void:
	super._ready()
	_route_parent = get_parent() as Node3D
	if _route_parent == null:
		push_error("Villager walk route requires a Node3D parent.")
		return

	if walk_points.size() > 1 and global_position.distance_to(_route_parent.to_global(walk_points[0])) < 0.8:
		_waypoint_index = 1


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if walk_points.size() < 2:
		return

	if _pause_remaining > 0.0:
		_pause_remaining = maxf(_pause_remaining - delta, 0.0)
		_stop_horizontal_motion(delta)
		move_and_slide()
		return

	var target_position := _route_parent.to_global(walk_points[_waypoint_index])
	var direction := target_position - global_position
	direction.y = 0.0

	if direction.length() < 0.7:
		_waypoint_index = (_waypoint_index + 1) % walk_points.size()
		_pause_remaining = pause_at_waypoint
		_stop_horizontal_motion(delta)
		move_and_slide()
		return

	direction = direction.normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	face_direction(global_position + direction)
	move_and_slide()


func _stop_horizontal_motion(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, walk_speed * delta)
	velocity.z = move_toward(velocity.z, 0.0, walk_speed * delta)
