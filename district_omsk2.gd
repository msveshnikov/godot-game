extends "res://district_omsk.gd"
## Omsk 2: nine-storey panel blocks among the old private sector, ~200 m round the
## home block, measured from the satellite map and Street View: the long home slab
## and an L-shaped neighbour, rows of brick garages, a car-service shop on a big
## lot, a gas station, two schools, a kindergarten, a waste-ground football pitch
## and streets of one-storey wooden houses behind fences. The northeast extension
## continues north of 10th Cheredovaya to No. 23 and Poltoratskogo Street.
##
## Map frame (district_omsk.gd): u = metres east, n = metres south, origin in the
## middle of the home block.

const HOME := Vector2(0.0, 8.0)
const HOME_LENGTH := 100.0
const MAIN_STREET_U := -160.0 # the main north-south street
const NORTH_ROAD_N := -170.0
const SOUTH_ROAD_N := 137.0
const SIDE_ROAD_U := 22.0 # the street east of the home block
const EAST_STREET_U := 128.0
const PATH_U := -12.0 # footpath along the home block's entrances
const PLAYGROUND := Vector2(-80.0, -31.0)
const CHEREDOVAYA_23 := Vector2(189.9, -291.1)
const CHEREDOVAYA_EAST := 427.0


func prepare_ground() -> void:
	var ground := get_node("../Ground") as MeshInstance3D
	var plane := ground.mesh.duplicate() as PlaneMesh
	plane.size = Vector2(740.0, 815.0)
	plane.subdivide_width = 235
	plane.subdivide_depth = 260
	ground.mesh = plane
	ground.position = Vector3(105.0, 0.0, -147.5)

	var forest := get_node("../Forest")
	forest.bounds = Rect2(-255.0, -545.0, 720.0, 800.0)
	forest.clearings = [
		Rect2(-215.0, -215.0, 430.0, 430.0),
		Rect2(-43.0, -500.0, 484.0, 292.0),
		Rect2(200.0, -215.0, 218.0, 117.0),
	] as Array[Rect2]


func _layout_seed() -> int:
	return 5591


func _tree_count() -> int:
	return 260


func _swing_spot() -> Vector3:
	return _w(PLAYGROUND.x - 4.5, PLAYGROUND.y - 2.6, 1.5)


func intro_text() -> String:
	return "Omsk 2: follow 10th Cheredovaya Street or Latvian Street from the old district to No. 23, its courtyards and the neighbouring wooden houses. The villagers carry pistols but won't shoot; they run when they see you armed."


func spawn_points() -> Array[Vector2]:
	# On the footpath along the home block's entrances (west side), facing it (+X).
	var spots: Array[Vector2] = []
	for n in [-36.0, -22.0, -8.0, 6.0, 20.0, 34.0, 48.0]:
		spots.append(Vector2(PATH_U, n))
	return spots


func spawn_yaw() -> float:
	return -PI * 0.5


