extends "res://district_moscow_landmarks.gd"
## A stylized Red Square and surrounding streets within a 300 m city wall.

const CAFE_RED := Color(0.56, 0.14, 0.12)
const MOSCOW_RADIUS := 300.0
const WALL_WALK_RADIUS := 293.0
const WALL_PATROL_SECTORS := 8
const WALL_PATROL_SPAWNS := [1, 3, 5, 7, 9]
const PLAZA_COLUMNS := [-35.0, -17.5, 0.0, 17.5, 35.0]
const PLAZA_ROWS := [-98.0, -78.0, -58.0, -38.0, -18.0, 2.0, 22.0, 42.0, 62.0]
const INNER_STREETS := [
	Vector2(-80, -140), Vector2(0, -140), Vector2(83, -140), Vector2(83, 0),
	Vector2(83, 130), Vector2(0, 130), Vector2(-80, 130), Vector2(-80, 0),
]
const OUTER_STREETS := [
	Vector2(-145, -188), Vector2(0, -232), Vector2(145, -188), Vector2(232, 0),
	Vector2(145, 188), Vector2(0, 232), Vector2(-145, 188), Vector2(-232, 0),
]
const NORTH_WALK := [Vector2(17.5, -98), Vector2(22.4, -110), Vector2(22.4, -127), Vector2(22.4, -140)]
const WEST_WALK := [Vector2(-35, 62), Vector2(-37, 86), Vector2(-65, 95), Vector2(-80, 95)]
const EAST_WALK := [Vector2(35, 62), Vector2(39, 96), Vector2(69, 96), Vector2(83, 96)]
const NEIGHBORHOOD_WALKS := [
	[Vector2(-65, -134), Vector2(-32, -134), Vector2(0, -134), Vector2(34, -134), Vector2(65, -134)],
	[Vector2(89, -112), Vector2(89, -66), Vector2(89, -10), Vector2(89, 19)],
	[Vector2(-56, 124), Vector2(-30, 124), Vector2(0, 124), Vector2(30, 124), Vector2(58, 124)],
	[Vector2(-86, -49), Vector2(-86, -15), Vector2(-86, 24), Vector2(-86, 63), Vector2(-86, 100)],
	[Vector2(218, 12), Vector2(202, 51), Vector2(187, 82), Vector2(171, 119), Vector2(157, 148)],
]


func _enter_tree() -> void:
	pass


func _ready() -> void:
	_rng.seed = 1147
	_collision = StaticBody3D.new()
	_collision.name = "DistrictCollision"
	add_child(_collision)
	_set_city_environment()
	var environment := (get_node("../../WorldEnvironment") as WorldEnvironment).environment
	environment.fog_density = 0.00058
	(environment.sky.sky_material as ShaderMaterial).set_shader_parameter("cloud_cover", 0.43)
	_build_boundary()
	_build_neighborhood()
	_build_wall_walk()
	_build_square()
	_kremlin()
	_build_kremlin_courts()
	_gum()
	_museum()
	_cathedral()
	_build_promenade()
	_forecourt_gardens()
	_build_zaryadye()
	_build_tree_meshes()
	_commit_chunks()
	_commit_wall_faces()
	_spawn_cars()
	_build_traffic()
	var ambience := Node.new()
	ambience.name = "Ambience"
	ambience.set_script(load("res://ambience.gd"))
	ambience.set("layers", [["res://audio/city_hum.wav", -17.0], ["res://audio/wind.wav", -23.0], ["res://audio/birds.ogg", -27.0]])
	add_child(ambience)


func intro_text() -> String:
	return "Red Square · Moscow. Walk through the Kremlin arch to the courtyard, or follow the signs to Zaryadye Park."


func spawn_points() -> Array[Vector2]:
	return [Vector2(-10, 48), Vector2(9, 45), Vector2(-14, 36), Vector2(13, 35)]


func spawn_yaw() -> float:
	return PI


func _boundary_outline() -> PackedVector2Array:
	return _circle(MOSCOW_RADIUS)


func _boundary_rim() -> float:
	return MOSCOW_RADIUS - 9.0


func _inside_street_limits(at: Vector2) -> bool:
	return at.length() < _boundary_rim()


func _traffic_lanes() -> Array:
	var outer := OUTER_STREETS.duplicate()
	outer.reverse()
	return [[Array(INNER_STREETS), 8], [outer, 7]]


func _parked_rows() -> Array:
	return [
		[Vector2(-85.8, -92), Vector2(-85.8, -58)],
		[Vector2(88.8, 25), Vector2(88.8, 57)],
		[Vector2(-55, 135.8), Vector2(-24, 135.8)],
		[Vector2(66, -145.8), Vector2(41, -145.8)],
	]


