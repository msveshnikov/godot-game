extends RigidBody3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(5.0).timeout.connect(queue_free)


func _on_body_entered(_body: Node) -> void:
	queue_free()