func bot_graph() -> Dictionary:
	var nodes: Array[Vector2] = [
		Vector2(-160, -200), Vector2(-160, -170), Vector2(-160, -50), Vector2(-160, 3), Vector2(-160, 60), # 0-4 west road
		Vector2(-160, 137), Vector2(-160, 200), # 5-6
		Vector2(-100, -170), Vector2(-40, -170), Vector2(22, -170), Vector2(80, -170), Vector2(128, -170), Vector2(200, -170), # 7-12 north road
		Vector2(22, -100), Vector2(22, -50), Vector2(22, 8), Vector2(22, 70), Vector2(22, 137), # 13-17 side road
		Vector2(-100, 137), Vector2(-40, 137), Vector2(44, 137), Vector2(128, 137), Vector2(200, 137), # 18-22 south road
		Vector2(128, -100), Vector2(128, -40), Vector2(128, 40), # 23-25 east road
		Vector2(-100, -50), Vector2(-40, -50), # 26-27 drive north of the blocks
		Vector2(-12, -40), Vector2(-12, 10), Vector2(-12, 58), # 28-30 home path
		Vector2(-37, 5), Vector2(-37, 74), Vector2(-55, 5), Vector2(-55, 74), # 31-34 garage aisles
		Vector2(-40, 85), Vector2(0, 85), Vector2(-75, 85), Vector2(-120, 90), # 35-38 lot, gas station
		Vector2(-85, 3.5), Vector2(-45, 3.5), # 39-40 path south of the L block
		Vector2(60, -40), Vector2(93, -42), Vector2(60, 40), Vector2(80, 78), # 41-44 waste ground, pitch
		Vector2(-80, -45), Vector2(-200, 3), # 45-46
		Vector2(-30, 181), Vector2(-130, 181), # 47-48 street south
		Vector2(-28, -8), # 49 east end of the L block
		Vector2(136, -203), Vector2(137, -273), Vector2(124, -290), # 50-52 Latvian Street
		Vector2(121, -350), Vector2(121, -441), Vector2(118, -492), # 53-55
		Vector2(172, -488), Vector2(276, -484), # 56-57 Poltoratskogo Street
		Vector2(275, -170), Vector2(276, -249), Vector2(275, -288), # 58-60 Krymskaya Street
		Vector2(274, -345), Vector2(274, -417), # 61-62
		Vector2(211, -347), Vector2(210, -297), Vector2(208, -263), # 63-65 No. 23 courtyard
		Vector2(232, -263), Vector2(231, -216), Vector2(154, -216), # 66-68 No. 25 courtyard
		Vector2(333, -170), Vector2(332, -273), Vector2(386, -170), Vector2(387, -253), # 69-72 eastern lanes
		Vector2(87, -293), Vector2(85, -265), Vector2(86, -181), # 73-75 library walk
	]
	var edges := [
		[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6],
		[1, 7], [7, 8], [8, 9], [9, 10], [10, 11], [11, 12],
		[9, 13], [13, 14], [14, 15], [15, 16], [16, 17],
		[5, 18], [18, 19], [19, 17], [17, 20], [20, 21], [21, 22],
		[11, 23], [23, 24], [24, 25], [25, 21],
		[2, 26], [26, 45], [45, 27], [27, 14],
		[27, 49], [49, 28], [28, 29], [29, 30], [30, 16],
		[49, 40], [39, 40], [40, 31], [31, 32], [33, 34], [39, 33], [33, 40],
		[32, 35], [34, 35], [35, 36], [35, 37], [37, 38], [38, 18], [38, 4], [36, 16],
		[3, 46],
		[14, 41], [41, 42], [42, 24], [41, 43], [43, 16], [43, 44], [44, 25],
		[19, 47], [47, 48], [48, 18], [47, 20],
		[11, 50], [50, 51], [51, 52], [52, 53], [53, 54], [54, 55], [55, 56], [56, 57],
		[12, 58], [58, 59], [59, 60], [60, 61], [61, 62], [62, 57],
		[61, 63], [63, 64], [64, 65], [65, 66], [66, 67], [67, 68], [68, 50],
		[58, 69], [69, 70], [69, 71], [71, 72],
		[52, 73], [73, 74], [74, 75], [75, 10],
	]
	var p := PLAYGROUND
	var civilians := [
		["civilian", p.x, p.y, 6.0, false], ["civilian", p.x + 3.0, p.y + 2.0, 6.0, false],
		["civilian", p.x - 1.0, p.y + 5.4, 0.5, true],
		["child", p.x, p.y, 6.5, false], ["child", p.x - 3.0, p.y + 2.0, 6.5, false], ["child", p.x + 3.0, p.y - 1.0, 6.5, false],
		["child", p.x + 1.0, p.y + 3.0, 6.5, false],
		["child", -40.0, -99.0, 6.0, false], ["child", -42.0, -97.0, 6.0, false], ["civilian", -40.0, -99.0, 5.0, false],
		["child", 144.0, -90.0, 5.0, false], ["child", 146.0, -88.0, 5.0, false], ["child", 142.0, -91.0, 5.0, false],
		["civilian", 144.0, -90.0, 4.0, false],
		["civilian", -108.0, 94.5, 1.0, false], ["civilian", 80.0, 80.0, 3.0, false], ["civilian", 76.0, 81.0, 3.0, false],
		["civilian", -60.0, SOUTH_ROAD_N + 5.9, 0.4, true],
	]
	return {
		"nodes": nodes, "edges": edges, "no_spawn": [28, 29, 30], "civilians": civilians,
		"patrol_spots": [nodes[54], nodes[64], nodes[69], nodes[73], nodes[72]],
	}


func _traffic_lanes() -> Array:
	return [
		[Vector2(MAIN_STREET_U + 1.7, 260), Vector2(MAIN_STREET_U + 1.7, -260), 3],
		[Vector2(MAIN_STREET_U - 1.7, -260), Vector2(MAIN_STREET_U - 1.7, 260), 3],
		[Vector2(-260, NORTH_ROAD_N + 1.7), Vector2(CHEREDOVAYA_EAST + 15.0, NORTH_ROAD_N + 1.7), 3],
		[Vector2(CHEREDOVAYA_EAST + 15.0, NORTH_ROAD_N - 1.7), Vector2(-260, NORTH_ROAD_N - 1.7), 3],
		[Vector2(-260, SOUTH_ROAD_N + 1.7), Vector2(260, SOUTH_ROAD_N + 1.7), 2],
		[Vector2(260, SOUTH_ROAD_N - 1.7), Vector2(-260, SOUTH_ROAD_N - 1.7), 2],
	]


func _build_layout() -> void:
	_build_roads()
	_build_blocks()
	_build_garages_and_lot()
	_build_institutions()
	_build_private_sector()
	_build_yards()
	_plant_rows()
	_build_cheredovaya_extension()


