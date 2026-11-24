class_name Rocket
extends Node3D
## A bazooka rocket: flies straight from the tube trailing smoke and fire, blows
## up on the first thing it touches (or at the end of its range). The blast is
## far bigger than a car's: a fireball, a shock flash, flying chunks, and it
## leaves its mark: a crater in the ground, or a scorched hole knocked into a
## wall (any wall, at any height: skyscrapers too) with rubble falling out of it.
##
## The shooter's rocket is `live`: it finds what it hits and reports back
## (`exploded`), and the shooter's side works out the cars and windows caught in
## it. Everyone else gets a harmless copy that only flies (net_world.gd) until
## the shooter's blast arrives. `explode` plays the blast the same everywhere and
## hurts only what each client owns: its own player and police, villagers on the host.

signal exploded(at: Vector3, normal: Vector3, surface: String, collider: Object)

const LAUNCH_SOUND: AudioStream = preload("res://audio/rocket_launch.wav")
const FLY_SOUND: AudioStreamWAV = preload("res://audio/rocket_fly.wav")
const RUBBLE_SOUND: AudioStream = preload("res://audio/rubble.wav")
const SPEED := 48.0
const RANGE := 260.0
const BLAST_RADIUS := 9.0
const LETHAL_RADIUS := 3.0 # anyone this close is dead
const KILL_RADIUS := 7.0 # villagers and police this close die
const CAR_RADIUS := 9.0 # cars this close blow up
const WINDOW_RADIUS := 7.0 # shop windows this close are blown out
const MAX_MARKS := 40 # craters and holes kept; past this the oldest go

static var _marks: Array[Node3D] = []
static var _fly_loop: AudioStreamWAV
static var _scorch_material: StandardMaterial3D
static var _hole_material: StandardMaterial3D
static var _rubble_material: StandardMaterial3D
static var _dirt_material: StandardMaterial3D
static var _earth_material: StandardMaterial3D
static var _body_material: StandardMaterial3D
static var _tip_material: StandardMaterial3D
static var _flame_material: StandardMaterial3D
static var _smoke_material: StandardMaterial3D
static var _fire_material: StandardMaterial3D

var live := false
var by := 0
var velocity := Vector3.ZERO
var exclude: Array[RID] = []
var _travelled := 0.0
var _trail: GPUParticles3D
var _done := false


## Fire a rocket from `from` along `direction`. `live`: this client's own shot.
static func launch(parent: Node, from: Vector3, direction: Vector3, shooter: int, is_live: bool, skip: Array[RID] = []) -> Rocket:
	_make_materials()
	var rocket := Rocket.new()
	rocket.name = "Rocket"
	rocket.live = is_live
	rocket.by = shooter
	rocket.exclude = skip
	rocket.velocity = direction.normalized() * SPEED
	parent.add_child(rocket)
	rocket.global_position = from
	rocket._build()
	_backblast(parent, from, direction.normalized())
	return rocket