func bot_graph() -> Dictionary:
	var nodes: Array[Vector2] = []
	var edges := []
	var no_spawn := []
	var columns := PLAZA_COLUMNS.size()
	var spawns := spawn_points()
	for row in PLAZA_ROWS.size():
		for column in columns:
			var index := nodes.size()
			var point := Vector2(PLAZA_COLUMNS[column], PLAZA_ROWS[row])
			nodes.append(point)
			if column > 0:
				edges.append([index - 1, index])
			if row > 0:
				edges.append([index - columns, index])
			for spawn_at in spawns:
				if point.distance_squared_to(spawn_at) < 64.0:
					no_spawn.append(index)
					break
	var inner := nodes.size()
	nodes.append_array(INNER_STREETS)
	var outer := nodes.size()
	nodes.append_array(OUTER_STREETS)
	for i in INNER_STREETS.size():
		var next := (i + 1) % INNER_STREETS.size()
		edges.append_array([[inner + i, inner + next], [outer + i, outer + next], [inner + i, outer + i]])
	_connect_walk(nodes, edges, NORTH_WALK, 3, inner + 1, inner + 2)
	_connect_walk(nodes, edges, WEST_WALK, inner - columns, inner + 6, inner + 7)
	_connect_walk(nodes, edges, EAST_WALK, inner - 1, inner + 3, inner + 4)
	var park_entrance := nodes.size() - 1
	var routes := [{"nodes": PackedInt32Array(range(nodes.size())), "spawns": PackedInt32Array()}]
	var street_joins := [inner + 1, inner + 3, inner + 5, inner + 7, outer + 3]
	for i in NEIGHBORHOOD_WALKS.size():
		var walk: Array = NEIGHBORHOOD_WALKS[i]
		var route := _add_patrol_route(nodes, edges, routes, walk, [1, walk.size() - 2])
		var junction: int = [2, 2, 2, 1, 0][i]
		edges.append([route + junction, street_joins[i]])
	var park := _add_patrol_route(nodes, edges, routes, PARK_WALK, [1, 3, 5, 7, 9, 11])
	edges.append_array([[park, park_entrance], [park + 1, park + PARK_WALK.size() - 1]])
	var court := _add_patrol_route(nodes, edges, routes, KREMLIN_WALK, [2, 4, 7, 9])
	var hall := _add_patrol_route(nodes, edges, routes, KREMLIN_HALL_WALK, [1, 3])
	edges.append_array([[court, (PLAZA_ROWS.size() - 2) * columns], [court + KREMLIN_WALK.size() - 1, hall]])
	_add_wall_patrols(nodes, edges, routes, outer)
	# Keep existing network slots stable by appending the new park walkers.
	var bridge_walk := _bridge_walk()
	var bridge := _add_patrol_route(nodes, edges, routes, bridge_walk, [0, bridge_walk.size() - 1])
	var theatre := _add_patrol_route(nodes, edges, routes, _amphitheatre_walk(), [0])
	edges.append_array([[bridge, park + 11], [bridge + bridge_walk.size() - 1, park + 10], [theatre, park + 5]])
	# The original crowd still spawns on the square. Each new patrol has its own homes.
	no_spawn.append_array(range(inner, nodes.size()))
	return {
		"nodes": nodes, "edges": edges, "no_spawn": no_spawn, "uniformed_half": true,
		"patrol_routes": routes,
		"patrol_spots": [Vector2(-32, -92), Vector2(33, -82), Vector2(-30, -47), Vector2(33, -27),
			Vector2(-32, 12), Vector2(33, 23), Vector2(-32, 55), Vector2(33, 59)],
	}


func _add_patrol_route(nodes: Array[Vector2], edges: Array, routes: Array, walk: Array, spawn_indices: Array) -> int:
	var first := nodes.size()
	nodes.append_array(walk)
	for i in range(first + 1, nodes.size()):
		edges.append([i - 1, i])
	var spawns := PackedInt32Array()
	for index: int in spawn_indices:
		spawns.append(first + index)
	routes.append({"nodes": PackedInt32Array(range(first, nodes.size())), "spawns": spawns})
	return first


func _add_wall_patrols(nodes: Array[Vector2], edges: Array, routes: Array, outer: int) -> void:
	var ring := _circle(WALL_WALK_RADIUS)
	var first := nodes.size()
	var sector_size := ring.size() / WALL_PATROL_SECTORS
	for sector in WALL_PATROL_SECTORS:
		var start := sector * sector_size
		_add_patrol_route(nodes, edges, routes, Array(ring.slice(start, start + sector_size)), WALL_PATROL_SPAWNS)
		# Players and police can cross between sectors. The residents stay on their own patrol.
		edges.append([first + start + sector_size - 1, first + (start + sector_size) % ring.size()])
	for i in [1, 3, 5, 7]:
		var link := _wall_walk_link(OUTER_STREETS[i], ring)
		var start := nodes.size()
		nodes.append_array(link.slice(1, 3))
		edges.append_array([[outer + i, start], [start, start + 1], [start + 1, first + ring.find(link[-1])]])


func _wall_walk_link(road: Vector2, ring: PackedVector2Array) -> Array[Vector2]:
	var outward := road.normalized()
	var side := outward.orthogonal() * 5.4
	var junction := posmod(roundi(road.angle() / TAU * ring.size()), ring.size())
	return [road, road + outward * 6.0 + side, ring[junction] - outward * 20.0 + side, ring[junction]]