func _build_roads() -> void:
	_road(Vector2(MAIN_STREET_U, -215), Vector2(MAIN_STREET_U, 215), 9.0, OMSK_ASPHALT, 0.02, true, true)
	_road(Vector2(-215, NORTH_ROAD_N), Vector2(CHEREDOVAYA_EAST, NORTH_ROAD_N), 7.0, OMSK_ASPHALT, 0.021, true, true)
	_road(Vector2(-215, SOUTH_ROAD_N), Vector2(215, SOUTH_ROAD_N), 8.0, OMSK_ASPHALT, 0.019, true, true)
	_road(Vector2(-215, 3), Vector2(MAIN_STREET_U - 4.5, 3), 6.0, OMSK_ASPHALT, 0.022)
	_road(Vector2(SIDE_ROAD_U, NORTH_ROAD_N + 3.5), Vector2(SIDE_ROAD_U, SOUTH_ROAD_N - 4.0), 7.0, OMSK_ASPHALT, 0.022, true)
	_road(Vector2(EAST_STREET_U, NORTH_ROAD_N), Vector2(EAST_STREET_U, 215), 6.0, OMSK_ASPHALT.lightened(0.05), 0.023)
	_road(Vector2(44, SOUTH_ROAD_N + 4.0), Vector2(44, 215), 6.0, OMSK_ASPHALT, 0.023)
	_road(Vector2(MAIN_STREET_U + 4.5, 181), Vector2(41, 181), 6.0, OMSK_ASPHALT, 0.024)
	_road(Vector2(MAIN_STREET_U + 4.5, -50), Vector2(SIDE_ROAD_U - 3.5, -50), 5.0, OMSK_ASPHALT, 0.024)
	_zebra(Vector2(MAIN_STREET_U, -60.0), 90.0, 9.0)
	_zebra(Vector2(SIDE_ROAD_U, SOUTH_ROAD_N - 8.0), 90.0, 7.0)
	_zebra(Vector2(-10.0, SOUTH_ROAD_N), 0.0, 8.0)
	# Sidewalks and paths.
	_road(Vector2(MAIN_STREET_U + 6.5, -212), Vector2(MAIN_STREET_U + 6.5, 212), 2.2, WALK_ASPHALT, 0.034)
	_road(Vector2(SIDE_ROAD_U + 5.0, NORTH_ROAD_N + 3.5), Vector2(SIDE_ROAD_U + 5.0, SOUTH_ROAD_N - 4.0), 2.0, WALK_ASPHALT, 0.034)
	_road(Vector2(PATH_U, -47.5), Vector2(PATH_U, 62), 2.5, WALK_ASPHALT, 0.035)
	_road(Vector2(15.5, -47.5), Vector2(15.5, 62), 2.0, WALK_ASPHALT, 0.035)
	_road(Vector2(-88, 3.5), Vector2(-20, 3.5), 2.5, WALK_ASPHALT, 0.035)
	_road(Vector2(-125, -20), Vector2(-36, -20), 2.0, WALK_ASPHALT, 0.036)
	_road(Vector2(-115, -60), Vector2(-115, -130), 2.0, WALK_ASPHALT, 0.036)
	_road(Vector2(-40, SOUTH_ROAD_N - 6.0), Vector2(15, SOUTH_ROAD_N - 6.0), 2.0, WALK_ASPHALT, 0.036)
	# Parking strip along the home block's entrances.
	_ground("HomeParking", -20.0, -40.0, -14.5, 55.0, 0.025, OMSK_ASPHALT.lightened(0.05))


func _build_blocks() -> void:
	# The home block: loggias east to the side street, entrances west to the path.
	_panel_slab("HomeBlock", HOME, HOME_LENGTH, 90.0, -1.0)
	# The L-shaped neighbour: a nine-storey slab with loggias to the north, and the
	# lower block wrapped round its west end.
	_panel_slab("CornerBlock", Vector2(-80.5, -7.5), 89.0, 0.0, -1.0, 9, PANEL_WALL.darkened(0.04))
	var low := _block("CornerLow", Vector2(-106.0, 30.0), Vector2(37, 34), 0.0, 4, Color(0.85, 0.83, 0.78))
	_door(low, 0.0, 17.0, 1.0)
	_frame_sign(low, 0.0, 17.0, 1.0, 3.6, "ПАРИКМАХЕРСКАЯ", Color(0.95, 0.95, 0.95), Color(0.65, 0.12, 0.35), 9.0)
	_block("CornerLink", Vector2(-108.0, 6.0), Vector2(16, 14), 0.0, 4, Color(0.85, 0.83, 0.78))
	# Five-storey blocks to the north with flat roofs, between the drive and the north street.
	_khrushchyovka("NorthBlock1", Vector2(-38.5, -79.5), 99.0, 0.0, 1.0, KHRUSH_WALL.lightened(0.05), false)
	var north2 := _khrushchyovka("NorthBlock2", Vector2(-38.5, -118.5), 99.0, 0.0, 1.0, KHRUSH_WALL, false)
	_obox(north2, 38.0, -6.0, 47.0, -6.06, 0.3, 2.1, GLASS, "glass")
	_frame_sign(north2, 42.5, -6.0, -1.0, 2.6, "АПТЕКА", Color(0.15, 0.6, 0.35), Color(1, 1, 1), 5.0)
	# Across the north street: a shopping centre, a market hall, a tower, a long slab.
	var mall := _block("ShoppingCentre", Vector2(-19.0, -191.5), Vector2(38, 27), 0.0, 2, Color(0.55, 0.36, 0.28))
	_obox(mall, -12.0, 13.5, 12.0, 13.6, 0.4, 3.3, GLASS, "glass")
	_frame_sign(mall, 0.0, 13.5, 1.0, 5.0, "ТОРГОВЫЙ ЦЕНТР", Color(0.95, 0.85, 0.25), Color(0.35, 0.1, 0.05), 12.0)
	var market := _block("MarketHall", Vector2(-93.0, -201.0), Vector2(62, 22), 0.0, 1, Color(0.62, 0.68, 0.74), "shop")
	_frame_sign(market, 0.0, 11.0, 1.0, 3.4, "МАГАЗИН", Color(0.85, 0.15, 0.12), Color(1, 1, 1), 8.0)
	_panel_slab("NorthTower", Vector2(17.5, -200.0), 22.0, 90.0, 1.0)
	_panel_slab("NorthEastSlab", Vector2(194.5, -202.4), 86.5, 1.6, -1.0, 10, PANEL_WALL.darkened(0.06), "ЦВЕТЫ")
	# South of the south street: an old red-roofed block, a small one by the main street, an office.
	_khrushchyovka("SouthBlock", Vector2(-74.0, 202.0), 72.0, 0.0, -1.0)
	_khrushchyovka("SouthCorner", Vector2(-141.5, 202.0), 24.0, 90.0, 1.0)
	_block("SouthOffice", Vector2(16.5, 203.0), Vector2(33, 22), 0.0, 4, Color(0.7, 0.72, 0.74))
	_khrushchyovka("SouthEastBlock", Vector2(61.0, 204.0), 24.0, 90.0, 1.0, Color(0.7, 0.42, 0.32), true, 3)