func _build() -> void:
	var dir := velocity.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	global_basis = Basis.looking_at(dir, up)
	for part in [[0.055, 0.055, 0.5, 0.0, _body_material], [0.012, 0.055, 0.14, -0.32, _tip_material], [0.02, 0.05, 0.1, 0.3, _body_material]]:
		var mesh := CylinderMesh.new()
		mesh.top_radius = part[0]
		mesh.bottom_radius = part[1]
		mesh.height = part[2]
		mesh.radial_segments = 10
		mesh.material = part[4]
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.rotation.x = -PI / 2.0
		instance.position = Vector3(0, 0, float(part[3]))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	var flame := MeshInstance3D.new()
	var blob := SphereMesh.new()
	blob.radius = 0.5
	blob.height = 1.0
	blob.radial_segments = 8
	blob.rings = 4
	flame.mesh = blob
	flame.material_override = _flame_material
	flame.scale = Vector3(0.16, 0.16, 0.55)
	flame.position = Vector3(0, 0, 0.55)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 3.0
	light.omni_range = 8.0
	light.position = Vector3(0, 0, 0.7)
	add_child(light)
	if _fly_loop == null:
		_fly_loop = FLY_SOUND.duplicate() as AudioStreamWAV
		_fly_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_fly_loop.loop_begin = 0
		_fly_loop.loop_end = int(_fly_loop.get_length() * _fly_loop.mix_rate)
	var roar := AudioStreamPlayer3D.new()
	roar.stream = _fly_loop
	roar.unit_size = 8.0
	roar.max_distance = 150.0
	roar.volume_db = 2.0
	add_child(roar)
	roar.play()
	# The smoke trail stays in the world (and in the scene) after the rocket is gone.
	var trail := _particles(get_parent(), global_position, 90, 2.4, _smoke_material, 0.2, 1.0)
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.08
	trail.direction = Vector3.UP
	trail.spread = 180.0
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.8
	trail.gravity = Vector3(0, 0.6, 0)
	trail.color_ramp = CarFire._ramp([Color(0.95, 0.92, 0.88, 0.7), Color(0.75, 0.74, 0.72, 0.45), Color(0.6, 0.6, 0.6, 0)])
	_trail = _start(trail, 400.0) # the emitter flies off: keep the whole trail drawn


func _physics_process(delta: float) -> void:
	if _done:
		return
	var from := global_position
	var step := velocity * delta
	var to := from + step
	if live:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = exclude
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var normal: Vector3 = hit.get("normal", Vector3.UP)
			var surface := "air"
			if normal.y > 0.6:
				surface = "ground"
			elif absf(normal.y) < 0.5:
				surface = "wall"
			_finish(hit["position"], normal, surface, hit.get("collider"))
			return
	global_position = to
	if _trail != null:
		_trail.global_position = to - velocity.normalized() * 0.5
	_travelled += step.length()
	if _travelled > RANGE:
		if live:
			_finish(to, -velocity.normalized(), "air", null)
		else:
			fizzle()


func _finish(at: Vector3, normal: Vector3, surface: String, collider: Object) -> void:
	_done = true
	global_position = at
	exploded.emit(at, normal, surface, collider)
	fizzle()


## The rocket is gone (blown up, or a remote copy whose blast has arrived):
## the trail stops and fades out, the rocket itself disappears at once.
func fizzle() -> void:
	_done = true
	if _trail != null and is_instance_valid(_trail):
		var trail := _trail
		trail.emitting = false
		trail.get_tree().create_timer(trail.lifetime + 0.2).timeout.connect(trail.queue_free)
		_trail = null
	queue_free()


## A flash at the muzzle and a little smoke out of the back of the tube.
static func _backblast(parent: Node, at: Vector3, dir: Vector3) -> void:
	var puff := _particles(parent, at - dir * 1.3, 10, 1.2, _smoke_material, 0.25, 0.7)
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 0.1
	puff.direction = -dir
	puff.spread = 20.0
	puff.initial_velocity_min = 2.0
	puff.initial_velocity_max = 5.0
	puff.gravity = Vector3(0, 0.4, 0)
	puff.color_ramp = CarFire._ramp([Color(0.9, 0.88, 0.85, 0.4), Color(0.75, 0.75, 0.75, 0.2), Color(0.7, 0.7, 0.7, 0)])
	var puff_fx := _start(puff)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.35)
	flash.light_energy = 6.0
	flash.omni_range = 9.0
	parent.add_child(flash)
	flash.global_position = at
	var fade := flash.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, 0.25)
	fade.tween_callback(flash.queue_free)
	GlassFx.play(parent as Node3D, at, LAUNCH_SOUND, 12.0, 4.0, randf_range(0.95, 1.05))
	parent.get_tree().create_timer(2.0).timeout.connect(puff_fx.queue_free)


