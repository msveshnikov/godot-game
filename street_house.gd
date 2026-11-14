extends Node3D

@export var facade_color := Color(0.7, 0.55, 0.42, 1)
@export var roof_color := Color(0.24, 0.25, 0.28, 1)
@export var trim_color := Color(0.91, 0.84, 0.7, 1)
## Ground-floor flat built into a panel block: skips the roof, chimney and hidden outer walls.
@export var apartment_mode := false

const DOOR_SCRIPT: Script = preload("res://interactable_door.gd")
const COGITO_LOUNGE_CHAIR: PackedScene = preload("res://addons/cogito/DemoScenes/DemoPrefabs/lounge_chair.tscn")
const COGITO_SIDE_TABLE: PackedScene = preload("res://addons/cogito/DemoScenes/DemoPrefabs/side_table.tscn")
const COGITO_BOOKS: PackedScene = preload("res://addons/cogito/DemoScenes/DemoPrefabs/books.tscn")
const COGITO_COFFEE_MUG: PackedScene = preload("res://addons/cogito/DemoScenes/DemoPrefabs/coffee_mug.tscn")
const COGITO_BOOKCASE: PackedScene = preload("res://addons/cogito/DemoScenes/DemoPrefabs/bookcase_open.tscn")
const COGITO_RUG: PackedScene = preload("res://addons/cogito/DemoScenes/DemoPrefabs/rug_rectangle.tscn")
const COGITO_SMALL_PLANT: PackedScene = preload("res://addons/cogito/DemoScenes/DemoPrefabs/plant_small_2.tscn")
const WALL_TEXTURE: Texture2D = preload("res://textures/interior_plaster.svg")
const FACADE_TEXTURE: Texture2D = preload("res://textures/exterior_siding.svg")
const FLOOR_TEXTURE: Texture2D = preload("res://textures/wood_planks.svg")
const DOOR_TEXTURE: Texture2D = preload("res://textures/wood_door.svg")
const ROOF_TEXTURE: Texture2D = preload("res://textures/roof_shingles.svg")
const HOUSE_FRONT_Z := -3.5
const WALL_COLOR := Color(0.95, 0.93, 0.87, 1)
const FLOOR_COLOR := Color.WHITE
const WOOD_COLOR := Color(0.48, 0.27, 0.14, 1)


func _ready() -> void:
	_build_shell()
	_build_exterior_finish()
	_build_facade()
	_build_door()
	_build_room_furnishings()


func _build_shell() -> void:
	_add_box("Floor", Vector3(0, -0.085, 0), Vector3(7.5, 0.2, 6.5), FLOOR_COLOR, false, Vector3.ZERO, null, FLOOR_TEXTURE)
	_add_box("LeftWall", Vector3(-3.875, 2.8, 0), Vector3(0.25, 5.6, 7), WALL_COLOR, true, Vector3.ZERO, null, WALL_TEXTURE)
	_add_box("RightWall", Vector3(3.875, 2.8, 0), Vector3(0.25, 5.6, 7), WALL_COLOR, true, Vector3.ZERO, null, WALL_TEXTURE)
	_add_box("BackWall", Vector3(0, 2.8, 3.375), Vector3(8, 5.6, 0.25), WALL_COLOR, true, Vector3.ZERO, null, WALL_TEXTURE)
	_add_box("FrontLeft", Vector3(-2.375, 2.8, HOUSE_FRONT_Z), Vector3(3.25, 5.6, 0.25), WALL_COLOR, true, Vector3.ZERO, null, WALL_TEXTURE)
	_add_box("FrontRight", Vector3(2.375, 2.8, HOUSE_FRONT_Z), Vector3(3.25, 5.6, 0.25), WALL_COLOR, true, Vector3.ZERO, null, WALL_TEXTURE)
	_add_box("FrontHeader", Vector3(0, 4, HOUSE_FRONT_Z), Vector3(1.5, 3.2, 0.25), WALL_COLOR, true, Vector3.ZERO, null, WALL_TEXTURE)
	_add_box("Ceiling", Vector3(0, 5.55, 0), Vector3(7.5, 0.2, 6.5), WALL_COLOR, true, Vector3.ZERO, null, WALL_TEXTURE)
	if apartment_mode:
		return
	_add_box("RoofFront", Vector3(0, 6.35, -1.72), Vector3(9, 0.32, 4.3), roof_color, false, Vector3(-28, 0, 0), null, ROOF_TEXTURE)
	_add_box("RoofBack", Vector3(0, 6.35, 1.72), Vector3(9, 0.32, 4.3), roof_color, false, Vector3(28, 0, 0), null, ROOF_TEXTURE)
	_add_box("Chimney", Vector3(2.7, 6.7, 1.6), Vector3(0.75, 1.5, 0.75), trim_color)


func _build_exterior_finish() -> void:
	if not apartment_mode:
		_build_outer_side_walls()
	_add_box("ExteriorFrontLeft", Vector3(-2.375, 2.8, HOUSE_FRONT_Z - 0.14), Vector3(3.25, 5.6, 0.03), facade_color, false, Vector3.ZERO, null, FACADE_TEXTURE)
	_add_box("ExteriorFrontRight", Vector3(2.375, 2.8, HOUSE_FRONT_Z - 0.14), Vector3(3.25, 5.6, 0.03), facade_color, false, Vector3.ZERO, null, FACADE_TEXTURE)
	_add_box("ExteriorFrontHeader", Vector3(0, 4, HOUSE_FRONT_Z - 0.14), Vector3(1.5, 3.2, 0.03), facade_color, false, Vector3.ZERO, null, FACADE_TEXTURE)


func _build_outer_side_walls() -> void:
	_add_box("ExteriorLeft", Vector3(-4.015, 2.8, 0), Vector3(0.03, 5.6, 7), facade_color, false, Vector3.ZERO, null, FACADE_TEXTURE)
	_add_box("ExteriorRight", Vector3(4.015, 2.8, 0), Vector3(0.03, 5.6, 7), facade_color, false, Vector3.ZERO, null, FACADE_TEXTURE)
	_add_box("ExteriorBack", Vector3(0, 2.8, 3.515), Vector3(8, 5.6, 0.03), facade_color, false, Vector3.ZERO, null, FACADE_TEXTURE)


func _build_facade() -> void:
	_add_box("DoorHeaderTrim", Vector3(0, 2.56, HOUSE_FRONT_Z - 0.04), Vector3(1.8, 0.16, 0.2), trim_color)
	_add_box("PorchStep", Vector3(0, -0.07, -3.92), Vector3(2.2, 0.2, 0.9), trim_color)

	for window_index in range(2):
		var side := -1.0 if window_index == 0 else 1.0
		var x := side * 2.35
		_add_box("WindowFrame%d" % int(side), Vector3(x, 3.5, HOUSE_FRONT_Z - 0.13), Vector3(1.55, 1.45, 0.12), trim_color)
		_add_box("WindowGlass%d" % int(side), Vector3(x, 3.5, HOUSE_FRONT_Z - 0.2), Vector3(1.28, 1.18, 0.04), Color(0.16, 0.29, 0.38, 1))
		_add_box("WindowMullion%d" % int(side), Vector3(x, 3.5, HOUSE_FRONT_Z - 0.24), Vector3(0.07, 1.18, 0.04), trim_color)
		_add_box("WindowRail%d" % int(side), Vector3(x, 3.5, HOUSE_FRONT_Z - 0.25), Vector3(1.28, 0.07, 0.04), trim_color)


func _build_door() -> void:
	_add_box("DoorLeftJamb", Vector3(-0.86, 1.25, HOUSE_FRONT_Z - 0.08), Vector3(0.18, 2.5, 0.18), trim_color)
	_add_box("DoorRightJamb", Vector3(0.86, 1.25, HOUSE_FRONT_Z - 0.08), Vector3(0.18, 2.5, 0.18), trim_color)

	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	hinge.position = Vector3(-0.75, 0, HOUSE_FRONT_Z)
	add_child(hinge)

	var door_body := StaticBody3D.new()
	door_body.name = "Door"
	door_body.position = Vector3(0.75, 1.2, 0)
	door_body.script = DOOR_SCRIPT

	var door_shape := CollisionShape3D.new()
	var door_box := BoxShape3D.new()
	door_box.size = Vector3(1.5, 2.4, 0.12)
	door_shape.shape = door_box
	door_body.add_child(door_shape)

	var door_mesh := MeshInstance3D.new()
	door_mesh.name = "DoorMesh"
	var door_box_mesh := BoxMesh.new()
	door_box_mesh.size = door_box.size
	door_mesh.mesh = door_box_mesh
	door_mesh.material_override = _make_material(WOOD_COLOR, DOOR_TEXTURE)
	door_body.add_child(door_mesh)

	var prompt := Label3D.new()
	prompt.name = "Prompt"
	prompt.position = Vector3(0, 1.35, 0.2)
	prompt.pixel_size = 0.004
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.text = "E - OPEN"
	door_body.add_child(prompt)
	hinge.add_child(door_body)


func _build_room_furnishings() -> void:
	var ceiling_light := OmniLight3D.new()
	ceiling_light.name = "RoomLight"
	ceiling_light.position = Vector3(0, 4.8, 0)
	ceiling_light.light_color = Color(1, 0.84, 0.65, 1)
	ceiling_light.light_energy = 3.0
	ceiling_light.omni_range = 9.0
	add_child(ceiling_light)

	var light_fixture := MeshInstance3D.new()
	light_fixture.name = "LightFixture"
	light_fixture.position = Vector3(0, 5.15, 0)
	var fixture_mesh := BoxMesh.new()
	fixture_mesh.size = Vector3(0.9, 0.12, 0.4)
	light_fixture.mesh = fixture_mesh
	light_fixture.material_override = _make_material(trim_color)
	add_child(light_fixture)

	_build_cogito_furnishings()


func _build_cogito_furnishings() -> void:
	_add_cogito_prop(COGITO_LOUNGE_CHAIR, "LoungeChair", Vector3(-2.75, 0, -1.55))
	_add_cogito_prop(COGITO_SIDE_TABLE, "SideTable", Vector3(-1.7, 0, -1.75))
	_add_cogito_prop(COGITO_BOOKS, "Books", Vector3(-1.25, 0.8, -1.85), 12.0)
	_add_cogito_prop(COGITO_COFFEE_MUG, "CoffeeMug", Vector3(-0.75, 0.8, -1.9))
	_add_cogito_prop(COGITO_BOOKCASE, "Bookcase", Vector3(-1.5, 0, 2.7))
	_add_cogito_prop(COGITO_RUG, "Rug", Vector3(-1.57, 0.02, -0.65))
	_add_cogito_prop(COGITO_SMALL_PLANT, "SmallPlant", Vector3(-3.15, 0, 2.4))


func _add_cogito_prop(
	prop_scene: PackedScene,
	prop_name: String,
	prop_position: Vector3,
	yaw_degrees := 0.0
) -> void:
	var prop := prop_scene.instantiate() as Node3D
	if prop == null:
		push_error("Cogito prop '%s' must have a Node3D root." % prop_name)
		return

	prop.name = prop_name
	prop.position = prop_position
	prop.rotation_degrees.y = yaw_degrees
	add_child(prop)


func _make_material(color: Color, texture: Texture2D = null) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var tint_texture := texture == FACADE_TEXTURE or texture == ROOF_TEXTURE
	material.albedo_color = color if texture == null or texture == WALL_TEXTURE or tint_texture else Color.WHITE
	material.roughness = 0.82
	if texture != null:
		material.albedo_texture = texture
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3(0.42, 0.42, 0.42) if texture == WALL_TEXTURE else Vector3(0.48, 0.48, 0.48)
	return material


func _add_box(
	node_name: String,
	box_position: Vector3,
	box_size: Vector3,
	color: Color,
	with_collision := false,
	box_rotation := Vector3.ZERO,
	parent: Node3D = null,
	surface_texture: Texture2D = null
) -> void:
	var target_parent := self if parent == null else parent
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = box_position
	mesh_instance.rotation_degrees = box_rotation
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _make_material(color, surface_texture)
	target_parent.add_child(mesh_instance)

	if with_collision:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_size
		collision.shape = shape
		body.add_child(collision)
		body.position = box_position
		body.rotation_degrees = box_rotation
		target_parent.add_child(body)