func _build_wall_walk() -> void:
	var ring := _circle(WALL_WALK_RADIUS)
	var paving := Color(0.61, 0.55, 0.49)
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		_gpoly(PackedVector2Array([a - a.normalized() * 3.4, a + a.normalized() * 3.4,
			b + b.normalized() * 3.4, b - b.normalized() * 3.4]), 0.037, paving, Surface.GRANITE)
	for i in [1, 3, 5, 7]:
		var link := _wall_walk_link(OUTER_STREETS[i], ring)
		for j in link.size() - 1:
			_gstrip(link[j], link[j + 1], 4.8, 0.039, paving, Surface.GRANITE)


func _connect_walk(nodes: Array[Vector2], edges: Array, walk: Array, start: int, end_a: int, end_b: int) -> void:
	var previous := start
	for i in range(1, walk.size()):
		var index := nodes.size()
		nodes.append(walk[i])
		edges.append([previous, index])
		previous = index
	edges.append_array([[previous, end_a], [previous, end_b]])


func _build_neighborhood() -> void:
	var streets := []
	for i in INNER_STREETS.size():
		var next := (i + 1) % INNER_STREETS.size()
		streets.append_array([
			[INNER_STREETS[i], INNER_STREETS[next]], [OUTER_STREETS[i], OUTER_STREETS[next]],
			[INNER_STREETS[i], OUTER_STREETS[i]],
		])
	for street in streets:
		_gstrip(street[0], street[1], 12.0, 0.045, Color(0.62, 0.57, 0.51), Surface.GRANITE)
		_gstrip(street[0], street[1], 8.0, 0.085, Color(0.35, 0.34, 0.34), Surface.ASPHALT)
	for point in INNER_STREETS + OUTER_STREETS:
		_grect(point.x - 4.3, point.y - 4.3, point.x + 4.3, point.y + 4.3,
			0.084, Color(0.35, 0.34, 0.34), Surface.ASPHALT)
	for walk in [NORTH_WALK, WEST_WALK, EAST_WALK]:
		for i in walk.size() - 1:
			_gstrip(walk[i], walk[i + 1], 6.0, 0.051, Color(0.62, 0.57, 0.51), Surface.GRANITE)
		_crosswalk(walk[-1], absf(walk[-1].x) < 79.0)
	for row in _parked_rows():
		var a: Vector2 = row[0]
		var b: Vector2 = row[1]
		_gstrip(a, b, 2.75, 0.086, Color(0.35, 0.34, 0.34), Surface.ASPHALT)
		var along := (b - a).normalized()
		var side := along.orthogonal()
		for offset in range(1, int(a.distance_to(b)) - 1, 7):
			var at := a + along * offset
			_gstrip(at - side * 1.2, at + side * 1.2, 0.10, 0.092, WHITE_STONE, Surface.PAINT)

	var landmarks := Rect2(-80, -141, 163, 271)
	for x in range(-253, 254, 36):
		for z in range(-252, 253, 36):
			var point := Vector2(x, z)
			if landmarks.grow(11.0).has_point(point) or PARK_BOUNDS.grow(14.0).has_point(point) or point.length() > 267.0:
				continue
			var clearance := INF
			for street in streets:
				var nearest := Geometry2D.get_closest_point_to_segment(point, street[0], street[1])
				clearance = minf(clearance, nearest.distance_to(point))
			if clearance > 21.0:
				_city_building(point)
			elif clearance > 8.0:
				_trees.append(["street_tree", _w(point.x, point.y), _rng.randf_range(0.78, 1.08)])
				_lantern(point + Vector2(1.65, 0), 4.5)


func _city_building(point: Vector2) -> void:
	var half_width := _rng.randf_range(9.0, 13.2)
	var half_depth := _rng.randf_range(6.4, 9.4)
	var height := _rng.randf_range(9.6, 19.0)
	var stone: Color = PALE_STONE[_rng.randi_range(0, PALE_STONE.size() - 1)]
	var style := Style.PARIS_STONE
	if _rng.randf() < 0.32:
		stone = BRICK_RED.lightened(0.27)
		style = Style.DUBLIN_BRICK
	var frame := _frame(point, 90 if absf(point.x) > absf(point.y) else 0)
	var corners := PackedVector2Array([
		_fp(frame, -half_width, -half_depth), _fp(frame, half_width, -half_depth),
		_fp(frame, half_width, half_depth), _fp(frame, -half_width, half_depth),
	])
	var shops := point.length() < 214 and _rng.randf() < 0.40
	_extrude(corners, 0, height, style, _rng.randf(), stone, shops)
	_register_ground(corners, [])
	_obox(frame, -half_width - 0.25, -half_depth - 0.25, half_width + 0.25, half_depth + 0.25,
		height - 0.45, height + 0.13, WHITE_STONE)
	_build_roof({"roof": "hipped"}, corners, height, stone, _rng.randf())


func _crosswalk(point: Vector2, north_south: bool) -> void:
	var across := Vector2.RIGHT if north_south else Vector2.DOWN
	var along := across.orthogonal()
	for i in range(-3, 4):
		var middle := point + across * i * 1.0
		_gstrip(middle - along * 1.6, middle + along * 1.6, 0.52,
			0.092, Color(0.87, 0.84, 0.73), Surface.PAINT)


