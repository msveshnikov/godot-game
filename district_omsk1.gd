extends "res://district_omsk.gd"
## Omsk 1: a Siberian estate of five-storey khrushchyovkas, ~200 m round the home
## block, measured from the satellite map and Street View. Grey panel blocks under
## new red pitched roofs, a main road with a T-junction, a diagonal street with a
## slanted block along it, two kindergartens, a school, yards with playgrounds and
## parking, and poplars and birches everywhere.
##
## Map frame (district_omsk.gd): u = metres east, n = metres south, origin in the
## middle of the home block.

const HOME := Vector2(-1.5, 8.5)
const HOME_LENGTH := 69.0
const MAIN_ROAD_U := 52.0 # the street running south from the junction
const CROSS_ROAD_N := -31.0 # the street running east-west north of the home block
const LANE_N := -14.0 # yard lane along the home block's entrances
const DIAGONAL_YAW := -42.9 # the slanted street and the block along it (towards the north-east)
const PLAYGROUND := Vector2(-22.0, 34.0)


func _layout_seed() -> int:
	return 5501


func _tree_count() -> int:
	return 330


func _swing_spot() -> Vector3:
	return _w(PLAYGROUND.x - 4.5, PLAYGROUND.y - 2.6, 1.5)


func intro_text() -> String:
	return "Omsk 1: five-storey khrushchyovkas under new red roofs, yellow birches and poplars. The villagers carry pistols but won't shoot; they run when they see you armed."


func spawn_points() -> Array[Vector2]:
	# On the yard lane in front of the home block's entrances, facing it (+Z).
	return [
		Vector2(-22.0, LANE_N), Vector2(-10.0, LANE_N), Vector2(2.0, LANE_N),
		Vector2(14.0, LANE_N), Vector2(26.0, LANE_N), Vector2(38.0, LANE_N),
	]