func _build_garages_and_lot() -> void:
	# Three double rows of brick garages between the L block and the lot.
	_ground("GarageYard", -72.0, 6.0, -20.0, 75.0, 0.024, DIRT)
	_garages(Vector2(-64.0, 40.0), 64.0, 90.0)
	_garages(Vector2(-46.0, 40.0), 64.0, 90.0)
	_garages(Vector2(-28.0, 40.0), 64.0, 90.0)
	# The big lot with the car-service shop (red fascia, garage doors to the south).
	_ground("Lot", -82.0, 77.0, SIDE_ROAD_U - 3.5, 121.0, 0.023, OMSK_ASPHALT.lightened(0.07))
	var shop := _block("CarService", Vector2(-37.0, 100.0), Vector2(42, 24), 0.0, 1, Color(0.9, 0.9, 0.88), "shop")
	_obox(shop, -21.2, -12.2, 21.2, 12.2, 3.0, 3.9, Color(0.78, 0.12, 0.1))
	for bay in [-14.0, -5.0, 4.0, 13.0]:
		_obox(shop, bay - 2.0, 12.0, bay + 2.0, 12.1, 0.0, 3.0, Color(0.55, 0.57, 0.6))
	_frame_sign(shop, 0.0, 12.2, 1.0, 3.45, "ШИНОМОНТАЖ  АВТОСЕРВИС", Color(0.78, 0.12, 0.1), Color(1, 1, 1), 16.0)
	for row_u in [-9.0, 0.5, 10.0]:
		_park_row(_frame(Vector2(row_u, 104.0), 90.0), -13.0, 13.0, 0.0, true, 0.7)
	_park_row(_frame(Vector2(-33.0, 80.5), 0.0), -45.0, 48.0, 0.0, true, 0.6)
	# Gas station by the main street: canopy on four posts, two pumps, the kiosk.
	_ground("GasStation", -150.0, 88.0, -100.0, 116.0, 0.026, OMSK_ASPHALT.lightened(0.1))
	_box_un(-139.0, 95.0, -117.0, 109.0, 4.6, 5.2, Color(0.95, 0.95, 0.95))
	_box_un(-139.1, 94.9, -116.9, 109.1, 4.6, 4.9, Color(0.1, 0.45, 0.25))
	for post in [Vector2(-136.0, 98.0), Vector2(-120.0, 98.0), Vector2(-136.0, 106.0), Vector2(-120.0, 106.0)]:
		_box_un(post.x - 0.2, post.y - 0.2, post.x + 0.2, post.y + 0.2, 0.0, 4.6, Color(0.85, 0.85, 0.85))
		_collider_between(_w(post.x - 0.2, post.y - 0.2), _w(post.x + 0.2, post.y + 0.2, 4.6))
	for pump in [Vector2(-131.0, 102.0), Vector2(-125.0, 102.0)]:
		_box_un(pump.x - 0.5, pump.y - 0.4, pump.x + 0.5, pump.y + 0.4, 0.0, 1.9, Color(0.1, 0.45, 0.25))
		_collider_between(_w(pump.x - 0.5, pump.y - 0.4), _w(pump.x + 0.5, pump.y + 0.4, 1.9))
	_car_spots.append(_car_transform(-131.0, 98.6, 90.0))
	_car_spots.append(_car_transform(-125.0, 105.6, 90.0))
	var kiosk := _block("GasKiosk", Vector2(-108.0, 102.0), Vector2(8, 10), 0.0, 1, Color(0.95, 0.95, 0.93), "shop")
	_frame_sign(kiosk, 0.0, -5.0, -1.0, 3.3, "АЗС", Color(0.1, 0.45, 0.25), Color(1, 1, 1), 4.0)
	_box_un(-148.5, 90.0, -147.5, 90.6, 0.0, 6.0, Color(0.85, 0.85, 0.85))
	_box_un(-149.5, 89.9, -146.5, 90.7, 4.4, 6.0, Color(0.1, 0.45, 0.25))
	_add_sign("ГАЗ", _w(-148.0, 89.85, 5.2), 180.0, Color(1, 1, 1), 0.01, 64)


