extends Node3D

@export var facade_color := Color(0.7, 0.55, 0.42, 1)
@export var roof_color := Color(0.24, 0.25, 0.28, 1)
@export var trim_color := Color(0.91, 0.84, 0.7, 1)

const DOOR_SCRIPT: Script = preload("res://interactable_door.gd")
const FRUIT_SCRIPT: Script = preload("res://fruit_pickup.gd")
const GUN_SCRIPT: Script = preload("res://locker_gun.gd")
const PISTOL_MODEL_SCENE: PackedScene = preload("res://foam_pistol_model.tscn")
const LOCKER_SCRIPT: Script = preload("res://interactable_locker.gd")
const WALL_TEXTURE: Texture2D = preload("res://textures/stone_blocks.svg")
const FLOOR_TEXTURE: Texture2D = preload("res://textures/wood_planks.svg")
const WOOD_TEXTURE: Texture2D = preload("res://textures/wood_planks.svg")
const ROOF_TEXTURE: Texture2D = preload("res://textures/wood_planks.svg")
const HOUSE_FRONT_Z := -3.5
const WALL_COLOR := Color(0.72, 0.68, 0.58, 1)
const FLOOR_COLOR := Color(0.28, 0.39, 0.35, 1)
const WOOD_COLOR := Color(0.48, 0.27, 0.14, 1)
const TRIM_WOOD_COLOR := Color(0.55, 0.34, 0.18, 1)
const BANANA_COLOR := Color(1, 0.79, 0.16, 1)
const BANANA_TIP_COLOR := Color(0.34, 0.2, 0.08, 1)
func _ready() -> void:
	_build_shell()
	_build_facade()
	_build_door()
	_build_room_furnishings()


func _build_shell() -> void:
	_add_box("Floor", Vector3(0, 0.1, 0), Vector3(7.5, 0.2, 6.5), FLOOR_COLOR, true, Vector3.ZERO, null, FLOOR_TEXTURE)
	_add_box("LeftWall", Vector3(-3.875, 2.8, 0), Vector3(0.25, 5.6, 7), WALL_COLOR, true, Vector3.ZERO, null, WALL_TEXTURE)
	_add_box("RightWall", Vector3(3.875, 2.8, 0), Vector3(0.25, 5.6, 7), WALL_COLOR, true, Vector3.ZERO, null, WALL_TEXTURE)
	_add_box("BackWall", Vector3(0, 2.8, 3.375), Vector3(8, 5.6, 0.25), WALL_COLOR, true, Vector3.ZERO, null, WALL_TEXTURE)
	_add_box("FrontLeft", Vector3(-2.375, 2.8, HOUSE_FRONT_Z), Vector3(3.25, 5.6, 0.25), facade_color, true, Vector3.ZERO, null, WALL_TEXTURE)
	_add_box("FrontRight", Vector3(2.375, 2.8, HOUSE_FRONT_Z), Vector3(3.25, 5.6, 0.25), facade_color, true, Vector3.ZERO, null, WALL_TEXTURE)
	_add_box("FrontHeader", Vector3(0, 4, HOUSE_FRONT_Z), Vector3(1.5, 3.2, 0.25), facade_color, true, Vector3.ZERO, null, WALL_TEXTURE)
	_add_box("Ceiling", Vector3(0, 5.55, 0), Vector3(7.5, 0.2, 6.5), WALL_COLOR, true, Vector3.ZERO, null, FLOOR_TEXTURE)
	_add_box("RoofFront", Vector3(0, 6.35, -1.72), Vector3(9, 0.32, 4.3), roof_color, false, Vector3(-28, 0, 0), null, ROOF_TEXTURE)
	_add_box("RoofBack", Vector3(0, 6.35, 1.72), Vector3(9, 0.32, 4.3), roof_color, false, Vector3(28, 0, 0), null, ROOF_TEXTURE)
	_add_box("Chimney", Vector3(2.7, 6.7, 1.6), Vector3(0.75, 1.5, 0.75), trim_color)


