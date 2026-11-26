extends Node3D
## Cars drive along district lanes. Straight estate lanes wrap unseen in the forest.
## In Paris the lanes form continuous loops. Cars brake for people and other cars.
## Local to each client: traffic is scenery, not gameplay state, except that a car
## shot by a player blows up (car_fire.gd) on everyone's screen at the same spot of
## its lane; it stands there burning, the cars behind queue up, and once the wreck
## has burnt out it is towed away and a new car joins the lane.

const ENGINE_SOUND := "res://audio/car_engine.wav"
const LOOK_AHEAD := 22.0
const STOP_GAP := 6.5
const LANE_HALF_WIDTH := 1.9

## Lanes: [start (game xz), end (game xz), cars on it], or [[points (game xz)...], cars on it]
## for a lane that turns a corner. With smooth_loops, omit the repeated closing point.
var lanes: Array = []
## Closed lanes can use baked curves, with rounded turns and speed limits.
var smooth_loops := false
## Car models: [mesh, collision size Vector3, paint material to replace], optionally followed
## by a fixed paint colour (a taxi is always yellow; null = random) and extra parts
## [[mesh, Transform3D, material], ...] such as a roof sign.
var models: Array = []
var colors: Array = []
## Optional traffic lights, per lane: [[distance along the lane of the stop line, axis], ...];
## axis 0 = the light for traffic along game Z, 1 = along X (see light_state()).
var stops: Array = []

## Signal cycle in seconds, the same on every client (wall clock): Z-traffic green, yellow,
## all red, X-traffic green, yellow, all red.
const CYCLE := [24.0, 3.0, 2.0, 18.0, 3.0, 2.0]

var _cars: Array = [] # {body, lane, s, speed, cruise, half, sound, mesh_node, paint, model, wreck}
var _paths: Array = [] # per lane: {"points": Array[Vector2], "ends": Array[float] (distance at each point), "length"}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2770
	var engine := _looping_wav(ENGINE_SOUND)
	for model in models:
		CarDamage.arrays_of(model[0]) # read back now rather than at the first bat blow
	for lane_index in lanes.size():
		var lane: Array = lanes[lane_index]
		var points: Array = lane[0] if lane[0] is Array else [lane[0], lane[1]]
		var length: float
		if smooth_loops:
			var curve := _bake_loop(points)
			length = curve.get_baked_length()
			_paths.append({"curve": curve, "length": length})
		else:
			var ends: Array[float] = [0.0]
			for index in range(1, points.size()):
				ends.append(ends[-1] + (points[index] as Vector2).distance_to(points[index - 1]))
			length = ends[-1]
			_paths.append({"points": points, "ends": ends, "length": length})
		var count: int = lane[-1]
		for k in count:
			var model: Array = models[_rng.randi() % models.size()]
			var body := AnimatableBody3D.new()
			body.name = "TrafficCar"
			body.sync_to_physics = false
			var size: Vector3 = model[1]
			var shape := BoxShape3D.new()
			shape.size = Vector3(size.x, size.y - 0.15, size.z - 0.1)
			var shape_node := CollisionShape3D.new()
			shape_node.shape = shape
			shape_node.position.y = size.y * 0.5 + 0.07
			body.add_child(shape_node)
			var mesh_node := MeshInstance3D.new()
			mesh_node.mesh = model[0]
			var paint := StandardMaterial3D.new()
			paint.albedo_color = colors[_rng.randi() % colors.size()]
			if model.size() > 3 and model[3] != null:
				paint.albedo_color = model[3]
			paint.metallic = 0.45
			paint.roughness = 0.28
			for surface in (model[0] as Mesh).get_surface_count():
				if (model[0] as Mesh).surface_get_material(surface) == model[2]:
					mesh_node.set_surface_override_material(surface, paint)
			body.add_child(mesh_node)
			if model.size() > 4:
				for extra in model[4]:
					var part := MeshInstance3D.new()
					part.mesh = extra[0]
					part.transform = extra[1]
					part.material_override = extra[2]
					mesh_node.add_child(part)
			var sound := AudioStreamPlayer3D.new()
			sound.stream = engine
			sound.unit_size = 5.0
			sound.max_distance = 70.0
			sound.volume_db = -6.0
			body.add_child(sound)
			add_child(body)
			var cruise := _rng.randf_range(8.0, 12.5)
			_cars.append({
				"body": body, "lane": lane_index, "s": length * (k + _rng.randf_range(0.0, 0.6)) / count,
				"speed": cruise, "cruise": cruise, "half": size.z * 0.5, "sound": sound,
				"mesh_node": mesh_node, "paint": paint, "model": model, "wreck": null, "battered": null,
			})
			sound.play(_rng.randf_range(0.0, 1.5))