func _build_square() -> void:
	var paving := Color(0.46, 0.43, 0.41)
	var walkway := Color(0.65, 0.60, 0.54)
	_grect(-63, -143, 66, 134, 0.027, paving, Surface.SETTS)
	_grect(-50, -114, 52, 118, 0.048, paving.lightened(0.05), Surface.SETTS)
	_grect(-47, -106, -39, 75, 0.061, walkway, Surface.GRANITE)
	_grect(39, -115, 53, 115, 0.061, walkway, Surface.GRANITE)
	_grect(-48, 74, 39, 112, 0.065, walkway.darkened(0.06), Surface.GRANITE)
	_grect(-45, -115, 39, -107, 0.061, walkway, Surface.GRANITE)
	for x in [-39, 39]:
		_grect(x - 0.14, -106, x + 0.14, 74, 0.070, walkway.lightened(0.10), Surface.GRANITE)
	for z in range(-88, 77, 27):
		_lantern(Vector2(43, z), 5.1)
		_city_bench(_frame(Vector2(46, z + 3.5), 90), 0)
		_street_bin(Vector2(43.3, z + 4))
	for z in [-80, -47, 16, 47]:
		_lantern(Vector2(-44, z), 4.7)
	for z in [84, 96, 108]:
		for x in [-32, 32]:
			_trees.append(["street_tree", Vector3(x, 0, z), _rng.randf_range(0.85, 1.13)])


func _kremlin() -> void:
	var wall := _frame(Vector2(-51, 0), 90)
	for ends in [Vector2(-123, 28.6), Vector2(37.4, 82)]:
		_brick_shell(wall, Rect2(ends.x, -3.2, ends.y - ends.x, 5.2), -0.2, 9.7, BRICK_RED)
		_ocollider(wall, ends.x, -3.2, ends.y, 2.0, -0.2, 10.9)
		_obox(wall, ends.x, -3.25, ends.y, 2.12, 0.0, 0.58, BRICK_SHADE)
	_brick_shell(wall, Rect2(28.6, -3.2, 8.8, 5.2), 5.5, 9.7, BRICK_RED)
	_ocollider(wall, 28.6, -3.2, 37.4, 2.0, 5.5, 10.9)
	_kremlin_arch()
	_obox(wall, -123, -3.3, 82, 2.19, 8.9, 9.45, BRICK_SHADE)
	for z in range(-121, 82, 3):
		_obox(wall, z, -2.0, z + 1.55, 2.10, 9.5, 11.25, BRICK_RED.lightened(0.08))
		for offset in [0.0, 1.04]:
			_obox(wall, z + offset, 0.45, z + offset + 0.51, 2.13, 11.15, 11.75, BRICK_RED)

	var tower := _frame(Vector2(-49, 66), 90)
	_brick_shell(tower, Rect2(-7.5, -6.6, 15, 13.2), 0, 17.6, BRICK_RED)
	_ocollider(tower, -7.5, -6.6, 7.5, 6.6, 0, 17.6)
	_obox(tower, -7.8, -6.85, 7.8, 6.85, 16.7, 17.8, WHITE_STONE)
	_brick_shell(tower, Rect2(-5.5, -5.4, 11, 10.8), 17.8, 29.8, BRICK_RED.lightened(0.05))
	for height in [19.0, 27.6, 29.1]:
		_obox(tower, -5.7, -5.6, 5.7, 5.6, height, height + 0.58, WHITE_STONE)
	for yaw in [0, 90, 180, 270]:
		var face := _frame(Vector2(-49, 66), yaw)
		_disc_face(face, 0, -5.67, 23.55, 3.38, 0.0, BRICK_SHADE)
		_disc_face(face, 0, -5.70, 23.55, 3.06, 0.0, GILT)
		_disc_face(face, 0, -5.73, 23.55, 2.86, 0.0, Color(0.055, 0.047, 0.042))
		for mark in 12:
			var angle := TAU * mark / 12.0
			_disc_face(face, cos(angle) * 2.36, -5.75, 23.55 + sin(angle) * 2.36, 0.12, 0, GILT)
		_obox(face, -0.10, -5.80, 0.10, -5.74, 23.5, 25.54, GILT)
		_obox(face, -1.48, -5.80, 0.10, -5.74, 23.43, 23.63, GILT)
	var roof := PackedVector2Array([Vector2(-6.05, -6.05), Vector2(6.05, -6.05),
		Vector2(6.05, 6.05), Vector2(-6.05, 6.05)])
	for side in roof.size():
		var a := roof[side]
		var b := roof[(side + 1) % roof.size()]
		var p := _front_point(tower, a.x, a.y, 29.8)
		var q := _front_point(tower, b.x, b.y, 29.8)
		var r := _front_point(tower, b.x * 0.11, b.y * 0.11, 42.1)
		var s := _front_point(tower, a.x * 0.11, a.y * 0.11, 42.1)
		var normal := (s - p).cross(q - p).normalized()
		var st := _tool("solid", p)
		st.set_color(ROOF_GREEN)
		st.set_normal(normal)
		_front_quad(st, p, q, r, s, normal)
	_cyl("solid", Vector3(-49, 41.8, 66), 0.16, 2.4, GILT, 8)
	_star(_frame(Vector2(-49, 66), 0), 44.7)
	_star(_frame(Vector2(-49, 66), 90), 44.7)

	var tomb := _frame(Vector2(-41, -14), 90)
	for tier in [[10.0, 4.6, 0.0, 1.1], [8.5, 4.05, 1.1, 4.8], [6.3, 3.4, 4.8, 6.0], [4.1, 2.5, 6.0, 7.0]]:
		_obox(tomb, -tier[0], -tier[1], tier[0], tier[1], tier[2], tier[3],
			Color(0.34, 0.14, 0.13) if tier[2] < 1.2 else Color(0.42, 0.22, 0.20))
	_ocollider(tomb, -10.0, -4.6, 10.0, 4.6, 0, 7.0)
	_sign_panel(tomb, 0, -4.15, 3.1, 5.7, 1.2, "ЛЕНИН", BRICK_SHADE, WHITE_STONE)


