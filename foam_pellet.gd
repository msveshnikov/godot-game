extends RigidBody3D
class_name FoamPellet

var _damage := 0.0
var _target_group: StringName


func launch(
	shooter: PhysicsBody3D,
	direction: Vector3,
	damage: float,
	target_group: StringName,
	speed: float = 18.0
) -> void:
	_damage = damage
	_target_group = target_group
	add_collision_exception_with(shooter)
	linear_velocity = direction.normalized() * speed

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(5.0).timeout.connect(queue_free)


func _on_body_entered(body: Node) -> void:
	if not _target_group.is_empty() and body.is_in_group(_target_group):
		if _target_group == &"villagers" and body.has_method("receive_hit"):
			body.call("receive_hit")
		elif _target_group == &"player" and body.has_method("receive_damage"):
			body.call("receive_damage", _damage)
	queue_free()
