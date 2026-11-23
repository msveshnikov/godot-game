class_name CarDamage
extends RefCounted
## A car worked over with the bat: the panels cave in where the bat lands (the
## car gets its own copy of the mesh, pushed in round the blow), the windows craze
## and then crumble onto the road, and it stays that way. A parked car's alarm
## goes off with the lights flashing; a driver honks. No fire: only bullets do that
## (car_fire.gd). Used for parked cars (district.gd) and the traffic (traffic.gd).

const DENT_SOUND: AudioStream = preload("res://audio/car_dent.wav")
const ALARM_SOUND := "res://audio/car_alarm.wav"
const HORN_SOUND: AudioStream = preload("res://audio/car_horn.wav")
const GLASS_SHADER: Shader = preload("res://car_glass.gdshader")
const DENT_RADIUS := 0.5
const DENT_DEPTH := 0.075
const MAX_DENT := 0.32 # no point sinks further than this from where it was built
const ALARM_TIME := 14.0
const NO_DENT := ["Tire", "Rim"]

static var _alarm_loop: AudioStreamWAV
## CPU copies of the car meshes' surface arrays (reading them back from the GPU
## costs tens of milliseconds a time): mesh -> [arrays per surface].
static var _arrays := {}


## Give `node` (showing a car mesh) its own copy to dent; returns the car's damage
## state for hit(). `paint` is put on the paint surface (a parked car's colour).
static func batter(node: MeshInstance3D, paint: Material = null) -> Dictionary:
	var source := node.mesh
	var state := {
		"arrays": [], "orig": [], "orig_normals": [], "materials": [], "overrides": [],
		"dentable": [], "glass_surface": -1, "lights": [], "hits": [],
		"glass": null, "alarm": null, "alarm_left": 0.0, "horn_ready": true, "node": node, "adj": {},
	}
	var source_arrays := arrays_of(source)
	for s in source.get_surface_count():
		var arrays: Array = (source_arrays[s] as Array).duplicate() # vertices and normals copy on write
		state["arrays"].append(arrays)
		state["orig"].append((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate())
		var normals = arrays[Mesh.ARRAY_NORMAL]
		state["orig_normals"].append((normals as PackedVector3Array).duplicate() if normals != null else PackedVector3Array())
		var material := source.surface_get_material(s)
		state["materials"].append(material)
		var override := node.get_surface_override_material(s)
		var name := material.resource_name if material != null else ""
		if name == "Paint" and paint != null:
			override = paint
		if name == "Glass":
			state["glass_surface"] = s
			var glass := ShaderMaterial.new()
			glass.shader = GLASS_SHADER
			glass.set_shader_parameter("hits", PackedVector4Array([Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4()]))
			state["glass"] = glass
			override = glass
		if name in ["HeadLight", "TailLight"]:
			var lamp := StandardMaterial3D.new()
			lamp.albedo_color = Color(0.9, 0.88, 0.8) if name == "HeadLight" else Color(0.6, 0.05, 0.04)
			lamp.emission_enabled = true
			lamp.emission = Color(1.0, 0.75, 0.35) if name == "HeadLight" else Color(1.0, 0.1, 0.05)
			lamp.emission_energy_multiplier = 0.0
			state["lights"].append(lamp)
			override = lamp
		state["overrides"].append(override)
		if name not in NO_DENT:
			state["dentable"].append(s)
	_rebuild(state)
	return state


## First point of a car's body the line from -> to (world) touches: {point, normal}
## in the car's own space and whether it is a window, or {} if it misses the car.
static func ray_mesh(mesh: Mesh, xf: Transform3D, from: Vector3, to: Vector3) -> Dictionary:
	var inverse := xf.affine_inverse()
	var a := inverse * from
	var b := inverse * to
	var dir := b - a
	var best := INF
	var result := {}
	var all_arrays := arrays_of(mesh)
	for s in mesh.get_surface_count():
		var material := mesh.surface_get_material(s)
		var name := material.resource_name if material != null else ""
		if name in NO_DENT:
			continue
		var arrays: Array = all_arrays[s]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices == null:
			continue
		var idx: PackedInt32Array = indices
		for t in range(0, idx.size(), 3):
			var p0 := verts[idx[t]]
			var p1 := verts[idx[t + 1]]
			var p2 := verts[idx[t + 2]]
			var hit = Geometry3D.segment_intersects_triangle(a, b, p0, p1, p2)
			if hit == null:
				continue
			var d := a.distance_squared_to(hit)
			if d < best:
				best = d
				var normal := (p1 - p0).cross(p2 - p0).normalized()
				if normal.dot(dir) > 0.0:
					normal = -normal
				result = {"point": hit, "normal": normal, "glass": name == "Glass"}
	return result


## The mesh's surface arrays, from the CPU copy (a battered car's own, or the cache).
static func arrays_of(mesh: Mesh) -> Array:
	if mesh.has_meta("car_arrays"):
		return mesh.get_meta("car_arrays")
	if not _arrays.has(mesh):
		var list := []
		for s in mesh.get_surface_count():
			list.append(mesh.surface_get_arrays(s))
		_arrays[mesh] = list
	return _arrays[mesh]


## One blow at `point` (car space), the bat moving along `dir` (car space).
## `parked`: the alarm goes off; otherwise the driver honks.
static func hit(state: Dictionary, point: Vector3, dir: Vector3, glass: bool, parked: bool) -> void:
	var node := state["node"] as MeshInstance3D
	if not is_instance_valid(node):
		return
	dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.DOWN
	_dent(state, point, dir, DENT_DEPTH * (0.35 if glass else 1.0))
	var world := node.global_transform * point
	var ground := node.global_position.y
	if glass and state["glass"] != null:
		var hits: Array = state["hits"]
		var crumbled := false
		var near := -1
		for k in hits.size():
			var h: Vector4 = hits[k]
			if Vector3(h.x, h.y, h.z).distance_to(point) < 0.38:
				near = k
				break
		if near >= 0:
			if (hits[near] as Vector4).w < 2.0:
				var h: Vector4 = hits[near]
				h.w = 2.0
				hits[near] = h
				crumbled = true
		else:
			hits.append(Vector4(point.x, point.y, point.z, 1.0))
			if hits.size() > 8:
				hits.pop_front()
		var packed := PackedVector4Array()
		for k in 8:
			packed.append(hits[k] if k < hits.size() else Vector4())
		(state["glass"] as ShaderMaterial).set_shader_parameter("hits", packed)
		if crumbled:
			GlassFx.crumble(node, world, ground, 30)
			GlassFx.play(node, world, GlassFx.SHATTER_SOUND, 7.0, -5.0, randf_range(1.2, 1.4))
		else:
			GlassFx.crack_sound(node, world)
			GlassFx.crumble(node, world, ground, 6)
	GlassFx.play(node, world, DENT_SOUND, 9.0, 1.0 if not glass else -6.0, randf_range(0.85, 1.12))
	if parked:
		_sound_alarm(state)
	elif state["horn_ready"]:
		_honk(state)


## The battered mesh, to leave behind as a burnt shell if the car is shot later.
static func mesh_of(state: Dictionary) -> Mesh:
	return (state["node"] as MeshInstance3D).mesh


## Stop the alarm (the car is blown up or towed away).
static func silence(state: Dictionary) -> void:
	if state["alarm"] != null and is_instance_valid(state["alarm"]):
		(state["alarm"] as Node).queue_free()
	state["alarm"] = null


static func _dent(state: Dictionary, point: Vector3, dir: Vector3, depth: float) -> void:
	var r2 := DENT_RADIUS * DENT_RADIUS
	for s in state["dentable"]:
		var arrays: Array = state["arrays"][s]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var orig: PackedVector3Array = state["orig"][s]
		var moved: Array[int] = []
		for i in verts.size():
			var d2 := verts[i].distance_squared_to(point)
			if d2 >= r2:
				continue
			var w := 1.0 - d2 / r2
			w *= w
			var o := orig[i]
			var crumple := 0.7 + 0.6 * absf(sin(o.x * 41.0 + o.y * 29.0 + o.z * 37.0))
			var v := verts[i] + dir * depth * w * crumple
			var off := v - o
			if off.length() > MAX_DENT:
				v = o + off.normalized() * MAX_DENT
			verts[i] = v
			moved.append(i)
		if moved.is_empty():
			continue
		arrays[Mesh.ARRAY_VERTEX] = verts
		var normals_v = arrays[Mesh.ARRAY_NORMAL]
		var indices = arrays[Mesh.ARRAY_INDEX]
		if normals_v == null or indices == null:
			continue
		var normals: PackedVector3Array = normals_v
		var orig_normals: PackedVector3Array = state["orig_normals"][s]
		var idx: PackedInt32Array = indices
		var adj := _adjacency(state, s, verts.size(), idx)
		# Every vertex of a triangle that moved gets its normal rebuilt from all its triangles.
		var affected := {}
		for i in moved:
			for t: int in adj[i]:
				affected[idx[t]] = true
				affected[idx[t + 1]] = true
				affected[idx[t + 2]] = true
		for k: int in affected:
			var sum := Vector3.ZERO
			for t: int in adj[k]:
				var a := idx[t]
				var b := idx[t + 1]
				var c := idx[t + 2]
				var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
				if n.dot(orig_normals[a] + orig_normals[b] + orig_normals[c]) < 0.0:
					n = -n
				sum += n
			if sum.length_squared() > 1e-14:
				normals[k] = sum.normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
	_rebuild(state)


## Per vertex of surface `s`: the triangles using it (index of their first corner).
static func _adjacency(state: Dictionary, s: int, count: int, idx: PackedInt32Array) -> Array:
	if state["adj"].has(s):
		return state["adj"][s]
	var adj := []
	adj.resize(count)
	for i in count:
		adj[i] = []
	for t in range(0, idx.size(), 3):
		(adj[idx[t]] as Array).append(t)
		(adj[idx[t + 1]] as Array).append(t)
		(adj[idx[t + 2]] as Array).append(t)
	state["adj"][s] = adj
	return adj


static func _rebuild(state: Dictionary) -> void:
	var mesh := ArrayMesh.new()
	for s in state["arrays"].size():
		var arrays: Array = state["arrays"][s]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(s, state["materials"][s])
	mesh.set_meta("car_arrays", state["arrays"])
	var node := state["node"] as MeshInstance3D
	node.mesh = mesh
	for s in state["overrides"].size():
		node.set_surface_override_material(s, state["overrides"][s])


static func _sound_alarm(state: Dictionary) -> void:
	state["alarm_left"] = ALARM_TIME
	if state["alarm"] != null and is_instance_valid(state["alarm"]):
		return
	var node := state["node"] as MeshInstance3D
	if _alarm_loop == null:
		var wav := load(ALARM_SOUND) as AudioStreamWAV
		_alarm_loop = wav.duplicate() as AudioStreamWAV
		_alarm_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_alarm_loop.loop_begin = 0
		_alarm_loop.loop_end = int(wav.get_length() * wav.mix_rate)
	var alarm := AudioStreamPlayer3D.new()
	alarm.name = "Alarm"
	alarm.stream = _alarm_loop
	alarm.unit_size = 12.0
	alarm.max_distance = 220.0
	alarm.volume_db = -2.0
	alarm.position = Vector3(0, 0.8, 0)
	node.add_child(alarm)
	alarm.play()
	state["alarm"] = alarm
	# Lights flash with the siren until it gives up.
	var blink := Timer.new()
	blink.wait_time = 0.4
	alarm.add_child(blink)
	var lit := [false]
	blink.timeout.connect(func() -> void:
		state["alarm_left"] = float(state["alarm_left"]) - blink.wait_time
		lit[0] = not lit[0] and float(state["alarm_left"]) > 0.0
		for lamp in state["lights"]:
			(lamp as StandardMaterial3D).emission_energy_multiplier = 4.0 if lit[0] else 0.0
		if float(state["alarm_left"]) <= 0.0:
			silence(state)
	)
	blink.start()


static func _honk(state: Dictionary) -> void:
	var node := state["node"] as MeshInstance3D
	state["horn_ready"] = false
	var pitch := randf_range(0.9, 1.1)
	for k in randi_range(1, 3):
		var delay := k * 0.32
		node.get_tree().create_timer(0.15 + delay).timeout.connect(func() -> void:
			if is_instance_valid(node):
				var horn := AudioStreamPlayer3D.new()
				horn.stream = HORN_SOUND
				horn.unit_size = 14.0
				horn.max_distance = 200.0
				horn.pitch_scale = pitch
				horn.position = Vector3(0, 0.7, 1.8)
				node.add_child(horn)
				horn.play()
				horn.finished.connect(horn.queue_free)
		)
	node.get_tree().create_timer(1.5).timeout.connect(func() -> void: state["horn_ready"] = true)