func bot_graph() -> Dictionary:
	var nodes: Array[Vector2] = [
		Vector2(-200, -31), Vector2(-120, -31), Vector2(-60, -31), Vector2(-38, -31), Vector2(-18, -31), # 0-4 cross road
		Vector2(25, -31), Vector2(52, -31), Vector2(69, -31), # 5-7
		Vector2(52, -14), Vector2(52, 40), Vector2(52, 100), Vector2(52, 160), Vector2(52, 205), # 8-12 main road
		Vector2(30, -14), Vector2(5, -14), Vector2(-20, -14), Vector2(-30, -14), # 13-16 yard lane
		Vector2(-44, 0), Vector2(-75, 32), Vector2(-97, 55), Vector2(-125, 84), # 17-20 slanted drive
		Vector2(-82, 10), Vector2(-126, 51), Vector2(-184, 105), # 21-23 slanted street
		Vector2(-40, 24), Vector2(-10, 24), Vector2(20, 24), Vector2(44, 24), # 24-27 path behind the home block
		Vector2(10, 60), Vector2(10, 120), Vector2(10, 175), # 28-30 path south
		Vector2(-18, -80), Vector2(-18, -137), Vector2(25, -80), Vector2(25, -137), # 31-34 paths between the blocks
		Vector2(-120, -137), Vector2(69, -137), Vector2(69, -80), Vector2(69, -200), # 35-38 north lane
		Vector2(69, -17.5), Vector2(69, 40), Vector2(69, 110), Vector2(69, 190), # 39-42 drive along the east blocks
		Vector2(100, -17.5), Vector2(134, -17.5), Vector2(190, -17.5), # 43-45 east lane
		Vector2(134, 50), Vector2(134, 120), Vector2(134, 195), Vector2(110, 30), # 46-49
		Vector2(-22, 25), # 50 by the playground
	]
	var edges := [
		[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [6, 8], [8, 9], [9, 10], [10, 11], [11, 12],
		[8, 13], [13, 14], [14, 15], [15, 16], [16, 17], [17, 18], [18, 19], [19, 20],
		[3, 21], [21, 22], [22, 23], [18, 21],
		[17, 24], [24, 50], [50, 25], [25, 26], [26, 27], [27, 9], [26, 28], [28, 29], [29, 30],
		[4, 31], [31, 32], [5, 33], [33, 34], [35, 32], [32, 34], [34, 36], [7, 37], [37, 36], [36, 38],
		[7, 39], [39, 40], [40, 41], [41, 42], [39, 43], [43, 44], [44, 45], [44, 46], [46, 47], [47, 48], [46, 49],
		[9, 40], [10, 41],
	]
	var p := PLAYGROUND
	var civilians := [
		["civilian", p.x, p.y, 6.0, false], ["civilian", p.x + 4.0, p.y + 3.0, 6.0, false],
		["civilian", p.x - 1.0, p.y + 5.4, 0.5, true],
		["child", p.x, p.y, 6.5, false], ["child", p.x - 3.0, p.y + 2.0, 6.5, false], ["child", p.x + 3.0, p.y - 1.0, 6.5, false],
		["child", p.x + 1.0, p.y + 3.0, 6.5, false], ["child", p.x - 4.0, p.y - 2.0, 6.5, false],
		["child", -161.5, -133.0, 5.0, false], ["child", -158.0, -131.0, 5.0, false], ["child", -165.0, -135.0, 5.0, false],
		["civilian", -161.5, -133.0, 4.0, false],
		["child", -57.5, 143.0, 5.0, false], ["child", -54.0, 141.0, 5.0, false], ["civilian", -57.5, 143.0, 4.0, false],
		["civilian", -90.0, -24.5, 0.4, true], ["civilian", 73.5, -2.0, 1.5, false],
		["child", 110.0, 30.0, 6.0, false], ["child", 112.0, 28.0, 6.0, false], ["civilian", 110.0, 30.0, 5.0, false],
	]
	return {"nodes": nodes, "edges": edges, "no_spawn": [8, 13, 14, 15, 16], "civilians": civilians}


func _traffic_lanes() -> Array:
	# Right-hand traffic: in along the cross road from the west, down the main road to
	# the south, and back. Both ends run into the forest.
	return [
		[[Vector2(-260, CROSS_ROAD_N + 1.7), Vector2(MAIN_ROAD_U - 1.7, CROSS_ROAD_N + 1.7), Vector2(MAIN_ROAD_U - 1.7, 260)], 3],
		[[Vector2(MAIN_ROAD_U + 1.7, 260), Vector2(MAIN_ROAD_U + 1.7, CROSS_ROAD_N - 1.7), Vector2(-260, CROSS_ROAD_N - 1.7)], 3],
	]


func _build_layout() -> void:
	_build_roads()
	_build_blocks()
	_build_institutions()
	_build_yards()
	_build_parking_spots()
	_plant_rows()


func _build_roads() -> void:
	var diagonal := Vector2(cos(deg_to_rad(DIAGONAL_YAW)), sin(deg_to_rad(DIAGONAL_YAW)))
	_road(Vector2(-215, CROSS_ROAD_N), Vector2(72, CROSS_ROAD_N), 7.0, OMSK_ASPHALT, 0.02, true, true)
	_road(Vector2(MAIN_ROAD_U, CROSS_ROAD_N - 3.5), Vector2(MAIN_ROAD_U, 215), 8.0, OMSK_ASPHALT, 0.021, true, true)
	_road(Vector2(-38, CROSS_ROAD_N), Vector2(-38, CROSS_ROAD_N) - diagonal * 242.0, 8.0, OMSK_ASPHALT, 0.019, true, true)
	_zebra(Vector2(MAIN_ROAD_U, LANE_N), 90.0, 8.0)
	_zebra(Vector2(MAIN_ROAD_U - 9.0, CROSS_ROAD_N), 0.0, 7.0)
	_zebra(Vector2(-20.0, CROSS_ROAD_N), 0.0, 7.0)
	# Lanes and drives.
	_road(Vector2(69, CROSS_ROAD_N - 3.5), Vector2(69, -215), 6.0, OMSK_ASPHALT, 0.022)
	_road(Vector2(69, CROSS_ROAD_N + 3.5), Vector2(69, 212), 5.0, OMSK_ASPHALT, 0.022)
	_road(Vector2(MAIN_ROAD_U, LANE_N), Vector2(-30, LANE_N), 5.0, OMSK_ASPHALT, 0.023)
	_road(Vector2(-30, LANE_N), Vector2(-125, 84), 5.0, OMSK_ASPHALT, 0.023)
	_road(Vector2(-125, -137), Vector2(69, -137), 5.0, OMSK_ASPHALT, 0.023)
	_road(Vector2(71.5, -17.5), Vector2(215, -17.5), 6.0, OMSK_ASPHALT, 0.023)
	_road(Vector2(134, -14.5), Vector2(134, 212), 5.0, OMSK_ASPHALT, 0.024)
	# Sidewalks and footpaths.
	_road(Vector2(44.75, CROSS_ROAD_N + 3.5), Vector2(44.75, 212), 2.5, WALK_ASPHALT, 0.035)
	_road(Vector2(62, CROSS_ROAD_N + 3.5), Vector2(62, 212), 2.0, WALK_ASPHALT, 0.035)
	_road(Vector2(-200, CROSS_ROAD_N + 5.0), Vector2(43.5, CROSS_ROAD_N + 5.0), 2.2, WALK_ASPHALT, 0.034)
	_road(Vector2(-18, CROSS_ROAD_N - 3.5), Vector2(-18, -137), 2.5, WALK_ASPHALT, 0.035)
	_road(Vector2(25, CROSS_ROAD_N - 3.5), Vector2(25, -137), 2.5, WALK_ASPHALT, 0.035)
	_road(Vector2(-44, 24), Vector2(44, 24), 2.5, WALK_ASPHALT, 0.036)
	_road(Vector2(10, 25.25), Vector2(10, 212), 2.5, WALK_ASPHALT, 0.036)
	# Paths to the home block's five entrances.
	var sections := 5
	for k in sections:
		var eu := HOME.x - HOME_LENGTH * 0.5 + HOME_LENGTH / sections * (k + 0.5)
		_road(Vector2(eu, LANE_N + 2.5), Vector2(eu, HOME.y - KHRUSH_DEPTH * 0.5 - 1.5), 1.8, WALK_ASPHALT, 0.04)
	# Dirt parking along the home block and the asphalt pocket on the main road.
	_ground("HomeParking", -32.0, LANE_N + 2.5, 33.0, -6.5, 0.025, DIRT)
	_road(Vector2(58.1, 0), Vector2(58.1, 120), 4.0, OMSK_ASPHALT.lightened(0.04), 0.022)
	_ground("YardLot", -20.0, 42.0, 6.0, 60.0, 0.025, OMSK_ASPHALT.lightened(0.06))


func _build_blocks() -> void:
	# The home block: balconies to the south yard, entrances to the lane on the north.
	_khrushchyovka("HomeBlock", HOME, HOME_LENGTH, 0.0, 1.0)
	# North of the cross road: three blocks end-on to it, two long ones along it.
	_khrushchyovka("NorthBlockW", Vector2(-38.5, -79.0), 76.0, 90.0, 1.0)
	_khrushchyovka("NorthBlockM", Vector2(3.5, -79.0), 76.0, 90.0, -1.0)
	_khrushchyovka("NorthBlockE", Vector2(45.5, -78.0), 74.0, 90.0, 1.0)
	var pub := _khrushchyovka("CrossRoadBlockW", Vector2(-94.5, -49.0), 73.0, 0.0, 1.0)
	_obox(pub, 19.0, 6.0, 30.0, 6.06, 0.3, 2.1, GLASS, "glass")
	_frame_sign(pub, 24.5, 6.0, 1.0, 2.6, "ПИВО", Color(0.95, 0.75, 0.15), Color(0.35, 0.1, 0.05), 5.0)
	_khrushchyovka("CrossRoadBlockE", Vector2(133.0, -49.0), 118.0, 0.0, 1.0)
	# Second row to the north.
	_khrushchyovka("FarNorthW", Vector2(-92.5, -177.5), 69.0, 90.0, 1.0)
	_khrushchyovka("FarNorthM", Vector2(-38.5, -177.5), 69.0, 90.0, -1.0)
	_khrushchyovka("FarNorthE", Vector2(3.5, -177.5), 69.0, 90.0, 1.0)
	# East of the main road: the long block with the grocery at its north end.
	var east := _khrushchyovka("EastBlock", Vector2(82.0, 53.5), 117.0, 90.0, -1.0)
	_frame_sign(east, -51.2, 6.0, 1.0, 3.05, "ПРОДУКТЫ", Color(0.82, 0.12, 0.1), Color(1, 1, 1), 6.5)
	_khrushchyovka("EastBlockSouth", Vector2(82.0, 168.0), 84.0, 90.0, -1.0)
	_khrushchyovka("FarEastBlock", Vector2(155.0, 130.0), 102.0, 90.0, 1.0)
	_khrushchyovka("EastRowN", Vector2(181.0, -1.0), 68.0, 0.0, 1.0)
	_khrushchyovka("EastRowS", Vector2(181.0, 52.0), 68.0, 0.0, 1.0, KHRUSH_WALL.lightened(0.08), false)
	# South of the home block and along the slanted street.
	_khrushchyovka("SouthBlock", Vector2(27.0, 105.5), 117.0, 90.0, -1.0)
	_khrushchyovka("SouthBlockFar", Vector2(27.0, 193.0), 36.0, 90.0, -1.0)
	_khrushchyovka("SlantedBlock", Vector2(-82.0, 68.0), 88.0, DIAGONAL_YAW, 1.0)
	_khrushchyovka("WestBlock", Vector2(-144.0, 154.5), 101.0, 90.0, 1.0)
	_khrushchyovka("FarWestBlock", Vector2(-184.0, 8.0), 60.0, 90.0, -1.0, KHRUSH_WALL.darkened(0.04), false)


func _build_institutions() -> void:
	# Kindergarten north-west: two wings joined in the middle, its own fenced garden.
	var brick := Color(0.88, 0.76, 0.58)
	_block("KindergartenW", Vector2(-180.0, -119.5), Vector2(12, 41), 0.0, 2, brick)
	_block("KindergartenE", Vector2(-143.0, -119.5), Vector2(12, 41), 0.0, 2, brick)
	var link := _block("KindergartenLink", Vector2(-161.5, -119.5), Vector2(25, 13), 0.0, 2, brick)
	_door(link, 0.0, 6.5, 1.0)
	_mesh_fence(Vector2(-160.0, -119.0), Vector2(62, 52), 180.0, [0.0])
	_yard_playground(Vector2(-161.5, -103.0))
	# Kindergarten south-west, same plan, and its little laundry block.
	_block("KindergartenSW", Vector2(-87.0, 155.0), Vector2(12, 36), 0.0, 2, brick.lightened(0.05))
	_block("KindergartenSE", Vector2(-28.0, 155.0), Vector2(12, 36), 0.0, 2, brick.lightened(0.05))
	var south_link := _block("KindergartenSLink", Vector2(-57.5, 155.0), Vector2(47, 12), 0.0, 2, brick.lightened(0.05))
	_door(south_link, 0.0, -6.0, -1.0)
	_mesh_fence(Vector2(-57.5, 155.0), Vector2(78, 46), 0.0, [0.0])
	_block("Laundry", Vector2(-110.0, 127.0), Vector2(14, 14), 0.0, 1, Color(0.8, 0.78, 0.72))
	# School north-east: two three-storey wings and the hall between them.
	var school_wall := Color(0.93, 0.85, 0.7)
	_block("SchoolNorth", Vector2(127.0, -174.0), Vector2(74, 16), 0.0, 3, school_wall)
	_block("SchoolHall", Vector2(126.5, -149.0), Vector2(17, 22), 0.0, 2, school_wall.darkened(0.05))
	var school := _block("SchoolSouth", Vector2(126.0, -124.0), Vector2(72, 16), 0.0, 3, school_wall)
	_door(school, 0.0, 8.0, 1.0)
	_frame_sign(school, 0.0, 8.0, 1.0, 4.6, "ШКОЛА", Color(0.95, 0.95, 0.92), Color(0.1, 0.2, 0.5), 7.0)
	_mesh_fence(Vector2(136.0, -158.0), Vector2(116, 100), 180.0, [10.0])
	_ground("SchoolCourt", 168.0, -200.0, 192.0, -172.0, 0.03, Color(0.35, 0.42, 0.5))
	for hoop in [Vector2(180.0, -199.0), Vector2(180.0, -173.0)]:
		var dir := 1.0 if hoop.y < -186.0 else -1.0
		_box_un(hoop.x - 0.08, hoop.y - 0.08, hoop.x + 0.08, hoop.y + 0.08, 0.0, 3.3, Color(0.3, 0.32, 0.35))
		_box_un(hoop.x - 0.9, hoop.y + dir * 0.3, hoop.x + 0.9, hoop.y + dir * 0.36, 2.8, 3.9, Color(0.95, 0.95, 0.95))
		_box_un(hoop.x - 0.25, hoop.y + dir * 0.36, hoop.x + 0.25, hoop.y + dir * 0.8, 3.05, 3.1, Color(0.9, 0.4, 0.1))


func _build_yards() -> void:
	_yard_playground(PLAYGROUND, true)
	_yard_playground(Vector2(110.0, 30.0))
	_bin_site(-30.0, 50.0)
	_bin_site(-25.0, -60.0)
	_bin_site(100.0, -10.0)
	_bus_stop(-90.0, CROSS_ROAD_N + 6.0)
	# Street lamps: along the main road and the cross road, and over the yard lane.
	var n := -20.0
	while n < 205.0:
		_street_lamp(MAIN_ROAD_U - 6.8, n, Vector2(1, 0))
		n += 30.0
	var u := -200.0
	while u < 40.0:
		if absf(u + 90.0) > 6.0:
			_street_lamp(u, CROSS_ROAD_N + 6.6, Vector2(0, -1))
		u += 32.0
	for lu in [-25.0, 5.0, 35.0]:
		_street_lamp(lu, LANE_N - 3.2, Vector2(0, 1))
	# Benches along the path behind the home block, clotheslines in the yard.
	for bu in [-38.0, -5.0, 30.0]:
		_bench(bu, 22.4, 0.0)
	for line in [[-5.0, 32.0], [-40.0, -100.0]]:
		var lu: float = line[0]
		var ln: float = line[1]
		for post in [lu - 4.0, lu + 4.0]:
			_box_un(post - 0.05, ln - 0.05, post + 0.05, ln + 0.05, 0.0, 1.9, Color(0.5, 0.52, 0.55))
		_box_un(lu - 4.0, ln - 0.01, lu + 4.0, ln + 0.01, 1.85, 1.87, Color(0.85, 0.85, 0.85))
		var pu := lu - 3.5
		while pu < lu + 3.2:
			var w := _rng.randf_range(0.4, 0.9)
			var clothes: Color = [Color(0.95, 0.95, 0.95), Color(0.3, 0.45, 0.8), Color(0.9, 0.3, 0.3), Color(0.95, 0.85, 0.3)][_rng.randi() % 4]
			_box_un(pu, ln - 0.01, pu + w, ln + 0.01, 1.85 - _rng.randf_range(0.4, 0.8), 1.85, clothes)
			pu += w + _rng.randf_range(0.1, 0.4)
	# Low pipe fences round the lawns, painted every spring.
	for fence in [[-34.0, 16.5, 34.0, 16.6], [-34.0, 21.0, 34.0, 21.1]]:
		var green := Color(0.25, 0.55, 0.3)
		_box_un(fence[0], fence[1], fence[2], fence[3], 0.5, 0.56, green)
		var fu: float = fence[0]
		while fu <= fence[2]:
			_box_un(fu - 0.03, fence[1] - 0.03, fu + 0.03, fence[1] + 0.03, 0.0, 0.55, green)
			fu += 2.0


func _build_parking_spots() -> void:
	# Along the home block, between the entrance paths.
	var entrances: Array[float] = []
	for k in 5:
		entrances.append(HOME.x - HOME_LENGTH * 0.5 + HOME_LENGTH / 5.0 * (k + 0.5))
	var u := -30.0
	while u < 32.0:
		var clear := true
		for eu in entrances:
			if absf(u - eu) < 3.2:
				clear = false
		if clear and _rng.randf() < 0.8:
			_car_spots.append(_car_transform(u, -9.0, 90.0))
		u += 5.3
	# Two rows nose-in on the yard lot, the pocket on the main road, the cross road's north kerb.
	for row_n in [45.2, 56.8]:
		var lot_u := -18.0
		while lot_u < 5.0:
			if _rng.randf() < 0.7:
				_car_spots.append(_car_transform(lot_u, row_n, 0.0))
			lot_u += 2.7
	var pocket := _frame(Vector2(58.1, 60.0), 90.0)
	_park_row(pocket, -58.0, 58.0, 0.0, false, 0.7)
	var kerb := _frame(Vector2(-92.0, CROSS_ROAD_N - 5.2), 0.0)
	_park_row(kerb, -32.0, 32.0, 0.0, false, 0.6)
	var east_lane := _frame(Vector2(105.0, -22.0), 0.0)
	_park_row(east_lane, -28.0, 28.0, 0.0, false, 0.55)


func _plant_rows() -> void:
	# Poplars along both sides of the main road, birches along the cross road.
	_tree_row("poplar", Vector2(40.6, -24.0), Vector2(40.6, 200.0), 8.5)
	_tree_row("poplar", Vector2(64.7, -24.0), Vector2(64.7, 200.0), 9.5)
	var u := -198.0
	while u < 38.0:
		if absf(u + 90.0) > 7.0 and absf(u + 38.0) > 6.0:
			_trees.append(["birch", Vector3(u, 0, CROSS_ROAD_N + 8.2), _rng.randf_range(0.9, 1.2)])
		u += 9.0
	# A few spruces at the home block's ends.
	for spot in [Vector2(-40.0, 4.0), Vector2(-40.0, 13.0), Vector2(37.0, 6.0)]:
		_trees.append(["spruce", Vector3(spot.x, 0, spot.y), _rng.randf_range(0.8, 1.0)])
