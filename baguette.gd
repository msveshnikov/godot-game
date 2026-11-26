extends RefCounted
## One shared mesh, carried in a paper sleeve by the Paris crowd.

static var _loaf: ArrayMesh


static func attach(skeleton: Skeleton3D, under_arm: bool) -> void:
	if skeleton == null:
		return
	var bone := skeleton.find_bone("DEF-spine.002" if under_arm else "DEF-hand.R")
	if bone < 0:
		return
	var rest := skeleton.get_bone_global_rest(bone)
	var grip := BoneAttachment3D.new()
	grip.name = "BaguetteGrip"
	grip.bone_idx = bone
	skeleton.add_child(grip)
	var model := MeshInstance3D.new()
	model.name = "Baguette"
	if _loaf == null:
		_loaf = _bake()
	model.mesh = _loaf
	var axis := Vector3(-0.06, 0.36, 0.93) if under_arm else Vector3(-0.16, 0.88, 0.44)
	var centre := Vector3(-0.245, 1.16, 0.065) if under_arm else rest.origin + rest.basis.y * 0.068 + Vector3.LEFT * 0.018
	model.transform = rest.affine_inverse() * Transform3D(Basis(Quaternion(Vector3.UP, axis.normalized())), centre)
	grip.add_child(model)


static func _bake() -> ArrayMesh:
	const ROWS := 40
	const SIDES := 12
	var points := PackedVector3Array()
	var colours := PackedColorArray()
	for row in ROWS + 1:
		var u := float(row) / ROWS
		for side in SIDES:
			var theta := float(side) * TAU / SIDES
			var slash := absf(fposmod(u * 4.0 - sin(theta) * 0.21, 1.0) - 0.49)
			var crumb := (1.0 - smoothstep(0.015, 0.14, slash)) * smoothstep(0.12, 0.75, cos(theta))
			var radius := 0.048 * pow(maxf(0.015, sin(u * PI)), 0.35) * (1.0 - crumb * 0.15)
			points.append(Vector3(cos(theta) * radius, (u - 0.5) * 0.67, sin(theta) * radius * 0.84))
			var crust := Color(0.60, 0.28, 0.087).lerp(Color(0.93, 0.66, 0.31), absf(sin(row * 2.77 + side * 1.71)) * 0.62)
			var colour := crust.lerp(Color(0.95, 0.80, 0.47), crumb)
			if u < 0.39:
				colour = Color(0.75, 0.62, 0.44).lightened(0.07 * absf(sin(theta * 3.0)))
			colours.append(colour)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in ROWS:
		for side in SIDES:
			var a := row * SIDES + side
			var b := row * SIDES + (side + 1) % SIDES
			for i in [a, a + SIDES, b, b, a + SIDES, b + SIDES]:
				surface.set_color(colours[i])
				surface.set_normal(Vector3(points[i].x, points[i].y * 0.045, points[i].z).normalized())
				surface.add_vertex(points[i])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.87
	surface.set_material(material)
	return surface.commit()
