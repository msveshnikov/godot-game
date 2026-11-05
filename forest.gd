extends Node3D

const TREE_COUNT := 180
const MIN_TREE_SPACING := 4.5


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42719

	var positions: Array[Vector2] = []
	var scales: Array[float] = []
	var foliage_colors: Array[Color] = []
	var trunk_colors: Array[Color] = []
	var attempts := 0

	while positions.size() < TREE_COUNT and attempts < TREE_COUNT * 40:
		attempts += 1
		var x := rng.randf_range(-88.0, 88.0)
		var z := rng.randf_range(-85.0, 85.0)
		if absf(x) < 36.0 and z > -20.0 and z < 44.0:
			continue

		var candidate := Vector2(x, z)
		var too_close := false
		for existing_position in positions:
			if candidate.distance_squared_to(existing_position) < MIN_TREE_SPACING * MIN_TREE_SPACING:
				too_close = true
				break
		if too_close:
			continue

		positions.append(candidate)
		scales.append(rng.randf_range(0.8, 1.25))
		foliage_colors.append(Color.from_hsv(
			rng.randf_range(0.25, 0.36),
			rng.randf_range(0.42, 0.62),
			rng.randf_range(0.3, 0.46)
		))
		trunk_colors.append(Color(0.3, 0.19, 0.11))

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.2
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 4.4
	trunk_mesh.radial_segments = 7
	trunk_mesh.material = _make_vertex_color_material()

	var foliage_mesh := CylinderMesh.new()
	foliage_mesh.top_radius = 0.0
	foliage_mesh.bottom_radius = 1.0
	foliage_mesh.height = 2.0
	foliage_mesh.radial_segments = 7
	foliage_mesh.material = _make_vertex_color_material()

	_add_tree_part(trunk_mesh, positions, scales, trunk_colors, Vector3.ONE, 2.2)
	_add_tree_part(foliage_mesh, positions, scales, foliage_colors, Vector3(2.1, 1.65, 2.1), 3.35)
	_add_tree_part(foliage_mesh, positions, scales, foliage_colors, Vector3(1.55, 1.55, 1.55), 4.55)


func _make_vertex_color_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	return material


func _add_tree_part(
	mesh: Mesh,
	positions: Array[Vector2],
	scales: Array[float],
	colors: Array[Color],
	part_scale: Vector3,
	height_offset: float
) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()

	for index in positions.size():
		var tree_scale := scales[index]
		var instance_basis := Basis().scaled(part_scale * tree_scale)
		var position := positions[index]
		var instance_position := Vector3(position.x, height_offset * tree_scale, position.y)
		multimesh.set_instance_transform(index, Transform3D(instance_basis, instance_position))
		multimesh.set_instance_color(index, colors[index])

	var forest_part := MultiMeshInstance3D.new()
	forest_part.multimesh = multimesh
	add_child(forest_part)