func _build_institutions() -> void:
	# School by the side street: an east-west wing, a north-south wing, a fenced yard.
	var school_wall := Color(0.9, 0.82, 0.62)
	var school := _block("School", Vector2(72.0, -138.0), Vector2(56, 16), 0.0, 3, school_wall)
	_door(school, -10.0, 8.0, 1.0)
	_frame_sign(school, -10.0, 8.0, 1.0, 4.5, "ШКОЛА", Color(0.95, 0.95, 0.92), Color(0.1, 0.2, 0.5), 7.0)
	_block("SchoolWing", Vector2(51.0, -113.0), Vector2(14, 34), 0.0, 3, school_wall)
	_mesh_fence(Vector2(72.0, -123.0), Vector2(64, 66), 180.0, [12.0])
	_panel_slab("EastTower", Vector2(114.0, -112.0), 32.0, 90.0, 1.0)
	# Waste ground with a dirt football pitch.
	_ground("Pitch", 70.0, -60.0, 115.0, -25.0, 0.022, DIRT)
	for goal_u in [71.5, 113.5]:
		for post_n in [-45.0, -40.0]:
			_box_un(goal_u - 0.06, post_n - 0.06, goal_u + 0.06, post_n + 0.06, 0.0, 2.2, Color(0.95, 0.95, 0.95))
		_box_un(goal_u - 0.06, -45.0, goal_u + 0.06, -40.0, 2.14, 2.22, Color(0.95, 0.95, 0.95))
	# Kindergarten east of the east street: a plus-shaped two-storey building in its garden.
	var garden := Color(0.88, 0.74, 0.55)
	var kinder := _block("Kindergarten", Vector2(161.5, -73.0), Vector2(49, 14), 0.0, 2, garden)
	_door(kinder, -18.0, -7.0, -1.0)
	_block("KindergartenCross", Vector2(162.0, -73.0), Vector2(20, 52), 0.0, 2, garden)
	_mesh_fence(Vector2(162.0, -73.0), Vector2(60, 60), -90.0, [0.0])
	_yard_playground(Vector2(144.0, -92.0))
	# Sports school south of the waste ground.
	var sports := _block("SportsSchool", Vector2(79.5, 97.5), Vector2(61, 25), 0.0, 2, Color(0.8, 0.84, 0.88))
	_door(sports, 0.0, -12.5, -1.0)
	_frame_sign(sports, 0.0, -12.5, -1.0, 5.0, "СПОРТИВНАЯ ШКОЛА", Color(0.15, 0.35, 0.7), Color(1, 1, 1), 14.0)


## One-storey wooden houses on fenced plots along the streets of the private sector.
func _build_private_sector() -> void:
	# West of the main street: plots facing it, a dirt lane behind them and a second row.
	_road(Vector2(-192.5, -212), Vector2(-192.5, 212), 4.0, DIRT, 0.021)
	_house_column(-178.0, 90.0, 24.0, -205.0, 205.0, [NORTH_ROAD_N, 3.0, SOUTH_ROAD_N])
	_house_column(-205.0, 90.0, 21.0, -205.0, 205.0, [NORTH_ROAD_N, 3.0, SOUTH_ROAD_N])
	# East of the east street: plots facing it, a lane, two more rows.
	_road(Vector2(185.5, -165), Vector2(185.5, 133), 4.0, DIRT, 0.021)
	_house_column(143.5, -90.0, 23.0, -162.0, 129.0, [], Vector2(-104.0, -42.0))
	_house_column(171.0, 90.0, 23.0, -162.0, 129.0, [], Vector2(-104.0, -42.0))
	_house_column(200.0, -90.0, 23.0, -162.0, 129.0, [], Vector2(-104.0, -42.0))


## A row of plots centred on u, `facing` yaw 90 (gate east) or -90 (gate west), from n0 to n1,
## leaving gaps for cross streets and an optional n range `skip`.
func _house_column(u: float, facing: float, depth: float, n0: float, n1: float, streets: Array, skip := Vector2.ZERO) -> void:
	var n := n0
	while n + 20.0 <= n1:
		var c := n + 10.0
		var clear := true
		for street in streets:
			if absf(c - float(street)) < 15.0:
				clear = false
		if skip != Vector2.ZERO and c + 10.0 > skip.x and c - 10.0 < skip.y:
			clear = false
		if clear:
			_house_plot(Vector2(u, c), facing, Vector2(20.0, depth))
		n += 21.0


