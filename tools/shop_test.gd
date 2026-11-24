extends SceneTree
## Shop test: start screen (with the SHOP button), the shop itself, buying a few
## things, and the player wearing them, front and back. Screenshots go to
## screenshots/shop/. The saved progress (user://progress.cfg) is put back after.
##   godot --path . -s tools/shop_test.gd -- --loc=nyc --server=ws://127.0.0.1:1 [--size=1600x720] [--body=female]

var _scene: Node
var _out := "res://screenshots/shop"


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


func _snap(name: String) -> void:
	await _wait(3)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [_out, name]))
	print("saved ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var saved := FileAccess.get_file_as_string("user://progress.cfg")
	await _wait(90)
	var game := root.get_node("Game")
	var player := get_first_node_in_group("player") as CharacterBody3D
	game.set("money", 1000)
	game.call("add_money", 0)
	await _snap("01_start")
	player.call("_open_shop")
	await _wait(20)
	await _snap("02_shop")
	var body := "male"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--body="):
			body = arg.trim_prefix("--body=")
	for pick in [["body", body], ["shirt", "red"], ["pants", "khaki"], ["hat", "black"], ["glasses", "dark"]]:
		print("buy ", pick, ": ", game.call("buy_or_wear", pick[0], pick[1]), " money ", game.get("money"))
	# Try on something too dear.
	game.set("money", 10)
	var shop: Node = null
	for node in (player.get("hud") as CanvasLayer).get_children():
		if node is ColorRect and node.has_method("_on_item"):
			shop = node
	if shop != null:
		shop.call("_refresh")
		shop.call("_on_item", "hat", "yellow")
	await _wait(30)
	await _snap("03_shop_bought")
	if shop != null:
		shop.queue_free()
	player.call("_start_game")
	await _wait(10)
	var cam := Camera3D.new()
	_scene.add_child(cam)
	cam.fov = 35.0
	var front := -player.global_basis.z
	cam.global_position = player.global_position + front * 3.2 + Vector3.UP * 0.5
	cam.look_at(player.global_position + Vector3.UP * 0.3)
	cam.make_current()
	await _snap("04_front")
	cam.global_position = player.global_position + front * 1.1 + Vector3.UP * 0.85
	cam.look_at(player.global_position + Vector3.UP * 0.8)
	await _snap("05_face")
	cam.global_position = player.global_position + player.global_basis.x * 1.2 + Vector3.UP * 0.9
	cam.look_at(player.global_position + Vector3.UP * 0.8)
	await _snap("06_side")
	# Put the saved progress back.
	var file := FileAccess.open("user://progress.cfg", FileAccess.WRITE)
	file.store_string(saved)
	file.close()
	quit()
