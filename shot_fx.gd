class_name ShotFx
extends RefCounted
## One-off visuals and sounds for pistol shots: the tracer streak, bullet holes
## and dust where a round hits the world, a spray of blood where it hits a person,
## and the gunshot heard from afar. Shared by the local player and the replay of
## other players' shots (net_world.gd).

const SHOT_SOUND: AudioStream = preload("res://audio/pistol_shot.ogg")
const SUPPRESSED_SOUND: AudioStream = preload("res://audio/m4a1_suppressed.ogg")
const MAX_HOLES := 80

static var _holes: Array[Node3D] = []
static var _tracer_material: StandardMaterial3D
static var _hole_material: StandardMaterial3D
static var _dust_material: StandardMaterial3D
static var _blood_material: StandardMaterial3D


## A thin bright streak from the muzzle to where the round ended up, gone in a blink.
static func tracer(root: Node, from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.3:
		return
	if _tracer_material == null:
		_tracer_material = StandardMaterial3D.new()
		_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tracer_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_tracer_material.albedo_color = Color(1.0, 0.86, 0.55, 0.85)
		_tracer_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.014, 0.014, 1.0)
	var streak := MeshInstance3D.new()
	streak.mesh = mesh
	streak.material_override = _tracer_material.duplicate()
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(streak)
	# Only the far part of the path: a streak right in front of the camera looks like a laser.
	var start := from.lerp(to, minf(0.35, 2.0 / length))
	var middle := (start + to) * 0.5
	var up := Vector3.UP if absf(from.direction_to(to).y) < 0.98 else Vector3.RIGHT
	var basis := Basis.looking_at(to - start, up)
	basis.z *= start.distance_to(to) # the unit box stretched along its own Z, the path
	streak.global_transform = Transform3D(basis, middle)
	var tween := streak.create_tween()
	tween.tween_property(streak.material_override, "albedo_color:a", 0.0, 0.08)
	tween.tween_callback(streak.queue_free)


## A round hitting a wall, the ground, a car: dark hole plus a puff of dust.
static func impact(root: Node, point: Vector3, normal: Vector3) -> void:
	if normal.length_squared() < 0.01:
		normal = Vector3.UP
	normal = normal.normalized()
	if _hole_material == null:
		_hole_material = StandardMaterial3D.new()
		_hole_material.albedo_color = Color(0.03, 0.03, 0.03, 0.92)
		_hole_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hole_material.roughness = 1.0
	var disc := CylinderMesh.new()
	disc.top_radius = 0.028
	disc.bottom_radius = 0.028
	disc.height = 0.002
	disc.radial_segments = 8
	disc.rings = 1
	var hole := MeshInstance3D.new()
	hole.mesh = disc
	hole.material_override = _hole_material
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hole)
	var side := Vector3.RIGHT if absf(normal.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := side.cross(normal).normalized()
	hole.global_transform = Transform3D(Basis(x, normal, x.cross(normal)), point + normal * 0.004)
	_holes.append(hole)
	while _holes.size() > MAX_HOLES:
		var oldest: Node3D = _holes.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	if _dust_material == null:
		_dust_material = _particle_material(Color(0.62, 0.58, 0.5))
	_burst(root, point + normal * 0.03, normal, _dust_material, 10, 1.6, 0.05)


## A round hitting a person: a short red spray out of the wound.
static func blood(root: Node, point: Vector3, direction: Vector3) -> void:
	if _blood_material == null:
		_blood_material = _particle_material(Color(0.55, 0.02, 0.02))
	_burst(root, point, direction.normalized(), _blood_material, 18, 2.4, 0.04)


## The gunshot from somewhere in the world (another player firing): loud, carries far.
static func shot_sound(root: Node, at: Vector3, suppressed := false) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = SUPPRESSED_SOUND if suppressed else SHOT_SOUND
	player.unit_size = 7.0 if suppressed else 12.0
	player.max_distance = 95.0 if suppressed else 220.0
	player.volume_db = -5.0 if suppressed else 2.0
	player.pitch_scale = randf_range(0.95, 1.05)
	root.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


static func _particle_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	return material


static func _burst(root: Node, at: Vector3, direction: Vector3, material: Material, count: int, speed: float, size: float) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = 0.45
	particles.local_coords = false
	particles.direction = direction
	particles.spread = 35.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -6.0, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
