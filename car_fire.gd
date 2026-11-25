class_name CarFire
extends RefCounted
## A car hit by a bullet blows up: fireball, flash, debris and a bang heard across
## the estate, then the charred shell burns for a long time and smoulders after.
## Everyone near the blast gets hurt (blast). Used for parked cars (district.gd)
## and for the traffic (traffic.gd).

const EXPLOSION_SOUND: AudioStream = preload("res://audio/car_explosion.ogg")
const FIRE_SOUND: AudioStreamOggVorbis = preload("res://audio/car_fire.ogg")
const BURN_TIME := 150.0 # open flames
const SMOULDER_TIME := 90.0 # then only smoke
const TOTAL_TIME := BURN_TIME + SMOULDER_TIME
const BLAST_RADIUS := 6.5
const LETHAL_RADIUS := 2.0 # anyone this close is dead
const VILLAGER_KILL_RADIUS := 4.5

static var _burnt: StandardMaterial3D
static var _flame: StandardMaterial3D
static var _smoke: StandardMaterial3D
static var _debris: StandardMaterial3D
static var _fire_loop: AudioStreamOggVorbis


## Blow up a car standing at `at` (its origin on the ground, size = its bounding box):
## returns the wreck node, added under `parent`, that burns on by itself.
static func explode(parent: Node3D, at: Transform3D, size: Vector3, mesh: Mesh) -> Node3D:
	_make_materials()
	var wreck := Node3D.new()
	wreck.name = "BurningWreck"
	parent.add_child(wreck)
	wreck.global_transform = at
	if mesh != null:
		var shell := MeshInstance3D.new()
		shell.mesh = mesh
		shell.material_override = _burnt
		wreck.add_child(shell)
		# Knocked askew by the blast.
		shell.rotation = Vector3(randf_range(-0.04, 0.04), randf_range(-0.12, 0.12), randf_range(-0.05, 0.05))
	var centre := Vector3(0, size.y * 0.55, 0)

	# The bang: fireball, black cloud, flying bits, a flash lighting up the street.
	var fireball := _particles(wreck, centre, 110, 1.3, _flame, 1.6, 4.2)
	fireball.one_shot = true
	fireball.explosiveness = 0.95
	fireball.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fireball.emission_sphere_radius = 1.2
	fireball.direction = Vector3.UP
	fireball.spread = 180.0
	fireball.initial_velocity_min = 4.0
	fireball.initial_velocity_max = 11.0
	fireball.gravity = Vector3(0, 2.5, 0)
	fireball.damping_min = 4.0
	fireball.damping_max = 7.0
	fireball.color_ramp = _ramp([Color(1, 0.95, 0.6, 1), Color(1, 0.55, 0.12, 0.95), Color(0.35, 0.1, 0.03, 0.6), Color(0.05, 0.04, 0.04, 0)])
	fireball.emitting = true
	var cloud := _particles(wreck, centre + Vector3.UP * 0.8, 45, 5.0, _smoke, 2.6, 6.0)
	cloud.one_shot = true
	cloud.explosiveness = 0.9
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cloud.emission_sphere_radius = 1.0
	cloud.direction = Vector3.UP
	cloud.spread = 70.0
	cloud.initial_velocity_min = 2.0
	cloud.initial_velocity_max = 5.0
	cloud.gravity = Vector3(0, 0.8, 0)
	cloud.damping_min = 1.0
	cloud.damping_max = 2.0
	cloud.color_ramp = _ramp([Color(0.08, 0.07, 0.07, 0.9), Color(0.12, 0.11, 0.1, 0.6), Color(0.2, 0.2, 0.2, 0)])
	cloud.emitting = true
	var bits := CPUParticles3D.new()
	bits.one_shot = true
	bits.explosiveness = 1.0
	bits.amount = 24
	bits.lifetime = 2.2
	bits.local_coords = false
	var bit_mesh := BoxMesh.new()
	bit_mesh.size = Vector3(0.18, 0.05, 0.14)
	bit_mesh.material = _debris
	bits.mesh = bit_mesh
	bits.direction = Vector3.UP
	bits.spread = 75.0
	bits.initial_velocity_min = 5.0
	bits.initial_velocity_max = 12.0
	bits.gravity = Vector3(0, -12.0, 0)
	bits.angular_velocity_min = -400.0
	bits.angular_velocity_max = 400.0
	bits.scale_amount_min = 0.5
	bits.scale_amount_max = 1.6
	bits.position = centre
	wreck.add_child(bits)
	bits.emitting = true
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.62, 0.25)
	flash.light_energy = 14.0
	flash.omni_range = 28.0
	flash.position = centre + Vector3.UP
	wreck.add_child(flash)
	flash.create_tween().tween_property(flash, "light_energy", 0.0, 0.9).set_ease(Tween.EASE_OUT)
	var bang := AudioStreamPlayer3D.new()
	bang.stream = EXPLOSION_SOUND
	bang.unit_size = 30.0
	bang.max_distance = 500.0
	bang.volume_db = 6.0
	bang.position = centre
	wreck.add_child(bang)
	bang.play()

	# Then it burns: flames over the whole car, a column of smoke, flickering light, crackle.
	var flames := _particles(wreck, Vector3(0, size.y * 0.5, 0), 140, 1.1, _flame, 0.8, 1.9)
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flames.emission_box_extents = Vector3(size.x * 0.42, size.y * 0.3, size.z * 0.42)
	flames.direction = Vector3.UP
	flames.spread = 12.0
	flames.initial_velocity_min = 1.8
	flames.initial_velocity_max = 3.6
	flames.gravity = Vector3(0, 2.0, 0)
	flames.color_ramp = _ramp([Color(1, 0.85, 0.4, 0.95), Color(1, 0.45, 0.08, 0.85), Color(0.6, 0.12, 0.02, 0.4), Color(0.1, 0.05, 0.03, 0)])
	flames.emitting = true
	var smoke := _particles(wreck, Vector3(0, size.y + 1.0, 0), 110, 9.0, _smoke, 2.2, 7.5)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(size.x * 0.35, 0.2, size.z * 0.35)
	smoke.direction = Vector3.UP
	smoke.spread = 10.0
	smoke.initial_velocity_min = 1.8
	smoke.initial_velocity_max = 3.0
	smoke.gravity = Vector3(0.35, 0.3, 0.15) # drifts off with the wind
	smoke.color_ramp = _ramp([Color(0.04, 0.035, 0.03, 1.0), Color(0.08, 0.075, 0.07, 0.9), Color(0.18, 0.17, 0.16, 0.6), Color(0.32, 0.32, 0.32, 0)])
	smoke.emitting = true
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.15)
	glow.light_energy = 3.5
	glow.omni_range = 12.0
	glow.position = Vector3(0, size.y + 0.4, 0)
	wreck.add_child(glow)
	var flicker := glow.create_tween().set_loops()
	flicker.tween_property(glow, "light_energy", 4.2, 0.13)
	flicker.tween_property(glow, "light_energy", 2.4, 0.17)
	flicker.tween_property(glow, "light_energy", 3.6, 0.11)
	flicker.tween_property(glow, "light_energy", 2.8, 0.19)
	if _fire_loop == null:
		_fire_loop = FIRE_SOUND.duplicate() as AudioStreamOggVorbis
		_fire_loop.loop = true
	var crackle := AudioStreamPlayer3D.new()
	crackle.stream = _fire_loop
	crackle.unit_size = 6.0
	crackle.max_distance = 60.0
	crackle.volume_db = 4.0
	crackle.position = centre
	wreck.add_child(crackle)
	crackle.play(randf_range(0.0, 20.0))

	# Flames die down after a while; the smoke goes on a little longer, thinning out.
	var life := wreck.create_tween()
	life.tween_interval(BURN_TIME)
	life.tween_callback(func() -> void:
		flames.emitting = false
		flicker.kill()
		smoke.amount = 40
	)
	life.tween_property(glow, "light_energy", 0.0, 6.0)
	life.parallel().tween_property(crackle, "volume_db", -40.0, 8.0)
	life.tween_callback(crackle.stop)
	life.tween_interval(SMOULDER_TIME - 8.0)
	life.tween_callback(func() -> void: smoke.emitting = false)
	return wreck


