extends Node3D

@export var facade_color := Color(0.7, 0.55, 0.42, 1)
@export var roof_color := Color(0.24, 0.25, 0.28, 1)
@export var trim_color := Color(0.91, 0.84, 0.7, 1)

const HOUSE_SIZE := Vector3(8, 5.6, 7)
const HOUSE_FRONT_Z := -3.55


func _ready() -> void:
	_add_box("HouseBody", Vector3(0, 2.8, 0), HOUSE_SIZE, facade_color, true)
	_add_box("FrontDoor", Vector3(0, 1.2, HOUSE_FRONT_Z), Vector3(1.5, 2.4, 0.12), roof_color)
	_add_box("DoorHeader", Vector3(0, 2.48, HOUSE_FRONT_Z), Vector3(1.8, 0.16, 0.2), trim_color)
	_add_box("PorchStep", Vector3(0, 0.1, -3.92), Vector3(2.2, 0.2, 0.9), trim_color)

	for window_index in range(2):
		var side := -1.0 if window_index == 0 else 1.0
		var x := side * 2.35
		_add_box("WindowFrame%d" % int(side), Vector3(x, 3.5, HOUSE_FRONT_Z), Vector3(1.55, 1.45, 0.16), trim_color)
		_add_box("WindowGlass%d" % int(side), Vector3(x, 3.5, HOUSE_FRONT_Z - 0.1), Vector3(1.28, 1.18, 0.05), Color(0.16, 0.29, 0.38, 1))
		_add_box("WindowMullion%d" % int(side), Vector3(x, 3.5, HOUSE_FRONT_Z - 0.14), Vector3(0.07, 1.18, 0.04), trim_color)
		_add_box("WindowRail%d" % int(side), Vector3(x, 3.5, HOUSE_FRONT_Z - 0.15), Vector3(1.28, 0.07, 0.04), trim_color)

	_add_box("RoofFront", Vector3(0, 6.35, -1.72), Vector3(9, 0.32, 4.3), roof_color, false, Vector3(-28, 0, 0))
	_add_box("RoofBack", Vector3(0, 6.35, 1.72), Vector3(9, 0.32, 4.3), roof_color, false, Vector3(28, 0, 0))
	_add_box("Chimney", Vector3(2.7, 6.7, 1.6), Vector3(0.75, 1.5, 0.75), trim_color)


func _add_box(
	node_name: String,
	box_position: Vector3,
	box_size: Vector3,
	color: Color,
	with_collision := false,
	box_rotation := Vector3.ZERO
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = box_position
	mesh_instance.rotation_degrees = box_rotation
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh_instance.material_override = material
	add_child(mesh_instance)

	if with_collision:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_size
		collision.shape = shape
		body.add_child(collision)
		body.position = box_position
		add_child(body)