func _physics_process(delta: float) -> void:
	var people: Array = []
	for group in ["player", "remote_players", "villagers", "civilians"]:
		for node in get_tree().get_nodes_in_group(group):
			if (node as Node3D).is_visible_in_tree():
				people.append(node)
	for car in _cars:
		if car["wreck"] != null:
			continue # burning where it stopped
		var path: Dictionary = _paths[car["lane"]]
		var length: float = path["length"]
		var placed := _place(path, float(car["s"]))
		var pos: Vector3 = placed[0]
		var dir: Vector3 = placed[1]
		var gap := LOOK_AHEAD
		for person in people:
			gap = minf(gap, _gap_to((person as Node3D).global_position, pos, dir) - float(car["half"]))
		for other in _cars:
			if other == car:
				continue
			if other["lane"] == car["lane"]:
				var ds := fposmod(float(other["s"]) - float(car["s"]), length)
				if ds > 0.0 and ds < LOOK_AHEAD:
					gap = minf(gap, ds - float(car["half"]) - float(other["half"]))
			else:
				# Lanes that share a stretch of road or cross: keep clear of cars ahead in them too.
				var other_pos := (other["body"] as Node3D).global_position
				gap = minf(gap, _gap_to(other_pos, pos, dir) - float(car["half"]) - float(other["half"]))
		if car["lane"] < stops.size():
			for stop in stops[car["lane"]]:
				var to_line := fposmod(float(stop[0]) - float(car["s"]), length)
				if to_line > LOOK_AHEAD + 4.0:
					continue
				var state := light_state(int(stop[1]))
				if state == 2 or (state == 1 and to_line > 9.0):
					gap = minf(gap, to_line - float(car["half"]) - 0.5)
		var target: float = car["cruise"]
		if gap < LOOK_AHEAD:
			target = clampf((gap - STOP_GAP) / (LOOK_AHEAD - STOP_GAP), 0.0, 1.0) * float(car["cruise"])
		if path.has("curve"):
			var curve: Curve2D = path["curve"]
			var ahead := curve.sample_baked_with_rotation(fposmod(float(car["s"]) + 11.0, length)).x
			var turn := Vector2(dir.x, dir.z).angle_to(ahead)
			target = minf(target, lerpf(float(car["cruise"]), 4.4, clampf(absf(turn) / (PI * 0.5), 0.0, 1.0)))
		var rate := 7.0 if target < float(car["speed"]) else 2.5
		car["speed"] = move_toward(float(car["speed"]), target, rate * delta)
		car["s"] = fposmod(float(car["s"]) + float(car["speed"]) * delta, length)
		placed = _place(path, float(car["s"]))
		pos = placed[0]
		dir = placed[1]
		(car["body"] as Node3D).global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), pos)
		var sound := car["sound"] as AudioStreamPlayer3D
		sound.pitch_scale = 0.75 + float(car["speed"]) / 16.0


