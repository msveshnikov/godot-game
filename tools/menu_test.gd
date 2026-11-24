extends SceneTree
## Menu test: the main menu, settings, how to play, the shop from the menu, then
## PLAY through the loading screen into the game and its pause menu. Screenshots
## go to screenshots/menu/.
##   godot --path . -s tools/menu_test.gd -- --server=ws://127.0.0.1:1 [--size=1600x720]

var _menu: Node
var _out := "res://screenshots/menu"


func _initialize() -> void:
	var window_size := Vector2i(1600, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var wh := arg.trim_prefix("--size=").split("x")
			window_size = Vector2i(int(wh[0]), int(wh[1]))
	DisplayServer.window_set_size(window_size)
	_menu = (load("res://main_menu.tscn") as PackedScene).instantiate()
	root.add_child(_menu)
	current_scene = _menu
	_run.call_deferred()


func _wait(frames: int) -> void:
	for k in frames:
		await process_frame


func _snap(name: String) -> void:
	await _wait(3)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [_out, name]))
	print("saved ", name)


func _close_overlays() -> void:
	var layer: CanvasLayer = _menu.get("_layer")
	for child in layer.get_children():
		child.queue_free()
	await _wait(2)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _wait(30)
	await _snap("01_menu")
	_menu.call("_select", "omsk1")
	await create_timer(0.7).timeout
	await _snap("02_menu_omsk1")
	_menu.call("_select", "nyc")
	await create_timer(0.7).timeout
	SettingsPanel.open(_menu.get("_layer"))
	await _snap("03_settings")
	await _close_overlays()
	_menu.call("_how_to_play")
	await _snap("04_how_to_play")
	await _close_overlays()
	Shop.open(_menu.get("_layer"))
	await _wait(10)
	await _snap("05_shop")
	await _close_overlays()
	_menu.call("_play")
	await _wait(4)
	await _snap("06_loading")
	# Wait for the game scene to take over and the loading screen to go.
	for k in 600:
		await process_frame
		if current_scene != _menu and current_scene != null and root.get_node_or_null("LoadingScreen") == null:
			break
	await create_timer(1.0).timeout
	print("scene now: ", current_scene.name if current_scene else "null", " loading screen gone: ", root.get_node_or_null("LoadingScreen") == null)
	await _snap("07_game")
	var player := get_first_node_in_group("player")
	print("playing: ", player.call("is_playing"))
	player.call("_pause")
	await _snap("08_pause")
	print("paused, playing: ", player.call("is_playing"))
	player.call("_resume")
	await _wait(5)
	print("resumed, playing: ", player.call("is_playing"))
	quit()