func _build_facade() -> void:
	_add_box("DoorHeaderTrim", Vector3(0, 2.56, HOUSE_FRONT_Z - 0.04), Vector3(1.8, 0.16, 0.2), trim_color)
	_add_box("PorchStep", Vector3(0, 0.1, -3.92), Vector3(2.2, 0.2, 0.9), trim_color, true)

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
	door_mesh.material_override = _make_material(roof_color, WOOD_TEXTURE)
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
	_add_box("TableTop", Vector3(-1.25, 1.15, 0.7), Vector3(2.6, 0.18, 1.6), WOOD_COLOR, true, Vector3.ZERO, null, WOOD_TEXTURE)
	for x in [-2.32, -0.18]:
		for z in [0.1, 1.3]:
			_add_box("TableLeg", Vector3(x, 0.58, z), Vector3(0.14, 1.15, 0.14), WOOD_COLOR, false, Vector3.ZERO, null, WOOD_TEXTURE)

	_add_fruit("Apple", Vector3(-1.65, 1.42, 0.55), Color(0.75, 0.12, 0.09, 1))
	_add_fruit("Orange", Vector3(-1.05, 1.42, 0.48), Color(0.95, 0.42, 0.08, 1))
	_add_fruit("Pear", Vector3(-1.35, 1.42, 0.92), Color(0.48, 0.68, 0.19, 1))
	_add_banana(Vector3(-0.75, 1.35, 0.9))

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

	var lamp_base := MeshInstance3D.new()
	lamp_base.name = "TableLampBase"
	lamp_base.position = Vector3(-2.0, 1.28, 0.72)
	var lamp_base_mesh := CylinderMesh.new()
	lamp_base_mesh.top_radius = 0.2
	lamp_base_mesh.bottom_radius = 0.25
	lamp_base_mesh.height = 0.12
	lamp_base.mesh = lamp_base_mesh
	lamp_base.material_override = _make_material(trim_color)
	add_child(lamp_base)

	var lamp_light := OmniLight3D.new()
	lamp_light.name = "TableLampLight"
	lamp_light.position = Vector3(-2.0, 2.0, 0.72)
	lamp_light.light_color = Color(1, 0.71, 0.37, 1)
	lamp_light.light_energy = 0.7
	lamp_light.omni_range = 4.0
	add_child(lamp_light)

	_build_wardrobe()


func _build_wardrobe() -> void:
	var wardrobe := Node3D.new()
	wardrobe.name = "Wardrobe"
	wardrobe.position = Vector3(2.45, 0, 2.35)
	wardrobe.rotation_degrees.y = 180
	add_child(wardrobe)

	var wardrobe_body := StaticBody3D.new()
	wardrobe_body.name = "WardrobeBody"
	wardrobe.add_child(wardrobe_body)
	var wardrobe_shape := CollisionShape3D.new()
	var wardrobe_box := BoxShape3D.new()
	wardrobe_box.size = Vector3(1.8, 3.1, 1.2)
	wardrobe_shape.shape = wardrobe_box
	wardrobe_shape.position = Vector3(0, 1.55, 0)
	wardrobe_body.add_child(wardrobe_shape)

	var wardrobe_mesh := MeshInstance3D.new()
	wardrobe_mesh.name = "WardrobeMesh"
	var wardrobe_box_mesh := BoxMesh.new()
	wardrobe_box_mesh.size = wardrobe_box.size
	wardrobe_mesh.mesh = wardrobe_box_mesh
	wardrobe_mesh.position = wardrobe_shape.position
	wardrobe_mesh.material_override = _make_material(WOOD_COLOR, WOOD_TEXTURE)
	wardrobe.add_child(wardrobe_mesh)

	var drawer := StaticBody3D.new()
	drawer.name = "LockerDrawer"
	drawer.position = Vector3(0, 0.95, 0.67)
	drawer.script = LOCKER_SCRIPT

	var drawer_shape := CollisionShape3D.new()
	var drawer_box := BoxShape3D.new()
	drawer_box.size = Vector3(1.65, 0.52, 0.16)
	drawer_shape.shape = drawer_box
	drawer.add_child(drawer_shape)

	var drawer_mesh := MeshInstance3D.new()
	drawer_mesh.name = "DrawerMesh"
	var drawer_box_mesh := BoxMesh.new()
	drawer_box_mesh.size = drawer_box.size
	drawer_mesh.mesh = drawer_box_mesh
	drawer_mesh.material_override = _make_material(TRIM_WOOD_COLOR, WOOD_TEXTURE)
	drawer.add_child(drawer_mesh)

	var handle := MeshInstance3D.new()
	handle.name = "Handle"
	handle.position = Vector3(0, 0, 0.12)
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.42, 0.08, 0.08)
	handle.mesh = handle_mesh
	handle.material_override = _make_material(Color(0.68, 0.62, 0.46, 1))
	drawer.add_child(handle)

	var drawer_prompt := Label3D.new()
	drawer_prompt.name = "Prompt"
	drawer_prompt.position = Vector3(0, 0.42, 0.12)
	drawer_prompt.pixel_size = 0.004
	drawer_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	drawer_prompt.text = "E - PULL"
	drawer.add_child(drawer_prompt)

	var pistol := Area3D.new()
	pistol.name = "FoamPistol"
	pistol.position = Vector3(0, 0.34, 0.2)
	pistol.scale = Vector3.ONE * 0.65
	pistol.visible = false
	pistol.script = GUN_SCRIPT
	pistol.add_to_group("gun_pickups")
	drawer.add_child(pistol)

	var pistol_model := PISTOL_MODEL_SCENE.instantiate() as Node3D
	pistol.add_child(pistol_model)

	var pistol_shape := CollisionShape3D.new()
	var pistol_box := BoxShape3D.new()
	pistol_box.size = Vector3(0.68, 0.4, 0.28)
	pistol_shape.shape = pistol_box
	pistol.add_child(pistol_shape)

	var pistol_prompt := Label3D.new()
	pistol_prompt.name = "Prompt"
	pistol_prompt.position = Vector3(0, 0.34, 0)
	pistol_prompt.pixel_size = 0.004
	pistol_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pistol_prompt.text = "E - TAKE FOAM PISTOL"
	pistol.add_child(pistol_prompt)

	wardrobe.add_child(drawer)


