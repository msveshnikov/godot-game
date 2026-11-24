extends SceneTree
## Store screenshots (Google Play wants 16:9, 1920 x 1080) straight from the game:
##   --set=menu    the main menu
##   --set=nyc     Times Square: walking in red, the bat on a car with coins flying, a car
##                 blowing up, the police shootout, the shop with Alice
##   --set=estate  Alice in the Czech estate
## Writes store/screenshots/<n>_<name>.png. The saved progress is put back afterwards.
##   godot --path . -s tools/store_shots.gd -- --set=nyc --loc=nyc --server=ws://127.0.0.1:1

var _scene: Node
var _out := "res://store/screenshots"
var _saved := ""


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_saved = FileAccess.get_file_as_string("user://progress.cfg")
	var which := _which_set()
	# A name and some cash on show (not saved: the progress file is put back after).
	var net := root.get_node_or_null("Net")
	if net != null:
		net.set("player_name", "Max")
	var game := root.get_node_or_null("Game")
	if game != null:
		game.set("money", 1250)
	_scene = (load("res://main_menu.tscn" if which == "menu" else "res://node_2d.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_run.call_deferred()


func _which_set() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			return arg.trim_prefix("--set=")
	return "nyc"


func _wait(frames: int) -> void:
	for k in frames:
		await process_frame


func _seconds(t: float) -> void:
	await create_timer(t).timeout


func _snap(name: String) -> void:
	await _wait(3)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [_out, name]))
	print("saved ", name)


func _finish() -> void:
	var file := FileAccess.open("user://progress.cfg", FileAccess.WRITE)
	file.store_string(_saved)
	file.close()
	quit()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	match _which_set():
		"menu":
			await _wait(40)
			(_scene.get("_online") as Label).visible = false
			await _snap("01_menu")
		"nyc":
			await _nyc()
		"estate":
			await _estate()
	_finish()


func _player() -> CharacterBody3D:
	return get_first_node_in_group("player") as CharacterBody3D


## No "Offline (connecting...)" in the corner of a store picture.
func _clean_hud() -> void:
	var net_world := _scene.get_node_or_null("NetWorld")
	if net_world != null:
		(net_world.get("_status_label") as Label).visible = false
	var game := root.get_node("Game")
	game.emit_signal("money_changed", int(game.get("money")))


func _dress(look: Dictionary) -> void:
	var game := root.get_node("Game")
	game.set("look", look)
	game.emit_signal("look_changed")


## Stand the player at `at` facing `target`, camera level behind.
func _place(player: CharacterBody3D, at: Vector3, target: Vector3, pitch := -0.1) -> void:
	var dir := target - at
	dir.y = 0.0
	player.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), Vector3(at.x, 0.9, at.z))
	player.velocity = Vector3.ZERO
	(player.get("camera_pivot") as Node3D).rotation = Vector3(pitch, 0, 0)


## The parked car nearest to `near`: [index, world transform].
func _parked_car(district: Node, near: Vector3, skip := -1) -> Array:
	var best := -1
	var best_d := INF
	var spots: Array = district.get("_car_spots")
	for i in spots.size():
		if i == skip:
			continue
		var xf: Transform3D = district.call("car_transform", i)
		var d := xf.origin.distance_to(near)
		if d < best_d:
			best_d = d
			best = i
	return [best, district.call("car_transform", best)]


func _nyc() -> void:
	await _wait(90)
	var player := _player()
	player.call("_start_game")
	_clean_hud()
	_dress({"body": "male", "shirt": "red", "pants": "blue", "hat": "none", "glasses": "none"})
	var district := _scene.get_node("Diorama/District")
	# 02: walking up the bowtie among the screens.
	_place(player, Vector3(-6.0, 0.9, -70.0), Vector3(10.0, 0.9, 200.0), -0.02)
	await _seconds(1.0)
	await _snap("02_times_square")

	# 03: the bat on a parked car, coins flying.
	var car: Array = _parked_car(district, player.global_position)
	var xf: Transform3D = car[1]
	var side := xf.basis.x.normalized()
	var stand := xf.origin + side * 2.35
	_place(player, stand, xf.origin, -0.25)
	player.call("set_weapon", "bat")
	await _seconds(0.6)
	for k in 2:
		player.call("_swing_bat")
		await _seconds(0.7)
	player.call("_swing_bat")
	await _seconds(0.26)
	# A good burst of cash off the roof, as a smashed car pays out.
	var coins_script := load("res://coins.gd")
	coins_script.call("spawn", _scene, xf.origin + Vector3.UP * 1.6, 50, player.global_position)
	await _seconds(0.22)
	await _snap("03_smash_for_cash")

	# 04: a car blowing up across the street.
	await _seconds(1.5)
	var other: Array = _parked_car(district, player.global_position + (-player.global_basis.z) * 14.0, car[0])
	var boom: Transform3D = other[1]
	var away := (player.global_position - boom.origin)
	away.y = 0.0
	_place(player, boom.origin + away.normalized() * 11.0, boom.origin, -0.05)
	player.call("set_weapon", "pistol")
	await _seconds(0.4)
	district.call("blow_up_car", other[0], -1.0, 0)
	await _seconds(0.45)
	await _snap("04_car_explosion")

	# 05: the police shootout.
	player.set("health", 100)
	_place(player, Vector3(-6.0, 0.9, -40.0), Vector3(-6.0, 0.9, 200.0), -0.05)
	var police: Node = _scene.get_node("Police")
	police.call("add_heat", 100.0)
	for k in 30:
		await _seconds(0.5)
		if police.get("state") == "fight":
			break
	await _seconds(5.0)
	(player.get("camera") as Camera3D).fov = 48.0
	# Face the nearest officer, a little off so both are in the picture.
	var nearest: Node3D = null
	for cop in get_nodes_in_group("police"):
		if nearest == null or (cop as Node3D).global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position):
			nearest = cop
	if nearest != null:
		var to_cop := nearest.global_position - player.global_position
		player.rotation.y = atan2(-to_cop.x, -to_cop.z) - 0.12
	player.set("_protection", 30.0)
	await _wait(2)
	player.call("_pull_trigger")
	await _seconds(0.12)
	await _snap("05_police")
	(player.get("camera") as Camera3D).fov = 75.0
	player.set("health", 100)
	police.call("stand_down")

	# 06: the shop, Alice in a yellow T-shirt and the NY cap.
	_dress({"body": "female", "shirt": "yellow", "pants": "blue", "hat": "yellow", "glasses": "gold"})
	player.call("_open_shop")
	await _wait(40)
	await _snap("06_shop")


func _estate() -> void:
	await _wait(90)
	var player := _player()
	player.call("_start_game")
	_clean_hud()
	_dress({"body": "female", "shirt": "black", "pants": "blue", "hat": "none", "glasses": "none"})
	player.call("set_weapon", "bat")
	await _seconds(1.0)
	# A camera in front of her, a little to the side, the blocks behind her.
	var cam := Camera3D.new()
	cam.fov = 55.0
	_scene.add_child(cam)
	var b := player.global_basis
	cam.global_position = player.global_position + (-b.z) * 3.4 + b.x * 1.2 + Vector3.UP * 0.25
	cam.look_at(player.global_position + Vector3.UP * 0.45 + b.x * 0.3 + (-b.z) * 0.3)
	cam.make_current()
	await _seconds(0.5)
	await _snap("07_estate")