func _star(f: Array, y: float) -> void:
	var st := _tool("solid", _front_point(f, 0, 0, y))
	st.set_color(Color(0.85, 0.07, 0.10))
	for side in [-1.0, 1.0]:
		var normal: Vector3 = _fbasis(f).z * side
		st.set_normal(normal)
		for i in 10:
			var a := Vector2.from_angle(PI / 2.0 + TAU * i / 10.0) * (1.60 if i % 2 == 0 else 0.72)
			var b := Vector2.from_angle(PI / 2.0 + TAU * (i + 1) / 10.0) * (0.72 if i % 2 == 0 else 1.60)
			_front_tri(st, _front_point(f, 0, side * 0.025, y),
				_front_point(f, a.x, side * 0.025, y + a.y), _front_point(f, b.x, side * 0.025, y + b.y), normal)


func _gum() -> void:
	var centre := _frame(Vector2(56, -18), -90)
	var stone := Color(0.77, 0.67, 0.52)
	var footprint := PackedVector2Array([_fp(centre, -104, -1), _fp(centre, 105, -1),
		_fp(centre, 105, 12), _fp(centre, -104, 12)])
	_extrude(footprint, 0, 4.95, Style.PARIS_STONE, 0.47, stone, true)
	_obox(centre, -104, -1.0, 105, 12.0, 4.95, 17.4, stone)
	_ocollider(centre, -104, -1.0, 105, 12.0, 4.95, 19.0)
	_obox(centre, -104.4, -1.48, 105.4, 12.3, 4.77, 5.23, WHITE_STONE)
	_obox(centre, -104.5, -1.65, 105.5, 12.5, 16.8, 18.1, WHITE_STONE)
	_obox(centre, -104.25, -1.40, 105.25, 12.2, 8.05, 8.55, WHITE_STONE)
	for i in range(-19, 20):
		var z := -18.0 + i * 5.28
		var bay := _frame(Vector2(55, z), -90)
		_arch_face(bay, 1.36, 7.15, 0.86, WHITE_STONE, WINDOW, true)
		for y in [10.2, 13.95]:
			_obox(bay, -1.40, -0.11, 1.40, 0.12, y - 0.24, y + 2.24, WHITE_STONE)
			_obox(bay, -1.13, -0.14, 1.13, -0.115, y, y + 1.95, WINDOW)
			_obox(bay, -0.055, -0.18, 0.055, -0.11, y, y + 1.95, WHITE_STONE)
		_obox(bay, -2.55, -0.32, -2.18, 0.07, 5.11, 17.05, stone.lightened(0.13))
		_obox(bay, -1.35, -0.075, 1.35, 0.025, 5.55, 7.18, WINDOW)
		_obox(bay, -0.065, -0.135, 0.065, -0.07, 5.55, 7.18, WHITE_STONE)
	for z in [-90.0, -18.0, 54.0]:
		var pavilion := _frame(Vector2(59, z), -90)
		_obox(pavilion, -6.0, -4.2, 6.0, 5.0, 17.5, 21.0, stone)
		_obox(pavilion, -6.3, -4.4, 6.3, 5.2, 20.75, 21.45, WHITE_STONE)
		_cone("solid", Vector3(59, 21.4, z), 7.6, 3.5, 5.0, ROOF_GREEN, 4)
		for side in [-4.3, 4.3]:
			_cyl("solid", Vector3(56, 21.2, z + side), 0.58, 2.9, stone, 8)
			_cone("solid", Vector3(56, 24, z + side), 0.83, 0.0, 1.8, ROOF_GREEN, 8)
	_engraving(centre, 0, -1.66, 17.45, "ГУМ", BRICK_SHADE, 5.0)
	for shop in [[-84.0, "КНИГИ"], [-43.0, "КОФЕ"], [-6.0, "ГУМ"], [31.0, "ЦВЕТЫ"], [69.0, "КОНДИТЕРСКАЯ"]]:
		var f := _frame(Vector2(55, shop[0]), -90)
		_awning(f, 0, 3.1, 4.44, 1.45, CAFE_RED if shop[0] < 0.0 else ROOF_GREEN)
		_sign_panel(f, 0, -0.20, 5.65, 5.6, 0.88, shop[1], ROOF_GREEN, WHITE_STONE)