func _build_yards() -> void:
	_yard_playground(PLAYGROUND, true)
	_yard_playground(Vector2(-40.0, -99.0))
	_bin_site(-14.0, 68.0)
	_bin_site(-95.0, -95.0)
	_bin_site(-125.0, -40.0)
	_bus_stop(-60.0, SOUTH_ROAD_N + 6.0)
	# Front garden on the loggia side of the home block: a low fence and young spruces.
	var fence := Color(0.25, 0.5, 0.35)
	_box_un(13.9, -40.0, 14.0, 56.0, 0.0, 1.2, fence)
	_collider_between(_w(13.9, -40.0), _w(14.0, 56.0, 1.2))
	for spot_n in range(-36, 56, 9):
		_trees.append(["spruce", Vector3(11.2, 0, spot_n), _rng.randf_range(0.5, 0.62)])
	# Street lamps.
	var n := -200.0
	while n < 205.0:
		_street_lamp(MAIN_STREET_U + 5.0, n, Vector2(-1, 0))
		n += 30.0
	var u := -150.0
	while u < 210.0:
		if absf(u - SIDE_ROAD_U) > 6.0 and absf(u - EAST_STREET_U) > 6.0:
			_street_lamp(u, SOUTH_ROAD_N - 4.9, Vector2(0, 1))
			_street_lamp(u + 15.0, NORTH_ROAD_N + 4.4, Vector2(0, -1))
		u += 30.0
	n = -150.0
	while n < 130.0:
		_street_lamp(SIDE_ROAD_U + 6.4, n, Vector2(-1, 0))
		n += 32.0
	# Benches on the home path, cars along its parking strip.
	for bn in [-29.0, -1.0, 27.0]:
		_bench(PATH_U - 2.2, bn, 0.0)
	_park_row(_frame(Vector2(-17.3, 7.5), 90.0), -46.0, 46.0, 0.0, false, 0.75)
	_park_row(_frame(Vector2(-90.0, -54.0), 0.0), -60.0, 30.0, 0.0, false, 0.5)


func _plant_rows() -> void:
	# Poplars along the main street (east side), birches behind the side street's east sidewalk.
	_tree_row("poplar", Vector2(MAIN_STREET_U + 8.6, -205.0), Vector2(MAIN_STREET_U + 8.6, 205.0), 9.0)
	var n := -160.0
	while n < 130.0:
		if absf(n + 50.0) > 5.0:
			_trees.append(["birch", Vector3(SIDE_ROAD_U + 9.0, 0, n), _rng.randf_range(0.9, 1.15)])
		n += 10.0