## The blast at `at`, on everyone's screen: `surface` "ground" (crater), "wall"
## (a hole in it) or "air"/"car"/"body" (no mark). `by` fired it.
static func explode(parent: Node3D, at: Vector3, normal: Vector3, surface: String, by: int) -> void:
	_make_materials()
	if normal.length_squared() < 0.01:
		normal = Vector3.UP
	normal = normal.normalized()
	var centre := at + normal * 0.6
	var root := Node3D.new()
	root.name = "RocketBlast"
	parent.add_child(root)
	root.global_position = centre

	var fireball := _particles(root, Vector3.ZERO, 160, 1.1, _fire_material, 2.2, 5.5)
	fireball.one_shot = true
	fireball.explosiveness = 0.97
	fireball.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fireball.emission_sphere_radius = 1.6
	fireball.direction = normal
	fireball.spread = 180.0
	fireball.initial_velocity_min = 6.0
	fireball.initial_velocity_max = 16.0
	fireball.gravity = Vector3(0, 3.0, 0)
	fireball.damping_min = 6.0
	fireball.damping_max = 10.0
	fireball.color_ramp = CarFire._ramp([Color(1, 1, 0.85, 1), Color(1, 0.7, 0.2, 1), Color(0.9, 0.3, 0.05, 0.8), Color(0.25, 0.08, 0.03, 0.4), Color(0.05, 0.04, 0.04, 0)])
	_start(fireball)
	var core := _particles(root, Vector3.ZERO, 6, 0.25, _fire_material, 7.0, 10.0)
	core.one_shot = true
	core.explosiveness = 1.0
	core.initial_velocity_max = 0.5
	core.color_ramp = CarFire._ramp([Color(1, 1, 0.95, 1), Color(1, 0.8, 0.4, 0.6), Color(1, 0.5, 0.1, 0)])
	_start(core)
	var cloud := _particles(root, normal * 1.0, 80, 5.5, _smoke_material, 4.5, 10.0)
	cloud.one_shot = true
	cloud.explosiveness = 0.85
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cloud.emission_sphere_radius = 1.8
	cloud.direction = (normal + Vector3.UP).normalized()
	cloud.spread = 80.0
	cloud.initial_velocity_min = 1.0
	cloud.initial_velocity_max = 3.5
	cloud.gravity = Vector3(0.3, 0.8, 0.15)
	cloud.damping_min = 0.8
	cloud.damping_max = 1.5
	cloud.color_ramp = CarFire._ramp([Color(0.12, 0.11, 0.1, 0.85), Color(0.2, 0.19, 0.18, 0.55), Color(0.35, 0.34, 0.33, 0)])
	_start(cloud)
	var dust := _particles(root, -normal * 0.4, 40, 4.0, _smoke_material, 2.0, 5.0)
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 1.0
	dust.direction = normal
	dust.spread = 85.0
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 10.0
	dust.damping_min = 3.0
	dust.damping_max = 5.0
	dust.gravity = Vector3(0, -0.6, 0)
	dust.color_ramp = CarFire._ramp([Color(0.55, 0.5, 0.44, 0.8), Color(0.62, 0.58, 0.52, 0.45), Color(0.7, 0.68, 0.64, 0)])
	_start(dust)
	var sparks := _particles(root, Vector3.ZERO, 50, 1.2, _fire_material, 0.08, 0.2)
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.direction = normal
	sparks.spread = 100.0
	sparks.initial_velocity_min = 12.0
	sparks.initial_velocity_max = 26.0
	sparks.gravity = Vector3(0, -14.0, 0)
	sparks.color_ramp = CarFire._ramp([Color(1, 0.95, 0.6, 1), Color(1, 0.6, 0.15, 1), Color(0.6, 0.15, 0.0, 0)])
	_start(sparks)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.65, 0.3)
	flash.light_energy = 22.0
	flash.omni_range = 40.0
	root.add_child(flash)
	flash.create_tween().tween_property(flash, "light_energy", 0.0, 1.0).set_ease(Tween.EASE_OUT)
	var bang := AudioStreamPlayer3D.new()
	bang.stream = CarFire.EXPLOSION_SOUND
	bang.unit_size = 45.0
	bang.max_distance = 700.0
	bang.volume_db = 10.0
	bang.pitch_scale = randf_range(0.72, 0.8)
	root.add_child(bang)
	bang.play()

	match surface:
		"ground":
			_crater(parent, at)
		"wall":
			_wall_hole(parent, at, normal)
	_chunks(parent, centre, normal, surface == "wall", at.y)
	if surface == "wall" or surface == "ground":
		GlassFx.play(parent, at, RUBBLE_SOUND, 14.0, 4.0, randf_range(0.9, 1.1))
	root.create_tween().tween_interval(8.0).finished.connect(root.queue_free)
	_shake(parent.get_tree(), at)
	_hurt(parent.get_tree(), at, by)