## 0 green, 1 yellow, 2 red for traffic along game Z (axis 0) or X (axis 1).
static func light_state(axis: int) -> int:
	var total := 0.0
	for part in CYCLE:
		total += part
	var t := fposmod(Time.get_unix_time_from_system(), total)
	var phase := 0
	while phase < CYCLE.size() - 1 and t >= CYCLE[phase]:
		t -= CYCLE[phase]
		phase += 1
	# Phases 0-2 belong to axis 0, 3-5 to axis 1: green, yellow, then red.
	var own := phase if axis == 0 else (phase + 3) % 6
	return [0, 1, 2, 2, 2, 2][own]


## Which car a bullet hit (hit dictionary from a ray), or -1.
func car_index_at(hit: Dictionary) -> int:
	for index in _cars.size():
		if _cars[index]["body"] == hit.get("collider"):
			return index
	return -1


## Where the car is along its lane, so other clients blow it up at the same spot.
func car_progress(index: int) -> float:
	return float(_cars[index]["s"]) if index >= 0 and index < _cars.size() else -1.0


## Cars (indices) on the road and not wrecks within `radius` of `centre`.
func cars_near(centre: Vector3, radius: float) -> Array[int]:
	var found: Array[int] = []
	for index in _cars.size():
		if _cars[index]["wreck"] == null and (_cars[index]["body"] as Node3D).global_position.distance_to(centre) < radius:
			found.append(index)
	return found


## Where a car is now (world).
func car_transform(index: int) -> Transform3D:
	return (_cars[index]["body"] as Node3D).global_transform if index >= 0 and index < _cars.size() else Transform3D()


## The car's mesh as it looks now (battered or not).
func car_mesh(index: int) -> Mesh:
	return (_cars[index]["mesh_node"] as MeshInstance3D).mesh


## A bat blow at `point`, the bat moving along `dir` (both in the car's own space):
## the car dents, its windows craze, the driver honks and drives on. Not a wreck.
func car_is_dented(index: int) -> bool:
	return index >= 0 and index < _cars.size() and _cars[index]["battered"] != null


func dent_car(index: int, point: Vector3, dir: Vector3, glass: bool) -> bool:
	if index < 0 or index >= _cars.size() or _cars[index]["wreck"] != null:
		return false
	var car: Dictionary = _cars[index]
	if car["battered"] == null:
		car["battered"] = CarDamage.batter(car["mesh_node"])
	CarDamage.hit(car["battered"], point, dir, glass, false)
	return true


## Shot: the car blows up where it is (or at `s` along its lane, as the shooter saw
## it) and burns there; `by` fired the shot. False if it is already a wreck.
func blow_up_car(index: int, s: float, by: int) -> bool:
	if index < 0 or index >= _cars.size() or _cars[index]["wreck"] != null:
		return false
	var car: Dictionary = _cars[index]
	var path: Dictionary = _paths[car["lane"]]
	if s >= 0.0:
		car["s"] = fposmod(s, float(path["length"]))
	var placed := _place(path, float(car["s"]))
	var body := car["body"] as Node3D
	body.global_transform = Transform3D(Basis.looking_at(-(placed[1] as Vector3), Vector3.UP), placed[0])
	car["speed"] = 0.0
	(car["sound"] as AudioStreamPlayer3D).stop()
	(car["mesh_node"] as Node3D).visible = false
	var model: Array = car["model"]
	var mesh: Mesh = model[0]
	if car["battered"] != null:
		CarDamage.silence(car["battered"])
		mesh = CarDamage.mesh_of(car["battered"]) # it burns out battered
	car["wreck"] = CarFire.explode(self, body.global_transform, model[1], mesh)
	CarFire.blast(get_tree(), body.global_position, by)
	get_tree().create_timer(CarFire.TOTAL_TIME).timeout.connect(_tow_away.bind(index))
	return true


