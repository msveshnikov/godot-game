extends SceneTree
## A poster shot for the game's card on maxims.top: Max in a red T-shirt with his
## pistol out, in Times Square among the screens, no HUD. Writes
## screenshots/card/card_<n>.png (1600 x 900) from a few camera spots.
##   godot --path . -s tools/card_shot.gd -- --loc=nyc --server=ws://127.0.0.1:1

var _scene: Node
var _out := "res://screenshots/card"


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	_scene = (load("res://node_2d.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_run.call_deferred()


func _wait(frames: int) -> void:
	for k in frames:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _wait(90)
	var player := get_first_node_in_group("player") as CharacterBody3D
	player.call("_start_game")
	var model := player.get("model") as Node3D
	model.call("apply_look", {"body": "male", "shirt": "red", "pants": "blue", "hat": "none", "glasses": "none"})
	for layer in _scene.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.far = 3000.0
	_scene.add_child(camera)
	camera.make_current()
	# [player spot, which way he faces (a point), camera offset from him, what the camera looks at (offset)]
	var shots := [
		[Vector3(-3.0, 0.9, -58.0), Vector3(-25.0, 0.9, -200.0), Vector3(1.3, 0.35, -2.9), Vector3(-0.4, 0.75, 0.0)],
		[Vector3(-3.0, 0.9, -58.0), Vector3(-10.0, 0.9, -200.0), Vector3(-1.4, 0.3, -2.8), Vector3(0.5, 0.8, 0.0)],
		[Vector3(2.0, 0.9, -40.0), Vector3(-25.0, 0.9, -200.0), Vector3(1.6, 0.25, -3.4), Vector3(-0.6, 0.9, 0.0)],
		[Vector3(-14.0, 0.9, -75.0), Vector3(-25.0, 0.9, -200.0), Vector3(1.2, 0.3, -2.6), Vector3(-0.5, 0.8, 0.0)],
	]
	for i in shots.size():
		var spot: Vector3 = shots[i][0]
		var facing: Vector3 = shots[i][1]
		var dir := facing - spot
		dir.y = 0.0
		player.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), spot)
		player.velocity = Vector3.ZERO
		model.set("has_aim_point", false)
		var basis := player.global_basis
		camera.global_position = spot + basis * shots[i][2]
		camera.look_at(spot + basis * shots[i][3], Vector3.UP)
		await _wait(20)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/card_%d.png" % [_out, i]))
		print("saved card_%d" % i)
	quit()