## The camera of a player near the blast jolts.
static func _shake(tree: SceneTree, at: Vector3) -> void:
	var player := tree.get_first_node_in_group("player") as Node3D
	if player != null and player.has_method("shake"):
		var distance := player.global_position.distance_to(at)
		player.call("shake", clampf(1.0 - distance / 60.0, 0.0, 1.0))


## Each client hurts its own player and police; the host the villagers too.
static func _hurt(tree: SceneTree, at: Vector3, by: int) -> void:
	var player := tree.get_first_node_in_group("player") as Node3D
	if player != null:
		var distance := (player.global_position + Vector3.UP * 0.9).distance_to(at)
		if distance < BLAST_RADIUS:
			var t := clampf((distance - LETHAL_RADIUS) / (BLAST_RADIUS - LETHAL_RADIUS), 0.0, 1.0)
			player.call("receive_damage", lerpf(100.0, 20.0, t), by, "rocket")
	for officer in tree.get_nodes_in_group("police"):
		var cop := officer as Node3D
		if cop.global_position.distance_to(at) < KILL_RADIUS and cop.call("can_be_hit"):
			cop.call("receive_hit", "blast")
	var net := tree.root.get_node_or_null("Net")
	if net != null and not net.call("is_host"):
		return
	for villager in tree.get_nodes_in_group("villagers"):
		var body := villager as Node3D
		if body.global_position.distance_to(at) < KILL_RADIUS and body.call("can_be_hit"):
			body.call("receive_hit", "blast")