## The burnt-out wreck goes; a fresh car in a new colour drives off from there.
func _tow_away(index: int) -> void:
	var car: Dictionary = _cars[index]
	if car["wreck"] != null:
		(car["wreck"] as Node).queue_free()
	car["wreck"] = null
	var model: Array = car["model"]
	if car["battered"] != null:
		# The new car comes without the old one's dents and broken glass.
		var node := car["mesh_node"] as MeshInstance3D
		node.mesh = model[0]
		for s in node.get_surface_override_material_count():
			var material := (model[0] as Mesh).surface_get_material(s)
			node.set_surface_override_material(s, car["paint"] if material == model[2] else null)
		car["battered"] = null
	(car["paint"] as StandardMaterial3D).albedo_color = model[3] if model.size() > 3 and model[3] != null else colors[_rng.randi() % colors.size()]
	(car["mesh_node"] as Node3D).visible = true
	(car["sound"] as AudioStreamPlayer3D).play()


## [position, heading] at distance `s` along a lane; corners are rounded over the last few metres.
func _place(path: Dictionary, s: float) -> Array:
	if path.has("curve"):
		var curve: Curve2D = path["curve"]
		var pose := curve.sample_baked_with_rotation(s)
		return [Vector3(pose.origin.x, 0.0, pose.origin.y), Vector3(pose.x.x, 0.0, pose.x.y)]
	var points: Array = path["points"]
	var ends: Array[float] = path["ends"]
	var index := 1
	while index < points.size() - 1 and ends[index] < s:
		index += 1
	var a: Vector2 = points[index - 1]
	var b: Vector2 = points[index]
	var segment := maxf(ends[index] - ends[index - 1], 0.001)
	var dir2 := (b - a) / segment
	var at := a + dir2 * clampf(s - ends[index - 1], 0.0, segment)
	# Turn smoothly: blend the heading into the next segment's over the last 6 m.
	if index < points.size() - 1:
		var left := ends[index] - s
		if left < 6.0:
			var next_dir := ((points[index + 1] as Vector2) - b).normalized()
			var t := 1.0 - left / 6.0
			dir2 = dir2.lerp(next_dir, t * 0.5).normalized()
			at += (next_dir - (b - a).normalized()) * t * t * 1.5
	if index > 1:
		var into := s - ends[index - 1]
		if into < 6.0:
			var prev_dir := (a - (points[index - 2] as Vector2)).normalized()
			var t := 1.0 - into / 6.0
			dir2 = dir2.lerp(prev_dir, t * 0.5).normalized()
			at += ((b - a).normalized() - prev_dir) * t * t * 1.5
	return [Vector3(at.x, 0.0, at.y), Vector3(dir2.x, 0.0, dir2.y)]


## Round the corners without cutting across blocks. The seam sits on a straight
## section, with the same position and heading on both sides of the wrap.
static func _bake_loop(points: Array) -> Curve2D:
	var curve := Curve2D.new()
	curve.bake_interval = 0.35
	var seam := (points[-1] as Vector2).lerp(points[0], 0.5)
	curve.add_point(seam)
	for index in points.size():
		var corner: Vector2 = points[index]
		var incoming := (points[index - 1] as Vector2) - corner
		var outgoing := (points[(index + 1) % points.size()] as Vector2) - corner
		var entry := corner + incoming.limit_length(minf(5.5, incoming.length() * 0.42))
		var exit := corner + outgoing.limit_length(minf(5.5, outgoing.length() * 0.42))
		curve.add_point(entry, Vector2.ZERO, (corner - entry) * (2.0 / 3.0))
		curve.add_point(exit, (corner - exit) * (2.0 / 3.0))
	curve.add_point(seam)
	return curve


## Distance along the lane to `point` if it stands in the lane ahead, else LOOK_AHEAD.
func _gap_to(point: Vector3, pos: Vector3, dir: Vector3) -> float:
	var rel := point - pos
	rel.y = 0.0
	var along := rel.dot(dir)
	if along <= 0.0 or along > LOOK_AHEAD:
		return LOOK_AHEAD
	var lateral := (rel - dir * along).length()
	return along if lateral < LANE_HALF_WIDTH + 0.6 else LOOK_AHEAD


static func _looping_wav(path: String) -> AudioStream:
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		return null
	stream = stream.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream
