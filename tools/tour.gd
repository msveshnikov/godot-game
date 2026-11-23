extends SceneTree
## Screenshot tour: loads the main scene in a location, hides the HUD and shoots
## a list of camera spots into screenshots/tour/.
##   godot --path . -s tools/tour.gd -- --loc=nyc --server=ws://127.0.0.1:1 [--only=3,5]
## Spots: name, camera position (game x, y, z), point looked at.

const SPOTS := {
	"omsk1": [["yard", Vector3(0.0, 1.7, -20.0), Vector3(30.0, 5.0, 60.0)], ["aerial", Vector3(-300.0, 200.0, 300.0), Vector3(0.0, 0.0, 0.0)]],
	"nyc": [
		["tkts_south", Vector3(-21.0, 6.6, -144.0), Vector3(14.0, 6.0, 230.0)],
		["bowtie_north", Vector3(-12.0, 1.7, -70.0), Vector3(14.0, 16.0, 200.0)],
		["bowtie_south", Vector3(12.0, 1.7, 190.0), Vector3(-18.0, 22.0, -120.0)],
		["aerial_sw", Vector3(-520.0, 330.0, 640.0), Vector3(0.0, 0.0, 50.0)],
		["aerial_ne", Vector3(480.0, 260.0, -420.0), Vector3(0.0, 0.0, 80.0)],
		["street_42", Vector3(110.0, 1.7, 249.0), Vector3(-250.0, 6.0, 249.0)],
		["promenade_w", Vector3(-291.0, 1.7, 140.0), Vector3(-280.0, 1.0, 330.0)],
		["street_44", Vector3(-160.0, 1.7, 80.0), Vector3(-60.0, 6.0, 86.0)],
		["roofs", Vector3(-210.0, 70.0, 140.0), Vector3(-110.0, 25.0, 60.0)],
		["seventh_north", Vector3(-5.0, 1.7, 320.0), Vector3(-5.0, 28.0, -100.0)],
		["torch", Vector3(-150.0, 30.0, 40.0), Vector3(-230.0, 40.0, -30.0)],
		["corner_45", Vector3(10.0, 1.7, 18.0), Vector3(-30.0, 8.0, -10.0)],
		["hero", Vector3(-15.0, 1.8, -108.0), Vector3(14.0, 13.0, 230.0)],
		["one_times_square", Vector3(4.0, 1.8, 150.0), Vector3(26.0, 45.0, 222.0)],
		["red_steps", Vector3(-17.0, 2.2, -108.0), Vector3(-21.0, 3.0, -135.0)],
		["theatres_45", Vector3(-95.0, 1.8, -6.0), Vector3(-160.0, 6.0, 4.0)],
	],
}

var _scene: Node
var _camera: Camera3D
var _out := "res://screenshots/tour"


func _initialize() -> void:
	var window_size := Vector2i(1600, 900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="): # e.g. --size=1600x720 for a 20:9 phone in landscape
			var wh := arg.trim_prefix("--size=").split("x")
			window_size = Vector2i(int(wh[0]), int(wh[1]))
	DisplayServer.window_set_size(window_size)
	_scene = (load("res://node_2d.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	_run.call_deferred()


func _run() -> void:
	var location := "nyc"
	var only := []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--loc="):
			location = arg.trim_prefix("--loc=")
		elif arg.begins_with("--only="):
			only = Array(arg.trim_prefix("--only=").split(","))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if OS.get_cmdline_user_args().has("--ui"):
		# The start screen as a player sees it, through the player's own camera.
		for k in 120:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s_start_screen.png" % [_out, location]))
		quit()
		return
	for layer in _scene.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	_camera = Camera3D.new()
	_camera.far = 6000.0
	_scene.add_child(_camera)
	_camera.make_current()
	for k in 90:
		await process_frame
	var counts := {}
	for node in _scene.find_children("*", "", true, false):
		var key := node.get_class()
		counts[key] = counts.get(key, 0) + 1
	print("nodes: ", counts)
	if OS.get_cmdline_user_args().has("--atlas"):
		# The baked billboard atlas (nyc_ads.gd), to look at every ad at once.
		var material = _scene.get_node("Diorama/District").get("_screen_material")
		if material != null:
			var texture := (material as ShaderMaterial).get_shader_parameter("atlas") as Texture2D
			texture.get_image().save_png(ProjectSettings.globalize_path("%s/%s_ad_atlas.png" % [_out, location]))
	var spots: Array = SPOTS.get(location, [])
	for index in spots.size():
		if not only.is_empty() and not only.has(str(index)):
			continue
		var spot: Array = spots[index]
		_camera.global_position = spot[1]
		_camera.look_at(spot[2], Vector3.UP)
		for k in 25:
			await process_frame
		var image := root.get_texture().get_image()
		var path := "%s/%s_%02d_%s.png" % [_out, location, index, spot[0]]
		image.save_png(ProjectSettings.globalize_path(path))
		print("saved %s  fps %d  draws %d  prims %dk" % [path, Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
	if OS.get_cmdline_user_args().has("--check"):
		await _check_crowd()
	quit()


## Let the crowd and the traffic run for a while, then report anyone standing
## inside a building or off the island, and cars that never moved.
func _check_crowd() -> void:
	var traffic := _scene.get_node_or_null("Diorama/District/Traffic")
	var start := {}
	if traffic != null:
		for car in traffic.get("_cars"):
			start[car["body"]] = (car["body"] as Node3D).global_position
	for k in 1800:
		await physics_frame
	var district := _scene.get_node("Diorama/District")
	var data: Dictionary = district.get("_data")
	var polys := []
	for building in data.get("buildings", []):
		var points := PackedVector2Array()
		for p in building["p"]:
			points.append(Vector2(p[0], p[1]))
		polys.append(points)
	var bad := 0
	var people := []
	for group in ["villagers", "civilians"]:
		people.append_array(get_nodes_in_group(group))
	for person in people:
		var pos := (person as Node3D).global_position
		var flat := Vector2(pos.x, pos.z)
		for points in polys:
			if Geometry2D.is_point_in_polygon(flat, points):
				print("INSIDE BUILDING: ", person.name, " ", pos)
				bad += 1
				break
		if absf(pos.x) > 300 or pos.z < -252 or pos.z > 354 or pos.y < -1.0:
			print("OFF ISLAND: ", person.name, " ", pos)
			bad += 1
	var still := 0
	if traffic != null:
		for car in traffic.get("_cars"):
			var body := car["body"] as Node3D
			if body.global_position.distance_to(start.get(body, Vector3.ZERO)) < 2.0:
				still += 1
				print("CAR STILL: ", body.global_position)
	print("crowd check: %d people, %d misplaced; %d cars, %d never moved" % [people.size(), bad, start.size(), still])