## A crater where it hit the ground: a scorched patch, a bowl of churned earth
## with a raised, broken rim, and lumps thrown about. It stays.
static func _crater(parent: Node3D, at: Vector3) -> void:
	var mark := Node3D.new()
	mark.name = "Crater"
	parent.add_child(mark)
	mark.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), at + Vector3.UP * 0.015)
	mark.add_child(_scorch(4.2, Vector3.UP, 0.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const RINGS := [[0.0, 0.0, 0.0], [0.7, 0.05, 0.08], [1.4, 0.24, 0.25], [1.85, 0.42, 0.45], [2.3, 0.2, 0.5], [2.9, 0.0, 0.45]]
	const SIDES := 18
	var jag := PackedFloat32Array()
	for k in SIDES:
		jag.append(randf_range(0.82, 1.18))
	var points := []
	for ring in RINGS:
		var row := []
		for k in SIDES:
			var a := TAU * k / SIDES
			var r: float = ring[0] * jag[k]
			row.append(Vector3(cos(a) * r, float(ring[1]) * randf_range(0.7, 1.3), sin(a) * r))
		points.append(row)
	for i in RINGS.size() - 1:
		var shade_in: float = RINGS[i][2]
		var shade_out: float = RINGS[i + 1][2]
		for k in SIDES:
			var a: Vector3 = points[i][k]
			var b: Vector3 = points[i][(k + 1) % SIDES]
			var c: Vector3 = points[i + 1][(k + 1) % SIDES]
			var d: Vector3 = points[i + 1][k]
			var ci := Color(0.1 + shade_in * 0.62, 0.085 + shade_in * 0.52, 0.07 + shade_in * 0.42)
			var co := Color(0.1 + shade_out * 0.62, 0.085 + shade_out * 0.52, 0.07 + shade_out * 0.42)
			# Faceted: one normal per triangle, so the bowl and the rim catch the light.
			for tri in [[[a, ci], [c, co], [b, ci]], [[a, ci], [d, co], [c, co]]]:
				var p0: Vector3 = tri[0][0]
				var n: Vector3 = ((tri[1][0] as Vector3) - p0).cross((tri[2][0] as Vector3) - p0).normalized()
				if n.y < 0.0:
					n = -n
				for v in tri:
					st.set_color(v[1])
					st.set_normal(n)
					st.add_vertex(v[0])
	var bowl := MeshInstance3D.new()
	bowl.mesh = st.commit()
	bowl.material_override = _dirt_material
	mark.add_child(bowl)
	for k in 14:
		var lump := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(randf_range(0.15, 0.45), randf_range(0.1, 0.25), randf_range(0.15, 0.4))
		lump.mesh = box
		lump.material_override = _rubble_material
		var a := randf() * TAU
		var r := randf_range(2.0, 4.2)
		lump.position = Vector3(cos(a) * r, box.size.y * 0.35, sin(a) * r)
		lump.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
		mark.add_child(lump)
	_keep(mark)


## A hole knocked into a wall: soot spread around it, a ragged black opening with
## broken concrete round its edge and rebar sticking out, a few lumps hanging on.
## Smoke goes on pouring out of it for a while, with a little fire inside.
static func _wall_hole(parent: Node3D, at: Vector3, normal: Vector3) -> void:
	var mark := Node3D.new()
	mark.name = "WallHole"
	parent.add_child(mark)
	var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.FORWARD
	var basis := Basis.looking_at(-normal, up) # -Z into the wall, +Z out of it
	basis = basis * Basis(Vector3.BACK, randf() * TAU)
	mark.global_transform = Transform3D(basis, at + normal * 0.02)
	mark.add_child(_scorch(5.5, Vector3.BACK, 0.0))
	var radius := randf_range(1.6, 2.1)
	const SIDES := 16
	var jag := PackedFloat32Array()
	for k in SIDES:
		jag.append(randf_range(0.7, 1.25))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := Color(0.36, 0.34, 0.31)
	var inner := Color(0.015, 0.012, 0.01)
	for k in SIDES:
		var a0 := TAU * k / SIDES
		var a1 := TAU * (k + 1) / SIDES
		var r0 := radius * jag[k]
		var r1 := radius * jag[(k + 1) % SIDES]
		var p0 := Vector3(cos(a0) * r0, sin(a0) * r0, 0.04)
		var p1 := Vector3(cos(a1) * r1, sin(a1) * r1, 0.04)
		# The opening: near black, a touch of depth toward the middle.
		for v in [Vector3(0, 0, 0.03), p1, p0]:
			st.set_color(inner)
			st.set_normal(Vector3.BACK)
			st.add_vertex(v)
		# Broken edge: a band of lighter concrete, ragged on the outside.
		var q0 := Vector3(cos(a0) * (r0 + randf_range(0.12, 0.3)), sin(a0) * (r0 + randf_range(0.12, 0.3)), 0.06)
		var q1 := Vector3(cos(a1) * (r1 + 0.18), sin(a1) * (r1 + 0.18), 0.06)
		var dark_edge := edge.darkened(randf_range(0.0, 0.35))
		for v in [p0, p1, q1, p0, q1, q0]:
			st.set_color(dark_edge)
			st.set_normal(Vector3.BACK)
			st.add_vertex(v)
	var hole := MeshInstance3D.new()
	hole.mesh = st.commit()
	hole.material_override = _hole_material
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.add_child(hole)
	# Rebar bent out of the edge.
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.22, 0.14, 0.1)
	steel.roughness = 0.8
	for k in 6:
		var bar := MeshInstance3D.new()
		var rod := CylinderMesh.new()
		rod.top_radius = 0.012
		rod.bottom_radius = 0.012
		rod.height = randf_range(0.4, 0.9)
		rod.radial_segments = 4
		rod.material = steel
		bar.mesh = rod
		var a := randf() * TAU
		var r := radius * randf_range(0.8, 1.05)
		bar.position = Vector3(cos(a) * r, sin(a) * r, 0.1)
		bar.rotation = Vector3(randf_range(-1.2, 1.2), 0.0, a + PI / 2.0 + randf_range(-0.5, 0.5))
		mark.add_child(bar)
	for k in 8:
		var lump := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(randf_range(0.15, 0.4), randf_range(0.12, 0.35), randf_range(0.1, 0.25))
		lump.mesh = box
		lump.material_override = _rubble_material
		var a := randf() * TAU
		var r := radius * randf_range(0.95, 1.3)
		lump.position = Vector3(cos(a) * r, sin(a) * r, box.size.z * 0.4)
		lump.rotation = Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf() * TAU)
		mark.add_child(lump)
	# It smokes on, with a glow of fire inside.
	var smoke := _particles(mark, Vector3(0, 0, 0.3), 40, 7.0, _smoke_material, 1.5, 4.5)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = radius * 0.6
	smoke.direction = Vector3.BACK
	smoke.spread = 30.0
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.8
	smoke.gravity = Vector3(0.3, 1.2, 0.1)
	smoke.color_ramp = CarFire._ramp([Color(0.05, 0.045, 0.04, 0.9), Color(0.12, 0.11, 0.1, 0.7), Color(0.3, 0.3, 0.3, 0)])
	var smoke_fx := _start(smoke)
	var flames := _particles(mark, Vector3(0, -radius * 0.55, 0.15), 18, 0.8, _fire_material, 0.3, 0.8)
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flames.emission_box_extents = Vector3(radius * 0.45, 0.1, 0.05)
	flames.direction = Vector3.UP
	flames.spread = 15.0
	flames.initial_velocity_min = 1.0
	flames.initial_velocity_max = 2.2
	flames.gravity = Vector3(0, 1.5, 0)
	flames.color_ramp = CarFire._ramp([Color(1, 0.85, 0.4, 0.9), Color(1, 0.45, 0.08, 0.7), Color(0.4, 0.1, 0.02, 0)])
	var flames_fx := _start(flames)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.15)
	glow.light_energy = 1.2
	glow.omni_range = 5.0
	glow.position = Vector3(0, -radius * 0.5, 1.5)
	mark.add_child(glow)
	var life := mark.create_tween()
	life.tween_interval(45.0)
	life.tween_callback(func() -> void: flames_fx.emitting = false)
	life.tween_property(glow, "light_energy", 0.0, 4.0)
	life.tween_interval(40.0)
	life.tween_callback(func() -> void: smoke_fx.emitting = false)
	_keep(mark)


