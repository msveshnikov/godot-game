extends SceneTree
## Bat test: puts the player in front of a shop window and next to a parked car in
## Times Square, swings the bat at them and saves before/after shots to
## screenshots/smash/.
##   godot --path . -s tools/smash_test.gd -- --loc=nyc --server=ws://127.0.0.1:1

var _scene: Node
var _camera: Camera3D
var _out := "res://screenshots/smash"


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_scene = (load("res://node_2d.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_run.call_deferred()


func _wait(frames: int) -> void:
	for k in frames:
		await process_frame


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)
	_camera.make_current()
	await _wait(4)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [_out, name]))
	print("saved ", name)


func _face(player: Node3D, at: Vector3, target: Vector3) -> void:
	var dir := target - at
	dir.y = 0.0
	dir = dir.normalized()
	player.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), at)
	(player.get("camera_pivot") as Node3D).rotation = Vector3(-0.08, 0, 0)


func _swing(player: Node) -> void:
	await physics_frame
	await physics_frame
	var started := Time.get_ticks_usec()
	player.call("_bat_hit")
	print("  swing took %.1f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	await _wait(20)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _wait(90)
	var player := get_first_node_in_group("player") as Node3D
	player.call("_start_game")
	player.call("set_weapon", "bat")
	for layer in _scene.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	_camera = Camera3D.new()
	_camera.far = 3000.0
	_scene.add_child(_camera)
	var district := _scene.get_node("Diorama/District")
	# Villagers would soak up the blows: send them away.
	for villager in get_nodes_in_group("villagers"):
		(villager as Node3D).global_position += Vector3(0, -500, 0)

	# A shop window: the longest street-level wall near the bowtie.
	var walls: Array = district.get("_shop_walls")
	var pick: Array = []
	for w in walls:
		var mid: Vector2 = ((w[0] as Vector2) + (w[1] as Vector2)) * 0.5
		var length := (w[0] as Vector2).distance_to(w[1])
		if length > 20.0 and mid.distance_to(Vector2(-20, 60)) < 120.0:
			pick = w
			break
	print("shop walls: ", walls.size(), " picked ", pick)
	var a: Vector2 = pick[0]
	var b: Vector2 = pick[1]
	var d := (b - a).normalized()
	var out := Vector2(d.y, -d.x)
	var unit: float = district.call("shop_unit", pick[3])
	for k in 2:
		# Middle of the window of shop k along the wall (left part, away from the door).
		var s: float = float(pick[2])
		var first := ceilf(s / unit) * unit - s
		var x := first + unit * (k + 0.3)
		var p := a + d * x
		var stand := p + out * 1.3
		var face := Vector3(p.x, 0.0, p.y)
		if k == 0:
			await _shot("window_before", Vector3(stand.x + out.x * 3.0, 1.7, stand.y + out.y * 3.0), face + Vector3.UP * 1.8)
		_face(player, Vector3(stand.x, 0.9, stand.y), face)
		await _swing(player)
		if k == 0:
			await _shot("window_cracked", Vector3(stand.x + out.x * 2.5, 1.6, stand.y + out.y * 2.5), face + Vector3.UP * 1.8)
		await _swing(player)
		await _wait(40)
	var view := a + d * (ceilf(float(pick[2]) / unit) * unit - float(pick[2]) + unit) + out * 5.5
	var look := a + d * (ceilf(float(pick[2]) / unit) * unit - float(pick[2]) + unit)
	var shards = GlassFx._shards
	print("shards node ", shards, " inside ", shards.is_inside_tree() if shards != null else false, " count ", shards.multimesh.visible_instance_count if shards != null else -1)
	if shards != null and shards.multimesh.visible_instance_count > 0:
		var first: Vector3 = shards.multimesh.get_instance_transform(0).origin
		print("  first shard at ", first)
		await _shot("shard_close", first + Vector3(0.0, 0.9, 0.0) + Vector3(out.x, 0, out.y) * 0.8, first)
	await _shot("window_smashed", Vector3(view.x, 1.7, view.y), Vector3(look.x, 1.5, look.y))
	await _shot("window_shards", Vector3(view.x - out.x * 3.0, 1.2, view.y - out.y * 3.0), Vector3(look.x + out.x * 1.0, 0.0, look.y + out.y * 1.0))

	# A parked car: three blows on the bonnet side, two on the windows.
	var spots: Array = district.get("_car_spots")
	var spot: Transform3D = (district as Node3D).global_transform * (spots[spots.size() / 2] as Transform3D)
	var car_side := spot.basis.x.normalized()
	var car_fwd := spot.basis.z.normalized()
	await _shot("car_before", spot.origin + car_side * 4.0 + car_fwd * 2.0 + Vector3.UP * 1.8, spot.origin + Vector3.UP * 0.8)
	for k in 5:
		var along: float = [1.2, 0.6, 1.4, -0.3, 0.1][k]
		var stand := spot.origin + car_side * 1.75 + car_fwd * along
		stand.y = 0.9
		var target := spot.origin + car_fwd * along
		_face(player, stand, target)
		await _swing(player)
	var battered: Dictionary = district.get("_battered")
	for key in battered:
		var state: Dictionary = battered[key]
		var t := Time.get_ticks_usec()
		CarDamage._dent(state, Vector3(0.8, 0.9, 1.0), Vector3.LEFT, 0.01)
		print("  dent alone %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
		t = Time.get_ticks_usec()
		CarDamage._rebuild(state)
		print("  rebuild alone %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
		t = Time.get_ticks_usec()
		CarDamage.ray_mesh(CarDamage.mesh_of(state), Transform3D(), Vector3(3, 1, 0), Vector3(-3, 1, 0))
		print("  ray alone %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
		t = Time.get_ticks_usec()
		GlassFx.crumble(_scene, Vector3(0, 1, 0), 0.0, 6)
		print("  crumble alone %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	player.global_position += Vector3(0, -50, 0)
	await _wait(30)
	await _shot("car_after", spot.origin + car_side * 4.0 + car_fwd * 2.0 + Vector3.UP * 1.8, spot.origin + Vector3.UP * 0.8)
	await _shot("car_close", spot.origin + car_side * 2.2 + car_fwd * 0.6 + Vector3.UP * 1.6, spot.origin + Vector3.UP * 0.9 + car_fwd * 0.6)
	# A driving car: a few blows straight from the code, then a look as it drives on.
	var traffic := district.get_node("Traffic")
	var xf: Transform3D = traffic.call("car_transform", 0)
	for blow in [[Vector3(0.0, 1.45, 0.3), Vector3.DOWN, false], [Vector3(0.85, 0.85, 1.2), Vector3.LEFT, false], [Vector3(0.75, 1.2, -0.2), Vector3.LEFT, true], [Vector3(0.75, 1.2, -0.2), Vector3.LEFT, true]]:
		traffic.call("dent_car", 0, blow[0], blow[1], blow[2])
	await _wait(3)
	xf = traffic.call("car_transform", 0)
	await _shot("traffic_dented", xf.origin + xf.basis.x * 3.5 + xf.basis.z * 2.5 + Vector3.UP * 2.0, xf.origin + Vector3.UP * 0.8)
	quit()