func _build_promenade() -> void:
	for z in [-101, -64, -36, 0, 29, 65]:
		var balcony := _frame(Vector2(48.4, z), 90)
		_long_planter(balcony, 2.0)
	for spot in [Vector2(46.8, -32), Vector2(49.5, -29), Vector2(47.0, 34), Vector2(49.5, 37)]:
		_terrace_table(spot, CAFE_RED if spot.y < 0.0 else ROOF_GREEN)
	for z in [-102, 76]:
		for x in [38, 41, 44]:
			_bollard(Vector2(x, z))
	for z in [-84, 56]:
		var frame := _frame(Vector2(49.4, z), -90)
		_obox(frame, -1.30, -0.76, 1.30, 0.92, 0.07, 2.5, ROOF_GREEN)
		_ocollider(frame, -1.30, -0.76, 1.30, 0.92, 0, 2.5)
		_obox(frame, -1.10, -0.81, 1.10, -0.73, 1.08, 2.05, WINDOW)
		_obox(frame, -1.14, -0.93, 1.14, -0.69, 0.94, 1.12, WHITE_STONE)
		_awning(frame, 0, 1.50, 2.60, 0.99, CAFE_RED)
		_ybox("solid", _front_point(frame, 0, 0.12, 2.61), Vector3(3.09, 0.17, 2.0), -90, CAFE_RED)
		_sign_panel(frame, 0, -0.79, 2.29, 2.38, 0.34, "МОРОЖЕНОЕ" if z > 0 else "АФИША", BRICK_SHADE, WHITE_STONE)


func _long_planter(f: Array, half: float) -> void:
	_obox(f, -half, -0.68, half, 0.68, 0.04, 0.58, WHITE_STONE.darkened(0.22))
	_obox(f, -half - 0.07, -0.75, half + 0.07, 0.75, 0.48, 0.64, WHITE_STONE)
	_obox(f, -half + 0.09, -0.58, half - 0.09, 0.58, 0.61, 0.66, Color(0.22, 0.16, 0.10))
	_ocollider(f, -half, -0.68, half, 0.68, 0.0, 0.59)
	var blooms := [Color(0.91, 0.30, 0.30), Color(0.99, 0.74, 0.25), Color(0.69, 0.27, 0.48), WHITE_STONE]
	for i in int(half * 9):
		var at := _front_point(f, _rng.randf_range(-half + 0.2, half - 0.2), _rng.randf_range(-0.44, 0.44), 0.71)
		var height := _rng.randf_range(0.20, 0.34)
		_cone("solid", at, 0.14, 0.079, height, Color(0.24, 0.41, 0.12), 6)
		_globe("solid", at + Vector3.UP * height, _rng.randf_range(0.075, 0.127), blooms[i % blooms.size()])


func _terrace_table(point: Vector2, cloth: Color) -> void:
	var at := _w(point.x, point.y, 0.06)
	_cyl("solid", at, 0.065, 2.34, CAST_IRON, 8)
	_cyl("solid", at + Vector3.UP * 0.76, 0.56, 0.09, Color(0.49, 0.30, 0.18), 12)
	_cone("solid", at + Vector3.UP * 2.18, 1.32, 0.035, 0.40, cloth, 10)
	_globe("solid", at + Vector3.UP * 2.60, 0.068, GILT)
	for side in [-1.0, 1.0]:
		var seat := _frame(point + Vector2(side * 0.96, 0), 90)
		_obox(seat, -0.25, -0.22, 0.25, 0.22, 0.39, 0.49, Color(0.48, 0.31, 0.19))
		_obox(seat, -0.25, -side * 0.23 - 0.04, 0.25, -side * 0.23 + 0.04, 0.49, 0.94, CAST_IRON)
		for offset in [-0.18, 0.18]:
			_obox(seat, offset - 0.027, -0.21, offset + 0.027, 0.21, 0.06, 0.40, CAST_IRON)


func _forecourt_gardens() -> void:
	# An ornamental stone basin and gardens frame the view from the south road.
	var at := Vector3(15, 0.05, 116)
	var stone := Color(0.69, 0.64, 0.56)
	_cyl("solid", at, 4.9, 0.27, stone, 24)
	_cyl("solid", at + Vector3.UP * 0.26, 4.56, 0.55, stone.darkened(0.17), 24)
	_cyl("glass", at + Vector3.UP * 0.80, 4.30, 0.035, Color(0.16, 0.37, 0.40), 24)
	var f := _frame(Vector2(at.x, at.z), 0)
	for i in 24:
		var phi := TAU * i / 24.0
		var outward := Vector2.from_angle(phi)
		var rim := _frame(Vector2(at.x, at.z) + outward * 4.42, rad_to_deg(phi) + 90)
		_obox(rim, -0.59, -0.18, 0.59, 0.18, 0.83, 1.01, stone)
	_ocollider(f, -3.35, -3.35, 3.35, 3.35, 0, 0.96)
	_cyl("solid", at, 0.76, 2.05, stone, 12)
	_cone("solid", at + Vector3.UP * 1.74, 0.59, 1.40, 0.43, stone, 16)
	_cyl("glass", at + Vector3.UP * 2.16, 1.32, 0.055, Color(0.18, 0.41, 0.47), 16)
	_globe("solid", at + Vector3.UP * 2.38, 0.23, GILT)
	_fountain_spray(at + Vector3.UP * 2.5)
	for x in [-33.0, 36.0]:
		_long_planter(_frame(Vector2(x, 114), 90), 3.3)
		_city_bench(_frame(Vector2(x * 0.82, 113), 0), 0)
		_lantern(Vector2(x, 120), 4.4)