## A soft-edged ring of soot, lying in its node's XY plane (normal +Z) or XZ (+Y).
static func _scorch(radius: float, facing: Vector3, lift: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 20
	var flat := facing == Vector3.UP
	var centre := Color(0.03, 0.026, 0.022, 0.85)
	var rims := []
	for k in SIDES:
		var a := TAU * k / SIDES
		var r := radius * randf_range(0.75, 1.15)
		rims.append(Vector2(cos(a) * r, sin(a) * r))
	for k in SIDES:
		var a: Vector2 = rims[k]
		var b: Vector2 = rims[(k + 1) % SIDES]
		for v in [[Vector2.ZERO, 0.92], [a * 0.55, 0.8], [b * 0.55, 0.8], [a * 0.55, 0.8], [a, 0.0], [b, 0.0], [a * 0.55, 0.8], [b, 0.0], [b * 0.55, 0.8]]:
			var p: Vector2 = v[0]
			st.set_color(Color(centre.r, centre.g, centre.b, float(v[1])))
			st.set_normal(facing)
			st.add_vertex(Vector3(p.x, lift, p.y) if flat else Vector3(p.x, p.y, lift))
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = _scorch_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Lumps of concrete (or earth) thrown out of the blast: real bodies that bounce
## off the street and the walls, then crumble away after a while.
static func _chunks(parent: Node3D, centre: Vector3, normal: Vector3, wall: bool, impact_y: float) -> void:
	var count := 12 if wall else 9
	if wall and impact_y > 12.0:
		count = 16 # high up there's further to fall: more of it
	for k in count:
		var body := RigidBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 1
		body.mass = 20.0
		var size := Vector3(randf_range(0.2, 0.7), randf_range(0.15, 0.5), randf_range(0.2, 0.6))
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		mesh.material_override = _rubble_material if wall else _earth_material
		body.add_child(mesh)
		parent.add_child(body)
		body.global_position = centre + Vector3(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))
		var spread := Vector3(randf_range(-1, 1), randf_range(-0.3, 1.0), randf_range(-1, 1)).normalized()
		var out := (normal * 1.3 + spread).normalized()
		body.linear_velocity = out * randf_range(5.0, 13.0) + Vector3.UP * (3.0 if not wall else 1.0)
		body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		var tween := body.create_tween()
		tween.tween_interval(randf_range(7.0, 10.0))
		tween.tween_property(mesh, "scale", Vector3.ONE * 0.01, 1.2)
		tween.tween_callback(body.queue_free)


