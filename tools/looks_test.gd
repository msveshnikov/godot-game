extends SceneTree
## Looks test: a character standing as in the shop preview, close-ups of the head
## with the cap, the sunglasses and both together, and the whole body turned round
## (shoulders), from several sides. Screenshots go to screenshots/looks/.
##   godot --path . -s tools/looks_test.gd -- [--body=female]

const MODEL_SCENE: PackedScene = preload("res://main_player.glb")
const MODEL_ANIMATOR = preload("res://player_model_animator.gd")
const PREVIEW_BODY = preload("res://preview_body.gd")

var _out := "res://screenshots/looks"
var _model: Node3D
var _turntable: Node3D
var _camera: Camera3D


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(900, 900))
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.35, 0.4, 0.45)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	environment.ambient_light_energy = 0.6
	var env := WorldEnvironment.new()
	env.environment = environment
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(150.0), 0.0)
	sun.light_energy = 1.3
	world.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	world.add_child(_camera)
	_turntable = PREVIEW_BODY.new()
	world.add_child(_turntable)
	_model = MODEL_SCENE.instantiate() as Node3D
	_model.set_script(MODEL_ANIMATOR)
	_model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	_turntable.add_child(_model)
	_model.call("set_weapon", "none")
	_run.call_deferred()


func _wait(frames: int) -> void:
	for k in frames:
		await process_frame


func _snap(name: String) -> void:
	await _wait(4)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [_out, name]))
	print("saved ", name)


func _look_from(yaw_deg: float, distance: float, height: float, target_y: float) -> void:
	var dir := Vector3(sin(deg_to_rad(yaw_deg)), 0.0, -cos(deg_to_rad(yaw_deg)))
	_camera.look_at_from_position(dir * distance + Vector3.UP * height, Vector3(0.0, target_y, 0.0))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _wait(10)
	var body := "female"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--body="):
			body = arg.trim_prefix("--body=")
	var heads := (MODEL_ANIMATOR as Script).get_script_constant_map()["HEADS"] as Dictionary
	var eyes := float(heads[body]["eyes"])
	var looks := {
		"glasses": {"body": body, "hat": "none", "glasses": "dark"},
		"aviators": {"body": body, "hat": "none", "glasses": "gold"},
		"cap": {"body": body, "hat": "red", "glasses": "none"},
		"cap_glasses": {"body": body, "hat": "black", "glasses": "dark"},
		"cap_aviators": {"body": body, "hat": "yellow", "glasses": "gold"},
	}
	for name in looks:
		_model.call("apply_look", looks[name])
		await _wait(3)
		# The model faces -Z of the turntable (rotated PI), so a camera on -Z sees the face.
		for view in [["front", 0.0], ["side", 90.0], ["three_q", 40.0], ["back", 180.0]]:
			_look_from(view[1], 1.1, eyes + 0.05, eyes - 0.02)
			await _snap("%s_%s_%s" % [body, name, view[0]])
	# The whole body turning, as on the shop turntable: shoulders.
	_model.call("apply_look", {"body": body, "hat": "none", "glasses": "none"})
	for yaw in [0.0, 45.0, 90.0, 135.0, 180.0, 270.0]:
		_look_from(yaw, 3.4, 1.25, 1.0)
		await _snap("%s_body_%03d" % [body, int(yaw)])
	for yaw in [90.0, 135.0, 225.0, 270.0]:
		_look_from(yaw, 1.7, 1.35, 1.25)
		await _snap("%s_shoulders_%03d" % [body, int(yaw)])
	# The same with the arm left as modelled (no shader pose).
	if OS.get_cmdline_user_args().has("--raw"):
		_model.set_process(false)
		var material := (_model.get("_material") as ShaderMaterial)
		material.set_shader_parameter("gun_arm_pitch", 0.0)
		material.set_shader_parameter("gun_arm_roll", 0.0)
		for yaw in [90.0, 135.0, 225.0, 270.0]:
			_look_from(yaw, 1.7, 1.35, 1.25)
			await _snap("%s_raw_%03d" % [body, int(yaw)])
	quit()
