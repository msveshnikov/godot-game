extends "res://nyc_builder.gd"
## Metric public-street geometry shared by Montmartre and Grafton Street.

const WALL_RADIUS := 248.0
const WALL_HEIGHT := 4.65
const RIM := 239.0
const LIMESTONE := Color(0.83, 0.77, 0.66)
const GRANITE_GREY := Color(0.58, 0.57, 0.55)
const CAST_IRON := Color(0.12, 0.16, 0.15)
const SLATE := Color(0.29, 0.32, 0.36)
const BRONZE := Color(0.31, 0.24, 0.17)
const PALE_STONE := [Color(0.85, 0.81, 0.72), Color(0.80, 0.74, 0.63), Color(0.91, 0.87, 0.78), Color(0.76, 0.74, 0.70)]
const IRISH_BRICKS := [Color(0.61, 0.34, 0.25), Color(0.52, 0.28, 0.22), Color(0.66, 0.42, 0.35), Color(0.44, 0.31, 0.26)]
const STREET_SIGN := Color(0.15, 0.29, 0.26)
const PAINT := Color(0.91, 0.89, 0.81)

var _data: Dictionary
var _footprints := {}
var _prop_positions: Array[Vector2] = []


func _data_path() -> String:
	return ""


func _is_paris() -> bool:
	return false


func _enter_tree() -> void:
	# Player._ready reads the spawn points before the district's _ready.
	_data = JSON.parse_string(FileAccess.get_file_as_string(_data_path()))


func _ready() -> void:
	_rng.seed = 7353 if _is_paris() else 8669
	_collision = StaticBody3D.new()
	_collision.name = "DistrictCollision"
	add_child(_collision)
	_set_city_environment()
	_build_boundary()
	_build_surfaces()
	_build_city_blocks()
	_build_street_details()
	_build_landmarks()
	_build_tree_meshes()
	_commit_chunks()
	_commit_wall_faces()
	_spawn_cars()
	_build_traffic()
	var birds := MultiMeshInstance3D.new()
	birds.name = "Birds"
	birds.set_script(load("res://birds.gd"))
	add_child(birds)
	var ambience := Node.new()
	ambience.name = "Ambience"
	ambience.set_script(load("res://ambience.gd"))
	ambience.set("layers", [["res://audio/city_hum.wav", -11.0], ["res://audio/wind.wav", -26.0], ["res://audio/birds.ogg", -25.0]])
	add_child(ambience)


