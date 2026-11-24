extends SceneTree
## Police test: starts a game, smashes up some cash, fills the heat meter and
## follows the patrol car in, watches the officers fight, puts them down and checks
## the reward. Screenshots (through the player's own camera, HUD on) go to
## screenshots/police/.
##   godot --path . -s tools/police_test.gd -- --loc=nyc --server=ws://127.0.0.1:1 [--size=1600x720]

var _scene: Node
var _out := "res://screenshots/police"


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


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _wait(90)
	var player := get_first_node_in_group("player") as CharacterBody3D
	var game := root.get_node("Game")
	var money_before: int = game.get("money")
	player.call("_start_game")
	await _wait(10)
	var police: Node = _scene.get_node("Police")
	print("money at start: ", money_before)

	# Cash: a car's worth of coins right in front of the player.
	var ahead := player.global_position - player.global_basis.z * 3.0
	player.call("_reward", ahead + Vector3.UP * 0.5, 40, 30.0)
	await _seconds(0.5)
	await _snap("01_coins")
	print("heat after one car: ", police.get("heat"))
	# Walk into them.
	for k in 40:
		player.global_position = player.global_position.lerp(ahead, 0.08)
		await physics_frame
	await _seconds(1.0)
	print("money after picking up: ", game.get("money"), " (+", int(game.get("money")) - money_before, ")")

	# Too much: the police come.
	police.call("add_heat", 100.0)
	print("state: ", police.get("state"))
	await _wait(5)
	await _snap("02_on_the_way")
	var car: Node3D = _scene.get_node_or_null("PoliceCar")
	for k in 12:
		await _seconds(1.0)
		if car != null and is_instance_valid(car):
			print("t=%d car %s, %.1f m from the player, state %s" % [k + 1, car.global_position.snapped(Vector3.ONE * 0.1), car.global_position.distance_to(player.global_position), police.get("state")])
		if police.get("state") == "fight":
			break
	await _seconds(0.6)
	await _snap("03_arrived")

	# Turn round to face the car and the officers.
	if car != null and is_instance_valid(car):
		var to_car := car.global_position - player.global_position
		player.rotation.y = atan2(-to_car.x, -to_car.z)
	for k in 6:
		await _seconds(0.5)
		for officer in get_nodes_in_group("police"):
			var body := officer as CharacterBody3D
			print("  %s: %.1f m, sees %s, active %s, vel %s real %s floor %s pm %s shots %s" % [officer.name, body.global_position.distance_to(player.global_position), officer.get("_sees"), officer.get("active"), body.velocity.snapped(Vector3.ONE * 0.1), body.get_real_velocity().snapped(Vector3.ONE * 0.1), body.is_on_floor(), body.process_mode, officer.get("shots")])
	if car != null and is_instance_valid(car):
		var car_cam := Camera3D.new()
		_scene.add_child(car_cam)
		car_cam.global_position = car.global_position + car.global_basis.x * 6.0 + Vector3.UP * 2.0
		car_cam.look_at(car.global_position + Vector3.UP * 0.8)
		car_cam.make_current()
		await _snap("03b_car")
		(player.get("camera") as Camera3D).make_current()
		car_cam.queue_free()
	await _snap("04_fight")
	player.set("health", 100)
	var health_before: int = player.get("health")
	await _seconds(4.0)
	print("player health %d -> %d over 4 s of being shot at" % [health_before, player.get("health")])
	await _snap("05_fight_later")

	# Close-up of the officers.
	var officers := get_nodes_in_group("police")
	print("officers: ", officers.size())
	if not officers.is_empty():
		var cam := Camera3D.new()
		_scene.add_child(cam)
		var o := officers[0] as Node3D
		cam.global_position = o.global_position + o.global_basis.z * -3.0 + Vector3.UP * 1.6 + o.global_basis.x * 1.2
		cam.look_at(o.global_position + Vector3.UP * 1.1)
		cam.make_current()
		await _snap("06_officer")
		if officers.size() > 1:
			var o2 := officers[1] as Node3D
			cam.global_position = o2.global_position + o2.global_basis.z * -3.0 + Vector3.UP * 1.6 + o2.global_basis.x * 1.2
			cam.look_at(o2.global_position + Vector3.UP * 1.1)
			await _snap("07_officer2")
		(player.get("camera") as Camera3D).make_current()
		cam.queue_free()

	# Put them down (the player back on its feet first, if they got it).
	player.set("health", 100)
	if player.get("_game_over"):
		player.call("_restart_game")
	var money_mid: int = game.get("money")
	for officer in officers:
		officer.call("take_damage", 40.0)
		print("officer after 40 dmg: hp ", officer.get("hp"), " alive ", officer.get("alive"))
		officer.call("take_damage", 100.0)
	await _seconds(0.5)
	print("after: state ", police.get("state"), " heat ", police.get("heat"))
	await _snap("08_police_down")
	for coin in _scene.get_children():
		if coin.get_script() != null and (coin.get_script() as Script).get_global_name() == &"Coins":
			(coin as Node3D).global_position = player.global_position + Vector3.UP * 0.6
	await _seconds(1.0)
	print("reward picked up: +", int(game.get("money")) - money_mid)
	# Leave the saved money as it was.
	game.set("money", money_before)
	game.call("add_money", 0)
	game.call("_save")
	quit()
