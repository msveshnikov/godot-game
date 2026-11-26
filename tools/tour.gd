extends SceneTree
## Screenshot tour: loads the main scene in a location, hides the HUD and shoots
## a list of camera spots into screenshots/tour/.
##   godot --path . -s tools/tour.gd -- --loc=nyc --server=ws://127.0.0.1:1 [--only=3,5]
## Spots: name, camera position (game x, y, z), point looked at.

const SPOTS := {
	"neratovice": [["estate", Vector3(-16.0, 2.4, -22.0), Vector3(14.0, 7.0, 22.0)]],
	"omsk2": [
		["slab", Vector3(-34.0, 2.4, -30.0), Vector3(8.0, 9.0, 6.0)],
		["cheredovaya23", Vector3(218.0, 2.5, -245.0), Vector3(193.0, 7.0, -278.0)],
		["north_aerial", Vector3(347.0, 158.0, -114.0), Vector3(143.0, 3.0, -269.0)],
	],
	"omsk1": [["yard", Vector3(0.0, 1.7, -20.0), Vector3(30.0, 5.0, 60.0)], ["aerial", Vector3(-300.0, 200.0, 300.0), Vector3(0.0, 0.0, 0.0)]],
	"paris": [
		["boulevard", Vector3(-47.5, 2.7, -9.3), Vector3(59.0, 10.0, 14.1)],
		["grevin", Vector3(4.8, 2.1, 1.8), Vector3(11.3, 5.6, -13.2)],
		["varietes", Vector3(-0.5, 2.1, 5.0), Vector3(1.0, 5.3, 21.0)],
		["passage", Vector3(-15.9, 2.0, 10.9), Vector3(-21.4, 2.8, 39.0)],
		["aerial", Vector3(-249.0, 164.0, -287.0), Vector3(0.0, 2.0, 0.0)],
		["brebant", Vector3(70.1, 2.0, 20.6), Vector3(95.0, 4.2, 1.6)],
		["wall", Vector3(212.0, 2.2, 58.0), Vector3(244.0, 2.0, 66.0)],
		["moulin_rouge", Vector3(-98.0, 2.8, -298.5), Vector3(-111.0, 9.2, -324.0)],
		["square_louise_michel", Vector3(57.0, 3.1, -330.0), Vector3(56.0, 28.0, -420.0)],
		["sacre_coeur", Vector3(69.0, 17.3, -396.0), Vector3(56.0, 34.0, -429.0)],
	],
	"dublin": [
		["grafton", Vector3(-17.0, 2.4, 43.0), Vector3(4.0, 7.0, -31.0)],
		["bewleys", Vector3(3.1, 2.4, -6.4), Vector3(-7.6, 4.2, 2.1)],
		["gaiety", Vector3(-105.7, 2.6, 169.4), Vector3(-103.5, 5.3, 158.0)],
		["aerial", Vector3(213.0, 172.0, -280.0), Vector3(0.0, 2.0, 0.0)],
		["st_anns", Vector3(94.5, 2.3, 76.3), Vector3(130.0, 7.9, 82.2)],
		["st_stephens", Vector3(-34.6, 3.4, 189.0), Vector3(-66.0, 8.6, 193.2)],
		["fusiliers", Vector3(-31.0, 2.5, 213.8), Vector3(-25.2, 5.1, 227.9)],
	],
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
	_start.call_deferred()


func _start() -> void:
	var window_size := Vector2i(1600, 900)
	var location := "nyc"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="): # e.g. --size=1600x720 for a 20:9 phone in landscape
			var wh := arg.trim_prefix("--size=").split("x")
			window_size = Vector2i(int(wh[0]), int(wh[1]))
		elif arg.begins_with("--loc="):
			location = arg.trim_prefix("--loc=")
	var net := root.get_node("Net")
	# This offline capture script can tour leaderboard-gated districts.
	net.set("_rank_score", net.get_script().get_script_constant_map()["LOCATION_POINTS"])
	net.set("location", location)
	DisplayServer.window_set_size(window_size)
	_scene = (load("res://node_2d.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_run()


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
	var perimeter := PackedVector2Array()
	if district.has_method("_boundary_outline"):
		perimeter = district.call("_boundary_outline")
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
		var inside := absf(pos.x) <= 300 and pos.z >= -252 and pos.z <= 354
		if not perimeter.is_empty():
			inside = Geometry2D.is_point_in_polygon(flat, perimeter)
		if not inside or pos.y < -1.0:
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
