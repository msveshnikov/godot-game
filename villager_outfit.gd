extends RefCounted
## Gives each villager bot its own look (skin, hair, T-shirt, shorts or jeans,
## shoes) on the shared Cogito mannequin. The outfit is picked from the bot's
## index, so every client dresses the same bot the same way without syncing.

const CLOTHES_SHADER: Shader = preload("res://villager_clothes.gdshader")

const SKIN := [
	Color(0.96, 0.8, 0.69), Color(0.91, 0.72, 0.58), Color(0.82, 0.6, 0.45),
	Color(0.67, 0.47, 0.33), Color(0.48, 0.32, 0.22), Color(0.36, 0.24, 0.17),
]
const HAIR := [
	Color(0.08, 0.06, 0.05), Color(0.25, 0.15, 0.08), Color(0.45, 0.28, 0.13),
	Color(0.85, 0.7, 0.42), Color(0.62, 0.25, 0.1), Color(0.6, 0.6, 0.6),
]
const SHIRTS := [
	Color(0.85, 0.15, 0.15), Color(0.15, 0.45, 0.85), Color(0.95, 0.8, 0.15),
	Color(0.2, 0.65, 0.3), Color(0.95, 0.95, 0.93), Color(0.12, 0.12, 0.14),
	Color(0.95, 0.5, 0.15), Color(0.55, 0.3, 0.75), Color(0.95, 0.55, 0.7),
	Color(0.1, 0.65, 0.7),
]
const TROUSERS := [
	Color(0.18, 0.27, 0.45), Color(0.28, 0.38, 0.55), Color(0.12, 0.12, 0.14),
	Color(0.62, 0.55, 0.4), Color(0.35, 0.36, 0.33),
]
const SHORTS := [
	Color(0.62, 0.55, 0.4), Color(0.2, 0.3, 0.5), Color(0.25, 0.4, 0.25),
	Color(0.85, 0.3, 0.2), Color(0.15, 0.15, 0.18),
]
const SHOES := [
	Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.1), Color(0.4, 0.25, 0.15),
	Color(0.8, 0.15, 0.15), Color(0.2, 0.35, 0.7),
]

static var _dressed_mesh: ArrayMesh


static func apply(npc: Node, index: int) -> void:
	var mannequin := npc.get_node_or_null("Rig/Skeleton3D/Mannequin") as MeshInstance3D
	if mannequin == null:
		push_error("Villager outfit: mannequin mesh not found.")
		return
	if _dressed_mesh == null:
		_dressed_mesh = _with_rest_positions(mannequin.mesh as ArrayMesh)
	mannequin.mesh = _dressed_mesh

	var rng := RandomNumberGenerator.new()
	rng.seed = 90210 + index * 7477
	var material := ShaderMaterial.new()
	material.shader = CLOTHES_SHADER
	material.set_shader_parameter("skin_color", _pick(SKIN, rng))
	material.set_shader_parameter("hair_color", _pick(HAIR, rng))
	var shirt: Color = SHIRTS[index % SHIRTS.size()]
	material.set_shader_parameter("shirt_color", shirt)
	var striped := rng.randf() < 0.3
	material.set_shader_parameter("stripes", 1.0 if striped else 0.0)
	material.set_shader_parameter("stripe_color", Color(0.95, 0.95, 0.93) if shirt.get_luminance() < 0.7 else Color(0.15, 0.25, 0.55))
	var shorts := rng.randf() < 0.55
	material.set_shader_parameter("hem_height", rng.randf_range(0.56, 0.66) if shorts else 0.125)
	material.set_shader_parameter("pants_color", _pick(SHORTS if shorts else TROUSERS, rng))
	material.set_shader_parameter("denim", 0.0 if shorts else 1.0)
	material.set_shader_parameter("sleeve_end", 0.68 if rng.randf() < 0.25 else rng.randf_range(0.28, 0.36))
	material.set_shader_parameter("long_hair", 1.0 if rng.randf() < 0.4 else 0.0)
	material.set_shader_parameter("shoe_color", _pick(SHOES, rng))
	for surface in _dressed_mesh.get_surface_count():
		mannequin.set_surface_override_material(surface, material)


static func _pick(options: Array, rng: RandomNumberGenerator) -> Color:
	return options[rng.randi() % options.size()]


## Copy of the mannequin mesh with each vertex's rest (T-pose) position in CUSTOM0,
## which the clothes shader uses to decide what is skin, shirt, trousers, etc.
static func _with_rest_positions(source: ArrayMesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var custom := PackedFloat32Array()
		custom.resize(vertices.size() * 4)
		for i in vertices.size():
			custom[i * 4] = vertices[i].x
			custom[i * 4 + 1] = vertices[i].y
			custom[i * 4 + 2] = vertices[i].z
			custom[i * 4 + 3] = 0.0
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		mesh.surface_set_material(surface, source.surface_get_material(surface))
	return mesh
