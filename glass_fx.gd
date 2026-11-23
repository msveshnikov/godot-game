class_name GlassFx
extends RefCounted
## Breaking glass: pieces falling out of a pane, the shards left lying on the
## pavement for good (one multimesh for the whole scene, so a street full of
## smashed windows still costs one draw call), and the sounds of it.
## Used by the shop windows (nyc_builder.gd) and the car windows (car_damage.gd).

const SHATTER_SOUND: AudioStream = preload("res://audio/glass_shatter.wav")
const CRACK_SOUNDS: Array[AudioStream] = [
	preload("res://addons/cogito/Assets/Audio/Kenney/Impacts/impactGlass_medium_000.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Impacts/impactGlass_medium_001.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Impacts/impactGlass_medium_002.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Impacts/impactGlass_medium_003.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Impacts/impactGlass_medium_004.ogg"),
]
const TINKLE_SOUNDS: Array[AudioStream] = [
	preload("res://addons/cogito/Assets/Audio/Kenney/Impacts/impactGlass_light_000.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Impacts/impactGlass_light_001.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Impacts/impactGlass_light_002.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Impacts/impactGlass_light_003.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Impacts/impactGlass_light_004.ogg"),
]
## Shards lying about; past this the oldest get swept up for the new ones.
const MAX_SHARDS := 12000

static var _shard_mesh: ArrayMesh
static var _shard_material: StandardMaterial3D
static var _shards: MultiMeshInstance3D
static var _next_shard := 0


## A pane giving way: pieces fall out of it (the rectangle centred on `centre`,
## `along` and `half_width` across, `height` up from its bottom edge at
## centre.y), the shards land on the ground in front (`out`), and the crash.
static func shatter(root: Node3D, centre: Vector3, along: Vector3, half_width: float, height: float, out: Vector3, ground_y: float, count := 90, tint := Color.WHITE) -> void:
	_ensure(root)
	var falling := CPUParticles3D.new()
	falling.one_shot = true
	falling.explosiveness = 0.75
	falling.amount = count
	falling.lifetime = 1.4
	falling.local_coords = false
	falling.mesh = _shard_mesh
	falling.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	falling.emission_box_extents = Vector3(half_width, height * 0.5, 0.02)
	falling.direction = Vector3(0, 0.2, 1)
	falling.spread = 35.0
	falling.initial_velocity_min = 0.6
	falling.initial_velocity_max = 2.8
	falling.gravity = Vector3(0, -9.8, 0)
	falling.angular_velocity_min = -720.0
	falling.angular_velocity_max = 720.0
	falling.scale_amount_min = 0.6
	falling.scale_amount_max = 2.4
	falling.particle_flag_rotate_y = true
	falling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	falling.color = tint
	root.add_child(falling)
	# Box X along the pane, Z out of it.
	var basis := Basis(along.normalized(), Vector3.UP, out.normalized())
	falling.global_transform = Transform3D(basis, centre + Vector3.UP * height * 0.5)
	falling.emitting = true
	falling.finished.connect(falling.queue_free)
	# The pieces come to rest on the pavement, most of them just under the pane.
	var rest := root.get_tree().create_timer(0.45)
	rest.timeout.connect(func() -> void:
		var lying: Array[Transform3D] = []
		for k in count * 2:
			var across := randf_range(-half_width, half_width) * 1.05
			var reach := absf(randfn(0.0, 0.45)) + 0.04
			var at := centre + along.normalized() * across + out.normalized() * reach
			at.y = ground_y + 0.012
			lying.append(_lying(at, randf_range(0.6, 3.2) if randf() < 0.8 else randf_range(3.0, 5.0)))
		_add(lying)
	)
	play(root, centre + Vector3.UP * height * 0.5, SHATTER_SOUND, 22.0, 3.0, randf_range(0.92, 1.08))
	for k in 4:
		var tinkle := root.get_tree().create_timer(randf_range(0.35, 1.1))
		tinkle.timeout.connect(func() -> void:
			if is_instance_valid(root):
				play(root, centre + out * 0.6, TINKLE_SOUNDS.pick_random(), 6.0, -6.0, randf_range(0.85, 1.2))
		)


