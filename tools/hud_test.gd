extends SceneTree
## HUD test: the health bar (full, after a hit, low), the weapon slots with each
## weapon in hand (bazooka not bought, then bought with rockets), the heat bar.
## Screenshots go to screenshots/hud/; progress is put back as it was.
##   godot --path . -s tools/hud_test.gd -- --loc=nyc --server=ws://127.0.0.1:1 [--size=1600x720] [--touch]

var _scene: Node
var _out := "res://screenshots/hud"


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
	var suffix := "_touch" if OS.get_cmdline_user_args().has("--touch") else ""
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s%s.png" % [_out, name, suffix]))
	print("saved ", name, suffix)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var saved := FileAccess.get_file_as_string("user://progress.cfg")
	await _wait(90)
	var game := root.get_node("Game")
	var player := get_first_node_in_group("player") as CharacterBody3D
	player.call("_start_game")
	_scene.get_node("Police").process_mode = Node.PROCESS_MODE_DISABLED
	game.set("has_bazooka", false)
	game.set("rockets", 0)
	game.emit_signal("arsenal_changed")
	await create_timer(0.5).timeout
	await _snap("01_start")
	player.call("receive_damage", 35.0)
	await create_timer(0.15).timeout
	await _snap("02_hit")
	await create_timer(1.5).timeout
	player.call("set_weapon", "bat")
	player.call("receive_damage", 45.0)
	await create_timer(1.6).timeout
	await _snap("03_low_bat")
	game.set("has_bazooka", true)
	game.set("rockets", 3)
	game.emit_signal("arsenal_changed")
	player.call("set_weapon", "bazooka")
	(_scene.get_node("Police") as Node).set("heat", 60.0)
	(_scene.get_node("Police") as Node).call("_update_hud")
	await create_timer(0.5).timeout
	await _snap("04_bazooka")
	player.call("set_weapon", "none")
	await create_timer(0.5).timeout
	await _snap("05_hands")
	var file := FileAccess.open("user://progress.cfg", FileAccess.WRITE)
	file.store_string(saved)
	file.close()
	quit()
