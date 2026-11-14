extends Node3D
## Cars driving along the main streets (Dr. E. Beneše, 28. října). Each lane is a
## straight line that runs out into the forest at both ends, where cars wrap round
## unseen. Cars brake for people and for the car in front, and hum as they go.
## Local to each client: traffic is scenery, not gameplay state.

const ENGINE_SOUND := "res://audio/car_engine.wav"
const LOOK_AHEAD := 22.0
const STOP_GAP := 6.5
const LANE_HALF_WIDTH := 1.9

## Lanes: [start (game xz), end (game xz), cars on it]; set before adding to the tree.
var lanes: Array = []
## Car models: [mesh, collision size Vector3, paint material to replace].
var models: Array = []
var colors: Array = []

var _cars: Array = [] # {body, lane, s, speed, cruise, half, sound}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2770
	var engine := _looping_wav(ENGINE_SOUND)
	for lane_index in lanes.size():
		var lane: Array = lanes[lane_index]
		var length: float = (lane[1] as Vector2).distance_to(lane[0])
		var count: int = lane[2]
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
			paint.metallic = 0.45
			paint.roughness = 0.28
			for surface in (model[0] as Mesh).get_surface_count():
				if (model[0] as Mesh).surface_get_material(surface) == model[2]:
					mesh_node.set_surface_override_material(surface, paint)
			body.add_child(mesh_node)
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
			})
			sound.play(_rng.randf_range(0.0, 1.5))


func _physics_process(delta: float) -> void:
	var people: Array = []
	for group in ["player", "remote_players", "villagers", "civilians"]:
		for node in get_tree().get_nodes_in_group(group):
			if (node as Node3D).is_visible_in_tree():
				people.append(node)
	for car in _cars:
		var lane: Array = lanes[car["lane"]]
		var a: Vector2 = lane[0]
		var b: Vector2 = lane[1]
		var length := a.distance_to(b)
		var dir2 := (b - a) / length
		var dir := Vector3(dir2.x, 0.0, dir2.y)
		var pos := Vector3(a.x, 0.0, a.y) + dir * float(car["s"])
		var gap := LOOK_AHEAD
		for person in people:
			gap = minf(gap, _gap_to((person as Node3D).global_position, pos, dir) - float(car["half"]))
		for other in _cars:
			if other == car or other["lane"] != car["lane"]:
				continue
			var ds := fposmod(float(other["s"]) - float(car["s"]), length)
			if ds > 0.0 and ds < LOOK_AHEAD:
				gap = minf(gap, ds - float(car["half"]) - float(other["half"]))
		var target: float = car["cruise"]
		if gap < LOOK_AHEAD:
			target = clampf((gap - STOP_GAP) / (LOOK_AHEAD - STOP_GAP), 0.0, 1.0) * float(car["cruise"])
		var rate := 7.0 if target < float(car["speed"]) else 2.5
		car["speed"] = move_toward(float(car["speed"]), target, rate * delta)
		car["s"] = fposmod(float(car["s"]) + float(car["speed"]) * delta, length)
		pos = Vector3(a.x, 0.0, a.y) + dir * float(car["s"])
		(car["body"] as Node3D).global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), pos)
		var sound := car["sound"] as AudioStreamPlayer3D
		sound.pitch_scale = 0.75 + float(car["speed"]) / 16.0


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