func _add_fruit(fruit_name: String, fruit_position: Vector3, color: Color) -> void:
	var fruit := Area3D.new()
	fruit.name = fruit_name
	fruit.position = fruit_position
	fruit.script = FRUIT_SCRIPT
	fruit.add_to_group("fruit_pickups")
	add_child(fruit)

	var fruit_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.24
	fruit_shape.shape = sphere_shape
	fruit.add_child(fruit_shape)

	var fruit_mesh := MeshInstance3D.new()
	fruit_mesh.name = "Mesh"
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.24
	sphere_mesh.height = 0.48
	fruit_mesh.mesh = sphere_mesh
	fruit_mesh.material_override = _make_material(color)
	fruit.add_child(fruit_mesh)


func _add_banana(banana_position: Vector3) -> void:
	var banana := Area3D.new()
	banana.name = "Banana"
	banana.position = banana_position
	banana.script = FRUIT_SCRIPT
	banana.add_to_group("fruit_pickups")
	add_child(banana)

	var collision := CollisionShape3D.new()
	collision.position.y = 0.05
	var collision_shape := SphereShape3D.new()
	collision_shape.radius = 0.24
	collision.shape = collision_shape
	banana.add_child(collision)

	var segment_mesh := CapsuleMesh.new()
	segment_mesh.radius = 0.065
	segment_mesh.height = 0.3
	segment_mesh.radial_segments = 12
	segment_mesh.rings = 4
	for segment_index in range(5):
		var segment := MeshInstance3D.new()
		segment.name = "CurveSegment%d" % segment_index
		segment.position = Vector3(-0.2 + segment_index * 0.1, 0.13 if segment_index in [0, 4] else 0.045, 0)
		segment.rotation_degrees.z = 54 + segment_index * 18
		segment.mesh = segment_mesh
		segment.material_override = _make_material(BANANA_COLOR)
		banana.add_child(segment)

	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.055
	tip_mesh.height = 0.11
	for tip_index in range(2):
		var tip := MeshInstance3D.new()
		tip.name = "Tip%d" % tip_index
		tip.position = Vector3(-0.29 if tip_index == 0 else 0.29, 0.24, 0)
		tip.mesh = tip_mesh
		tip.material_override = _make_material(BANANA_TIP_COLOR)
		banana.add_child(tip)


func _make_material(color: Color, texture: Texture2D = null) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color if texture == null or texture == WALL_TEXTURE else Color.WHITE
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