## OpenStreetMap metres, aligned with the original 10th Cheredovaya road.
func _build_cheredovaya_extension() -> void:
	_cheredovaya_road([Vector2(128, -170), Vector2(134, -181), Vector2(136, -203),
		Vector2(137, -273), Vector2(124, -290), Vector2(121, -350), Vector2(121, -441),
		Vector2(118, -492)], 5.5)
	_cheredovaya_road([Vector2(-45, -501), Vector2(57, -496), Vector2(118, -492),
		Vector2(172, -488), Vector2(276, -484), Vector2(427, -480)], 7.0)
	_cheredovaya_road([Vector2(237, -128), Vector2(230, -170)], 4.0)
	_cheredovaya_road([Vector2(278, -111), Vector2(275, -170), Vector2(276, -249),
		Vector2(275, -288), Vector2(274, -345), Vector2(274, -417), Vector2(276, -484)], 6.0)
	_cheredovaya_road([Vector2(333, -170), Vector2(332, -273), Vector2(323, -284),
		Vector2(275, -288)], 4.5)
	_cheredovaya_road([Vector2(386, -170), Vector2(387, -253), Vector2(386, -277)], 4.5)
	_cheredovaya_road([Vector2(332, -482), Vector2(332, -441)], 4.5)
	_cheredovaya_road([Vector2(274, -417), Vector2(333, -417)], 4.5)
	_cheredovaya_road([Vector2(136, -203), Vector2(154, -216), Vector2(231, -216),
		Vector2(232, -263), Vector2(208, -263), Vector2(211, -347), Vector2(274, -345)], 4.6)
	_cheredovaya_road([Vector2(48, -351), Vector2(54, -441), Vector2(57, -496)], 5.0)
	_cheredovaya_road([Vector2(54, -441), Vector2(121, -441)], 4.5)
	_cheredovaya_road([Vector2(153, -385), Vector2(231, -387), Vector2(274, -385)], 4.5)
	_cheredovaya_road([Vector2(124, -290), Vector2(101, -282), Vector2(87, -293),
		Vector2(88, -310)], 3.8)
	_road(Vector2(22, -178.5), Vector2(420, -178.5), 2.2, WALK_ASPHALT, 0.036)
	_road(Vector2(22, -161.5), Vector2(401, -161.5), 2.0, WALK_ASPHALT, 0.036)
	_road(Vector2(86, -178.5), Vector2(85, -294), 2.0, WALK_ASPHALT, 0.036)
	_road(Vector2(200, -248), Vector2(202.5, -338), 2.4, WALK_ASPHALT, 0.036)
	_road(Vector2(196.0, -252), Vector2(200.1, -252), 1.7, WALK_ASPHALT, 0.035)
	for n: float in [-267.5, -283.0, -299.0, -314.5, -330.0]:
		_road(Vector2(196.0, n), Vector2(212.0, n), 1.7, WALK_ASPHALT, 0.035)
	_zebra(Vector2(265, -170), 0.0, 7.0)
	_zebra(Vector2(139, -170), 0.0, 7.0)

	var house := _khrushchyovka("Cheredovaya23", CHEREDOVAYA_23, 96.9, 91.6, 1.0,
		Color(0.77, 0.72, 0.65), false, 5, 13.1)
	_frame_sign(house, -38.0, -6.55, -1.0, 3.5, "10-я ЧЕРЕДОВАЯ   23",
		Color(0.10, 0.29, 0.52), Color.WHITE, 7.4)
	_frame_sign(house, 32.8, -6.55, -1.0, 2.7, "23",
		Color(0.10, 0.29, 0.52), Color.WHITE, 1.1)
	_khrushchyovka("Cheredovaya21", Vector2(189.1, -372.3), 91.1, 1.6, 1.0, KHRUSH_WALL, false)
	_block("Cheredovaya21Wing", Vector2(246.5, -368.3), Vector2(19.7, 30), 1.6, 5, KHRUSH_WALL)
	_panel_slab("Cheredovaya27", Vector2(246, -267), 113.7, 91.6, 1.0, 10)
	_khrushchyovka("Cheredovaya15a", Vector2(-7.1, -333.9), 64.2, 1.1, -1.0, KHRUSH_WALL, false)
	var library := _block("KosmodemyanskayaLibrary", Vector2(96.5, -238), Vector2(50.8, 12.6),
		90.3, 2, Color(0.79, 0.62, 0.42))
	_door(library, 13.0, 6.3, 1.0)
	_frame_sign(library, 13.0, 6.3, 1.0, 3.6, "БИБЛИОТЕКА", Color(0.29, 0.16, 0.08), Color.WHITE)
	_block("Cheredovaya23Utility", Vector2(137.5, -301.5), Vector2(23.6, 13.2), 89.6, 1, Color(0.60, 0.47, 0.38))
	_block("Cheredovaya27Utility", Vector2(250.0, -338.8), Vector2(17.0, 10.0), 1.6, 1, Color(0.73, 0.68, 0.56))
	_block("KareloFinskaya53", Vector2(64.9, -291.3), Vector2(15.7, 13), 89.8, 2, Color(0.68, 0.60, 0.52))

	for x: float in [65.0, 109.0]:
		for n: float in [-329.0, -362.0, -394.0, -425.0]:
			_khrushchyovka("NeighbourBlock", Vector2(x, n), 18.5, 90.0, signf(x - 80.0),
				Color(0.74, 0.65, 0.54), true, 2, 15.0)
	for x: float in [153.1, 200.2, 247.7]:
		_khrushchyovka("PoltoratskogoBlock", Vector2(x, -425), 61.0, 90.3, 1.0, KHRUSH_WALL, false)
	_khrushchyovka("Poltoratskogo56a", Vector2(86.7, -456.9), 58.4, 0.3, 1.0, KHRUSH_WALL, true, 4)
	_khrushchyovka("Poltoratskogo64", Vector2(394.9, -459.2), 101.4, 1.6, 1.0, KHRUSH_WALL, false)
	_block("Poltoratskogo54North", Vector2(3.8, -448), Vector2(67.5, 16), 0.3, 3, Color(0.76, 0.61, 0.50))
	_block("Poltoratskogo54West", Vector2(-19.5, -423), Vector2(17, 37), 0.3, 2, Color(0.76, 0.61, 0.50))
	for row in [
		[129.8, -239.7, 64.1, 90.3], [144.4, -264.4, 30.9, 90.3],
		[161.5, -271.0, 35.0, 90.3], [153.3, -338.7, 36.9, 1.6],
		[146.7, -475.9, 32.1, 0.3], [305.8, -398.5, 36.0, 2.7],
		[316.0, -377.2, 52.6, 2.7], [393.0, -407.2, 98.0, 1.6],
		[400.7, -384.5, 85.6, 1.6], [409.7, -356.7, 50.1, 3.7],
		[256.0, -151.0, 20.3, -2.3], [256.7, -135.7, 20.3, -2.3],
	]:
		_garages(Vector2(row[0], row[1]), row[2], row[3], false)

	# Driveways, small gardens and parked cars between the five- and ten-storey slabs.
	_yard_playground(Vector2(218.5, -320.0))
	_bin_site(219.0, -274.0)
	_bus_stop(245.0, -161.5)
	_park_row(_frame(Vector2(220.0, -286.5), 90.0), -7.0, 6.0, 0.0, false, 0.8)
	_park_row(_frame(Vector2(201.0, -222.0), 0.0), -23.0, 24.0, 0.0, false, 0.7)
	for n: float in [-260.0, -292.0, -325.0]:
		_bench(203.5, n, 90.0)
	for x in range(240, 415, 27):
		_street_lamp(x, -164.0, Vector2(0, -1))
	for n in range(-383, -181, 26):
		_street_lamp(280.0, n, Vector2(-1, 0))
	_tree_row("birch", Vector2(177, -334), Vector2(176, -242), 10.0)
	_tree_row("birch", Vector2(228.5, -329), Vector2(228, -278), 10.0)
	_tree_row("leafy", Vector2(204.5, -327), Vector2(204.0, -265), 14.0)
	_tree_row("poplar", Vector2(78, -258), Vector2(77, -184), 9.5)
	_tree_row("birch", Vector2(94, -173.8), Vector2(119, -173.8), 8.5)
	_tree_row("birch", Vector2(193, -397), Vector2(147, -396), 9.0)
	_tree_row("leafy", Vector2(281.5, -308), Vector2(281.5, -346), 7.5)
	_build_cheredovaya_houses()