func _set_city_environment() -> void:
	get_node("../Forest").queue_free()
	(get_node("../Ground") as Node3D).hide()
	var world := get_node("../../WorldEnvironment") as WorldEnvironment
	var env := world.environment.duplicate() as Environment
	env.fog_density = 0.00065 if _is_paris() else 0.00088
	env.fog_light_color = Color(0.80, 0.82, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.79, 0.76)
	env.ambient_light_energy = 0.67
	env.adjustment_saturation = 0.92
	env.glow_intensity = 0.45
	if env.sky != null:
		env.sky = env.sky.duplicate() as Sky
		var sky_material := env.sky.sky_material.duplicate() as ShaderMaterial
		sky_material.set_shader_parameter("ground_color", Color(0.25, 0.27, 0.23))
		sky_material.set_shader_parameter("cloud_cover", 0.40 if _is_paris() else 0.59)
		env.sky.sky_material = sky_material
	world.environment = env
	var sun := get_node("../../Sun") as DirectionalLight3D
	sun.rotation_degrees = Vector3(-52, -34 if _is_paris() else 42, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.12 if _is_paris() else 0.98
	sun.directional_shadow_max_distance = 115.0


static func _point(raw: Array) -> Vector2:
	return Vector2(float(raw[0]), float(raw[1]))


static func _points(raw: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for xy in raw:
		out.append(_point(xy))
	return out


func spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	points.assign(_points(_data["spawns"]))
	return points


func spawn_yaw() -> float:
	return deg_to_rad(-103.0 if _is_paris() else 23.0)


func bot_graph() -> Dictionary:
	var graph: Dictionary = _data["graph"]
	var points := _points(graph["nodes"])
	var near_spawn := []
	var spawns := spawn_points()
	for i in points.size():
		if not _fits_street(points[i], 1.62):
			near_spawn.append(i)
			continue
		for spawn_at in spawns:
			if points[i].distance_squared_to(spawn_at) < 30.0:
				near_spawn.append(i)
				break
	var edges := []
	for edge in graph["edges"]:
		edges.append([int(edge[0]), int(edge[1])])
	return {"nodes": Array(points), "edges": edges, "no_spawn": near_spawn,
		"patrol_spots": _patrol_spots(), "baguettes": _is_paris()}


func _patrol_spots() -> Array[Vector2]:
	return []


func _parked_rows() -> Array:
	return []


func _circle(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 96:
		points.append(Vector2.from_angle(TAU * i / 96.0) * radius)
	return points


func _build_boundary() -> void:
	var outline := _circle(WALL_RADIUS)
	_grect(-840, -840, 840, 840, -0.03, Color(0.33, 0.36, 0.31), Surface.ASPHALT)
	_gpoly(outline, 0.005, Color(0.58, 0.56, 0.53), Surface.ASPHALT)
	_gpoly(_circle(RIM), 0.008, Color(0.58, 0.56, 0.53) if _is_paris() else Color(0.56, 0.55, 0.53), Surface.ASPHALT)
	var masonry := Color(0.65, 0.61, 0.54) if _is_paris() else Color(0.55, 0.53, 0.49)
	var coping := masonry.lightened(0.14)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var f := _edge_frame(a, b)
		var half := a.distance_to(b) * 0.5 + 0.12
		_ocollider(f, -half, -0.42, half, 0.48, -1.0, WALL_HEIGHT + 0.25)
		var band := PackedVector2Array([_fp(f, -half, -0.40), _fp(f, half, -0.40),
			_fp(f, half, 0.47), _fp(f, -half, 0.47)])
		_extrude(band, -0.04, WALL_HEIGHT, Style.BOUNDARY_STONE, float(i % 7) * 0.13, masonry, false, false)
		_obox(f, -half, -0.52, half, 0.60, 0.03, 0.29, masonry.darkened(0.13))
		_obox(f, -half, -0.51, half, 0.55, WALL_HEIGHT - 0.16, WALL_HEIGHT + 0.11, coping)
		_obox(f, -half, 0.43, -half + 0.67, 0.72, 0.02, WALL_HEIGHT + 0.16, masonry.darkened(0.06))
		_obox(f, -half - 0.08, 0.38, -half + 0.75, 0.79, WALL_HEIGHT + 0.06, WALL_HEIGHT + 0.28, coping)
		if i % 3 == 0:
			_lantern(_fp(f, 0.0, 1.54), 4.05)
		if i % 5 == 0:
			_city_bench(f, 1.25)
		# A skyline behind the wall keeps the streets visually connected to the city.
		if i % 2 == 0:
			var face := _frame((_fp(f, 0.0, 0.0) as Vector2).normalized() * (275 + i % 9), rad_to_deg((b - a).angle()))
			var h := 12.5 + (i * 17 % 14)
			var rear := PackedVector2Array([_fp(face, -12.5, -7.0), _fp(face, 12.5, -7.0),
				_fp(face, 12.5, 8.0), _fp(face, -12.5, 8.0)])
			var tint: Color = PALE_STONE[i % PALE_STONE.size()] if _is_paris() else IRISH_BRICKS[(i / 2) % IRISH_BRICKS.size()]
			_extrude(rear, 0.0, h, Style.PARIS_STONE if _is_paris() else Style.DUBLIN_BRICK,
				float(i % 13) / 14.0, tint.darkened(0.13), false, false)
			_cap(rear, h, SLATE)


func _build_surfaces() -> void:
	var ground: Dictionary = _data["ground"]
	var surfaces := [
		["park", 0.017, Color(0.29, 0.41, 0.22), Surface.GRASS],
		["paving", 0.025, Color(0.61, 0.58, 0.55) if _is_paris() else Color(0.62, 0.60, 0.58), Surface.SETTS],
		["road", 0.033, Color(0.40, 0.39, 0.38), Surface.ASPHALT],
		["cycle", 0.039, Color(0.44, 0.43, 0.37), Surface.ASPHALT],
	]
	for spec in surfaces:
		for raw in ground[spec[0]]:
			_gpoly(_points(raw), spec[1], spec[2], spec[3])
	for raw in ground["kerbs"]:
		var ring := _points(raw)
		for i in ring.size():
			var a := ring[i]
			var b := ring[(i + 1) % ring.size()]
			if a.distance_squared_to(b) > 0.09:
				_gstrip(a, b, 0.23, 0.057, GRANITE_GREY.lightened(0.12), Surface.GRANITE)
	for raw in _data["props"]["crossings"]:
		var at := _point(raw[0])
		var dir := Vector2.from_angle(raw[1])
		var across := dir.orthogonal()
		var half := float(raw[2]) * 0.47
		for offset in range(-4, 5):
			var p := at + across * (float(offset) * half / 4.5)
			_gstrip(p - dir * 1.55, p + dir * 1.55, 0.31, 0.055, PAINT, Surface.PAINT)
	for lane in _data["lanes"]:
		if not _is_paris() or not str(lane[2]).begins_with("Boulevard") or lane[1] == 0.0:
			continue
		var line := _points(lane[0])
		for i in range(1, line.size()):
			var a := line[i - 1]
			var b := line[i]
			var dir := (b - a).normalized()
			for k in range(4, int(a.distance_to(b)) - 3, 8):
				var p := a + dir * k
				_gstrip(p, p + dir * 2.7, 0.13, 0.052, PAINT, Surface.PAINT)
	for raw in _data["rail"]:
		var line := _points(raw)
		for i in range(1, line.size()):
			var a := line[i - 1]
			var b := line[i]
			var normal := (b - a).normalized().orthogonal()
			for side in [-0.73, 0.73]:
				_gstrip(a + normal * side, b + normal * side, 0.082, 0.058, Color(0.47, 0.49, 0.49), Surface.GRANITE)
				_gstrip(a + normal * (side + 0.07), b + normal * (side + 0.07), 0.075, 0.056, Color(0.15, 0.15, 0.15), Surface.GRANITE)


func _register_ground(outline: PackedVector2Array, holes: Array) -> void:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for p in outline:
		bounds = bounds.expand(p)
	var start := (bounds.position / 25.0).floor()
	var end := (bounds.end / 25.0).floor()
	for x in range(int(start.x), int(end.x) + 1):
		for z in range(int(start.y), int(end.y) + 1):
			var key := Vector2i(x, z)
			if not _footprints.has(key):
				_footprints[key] = []
			_footprints[key].append([outline, holes])


func _fits_street(at: Vector2, margin: float) -> bool:
	if at.length() > RIM - 2.0:
		return false
	for direction in [Vector2.ZERO, Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var p: Vector2 = at + direction * margin
		var key := Vector2i((p / 25.0).floor())
		for footprint in _footprints.get(key, []):
			if Geometry2D.is_point_in_polygon(p, footprint[0]) and not footprint[1].any(
					func(hole): return Geometry2D.is_point_in_polygon(p, hole)):
				return false
	return true


func _build_city_blocks() -> void:
	for item in _data["buildings"]:
		var outline := _points(item["p"])
		var holes: Array = item.get("holes", []).map(_points)
		if item.has("base"):
			for base in item["base"]:
				_register_ground(_points(base[0]), base.slice(1).map(_points))
		else:
			_register_ground(outline, holes)
	for item in _data["buildings"]:
		_build_block(item)


func _build_block(item: Dictionary) -> void:
	var outline := _points(item["p"])
	var holes: Array = item.get("holes", []).map(_points)
	var height: float = item["h"]
	var seed := (posmod(int(item["id"]), 997) + 1.0) / 999.0
	var shops: bool = item["shops"]
	var colour: Color = PALE_STONE[int(seed * PALE_STONE.size())]
	var style := Style.PARIS_STONE if _is_paris() else Style.DUBLIN_STONE
	match item["s"]:
		"brick":
			colour = IRISH_BRICKS[int(seed * IRISH_BRICKS.size())]
			style = Style.DUBLIN_BRICK if not _is_paris() else Style.BRICK
		"glass":
			colour = Color(0.48, 0.54, 0.57)
			style = Style.GLASS
		"ashlar":
			colour = LIMESTONE
			style = Style.BOUNDARY_STONE
	if height < 5.5:
		style = Style.BLANK
	if item.has("base"):
		for base in item["base"]:
			for raw in base:
				_extrude(_points(raw), 0.0, 4.8, style, seed, colour, shops)
		_extrude(outline, 4.8, height, style, seed, colour, shops)
		for hole in holes:
			_extrude(hole, 4.8, height, style, seed, colour, false)
	else:
		_extrude(outline, 0, height, style, seed, colour, shops)
		for hole in holes:
			_extrude(hole, 0, height, style, seed, colour, false)
	_build_roof(item, outline, height, colour, seed)
	if shops and style != Style.GLASS:
		_trim_fronts(outline, height, colour, seed, item.has("base"))


func _build_roof(item: Dictionary, outline: PackedVector2Array, h: float, colour: Color, seed: float) -> void:
	var roof := SLATE.lerp(Color(0.48, 0.47, 0.45), seed * 0.55)
	var centre := _centroid(outline)
	var rise := 1.9 + seed * 1.8
	var shaped: bool = h > 8.0 and not item.has("holes") and outline.size() <= 22 and absf(_area(outline)) > 36.0 \
		and item["roof"] not in ["flat", "terrace"] and Geometry2D.is_point_in_polygon(centre, outline)
	if shaped:
		var top := PackedVector2Array()
		for p in outline:
			top.append(p.lerp(centre, 0.29 if _is_paris() else 0.47))
		for i in outline.size():
			var j := (i + 1) % outline.size()
			var a := _w(outline[i].x, outline[i].y, h)
			var b := _w(outline[j].x, outline[j].y, h)
			var c := _w(top[j].x, top[j].y, h + rise)
			var d := _w(top[i].x, top[i].y, h + rise)
			var st := _tool("solid", a)
			st.set_color(roof)
			var normal := (d - a).cross(b - a).normalized()
			st.set_normal(normal)
			_front_quad(st, a, b, c, d, normal)
		_cap(top, h + rise, roof.lightened(0.08))
	else:
		if item.has("caps"):
			for raw in item["caps"]:
				_cap(_points(raw), h, roof)
		else:
			_cap(outline, h, roof)
		if h > 8.0:
			_parapet(outline, h, 0.32, colour.darkened(0.08))
	if h > 8.0 and Geometry2D.is_point_in_polygon(centre, outline) and not item.has("holes"):
		var top_y := h + (rise if shaped else 0.0)
		var f := _frame(centre, 0)
		var stack := LIMESTONE.darkened(0.1) if _is_paris() else IRISH_BRICKS[1]
		_obox(f, -0.52, -0.31, 0.52, 0.32, top_y - 0.02, top_y + 1.45, stack)
		_obox(f, -0.59, -0.38, 0.59, 0.38, top_y + 1.38, top_y + 1.50, stack.lightened(0.1))
		for side in [-0.28, 0.28]:
			_cyl("solid", _w(centre.x + side, centre.y, top_y + 1.50), 0.15, 0.35, IRISH_BRICKS[0], 7)


func _trim_fronts(outline: PackedVector2Array, height: float, stone: Color, seed: float, arcade: bool) -> void:
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var length := a.distance_to(b)
		if length < 3.2:
			continue
		var f := _edge_frame(a, b)
		if not _fits_street(_fp(f, 0.0, -1.65), 0.32):
			continue
		var half := length * 0.5 - 0.09
		_obox(f, -half, -0.30, half, 0.04, height - 0.38, height - 0.12, stone.lightened(0.12))
		_obox(f, -half, -0.37, half, -0.02, height - 0.19, height - 0.06, stone.lightened(0.08))
		if not arcade:
			_obox(f, -half, -0.15, half, 0.02, 0.08, 0.36, stone.darkened(0.22))
		if height > 10.0:
			_obox(f, -half, -0.18, half, 0.025, 4.45, 4.58, stone.lightened(0.10))
		if _is_paris() and not arcade and length < 32.0 and seed > 0.12 and height > 12.0:
			for y in [7.88, maxf(10.7, height - 3.25)]:
				_obox(f, -half, -0.66, half, 0.005, y - 0.11, y + 0.045, stone.darkened(0.06))
				_railing(f, -half, half, -0.64, y, 0.88, 0.28)
				for j in range(1, floori(half) + 1, 3):
					for s in [-float(j), float(j)]:
						_obox(f, s - 0.12, -0.42, s + 0.12, -0.04, y - 0.38, y - 0.07, stone.lightened(0.03))
				if length > 7.5 and seed > 0.50:
					_flower_box(f, length * 0.26, -0.50, y + 0.21, 1.3)
		elif not _is_paris() and not arcade and length > 5.8 and length < 19.0 and seed > 0.38:
			var trim := stone.lightened(0.23)
			for s in [-half + 0.22, half - 0.22]:
				_obox(f, s - 0.15, -0.22, s + 0.15, 0.02, 0.1, 4.27, trim)
			_obox(f, -half, -0.27, half, 0.02, 3.94, 4.22, trim)
		if length > 5.3 and not arcade and seed > 0.27:
			for side in [-1.0, 1.0]:
				var edge: float = half * side
				for y in range(5, mini(int(height - 1.0), 20)):
					_obox(f, edge - 0.18, -0.055, edge + 0.18, 0.01, y, y + 0.34, stone.lightened(0.04))


func _edge_frame(a: Vector2, b: Vector2) -> Array:
	return _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))


func _railing(f: Array, s0: float, s1: float, t: float, y: float, h: float, spacing: float) -> void:
	_obox(f, s0, t - 0.045, s1, t + 0.045, y + h - 0.065, y + h, CAST_IRON)
	_obox(f, s0, t - 0.027, s1, t + 0.027, y + 0.1, y + 0.14, CAST_IRON)
	var count := maxi(2, int((s1 - s0) / spacing))
	for i in count + 1:
		var s := lerpf(s0, s1, float(i) / count)
		_obox(f, s - 0.024, t - 0.024, s + 0.024, t + 0.024, y + 0.02, y + h, CAST_IRON)


func _lantern(at: Vector2, h: float) -> void:
	_cyl("solid", _w(at.x, at.y), 0.17, 0.55, CAST_IRON, 8)
	_cone("solid", _w(at.x, at.y, 0.30), 0.105, 0.055, h - 0.64, CAST_IRON, 8)
	_cone("glow", _w(at.x, at.y, h - 0.35), 0.13, 0.22, 0.42, Color(0.90, 0.74, 0.44), 6)
	_cone("solid", _w(at.x, at.y, h + 0.055), 0.25, 0.06, 0.21, CAST_IRON, 6)


func _city_bench(f: Array, t: float) -> void:
	for side in [-0.7, 0.7]:
		_obox(f, side - 0.05, t - 0.22, side + 0.05, t + 0.19, 0.02, 0.44, CAST_IRON)
	for i in 4:
		var z := t - 0.20 + float(i) * 0.112
		_obox(f, -0.96, z, 0.96, z + 0.09, 0.42, 0.49, Color(0.37, 0.25, 0.15))
	_obox(f, -0.96, t + 0.23, 0.96, t + 0.30, 0.65, 0.88, Color(0.37, 0.25, 0.15))


func _bollard(p: Vector2) -> void:
	_cyl("solid", _w(p.x, p.y), 0.078, 0.86, CAST_IRON, 8)
	_globe("solid", _w(p.x, p.y, 0.86), 0.081, CAST_IRON)


func _street_bin(p: Vector2) -> void:
	_cyl("solid", _w(p.x, p.y), 0.28, 0.87, CAST_IRON, 10)
	_cyl("solid", _w(p.x, p.y, 0.76), 0.32, 0.12, Color(0.22, 0.26, 0.24), 10)
	_cyl("solid", _w(p.x, p.y, 0.88), 0.21, 0.019, Color(0.06, 0.07, 0.06), 10)


func _build_street_details() -> void:
	var props: Dictionary = _data["props"]
	for raw in props["trees"]:
		var p := _point(raw)
		_trees.append(["street_tree", _w(p.x, p.y), _rng.randf_range(0.76, 1.03)])
		_prop_positions.append(p)
	for raw in props["lamps"]:
		var p := _point(raw)
		if _prop_positions.all(func(other): return p.distance_squared_to(other) > 2.5):
			_lantern(p, 4.6)
			_prop_positions.append(p)
	for street in _data["focus"]:
		var line := _points(street[0])
		var name := str(street[2])
		var wide := name.begins_with("Boulevard") or name == "Grafton Street"
		for i in range(1, line.size()):
			var a := line[i - 1]
			var b := line[i]
			var dir := (b - a).normalized()
			for d in range(9, int(a.distance_to(b)) - 7, 16 if wide else 24):
				for sign in [-1.0, 1.0]:
					var p: Vector2 = a + dir * d + dir.orthogonal() * (float(street[1]) * 0.5 + 0.85) * sign
					if not _fits_street(p, 0.7) or _prop_positions.any(func(other): return p.distance_squared_to(other) < 18.0):
						continue
					_prop_positions.append(p)
					var f := _frame(p, rad_to_deg(dir.angle()))
					if (d + i) % 3 == 0:
						_city_bench(f, 0.0)
					elif (d + i) % 3 == 1:
						_street_bin(p)
					else:
						_lantern(p, 5.1 if _is_paris() else 4.25)
		if line.size() > 1 and (line[-1] - line[0]).length() > 24.0 and wide:
			_street_name(line[0].lerp(line[1], 0.35), (line[1] - line[0]).normalized(), street[1], name)


func _street_name(at: Vector2, along: Vector2, width: float, label: String) -> void:
	var p := at + along.orthogonal() * (width * 0.5 + 0.9)
	if not _fits_street(p, 0.4):
		return
	var f := _frame(p, rad_to_deg(along.angle()))
	var text := label.to_upper()
	var half := maxf(0.7, text.length() * 0.038)
	_cyl("solid", _w(p.x, p.y), 0.045, 2.49, CAST_IRON, 8)
	_obox(f, -half, -0.05, half, 0.05, 2.08, 2.39, STREET_SIGN)
	_engraving(f, 0, -0.056, 2.23, text, PAINT, half * 1.85)
	_engraving(f, 0, 0.056, 2.23, text, PAINT, half * 1.85, 1.0)


func _front(key: String, requested_half: float) -> Array:
	if not _data["fronts"].has(key):
		return []
	var data: Array = _data["fronts"][key]
	var a := _point(data[0])
	var b := _point(data[1])
	var direction := (b - a).normalized()
	var half := minf(requested_half, a.distance_to(b) * 0.48)
	var at := clampf((_point(data[2]) - a).dot(direction), half, a.distance_to(b) - half)
	return [_frame(a + direction * at, rad_to_deg(direction.angle())), half]


func _engraving(f: Array, s: float, t: float, y: float, title: String, ink: Color, width: float, side := -1.0) -> void:
	var label := Label3D.new()
	label.text = title
	label.font_size = 52
	label.pixel_size = width / maxf(50.0, title.length() * 33.0)
	label.outline_size = 0
	label.modulate = ink
	label.no_depth_test = false
	label.visibility_range_end = 94.0
	var p := _fp(f, s, t)
	label.position = _w(p.x, p.y, y)
	label.rotation_degrees.y = _face_yaw(f, side)
	add_child(label)


func _arch_face(f: Array, half: float, spring: float, rise: float, trim: Color, fill: Color, open := false) -> void:
	var st := _tool("solid", _w(f[0].x, f[0].y))
	var facing: Vector2 = -f[2]
	var normal := Vector3(facing.x, 0.0, facing.y)
	st.set_normal(normal)
	for i in 18:
		var a := Vector2.from_angle(PI * i / 18.0)
		var b := Vector2.from_angle(PI * (i + 1) / 18.0)
		var c := _front_point(f, a.x * half, -0.09, spring + a.y * rise)
		var d := _front_point(f, b.x * half, -0.09, spring + b.y * rise)
		st.set_color(trim.lightened(0.055 if i % 2 == 0 else 0.0))
		_front_quad(st, c, d, _front_point(f, b.x * (half + 0.18), -0.09, spring + b.y * (rise + 0.18)),
			_front_point(f, a.x * (half + 0.18), -0.09, spring + a.y * (rise + 0.18)), normal)
		if not open:
			st.set_color(fill)
			_front_tri(st, _front_point(f, 0.0, -0.08, spring), c, d, normal)
	for side in [-1.0, 1.0]:
		_obox(f, side * (half + 0.09) - 0.09, -0.12, side * (half + 0.09) + 0.09, 0.02, 0.03, spring, trim)
	if not open:
		_obox(f, -half, -0.076, half, 0.00, 0.02, spring, fill)


func _front_point(f: Array, s: float, t: float, y: float) -> Vector3:
	var p := _fp(f, s, t)
	return _w(p.x, p.y, y)


func _awning(f: Array, s: float, half: float, y: float, reach: float, colour: Color) -> void:
	var st := _tool("solid", _front_point(f, s, 0, y))
	st.set_color(colour)
	var a := _front_point(f, s - half, -0.03, y)
	var b := _front_point(f, s + half, -0.03, y)
	var c := _front_point(f, s + half, -reach, y - 0.73)
	var d := _front_point(f, s - half, -reach, y - 0.73)
	var normal := (d - a).cross(b - a).normalized()
	st.set_normal(normal)
	_front_quad(st, a, b, c, d, normal)
	st.set_normal(-normal)
	_front_quad(st, d, c, b, a, -normal)
	_obox(f, s - half, -reach - 0.035, s + half, -reach + 0.035, y - 0.88, y - 0.73, colour.darkened(0.15))


func _build_landmarks() -> void:
	pass


func _flower_box(f: Array, s: float, t: float, y: float, span: float) -> void:
	var h := span * 0.5
	_obox(f, s - h, t - 0.16, s + h, t + 0.16, y, y + 0.23, Color(0.28, 0.21, 0.15))
	for i in maxi(3, roundi(span / 0.21)):
		var loc := _fp(f, s - h + 0.16 + i * 0.17, t)
		_globe("solid", _w(loc.x, loc.y, y + 0.29), 0.13, Color(0.29, 0.39, 0.20))
		_globe("solid", _w(loc.x, loc.y, y + 0.38 + (i % 2) * 0.035), 0.057,
			Color(0.68, 0.20, 0.27) if i % 3 == 0 else Color(0.87, 0.67, 0.28))


func _shopfront(key: String, title: String, board: Color, ink: Color, width: float, canopy: bool) -> void:
	var door := _front(key, width * 0.5)
	if door.is_empty():
		return
	var f: Array = door[0]
	var h: float = door[1]
	_obox(f, -h, -0.21, h, 0.015, 3.51, 4.32, board)
	for y in [3.49, 4.27]:
		_obox(f, -h - 0.04, -0.29, h + 0.04, -0.08, y, y + 0.076, board.lightened(0.27))
	_engraving(f, 0, -0.229, 3.91, title, ink, h * 1.82)
	for s in [-h + 0.15, 0.0, h - 0.15]:
		_obox(f, s - 0.064, -0.11, s + 0.064, 0.01, 0.39, 3.50, board.lightened(0.10))
	_obox(f, -h, -0.11, h, 0.01, 0.11, 0.42, board)
	if canopy:
		_awning(f, 0, h * 0.95, 3.52, 0.98, board.lightened(0.16))


func _sign_panel(f: Array, s: float, t: float, y: float, width: float, h: float, title: String, board: Color, ink: Color) -> void:
	_obox(f, s - width * 0.5, t, s + width * 0.5, t + 0.045, y - h * 0.5, y + h * 0.5, board)
	_engraving(f, s, t - 0.013, y, title, ink, width * 0.9)


func _disc_face(f: Array, s: float, t: float, y: float, radius: float, ring: float, colour: Color) -> void:
	var st := _tool("solid", _front_point(f, s, t, y))
	var facing: Vector2 = -f[2]
	var normal := Vector3(facing.x, 0, facing.y)
	st.set_color(colour)
	st.set_normal(normal)
	for k in 24:
		var a := Vector2.from_angle(TAU * k / 24.0)
		var b := Vector2.from_angle(TAU * (k + 1) / 24.0)
		var p := _front_point(f, s + a.x * radius, t, y + a.y * radius)
		var q := _front_point(f, s + b.x * radius, t, y + b.y * radius)
		_front_quad(st, p, q, _front_point(f, s + b.x * ring, t, y + b.y * ring),
			_front_point(f, s + a.x * ring, t, y + a.y * ring), normal)


func _spawn_cars() -> void:
	for row in _parked_rows():
		var a: Vector2 = row[0]
		var b: Vector2 = row[1]
		var dir := (b - a).normalized()
		for d in range(3, int(a.distance_to(b)) - 2, 7):
			var p := a + dir * d
			if _fits_street(p, 1.24):
				_car_spots.append(_car_transform(p.x, p.y, rad_to_deg(atan2(dir.x, dir.y))))
	super._spawn_cars()


func _build_traffic() -> void:
	var models := []
	for model in CAR_MODELS:
		var mesh := _car_mesh(model[0])
		if mesh != null:
			models.append([mesh, model[2], _materials.get("car_paint")])
	if models.is_empty():
		return

	var traffic := Node3D.new()
	traffic.name = "Traffic"
	traffic.set_script(TRAFFIC)
	traffic.set("models", models)
	traffic.set("colors", CAR_COLORS.map(func(p): return p[0]))
	traffic.set("lanes", _traffic_lanes())
	traffic.set("smooth_loops", true)
	traffic.set("rail_crossings", _traffic_rail_crossings())
	add_child(traffic)


func _traffic_lanes() -> Array:
	return []


func _traffic_rail_crossings() -> Dictionary:
	return {}