## Soft round sprites set up like CarFire's. They are configured as a
## CPUParticles3D (not in the tree yet) and turned into GPU particles by _start:
## on this Godot a CPUParticles3D draws its unborn and dead sprites as black
## squares at the emitter.
static func _particles(parent: Node, at: Vector3, amount: int, lifetime: float, material: Material, size_min: float, size_max: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
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
	particles.position = at
	particles.set_meta("parent", parent)
	return particles


## The configured particles, as GPU particles under their parent, emitting.
## `reach`: half the size of the box they may be seen in, round the emitter.
static func _start(setup: CPUParticles3D, reach := 30.0) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.convert_from_particles(setup)
	particles.visibility_aabb = AABB(Vector3.ONE * -reach, Vector3.ONE * reach * 2.0)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.position = setup.position
	(setup.get_meta("parent") as Node).add_child(particles)
	particles.emitting = true
	setup.free()
	return particles


static func _keep(mark: Node3D) -> void:
	_marks = _marks.filter(func(m: Node3D) -> bool: return is_instance_valid(m))
	_marks.append(mark)
	while _marks.size() > MAX_MARKS:
		var old: Node3D = _marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func _make_materials() -> void:
	if _scorch_material != null:
		return
	_scorch_material = StandardMaterial3D.new()
	_scorch_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_scorch_material.vertex_color_use_as_albedo = true
	_scorch_material.vertex_color_is_srgb = true
	_scorch_material.roughness = 1.0
	_scorch_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_scorch_material.render_priority = 1
	_hole_material = StandardMaterial3D.new()
	_hole_material.vertex_color_use_as_albedo = true
	_hole_material.vertex_color_is_srgb = true
	_hole_material.roughness = 1.0
	_hole_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rubble_material = StandardMaterial3D.new()
	_rubble_material.albedo_color = Color(0.36, 0.34, 0.31)
	_rubble_material.roughness = 0.95
	_dirt_material = StandardMaterial3D.new()
	_dirt_material.vertex_color_use_as_albedo = true
	_dirt_material.vertex_color_is_srgb = true
	_dirt_material.albedo_color = Color(1, 1, 1)
	_dirt_material.roughness = 1.0
	_dirt_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_earth_material = StandardMaterial3D.new()
	_earth_material.albedo_color = Color(0.27, 0.24, 0.2)
	_earth_material.roughness = 1.0
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Color(0.32, 0.34, 0.28)
	_body_material.metallic = 0.4
	_body_material.roughness = 0.5
	_tip_material = StandardMaterial3D.new()
	_tip_material.albedo_color = Color(0.75, 0.12, 0.08)
	_flame_material = StandardMaterial3D.new()
	_flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flame_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flame_material.albedo_color = Color(1.0, 0.7, 0.3, 0.95)
	_smoke_material = CarFire._soft_material(false)
	_fire_material = CarFire._soft_material(true)