func _cheredovaya_road(points: Array[Vector2], width: float) -> void:
	for i in range(1, points.size()):
		var direction := points[i - 1].direction_to(points[i])
		_road(points[i - 1] - direction * 0.3, points[i] + direction * 0.3, width,
			OMSK_ASPHALT.lightened(0.055), 0.012 + i * 0.0005)


func _build_cheredovaya_houses() -> void:
	# Coordinates, length, depth and azimuth of the private-sector roofs.
	var footprints := [
		[291.7, -189.3, 8.6, 7.8, 90.1], [320.1, -191.5, 10.7, 10.4, 90.1],
		[345.3, -189.6, 12.3, 7.5, 0.2], [375.1, -189.6, 9.5, 7.0, 0.2],
		[397.3, -191.2, 10.7, 7.6, 90.1], [397.6, -212.4, 9.7, 6.1, 0.1],
		[289.6, -223.0, 10.6, 7.3, 0.2], [317.9, -217.7, 14.8, 7.2, 0.2],
		[343.6, -219.7, 10.6, 9.5, 90.1], [372.4, -210.3, 12.6, 7.7, 0.2],
		[289.3, -243.8, 12.1, 8.1, 0.2], [318.6, -241.8, 13.8, 10.0, 0.1],
		[347.2, -243.5, 13.4, 8.0, 0.1], [371.4, -241.2, 16.8, 15.1, 90.2],
		[397.4, -244.7, 8.9, 7.3, 0.1], [294.1, -266.6, 20.0, 13.0, 0.1],
		[318.3, -266.0, 14.2, 7.1, 0.2], [343.9, -265.6, 8.9, 8.7, 0.1],
		[374.7, -266.3, 10.1, 7.0, 0.1], [399.3, -265.0, 11.0, 9.0, 0.2],
		[289.7, -149.4, 11.9, 11.1, 89.9], [311.6, -149.2, 14.3, 11.6, 89.9],
		[340.6, -150.3, 20.0, 10.1, -0.3], [372.1, -149.6, 13.5, 9.2, -0.1],
		[290.4, -125.1, 11.3, 6.3, 0.8], [345.2, -128.7, 12.6, 6.9, 0.8],
		[369.8, -125.8, 12.8, 10.3, 89.9],
	]
	for roof in footprints:
		var f := _frame(Vector2(roof[0], roof[1]), roof[4])
		var s: float = roof[2] * 0.5
		var t: float = roof[3] * 0.5
		var walls: Color = HOUSE_WALLS[_rng.randi_range(0, HOUSE_WALLS.size() - 1)]
		var tiles: Color = HOUSE_ROOFS[_rng.randi_range(0, HOUSE_ROOFS.size() - 1)]
		_owall("KrymskayaHouse", f, -s, -t, s, t, 0.0, 3.0, walls)
		_ocollider(f, -s, -t, s, t, 0.0, 3.0)
		_oroof(f, -s - 0.3, -t - 0.3, s + 0.3, t + 0.3, 3.0, minf(2.5, t * 0.57), tiles, walls)
		_obox(f, s * 0.4, -0.27, s * 0.4 + 0.6, 0.27, 4.0, 5.8, Color(0.52, 0.30, 0.23))
		_door(f, 0.0, t, 1.0)
		for side in [-1.0, 1.0]:
			for offset in [-s * 0.48, s * 0.52]:
				_obox(f, offset - 0.62, side * t, offset + 0.62, side * (t + 0.035), 1.05, 2.4, WHITE_PVC)
				_obox(f, offset - 0.52, side * (t + 0.035), offset + 0.52, side * (t + 0.07), 1.15, 2.3, GLASS, "glass")
	for x: float in [283.5, 325.5, 340.0, 379.0, 393.0]:
		var f := _frame(Vector2(x, -231), 90.0)
		var fence := Color(0.42, 0.44, 0.36).lightened(_rng.randf_range(0.0, 0.22))
		for s: float in [-49.0, -30.0, -11.0, 8.0, 27.0, 46.0]:
			_ofence(f, s, 0.0, s + 12.0, 0.0, 1.55, fence)