func _fountain_spray(at: Vector3) -> void:
	var water := CPUParticles3D.new()
	water.name = "FountainSpray"
	water.position = at
	water.amount = 46
	water.lifetime = 1.1
	water.preprocess = 1.0
	water.direction = Vector3.UP
	water.spread = 28.0
	water.initial_velocity_min = 3.2
	water.initial_velocity_max = 4.5
	water.gravity = Vector3(0, -8.8, 0)
	var drop := SphereMesh.new()
	drop.radius = 0.038
	drop.height = 0.076
	drop.radial_segments = 6
	drop.rings = 3
	var sheen := StandardMaterial3D.new()
	sheen.albedo_color = Color(0.62, 0.83, 0.89)
	sheen.roughness = 0.22
	drop.material = sheen
	water.mesh = drop
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _museum() -> void:
	var hall := _frame(Vector2(-12, -116), 180)
	_brick_shell(hall, Rect2(-28, -5.2, 56, 12.2), 0, 20.0, BRICK_RED)
	_ocollider(hall, -28, -5.2, 28, 7.0, 0, 20.0)
	for y in [6.3, 12.1, 18.8]:
		_obox(hall, -28.4, -5.5, 28.4, 7.3, y, y + 0.4, BRICK_RED.lightened(0.25))
	for x in range(-24, 26, 4):
		var bay := _frame(Vector2(x - 12, -110.78), 180)
		_arch_face(bay, 0.86, 3.4, 1.15, WHITE_STONE, WINDOW)
		for y in [8.5, 14.0]:
			_obox(bay, -0.72, -0.13, 0.72, 0.05, y, y + 2.6, WINDOW)
			_obox(bay, -0.96, -0.19, 0.96, 0, y + 2.45, y + 2.84, WHITE_STONE)
	for x in [-36, -23, 0, 12]:
		var tall: bool = x == -23 or x == 0
		var top := 29.0 if tall else 23.5
		_ybox("solid", Vector3(x, (top + 17.0) * 0.5, -115), Vector3(7.8, top - 17.0, 8.5), 0, BRICK_RED)
		_cone("solid", Vector3(x, top, -115), 5.6, 0.0, 8.1 if tall else 5.5, ROOF_GREEN, 4)
		_globe("solid", Vector3(x, top + (8.1 if tall else 5.5), -115), 0.27, GILT)
	_engraving(hall, 0, -5.55, 12.5, "ИСТОРИЧЕСКИЙ МУЗЕЙ", WHITE_STONE, 11.0)
	var gate := _frame(Vector2(27, -116), 180)
	for x in [-9.2, 0.0, 9.2]:
		_obox(gate, x - 1.1, -3.2, x + 1.1, 3.2, 0, 12.4, BRICK_RED)
		_ocollider(gate, x - 1.1, -3.2, x + 1.1, 3.2, 0, 12.4)
	_obox(gate, -10.3, -3.2, 10.3, 3.2, 6.15, 12.6, BRICK_RED)
	for x in [-4.6, 4.6]:
		var face := _frame(Vector2(27 + x, -112.78), 180)
		_arch_face(face, 3.45, 3.45, 3.1, WHITE_STONE, WINDOW, true)
		_cyl("solid", Vector3(27 + x, 12.55, -116), 2.3, 3.2, BRICK_RED, 8)
		_cone("solid", Vector3(27 + x, 15.6, -116), 2.9, 0.0, 6.8, ROOF_GREEN, 8)
		_globe("solid", Vector3(27 + x, 22.55, -116), 0.24, GILT)