## A handful of small bits (a crazed car window crumbling) dropped around `at`.
static func crumble(root: Node3D, at: Vector3, ground_y: float, count := 25, tint := Color(0.8, 0.92, 0.88)) -> void:
	_ensure(root)
	var bits := CPUParticles3D.new()
	bits.one_shot = true
	bits.explosiveness = 0.9
	bits.amount = count
	bits.lifetime = 1.0
	bits.local_coords = false
	bits.mesh = _shard_mesh
	bits.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bits.emission_sphere_radius = 0.2
	bits.direction = Vector3.UP
	bits.spread = 70.0
	bits.initial_velocity_min = 0.8
	bits.initial_velocity_max = 2.5
	bits.gravity = Vector3(0, -9.8, 0)
	bits.angular_velocity_min = -720.0
	bits.angular_velocity_max = 720.0
	bits.scale_amount_min = 0.4
	bits.scale_amount_max = 1.0
	bits.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bits.color = tint
	root.add_child(bits)
	bits.global_position = at
	bits.emitting = true
	bits.finished.connect(bits.queue_free)
	var lying: Array[Transform3D] = []
	for k in count:
		var spot := at + Vector3(randfn(0.0, 0.45), 0.0, randfn(0.0, 0.45))
		spot.y = ground_y + 0.012
		lying.append(_lying(spot, randf_range(0.35, 1.0)))
	_add(lying)


static func crack_sound(root: Node3D, at: Vector3) -> void:
	play(root, at, CRACK_SOUNDS.pick_random(), 8.0, 0.0, randf_range(0.8, 1.05))


## A one-off positional sound at `at`, freed when done.
static func play(root: Node3D, at: Vector3, stream: AudioStream, unit_size: float, volume_db: float, pitch := 1.0) -> void:
	if root == null or not root.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.unit_size = unit_size
	player.max_distance = 160.0
	player.volume_db = volume_db
	player.pitch_scale = pitch
	root.add_child(player)
	player.global_position = at
	player.play()
	player.finished.connect(player.queue_free)


## Ground height under `at` (the pavement in front of a window, the road by a car).
static func ground_below(root: Node3D, at: Vector3) -> float:
	var space := root.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at - Vector3.UP * 3.0)
	var hit := space.intersect_ray(query)
	return float(hit["position"].y) if not hit.is_empty() else 0.0


static func _lying(at: Vector3, size: float) -> Transform3D:
	var basis := Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, randf_range(-0.15, 0.15))
	return Transform3D(basis.scaled(Vector3.ONE * size), at)


static func _add(transforms: Array[Transform3D]) -> void:
	if not is_instance_valid(_shards):
		return
	var multimesh := _shards.multimesh
	for xf in transforms:
		multimesh.set_instance_transform(_next_shard % MAX_SHARDS, xf)
		_next_shard += 1
	multimesh.visible_instance_count = mini(_next_shard, MAX_SHARDS)


## The shard mesh, its glinting material and the scene-wide multimesh of lying shards.
static func _ensure(root: Node3D) -> void:
	if _shard_mesh == null:
		_shard_material = StandardMaterial3D.new()
		_shard_material.albedo_color = Color(0.78, 0.86, 0.86)
		_shard_material.vertex_color_use_as_albedo = true
		_shard_material.metallic = 0.3
		_shard_material.metallic_specular = 1.0
		_shard_material.roughness = 0.06
		_shard_material.emission_enabled = true # a faint glitter, so they read from afar
		_shard_material.emission = Color(0.55, 0.62, 0.62)
		_shard_material.emission_energy_multiplier = 0.25
		_shard_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		# A jagged sliver about 4 cm across, lying flat (scaled per shard).
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		st.set_color(Color.WHITE)
		for p in [Vector3(-0.02, 0, -0.012), Vector3(0.026, 0, -0.004), Vector3(-0.004, 0, 0.024),
				Vector3(0.026, 0, -0.004), Vector3(0.012, 0, 0.02), Vector3(-0.004, 0, 0.024)]:
			st.add_vertex(p)
		_shard_mesh = st.commit()
		_shard_mesh.surface_set_material(0, _shard_material)
	if is_instance_valid(_shards) and _shards.is_inside_tree():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _shard_mesh
	multimesh.instance_count = MAX_SHARDS
	multimesh.visible_instance_count = 0
	_shards = MultiMeshInstance3D.new()
	_shards.name = "GlassShards"
	_shards.multimesh = multimesh
	_shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Shards spread over the whole map: a generous box so they are never culled.
	_shards.custom_aabb = AABB(Vector3(-2000, -50, -2000), Vector3(4000, 100, 4000))
	root.get_tree().current_scene.add_child(_shards)
	_next_shard = 0
