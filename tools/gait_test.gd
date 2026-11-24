extends SceneTree
## Gait test: a player model (male or female) running on the spot, seen from the side
## and from the front, a few frames apart, plus aiming the pistol and swinging the bat.
## Writes screenshots/gait/<body>.png (a strip of frames).
##   godot --path . -s tools/gait_test.gd -- --body=female [--hat=red] [--glasses=dark]
## (a cap and sunglasses must run with the head, not jump about).

const MODEL_SCENE: PackedScene = preload("res://main_player.glb")
const MODEL_ANIMATOR = preload("res://player_model_animator.gd")
const PREVIEW_BODY = preload("res://preview_body.gd")

var _out := "res://screenshots/gait"


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(480, 640))
	_run.call_deferred()


func _wait(frames: int) -> void:
	for k in frames:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var body_kind := "male"
	var hat := "none"
	var glasses := "none"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--body="):
			body_kind = arg.trim_prefix("--body=")
		elif arg.begins_with("--hat="):
			hat = arg.trim_prefix("--hat=")
		elif arg.begins_with("--glasses="):
			glasses = arg.trim_prefix("--glasses=")
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.75, 0.78, 0.82)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	var we := WorldEnvironment.new()
	we.environment = environment
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(140), 0)
	world.add_child(sun)
	var body := PREVIEW_BODY.new() as CharacterBody3D
	world.add_child(body)
	var model := MODEL_SCENE.instantiate() as Node3D
	model.set_script(MODEL_ANIMATOR)
	model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	body.add_child(model)
	await _wait(2)
	model.call("apply_look", {"body": body_kind, "shirt": "black", "pants": "blue", "hat": hat, "glasses": glasses})
	var camera := Camera3D.new()
	camera.fov = 40
	world.add_child(camera)
	camera.make_current()
	var frames: Array[Image] = []
	body.velocity = Vector3(0, 0, -7.5) # running forward
	for view in [Vector3(4.5, 1.0, 0.0), Vector3(0.0, 1.0, -4.5)]:
		camera.look_at_from_position(view, Vector3(0, 0.9, 0))
		for k in 4:
			await _wait(7)
			frames.append(root.get_texture().get_image())
	body.velocity = Vector3.ZERO
	await _wait(30)
	model.call("set_weapon", "pistol")
	model.set("aim_point", Vector3(0, 1.4, -20))
	model.set("has_aim_point", true)
	model.call("raise_gun")
	await _wait(10)
	camera.look_at_from_position(Vector3(3.2, 1.3, -2.0), Vector3(0, 1.0, 0))
	frames.append(root.get_texture().get_image())
	model.call("set_weapon", "bat")
	model.call("swing")
	await _wait(12)
	frames.append(root.get_texture().get_image())
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var strip := Image.create(w * 5, h * 2, false, frames[0].get_format())
	for i in frames.size():
		strip.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i((i % 5) * w, (i / 5) * h))
	strip.save_png(ProjectSettings.globalize_path("%s/%s.png" % [_out, body_kind]))
	print("saved ", body_kind)
	quit()