func _cathedral() -> void:
	var base := _frame(Vector2(7, 93), 0)
	for step in 3:
		var inset := float(step) * 0.46
		_obox(base, -18 + inset, -13 + inset, 18 - inset, 13 - inset, step * 0.27, (step + 1) * 0.27, WHITE_STONE)
	_brick_shell(base, Rect2(-16.5, -11.5, 33, 23), 0.8, 7.1, BRICK_RED)
	_ocollider(base, -17.1, -12.1, 17.1, 12.1, 0, 8.0)
	_obox(base, -17, -12, 17, 12, 6.85, 7.5, WHITE_STONE)
	for x in [-12, -6, 0, 6, 12]:
		_cathedral_bay(_frame(Vector2(x + 7, 81.4), 0))
		_cathedral_bay(_frame(Vector2(x + 7, 104.6), 180))
	for z in [85.2, 90.4, 95.6, 100.8]:
		_cathedral_bay(_frame(Vector2(-9.6, z), -90))
		_cathedral_bay(_frame(Vector2(23.6, z), 90))
	_obox(base, -16.78, -11.74, 16.78, 11.74, 5.98, 6.16, WHITE_STONE)
	_obox(base, -16.78, -11.74, 16.78, 11.74, 6.52, 6.72, WHITE_STONE)
	var colours := [
		[Color(0.83, 0.23, 0.17), Color(0.95, 0.84, 0.55)],
		[Color(0.10, 0.43, 0.62), Color(0.80, 0.92, 0.86)],
		[Color(0.15, 0.48, 0.27), Color(0.82, 0.67, 0.28)],
		[Color(0.94, 0.65, 0.18), Color(0.66, 0.28, 0.18)],
	]
	for i in 8:
		var around := Vector2.from_angle(TAU * i / 8.0) * Vector2(12.1, 8.6)
		var at := _w(7 + around.x, 93 + around.y, 7.1)
		var top := 15.2 + (2.4 if i % 2 == 0 else 0.0)
		var radius := 2.15 if i % 2 == 0 else 1.78
		_cyl("solid", at, radius, top - at.y, BRICK_RED, 8)
		_cyl("solid", at + Vector3.UP * 0.2, radius * 1.07, 0.56, WHITE_STONE, 8)
		_cyl("solid", Vector3(at.x, top - 0.55, at.z), radius * 1.10, 0.65, WHITE_STONE, 8)
		for yaw in [0, 90, 180, 270]:
			var face := _frame(Vector2(at.x, at.z), yaw)
			_obox(face, -0.47, -radius - 0.02, 0.47, -radius + 0.12, top - 4.0, top - 1.32, WHITE_STONE)
			_obox(face, -0.23, -radius - 0.05, 0.23, -radius - 0.015, top - 3.73, top - 1.52, WINDOW)
		_onion_dome(Vector3(at.x, top, at.z), radius * 1.43, colours[i % 4])
	_cyl("solid", Vector3(7, 7.1, 93), 4.2, 13.0, BRICK_RED, 8)
	for y in [10.5, 15.4, 19.8]:
		_cyl("solid", Vector3(7, y, 93), 4.3, 0.49, WHITE_STONE, 8)
	_cone("solid", Vector3(7, 20.15, 93), 4.46, 0.87, 12.6, BRICK_RED, 8)
	_cone("solid", Vector3(7, 27.5, 93), 2.44, 1.58, 2.75, WHITE_STONE, 8)
	_onion_dome(Vector3(7, 32.6, 93), 1.37, [GILT, Color(0.78, 0.41, 0.12)])


func _cathedral_bay(f: Array) -> void:
	_arch_face(f, 1.35, 3.65, 1.7, WHITE_STONE, BRICK_SHADE)
	_disc_face(f, 0, -0.10, 5.90, 0.42, 0.23, GILT)
	_disc_face(f, 0, -0.105, 5.90, 0.22, 0.0, ROOF_GREEN)
	for side in [-2.30, 2.30]:
		_obox(f, side - 0.18, -0.29, side + 0.18, 0.03, 0.82, 6.94, WHITE_STONE)
		_obox(f, side - 0.31, -0.31, side + 0.31, 0.05, 6.21, 6.91, WHITE_STONE)


func _onion_dome(base: Vector3, radius: float, colours: Array) -> void:
	var profile := [Vector2(0.66, 0), Vector2(0.87, 0.20), Vector2(1.0, 0.49),
		Vector2(0.96, 0.77), Vector2(0.73, 1.07), Vector2(0.42, 1.34),
		Vector2(0.19, 1.60), Vector2(0.10, 1.79)]
	var st := _tool("solid", base)
	for band in profile.size() - 1:
		var lower: Vector2 = profile[band] * radius
		var upper: Vector2 = profile[band + 1] * radius
		for i in 20:
			var a := TAU * i / 20.0 + float(band) * 0.07
			var b := a + TAU / 20.0
			var da := Vector3(cos(a), 0, sin(a))
			var db := Vector3(cos(b), 0, sin(b))
			var d := Vector3(cos(a + 0.07), 0, sin(a + 0.07))
			var e := Vector3(cos(b + 0.07), 0, sin(b + 0.07))
			var normal := (da + db + Vector3.UP * (lower.x - upper.x) / (upper.y - lower.y)).normalized()
			st.set_color(colours[(i / 2) % 2])
			st.set_normal(normal)
			_front_quad(st, base + da * lower.x + Vector3.UP * lower.y, base + db * lower.x + Vector3.UP * lower.y,
				base + e * upper.x + Vector3.UP * upper.y, base + d * upper.x + Vector3.UP * upper.y, normal)
	var finial := base + Vector3.UP * (1.74 * radius)
	_globe("solid", finial, radius * 0.13, GILT)
	_cyl("solid", finial, radius * 0.038, radius * 0.49, GILT, 8)
	_ybox("solid", finial + Vector3.UP * (radius * 0.34), Vector3(radius * 0.40, radius * 0.055, radius * 0.055), 0.0, GILT)