## The blast hurts whoever stands near `centre`: the local player (each client hurts
## only its own player; `by` is who fired, for the kill feed) and, on the host, the
## villagers nearby, who die.
static func blast(tree: SceneTree, centre: Vector3, by: int) -> void:
	var player := tree.get_first_node_in_group("player") as Node3D
	if player != null:
		var distance := player.global_position.distance_to(centre)
		if distance < BLAST_RADIUS:
			var t := clampf((distance - LETHAL_RADIUS) / (BLAST_RADIUS - LETHAL_RADIUS), 0.0, 1.0)
			player.call("receive_damage", lerpf(100.0, 15.0, t), by, "blast")
	# The police are local to each player (police.gd), so every client hurts its own.
	for officer in tree.get_nodes_in_group("police"):
		var cop := officer as Node3D
		if cop.global_position.distance_to(centre) < VILLAGER_KILL_RADIUS and cop.call("can_be_hit"):
			cop.call("receive_hit", "blast")
	var net := tree.root.get_node_or_null("Net")
	if net != null and not net.call("is_host"):
		return
	for villager in tree.get_nodes_in_group("villagers"):
		var body := villager as Node3D
		if body.global_position.distance_to(centre) < VILLAGER_KILL_RADIUS and body.call("can_be_hit"):
			body.call("receive_hit", "blast", by)


static func _particles(parent: Node3D, at: Vector3, amount: int, lifetime: float, material: Material, size_min: float, size_max: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.randomness = 0.5
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	particles.mesh = quad
	particles.scale_amount_min = size_min
	particles.scale_amount_max = size_max
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.45))
	grow.add_point(Vector2(1.0, 1.0))
	particles.scale_amount_curve = grow
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.position = at
	parent.add_child(particles)
	return particles


static func _ramp(colors: Array) -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var packed := PackedColorArray()
	for index in colors.size():
		offsets.append(float(index) / float(colors.size() - 1))
		packed.append(colors[index])
	gradient.offsets = offsets
	gradient.colors = packed
	return gradient


static func _make_materials() -> void:
	if _burnt != null:
		return
	_burnt = StandardMaterial3D.new()
	_burnt.albedo_color = Color(0.055, 0.045, 0.04)
	_burnt.roughness = 0.95
	_burnt.metallic = 0.2
	_flame = _soft_material(true)
	_smoke = _soft_material(false)
	_debris = StandardMaterial3D.new()
	_debris.albedo_color = Color(0.08, 0.07, 0.065)
	_debris.roughness = 0.9


## Round soft-edged sprite drawn with the particle colour: additive glow for fire, plain blend for smoke.
static func _soft_material(glow: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if glow else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_dot(0.5 if glow else 0.75, 0.55 if glow else 0.85)
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material


static func _soft_dot(plateau: float, plateau_alpha: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, plateau, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, plateau_alpha), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
