extends SceneTree
## Bazooka test: buys the bazooka and rockets (checks the price and the 5-rocket
## cap), takes it in hand, fires at the cars nearby, into the street (crater),
## up a tall building (hole high up), and at a shop front (windows out), and
## shows the shop's weapons row. Screenshots go to screenshots/bazooka/. The saved
## progress (user://progress.cfg) is put back as it was.
##   godot --path . -s tools/bazooka_test.gd -- --loc=nyc --server=ws://127.0.0.1:1 [--size=1600x720]

var _scene: Node
var _out := "res://screenshots/bazooka"
var _player: CharacterBody3D
var _game: Node


func _initialize() -> void:
	var window_size := Vector2i(1600, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var wh := arg.trim_prefix("--size=").split("x")
			window_size = Vector2i(int(wh[0]), int(wh[1]))
	DisplayServer.window_set_size(window_size)
	_scene = (load("res://node_2d.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_run.call_deferred()


func _wait(frames: int) -> void:
	for k in frames:
		await process_frame


func _seconds(t: float) -> void:
	await create_timer(t).timeout


func _snap(name: String) -> void:
	await _wait(2)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [_out, name]))
	print("saved ", name)


## Turn the player and tilt the camera so the crosshair sits on `target`.
func _aim_at(target: Vector3) -> void:
	var flat := target - _player.global_position
	_player.rotation.y = atan2(-flat.x, -flat.z)
	var pivot := _player.get("camera_pivot") as Node3D
	for k in 4:
		await physics_frame
		var camera := _player.get("camera") as Camera3D
		var dir := camera.global_position.direction_to(target)
		pivot.rotation.x = clampf(asin(dir.y), deg_to_rad(-60.0), deg_to_rad(35.0))
	await _wait(3)


func _fire() -> void:
	_player.set("_can_fire", true)
	_player.call("_fire_rocket")


## A side camera looking at `at` from `from`.
func _side_cam(from: Vector3, at: Vector3) -> Camera3D:
	var cam := Camera3D.new()
	_scene.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	return cam


func _wrecks() -> int:
	var district := _scene.get_node("Diorama/District")
	var n := (district.get("_wrecked_spots") as Dictionary).size()
	var traffic := district.get_node_or_null("Traffic")
	if traffic != null:
		for car in traffic.get("_cars"):
			if car["wreck"] != null:
				n += 1
	return n


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _wait(90)
	_player = get_first_node_in_group("player") as CharacterBody3D
	_game = root.get_node("Game")
	var saved := [_game.get("money"), _game.get("has_bazooka"), _game.get("rockets")]
	_player.call("_start_game")
	await _wait(10)
	var police: Node = _scene.get_node("Police")
	police.set("process_mode", Node.PROCESS_MODE_DISABLED) # no patrol car in the shots

	# The shop: too poor, then buy, then fill up past the cap.
	_game.set("money", 500)
	_game.set("has_bazooka", false)
	_game.set("rockets", 0)
	print("buy with $500: ", _game.call("buy_bazooka"), " (want false)")
	_game.set("money", 3000)
	print("buy with $3000: ", _game.call("buy_bazooka"), " money ", _game.get("money"), " (want true, 2000)")
	print("buy 3 rockets: ", _game.call("buy_rockets", 3), " money ", _game.get("money"), " (want 3, 1700)")
	print("buy 9 more: ", _game.call("buy_rockets", 9), " rockets ", _game.get("rockets"), " money ", _game.get("money"), " (want 2, 5, 1500)")
	print("buy 1 more: ", _game.call("buy_rockets", 1), " (want 0)")
	var shop := Shop.open(_player.get("hud") as CanvasLayer)
	await _seconds(0.5)
	await _snap("01_shop")
	shop.queue_free()
	await _wait(3)

	_player.call("set_weapon", "bazooka")
	_game.set("rockets", 5)
	_game.emit_signal("arsenal_changed")
	await _seconds(0.6)
	await _snap("02_holding")
	var model := _player.get("model") as Node3D
	var cam := _side_cam(_player.global_position + _player.global_basis.x * 2.2 - _player.global_basis.z * 1.5 + Vector3.UP * 1.6, _player.global_position + Vector3.UP * 1.2)
	await _snap("03_holding_side")
	cam.global_position = _player.global_position + _player.global_basis.z * -3.0 + Vector3.UP * 1.7
	cam.look_at(_player.global_position + Vector3.UP * 1.3)
	await _snap("04_holding_front")
	(_player.get("camera") as Camera3D).make_current()
	cam.queue_free()

	# The cars: the parked or driving car nearest the player with others round it.
	var district := _scene.get_node("Diorama/District")
	var best := Vector3.INF
	var best_count := 0
	for cars: Node in [district, district.get_node_or_null("Traffic")]:
		if cars == null:
			continue
		for index: int in cars.call("cars_near", _player.global_position, 60.0):
			var at: Vector3 = (cars.call("car_transform", index) as Transform3D).origin
			if at.distance_to(_player.global_position) < 14.0:
				continue
			var around := (district.call("cars_near", at, Rocket.CAR_RADIUS) as Array).size()
			if district.get_node_or_null("Traffic") != null:
				around += (district.get_node("Traffic").call("cars_near", at, Rocket.CAR_RADIUS) as Array).size()
			if around > best_count:
				best_count = around
				best = at
	# Stand 16 m off it, wherever the view to it is clear.
	if best != Vector3.INF:
		var space0 := (_player as Node3D).get_world_3d().direct_space_state
		for k in 16:
			var stand := best + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0) * 16.0
			var look := PhysicsRayQueryParameters3D.create(stand + Vector3.UP * 1.5, best + Vector3.UP * 0.7)
			look.exclude = [_player.get_rid()]
			var seen := space0.intersect_ray(look)
			var clear_ground := space0.intersect_ray(PhysicsRayQueryParameters3D.create(stand + Vector3.UP * 3.0, stand - Vector3.UP * 2.0))
			if not clear_ground.is_empty() and (seen.is_empty() or (seen["position"] as Vector3).distance_to(best) < 3.0):
				_player.global_position = (clear_ground["position"] as Vector3) + Vector3.UP * 0.95
				break
		await _wait(5)
	print("cars target: ", best, " with ", best_count, " cars in the blast radius")
	if best != Vector3.INF:
		var wrecks_before := _wrecks()
		await _aim_at(best + Vector3.UP * 0.7)
		await _snap("05_aim_cars")
		_fire()
		await _seconds(0.12)
		await _snap("06_rocket_flying")
		await _seconds(0.5)
		await _snap("07_cars_blast")
		await _seconds(1.5)
		await _snap("08_cars_after")
		print("cars blown up by one rocket: ", _wrecks() - wrecks_before, "  rockets left ", _game.get("rockets"))
		print("player health ", _player.get("health"))

	# The street: a crater a few metres ahead.
	_player.set("health", 100)
	_player.rotation.y += PI * 0.5
	await _wait(3)
	var ground_target := _player.global_position - _player.global_basis.z * 9.0
	await _aim_at(ground_target)
	(_player.get("camera_pivot") as Node3D).rotation.x = deg_to_rad(-38.0)
	await _wait(3)
	_fire()
	await _seconds(0.6)
	await _snap("09_ground_blast")
	await _seconds(3.0)
	var crater := _find("Crater")
	if crater != null:
		cam = _side_cam(crater.global_position + Vector3(5.0, 3.5, 5.0), crater.global_position)
		await _snap("10_crater")
		(_player.get("camera") as Camera3D).make_current()
		cam.queue_free()
	else:
		print("NO CRATER (rocket hit something else)")
	print("player health ", _player.get("health"))

	# A tall building: look round for the highest wall within 120 m and aim up it.
	_player.set("health", 100)
	if _player.get("_game_over"):
		_player.call("_restart_game")
	var space := (_player as Node3D).get_world_3d().direct_space_state
	var wall := Vector3.INF
	var wall_normal := Vector3.ZERO
	for k in 24:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 24.0)
		var from := _player.global_position + Vector3.UP * 40.0
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * 120.0)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.3:
			if wall == Vector3.INF or from.distance_to(hit["position"]) < _player.global_position.distance_to(wall):
				wall = hit["position"]
				wall_normal = hit["normal"]
	print("tall wall at ", wall)
	if wall != Vector3.INF:
		# Back off 35 m from the wall so the camera can tilt up to the 25th metre.
		var away := _player.global_position + wall_normal * 0.0
		var flat_n := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
		var foot := Vector3(wall.x, 0.0, wall.z) + flat_n * 35.0
		var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 5.0, foot - Vector3.UP * 5.0))
		if not ground.is_empty():
			_player.global_position = (ground["position"] as Vector3) + Vector3.UP * 0.95
		await _wait(4)
		var high := wall
		high.y = 22.0
		await _aim_at(high)
		await _snap("11_aim_high")
		_fire()
		var distance := _player.global_position.distance_to(high)
		await _seconds(distance / Rocket.SPEED + 0.25)
		await _snap("12_high_blast")
		await _seconds(2.5)
		await _snap("13_high_debris")
		var hole := _find("WallHole")
		if hole != null:
			cam = _side_cam(hole.global_position + wall_normal * 14.0 + Vector3.UP * 2.0, hole.global_position)
			await _snap("14_hole_close")
			(_player.get("camera") as Camera3D).make_current()
			cam.queue_free()
		else:
			print("NO WALL HOLE")

	# A shop front at street level: hit the wall a little above the pavement.
	if district.has_method("blow_out_windows"):
		var shops: Array = district.get("_shop_walls")
		var front := Vector3.INF
		var out := Vector3.ZERO
		for w in shops:
			var a: Vector2 = w[0]
			var b: Vector2 = w[1]
			if a.distance_to(b) < 12.0:
				continue
			var mid := (a + b) * 0.5
			var p := Vector3(mid.x, 1.2, mid.y)
			if front == Vector3.INF or p.distance_to(_player.global_position) < front.distance_to(_player.global_position):
				var d := (b - a).normalized()
				front = p
				out = Vector3(d.y, 0.0, -d.x)
		if front != Vector3.INF:
			_player.global_position = front + out * 14.0 + Vector3.UP * 0.2
			await _wait(4)
			await _aim_at(front + Vector3.UP * 0.6)
			var coins_before: int = _game.get("money")
			_fire()
			await _seconds(0.9)
			await _snap("15_shopfront_blast")
			await _seconds(3.0)
			await _snap("16_shopfront_after")
			print("rockets left ", _game.get("rockets"), " money from it ", int(_game.get("money")) - coins_before)

	# Remote copy: a harmless rocket, then the blast arriving.
	var copy := Rocket.launch(_scene, _player.global_position + Vector3.UP * 2.0, -_player.global_basis.z, 99, false)
	await _seconds(0.3)
	copy.fizzle()
	Rocket.explode(_scene, _player.global_position - _player.global_basis.z * 30.0, Vector3.UP, "ground", 99)
	await _seconds(0.3)

	# Out of rockets: no shot, a toast.
	_game.set("rockets", 0)
	_fire()
	await _seconds(0.3)
	await _snap("17_empty")
	print("fired with 0 rockets, rockets now ", _game.get("rockets"))

	_game.set("money", saved[0])
	_game.set("has_bazooka", saved[1])
	_game.set("rockets", saved[2])
	_game.call("_save")
	quit()


func _find(node_name: String) -> Node3D:
	for child in _scene.get_children():
		if str(child.name).begins_with(node_name):
			return child as Node3D
	return null
