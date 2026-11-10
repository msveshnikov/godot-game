extends Node3D
## Panel-housing estate (sídliště) laid out after a satellite screenshot of the
## real neighbourhood. Map scale is ~0.17 game units per screenshot pixel; map
## north is +Z and map east is -X, so the view from the start room matches the
## map when facing north. Everything is built from boxes at runtime.
##
## The five enterable flats (fruit + wardrobe with a foam pistol) that used to be
## stand-alone street houses now sit on the ground floor of the panel blocks.

const STREET_HOUSE_SCENE: PackedScene = preload("res://street_house.tscn")

const FLOOR_HEIGHT := 3.0
## Half width / height of the hole cut into a block for a ground-floor flat.
const FLAT_SLOT_HALF_WIDTH := 4.03
const FLAT_SLOT_HEIGHT := 5.6
const FLAT_SLOT_DEPTH := 7.19
## Distance from the flat's origin to its outer front facade.
const FLAT_FRONT_OFFSET := 3.655

const ROAD_COLOR := Color(0.2, 0.21, 0.23)
const LOT_COLOR := Color(0.27, 0.28, 0.3)
const PATH_COLOR := Color(0.66, 0.65, 0.62)
const ROOF_COLOR := Color(0.58, 0.58, 0.57)
const MARKING_COLOR := Color(0.91, 0.78, 0.4)
const LINE_COLOR := Color(0.9, 0.9, 0.88)
const GLASS_COLOR := Color(0.16, 0.22, 0.28)
const DOOR_COLOR := Color(0.3, 0.22, 0.16)

const CAR_COLORS := [
	Color(0.75, 0.1, 0.1), Color(0.92, 0.92, 0.9), Color(0.12, 0.13, 0.15),
	Color(0.55, 0.57, 0.6), Color(0.15, 0.27, 0.55), Color(0.82, 0.78, 0.66),
	Color(0.2, 0.42, 0.3), Color(0.35, 0.36, 0.4),
]

var _materials := {}
var _window_texture: Texture2D
## XZ footprints of everything solid or paved, used to keep trees off them.
var _blocked: Array[Rect2] = []


func _ready() -> void:
	_window_texture = _make_window_texture()
	_build_roads()
	_build_paths()
	_build_parking()
	_build_panel_blocks()
	_build_other_buildings()
	_build_family_houses()
	_build_trees()


# ---------------------------------------------------------------- layout ----

func _build_roads() -> void:
	# Main street (Dr. E. Beneše) lives in the scene; only extend its markings.
	var marking_mat := _plain(MARKING_COLOR)
	for x in range(30, 79, 6):
		for side in [-1, 1]:
			_box("LaneMarking", Vector3(x * side, 0.08, 17), Vector3(2.6, 0.025, 0.12), marking_mat, false)

	# Vertical roads are a touch thicker than east-west ones so crossings don't z-fight.
	_flat("EastRoad", -53.5, 22.25, -47.5, 150.5, 0.07, ROAD_COLOR)
	_flat("WestRoad", 55.0, 22.25, 61.0, 150.5, 0.07, ROAD_COLOR)
	_flat("NaSkalkachRoad", -47.5, 63.5, 55.0, 68.5, 0.05, ROAD_COLOR)
	_flat("ZaJednotouRoad", -47.5, 100.1, 55.0, 105.1, 0.05, ROAD_COLOR)
	_flat("BaaraRoad", -47.5, 145.5, 55.0, 150.5, 0.05, ROAD_COLOR)
	_flat("HousesLane", -47.5, 129.0, 55.0, 133.0, 0.05, ROAD_COLOR)
	_flat("LomenaRoad", 4.8, 117.8, 9.8, 145.5, 0.07, ROAD_COLOR)
	_flat("TravniRoad", -30.9, 105.1, -25.9, 145.5, 0.07, ROAD_COLOR)


func _build_paths() -> void:
	_flat("PathBehindHome", -7.0, 83.2, 51.0, 85.2, 0.09, PATH_COLOR)
	_flat("PathWestLoop", -7.0, 68.5, -5.0, 100.1, 0.09, PATH_COLOR)
	_flat("PathEastLoop", 49.0, 68.5, 51.0, 100.1, 0.09, PATH_COLOR)
	_flat("PathToTowerB", 18.7, 31.0, 20.7, 49.6, 0.09, PATH_COLOR)
	_flat("PathToTowerC", -10.7, 31.0, -8.7, 47.6, 0.09, PATH_COLOR)
	_flat("PathToTowerA", 46.0, 31.0, 48.0, 50.5, 0.09, PATH_COLOR)
	# Diagonal path from the street up past the east blocks.
	var start := Vector2(-12.5, 47.0)
	var finish := Vector2(-31.0, 22.3)
	var mid := (start + finish) * 0.5
	var along := finish - start
	var yaw := rad_to_deg(atan2(along.x, along.y))
	_box("DiagonalPath", Vector3(mid.x, 0.045, mid.y), Vector3(2.0, 0.09, along.length()), _plain(PATH_COLOR), true, yaw)


func _build_parking() -> void:
	var spots: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150

	# Long lot along Dr. E. Beneše, cars nose-in towards the street.
	_flat("BenesheParking", -24.0, 22.25, 50.0, 31.0, 0.04, LOT_COLOR)
	_add_parking_row(spots, rng, -22.0, 48.5, 28.6, 0.0, 0.8)
	# Supermarket lot (east of the shop) with two rows facing a middle aisle.
	_flat("ShopParking", -47.5, 80.5, -27.0, 100.1, 0.04, LOT_COLOR)
	_add_parking_row(spots, rng, -45.5, -28.5, 83.0, 180.0, 0.75)
	_add_parking_row(spots, rng, -45.5, -28.5, 97.6, 0.0, 0.7)
	# Small lot north of the shop.
	_flat("NorthParking", -25.5, 105.1, -9.0, 116.0, 0.04, LOT_COLOR)
	_add_parking_row(spots, rng, -24.0, -10.5, 113.6, 0.0, 0.85)
	_spawn_cars(spots, rng)


func _build_panel_blocks() -> void:
	# Long five-storey blocks: two along Za Jednotou and the "home" block below.
	_add_block("ZaJednotouNorth", Vector2(19.2, 111.7), Vector2(47.6, 11.0), 5,
		Color(0.78, 0.85, 0.93), Color(0.36, 0.53, 0.72),
		{"x": 30.0, "facade": Color(0.32, 0.51, 0.7), "roof": Color(0.19, 0.24, 0.32)})
	_add_block("ZaJednotouSouth", Vector2(20.6, 93.5), Vector2(48.5, 11.0), 5,
		Color(0.8, 0.89, 0.76), Color(0.42, 0.62, 0.38),
		{"x": 12.0, "facade": Color(0.46, 0.65, 0.42), "roof": Color(0.29, 0.27, 0.22)})
	_add_block("HomeBlock", Vector2(22.1, 74.8), Vector2(48.5, 11.0), 5,
		Color(0.95, 0.88, 0.74), Color(0.8, 0.45, 0.3),
		{"x": 27.0, "facade": Color(0.79, 0.43, 0.31), "roof": Color(0.38, 0.21, 0.19)})
	_add_sign("HOME", Vector3(27.0, 6.5, 69.3 - 0.06), Color(1.0, 0.62, 0.3), 0.024)

	# Na Skalkách point towers.
	_add_block("TowerA", Vector2(47.0, 56.5), Vector2(12.0, 12.0), 8,
		Color(0.9, 0.9, 0.88), Color(0.85, 0.6, 0.3))
	_add_block("TowerB", Vector2(19.7, 55.6), Vector2(12.0, 12.0), 8,
		Color(0.86, 0.82, 0.92), Color(0.55, 0.44, 0.7),
		{"x": 19.7, "facade": Color(0.62, 0.48, 0.7), "roof": Color(0.27, 0.23, 0.34)})
	_add_block("TowerC", Vector2(-9.7, 53.6), Vector2(12.0, 12.0), 8,
		Color(0.96, 0.91, 0.7), Color(0.8, 0.66, 0.3),
		{"x": -9.7, "facade": Color(0.83, 0.7, 0.39), "roof": Color(0.34, 0.28, 0.2)})
	_add_block("TowerD", Vector2(6.5, 37.4), Vector2(11.0, 11.0), 6,
		Color(0.88, 0.89, 0.9), Color(0.4, 0.6, 0.65))

	# East Na Skalkách slabs.
	_add_block("EastSlabNorth", Vector2(-34.3, 57.8), Vector2(21.0, 9.0), 7,
		Color(0.95, 0.82, 0.74), Color(0.75, 0.42, 0.35))
	_add_block("EastSlabSouth", Vector2(-34.0, 39.1), Vector2(22.0, 9.0), 5,
		Color(0.82, 0.86, 0.9), Color(0.45, 0.5, 0.6))


func _build_other_buildings() -> void:
	# Supermarket + pharmacy: low white box with a glass shopfront.
	var shop_center := Vector2(-17.9, 91.8)
	var shop_size := Vector3(16.0, 7.0, 15.5)
	_box("Shop", Vector3(shop_center.x, shop_size.y * 0.5, shop_center.y), shop_size, _plain(Color(0.93, 0.93, 0.91)))
	_block_rect(shop_center, Vector2(shop_size.x, shop_size.z))
	var shop_front := shop_center.y - shop_size.z * 0.5
	_flat("ShopForecourt", -26.0, 78.0, -9.9, shop_front, 0.09, PATH_COLOR)
	_flat("ShopFootpath", -14.0, 68.5, -12.0, 78.0, 0.09, PATH_COLOR)
	_box("ShopRoof", Vector3(shop_center.x, 7.15, shop_center.y), Vector3(16.4, 0.3, 15.9), _plain(ROOF_COLOR), false)
	_box("ShopWindow", Vector3(shop_center.x, 1.6, shop_front - 0.04), Vector3(12.0, 2.6, 0.1), _plain(GLASS_COLOR), false)
	_box("ShopEntrance", Vector3(shop_center.x + 3.0, 1.3, shop_front - 0.08), Vector3(2.2, 2.6, 0.1), _plain(Color(0.35, 0.45, 0.5)), false)
	_box("ShopCanopy", Vector3(shop_center.x, 3.2, shop_front - 0.8), Vector3(14.0, 0.2, 1.6), _plain(Color(0.85, 0.15, 0.2)), false)
	_add_sign("POTRAVINY", Vector3(shop_center.x - 2.5, 4.9, shop_front - 0.06), Color(0.85, 0.15, 0.2), 0.02)
	_add_sign("+ LÉKÁRNA", Vector3(shop_center.x + 4.5, 4.9, shop_front - 0.06), Color(0.1, 0.62, 0.3), 0.016)
	for index in range(3):
		_box("RoofUnit", Vector3(shop_center.x - 4.0 + index * 4.0, 7.75, shop_center.y + 2.0), Vector3(2.0, 1.0, 1.4), _plain(Color(0.75, 0.76, 0.77)), false)

	# Red-roofed three-storey building east of the home block.
	_add_gabled_house("RedRoofHall", Vector2(-35.7, 74.8), Vector2(21.0, 10.0), 9.0, 3.5,
		Color(0.94, 0.9, 0.8), Color(0.72, 0.2, 0.16), true)
	# Low building with a purple roof (kindergarten-ish) west of tower D.
	_add_gabled_house("PurpleRoofHall", Vector2(36.2, 40.0), Vector2(10.0, 10.0), 6.0, 3.0,
		Color(0.93, 0.9, 0.85), Color(0.45, 0.3, 0.55), false)
	# Row of garages near the street.
	_box("Garages", Vector3(-37.0, 1.6, 27.5), Vector3(11.0, 3.2, 5.0), _plain(Color(0.7, 0.7, 0.68)))
	_block_rect(Vector2(-37.0, 27.5), Vector2(11.0, 5.0))
	for index in range(4):
		_box("GarageDoor", Vector3(-41.1 + index * 2.75, 1.2, 24.97), Vector3(2.2, 2.2, 0.06), _plain(Color(0.5, 0.52, 0.55)), false)


func _build_family_houses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2412
	var walls := [Color(0.95, 0.92, 0.84), Color(0.96, 0.88, 0.7), Color(0.9, 0.9, 0.9), Color(0.92, 0.8, 0.7)]
	var roofs := [Color(0.72, 0.24, 0.16), Color(0.62, 0.2, 0.15), Color(0.8, 0.36, 0.2), Color(0.42, 0.3, 0.26)]
	var columns := [49.5, 39.0, 28.5, 18.0, 0.0, -9.5, -19.0, -35.0, -43.0]
	for row_z in [124.8, 137.5]:
		for x in columns:
			var width := rng.randf_range(6.2, 7.2)
			var depth := rng.randf_range(6.2, 7.0)
			var floors := 1 if rng.randf() < 0.55 else 2
			var height := 3.4 if floors == 1 else 6.0
			_add_gabled_house("FamilyHouse", Vector2(x + rng.randf_range(-0.5, 0.5), row_z), Vector2(width, depth),
				height, rng.randf_range(2.2, 2.8), walls[rng.randi() % walls.size()],
				roofs[rng.randi() % roofs.size()], rng.randf() < 0.5)


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731
	# Villager NPCs stand here; keep trees off them.
	_blocked.append(Rect2(-30.5, 30.5, 4.0, 4.0))
	_blocked.append(Rect2(-18.5, 34.2, 4.0, 4.0))

	var trees: Array[Vector3] = []
	var attempts := 0
	while trees.size() < 210 and attempts < 6000:
		attempts += 1
		var point := Vector2(rng.randf_range(-47.0, 55.0), rng.randf_range(32.0, 144.0))
		if _is_blocked(point, 2.3):
			continue
		var too_close := false
		for tree in trees:
			if Vector2(tree.x, tree.y).distance_squared_to(point) < 4.6 * 4.6:
				too_close = true
				break
		if not too_close:
			trees.append(Vector3(point.x, point.y, rng.randf_range(0.8, 1.3)))

	# Avenue between the street parking and the towers.
	for x in range(-20, 50, 6):
		var point := Vector2(x + 1.0, 32.6)
		if not _is_blocked(point, 1.2):
			trees.append(Vector3(point.x, point.y, 0.9))

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 3.0
	trunk_mesh.radial_segments = 7
	trunk_mesh.material = _vertex_color_material()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 6
	crown_mesh.material = _vertex_color_material()

	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var crown_colors: Array[Color] = []
	var trunk_colors: Array[Color] = []
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.3
	trunk_shape.height = 3.0
	for tree in trees:
		var s := tree.z
		var base := Vector3(tree.x, 0, tree.y)
		trunks.append(Transform3D(Basis().scaled(Vector3.ONE * s), base + Vector3(0, 1.5 * s, 0)))
		trunk_colors.append(Color(0.33, 0.23, 0.15))
		var green := Color.from_hsv(rng.randf_range(0.22, 0.32), rng.randf_range(0.45, 0.65), rng.randf_range(0.32, 0.5))
		crowns.append(Transform3D(Basis().scaled(Vector3(2.3, 2.0, 2.3) * s), base + Vector3(0, 4.3 * s, 0)))
		crown_colors.append(green)
		crowns.append(Transform3D(Basis().scaled(Vector3(1.6, 1.4, 1.6) * s), base + Vector3(0.9, 5.4, -0.6) * s))
		crown_colors.append(green.lightened(0.08))

		var body := StaticBody3D.new()
		body.name = "TreeTrunk"
		body.position = base + Vector3(0, 1.5, 0)
		var shape_node := CollisionShape3D.new()
		shape_node.shape = trunk_shape
		body.add_child(shape_node)
		add_child(body)

	_add_multimesh("TreeTrunks", trunk_mesh, trunks, trunk_colors)
	_add_multimesh("TreeCrowns", crown_mesh, crowns, crown_colors)


# ------------------------------------------------------------- builders ----

## A panel block with window facade, flat roof, balconies and entrances.
## `flat` optionally carves an enterable ground-floor flat into the south face:
## {"x": slot centre, "facade": Color, "roof": Color}.
func _add_block(block_name: String, center: Vector2, size: Vector2, floors: int, tint: Color, accent: Color, flat := {}) -> void:
	var height := floors * FLOOR_HEIGHT
	var x0 := center.x - size.x * 0.5
	var x1 := center.x + size.x * 0.5
	var z0 := center.y - size.y * 0.5 # south face, towards the street
	var z1 := center.y + size.y * 0.5
	var wall := _facade(tint)
	_block_rect(center, size)

	if flat.is_empty():
		_box(block_name, Vector3(center.x, height * 0.5, center.y), Vector3(size.x, height, size.y), wall)
	else:
		var slot_x: float = flat["x"]
		var a := slot_x - FLAT_SLOT_HALF_WIDTH
		var b := slot_x + FLAT_SLOT_HALF_WIDTH
		_box_between(block_name + "Left", Vector3(x0, 0, z0), Vector3(a, height, z1), wall)
		_box_between(block_name + "Right", Vector3(b, 0, z0), Vector3(x1, height, z1), wall)
		_box_between(block_name + "AboveFlat", Vector3(a, FLAT_SLOT_HEIGHT, z0), Vector3(b, height, z1), wall)
		_box_between(block_name + "BehindFlat", Vector3(a, 0, z0 + FLAT_SLOT_DEPTH), Vector3(b, FLAT_SLOT_HEIGHT, z1), wall)

		var house := STREET_HOUSE_SCENE.instantiate() as Node3D
		house.name = block_name + "Flat"
		house.set("apartment_mode", true)
		house.set("facade_color", flat["facade"])
		house.set("roof_color", flat["roof"])
		house.position = Vector3(slot_x, 0, z0 + FLAT_FRONT_OFFSET)
		add_child(house)

	# Flat roof with a raised parapet edge and a lift machine room.
	var roof := _plain(ROOF_COLOR)
	_box(block_name + "Roof", Vector3(center.x, height + 0.2, center.y), Vector3(size.x + 0.4, 0.4, size.y + 0.4), roof, false)
	_box(block_name + "RoofTop", Vector3(center.x, height + 0.45, center.y), Vector3(size.x - 0.6, 0.12, size.y - 0.6), _plain(ROOF_COLOR.darkened(0.15)), false)
	var machine_count := maxi(1, int(size.x / 16.0))
	for index in range(machine_count):
		var mx := x0 + size.x * (index + 0.5) / machine_count
		_box(block_name + "LiftRoom", Vector3(mx, height + 1.4, center.y + 1.0), Vector3(3.0, 2.0, 3.0), _plain(tint.darkened(0.1)), false)

	# Balconies on the south face from the third floor up (clear of the flat).
	var balcony := _plain(accent)
	var columns := maxi(1, int(size.x / 9.0))
	for column in range(columns):
		var bx := x0 + size.x * (column + 0.5) / columns
		for floor_index in range(2, floors):
			_box(block_name + "Balcony", Vector3(bx, floor_index * FLOOR_HEIGHT + 0.55, z0 - 0.6), Vector3(2.8, 1.1, 1.2), balcony, false)

	# Stairwell entrances on the north face.
	var entrances := maxi(1, int(size.x / 12.0))
	for index in range(entrances):
		var ex := x0 + size.x * (index + 0.5) / entrances
		_box(block_name + "EntranceDoor", Vector3(ex, 1.25, z1 + 0.06), Vector3(1.6, 2.5, 0.12), _plain(DOOR_COLOR), false)
		_box(block_name + "EntranceCanopy", Vector3(ex, 2.75, z1 + 0.7), Vector3(2.6, 0.18, 1.4), _plain(ROOF_COLOR), false)
		_box(block_name + "EntranceStep", Vector3(ex, 0.08, z1 + 0.7), Vector3(2.4, 0.16, 1.4), _plain(PATH_COLOR), true)


func _add_gabled_house(house_name: String, center: Vector2, size: Vector2, wall_height: float, roof_height: float,
		wall_color: Color, roof_color: Color, ridge_along_x: bool) -> void:
	_box(house_name, Vector3(center.x, wall_height * 0.5, center.y), Vector3(size.x, wall_height, size.y), _facade(wall_color))
	_block_rect(center, size)
	var roof := MeshInstance3D.new()
	roof.name = house_name + "Roof"
	var prism := PrismMesh.new()
	# PrismMesh's ridge runs along its local Z.
	prism.size = Vector3(size.y + 0.8, roof_height, size.x + 0.8) if ridge_along_x else Vector3(size.x + 0.8, roof_height, size.y + 0.8)
	roof.mesh = prism
	roof.material_override = _plain(roof_color)
	roof.position = Vector3(center.x, wall_height + roof_height * 0.5, center.y)
	if ridge_along_x:
		roof.rotation_degrees.y = 90.0
	add_child(roof)
	# Front door facing the street side.
	_box(house_name + "Door", Vector3(center.x, 1.15, center.y - size.y * 0.5 - 0.05), Vector3(1.1, 2.3, 0.1), _plain(DOOR_COLOR), false)


func _add_parking_row(spots: Array[Transform3D], rng: RandomNumberGenerator, from_x: float, to_x: float, z: float, yaw: float, fill: float) -> void:
	var line_mat := _plain(LINE_COLOR)
	var x := from_x
	while x <= to_x:
		_box("ParkingLine", Vector3(x - 1.35, 0.05, z), Vector3(0.12, 0.02, 4.8), line_mat, false)
		if rng.randf() < fill:
			var jitter := Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.3, 0.3))
			spots.append(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw + rng.randf_range(-4, 4))), Vector3(x, 0, z) + jitter))
		x += 2.7


func _spawn_cars(spots: Array[Transform3D], rng: RandomNumberGenerator) -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.8, 0.7, 4.2)
	body_mesh.material = _vertex_color_material()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.56, 0.62, 2.1)
	cabin_mesh.material = _vertex_color_material()
	var chassis_mesh := BoxMesh.new()
	chassis_mesh.size = Vector3(1.7, 0.35, 3.4)
	chassis_mesh.material = _vertex_color_material()

	var bodies: Array[Transform3D] = []
	var cabins: Array[Transform3D] = []
	var chassis: Array[Transform3D] = []
	var body_colors: Array[Color] = []
	var cabin_colors: Array[Color] = []
	var chassis_colors: Array[Color] = []
	var car_shape := BoxShape3D.new()
	car_shape.size = Vector3(1.8, 1.6, 4.2)
	for spot in spots:
		bodies.append(spot * Transform3D(Basis(), Vector3(0, 0.62, 0)))
		cabins.append(spot * Transform3D(Basis(), Vector3(0, 1.28, -0.15)))
		chassis.append(spot * Transform3D(Basis(), Vector3(0, 0.2, 0)))
		body_colors.append(CAR_COLORS[rng.randi() % CAR_COLORS.size()])
		cabin_colors.append(Color(0.32, 0.4, 0.48))
		chassis_colors.append(Color(0.06, 0.06, 0.07))

		var body := StaticBody3D.new()
		body.name = "ParkedCar"
		body.transform = spot * Transform3D(Basis(), Vector3(0, 0.8, 0))
		var shape_node := CollisionShape3D.new()
		shape_node.shape = car_shape
		body.add_child(shape_node)
		add_child(body)

	_add_multimesh("CarBodies", body_mesh, bodies, body_colors)
	_add_multimesh("CarCabins", cabin_mesh, cabins, cabin_colors)
	_add_multimesh("CarChassis", chassis_mesh, chassis, chassis_colors)


func _add_sign(text: String, sign_position: Vector3, color: Color, pixel_size: float) -> void:
	var label := Label3D.new()
	label.name = "Sign"
	label.text = text
	label.position = sign_position
	label.rotation_degrees.y = 180.0 # face the street (-Z)
	label.pixel_size = pixel_size
	label.font_size = 64
	label.outline_size = 14
	label.modulate = color
	label.outline_modulate = Color(1, 1, 1)
	label.double_sided = false
	add_child(label)


# -------------------------------------------------------------- helpers ----

## Paved surface lying on the ground between two XZ corners.
func _flat(node_name: String, x0: float, z0: float, x1: float, z1: float, thickness: float, color: Color) -> void:
	var lo := Vector3(minf(x0, x1), 0, minf(z0, z1))
	var hi := Vector3(maxf(x0, x1), thickness, maxf(z0, z1))
	_box_between(node_name, lo, hi, _plain(color), true)
	_blocked.append(Rect2(lo.x, lo.z, hi.x - lo.x, hi.z - lo.z))


func _block_rect(center: Vector2, size: Vector2) -> void:
	_blocked.append(Rect2(center - size * 0.5, size))


func _is_blocked(point: Vector2, margin: float) -> bool:
	for rect in _blocked:
		if rect.grow(margin).has_point(point):
			return true
	return false


func _box_between(node_name: String, lo: Vector3, hi: Vector3, material: Material, collide := true) -> void:
	var size := hi - lo
	if size.x <= 0.01 or size.y <= 0.01 or size.z <= 0.01:
		return
	_box(node_name, (lo + hi) * 0.5, size, material, collide)


func _box(node_name: String, center: Vector3, size: Vector3, material: Material, collide := true, yaw_degrees := 0.0) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = center
	mesh_instance.rotation_degrees.y = yaw_degrees
	add_child(mesh_instance)
	if not collide:
		return
	var body := StaticBody3D.new()
	body.name = node_name + "Body"
	body.position = center
	body.rotation_degrees.y = yaw_degrees
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color]) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_color(index, colors[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	add_child(instance)


func _plain(color: Color) -> StandardMaterial3D:
	var key := "plain_%s" % color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		_materials[key] = material
	return _materials[key]


## Window-grid facade: one texture tile = one 3 m wide x 3 m tall panel, mapped in
## world space so split boxes line up seamlessly.
func _facade(tint: Color) -> StandardMaterial3D:
	var key := "facade_%s" % tint.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.albedo_texture = _window_texture
		material.roughness = 0.85
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_triplanar_sharpness = 8.0
		material.uv1_scale = Vector3.ONE / FLOOR_HEIGHT
		_materials[key] = material
	return _materials[key]


func _vertex_color_material() -> StandardMaterial3D:
	if not _materials.has("vertex"):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 0.85
		_materials["vertex"] = material
	return _materials["vertex"]


func _make_window_texture() -> Texture2D:
	# Triplanar flips V, so texture row 63 sits at floor level and row 0 at the ceiling.
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.97, 0.97, 0.96))
	image.fill_rect(Rect2i(0, 61, 64, 3), Color(0.8, 0.8, 0.79)) # floor seam
	image.fill_rect(Rect2i(0, 0, 1, 64), Color(0.86, 0.86, 0.85)) # panel seam
	image.fill_rect(Rect2i(13, 17, 38, 30), Color(1, 1, 1)) # frame
	image.fill_rect(Rect2i(15, 19, 34, 26), Color(0.24, 0.3, 0.36)) # glass
	image.fill_rect(Rect2i(15, 19, 34, 6), Color(0.33, 0.4, 0.46)) # sky reflection
	image.fill_rect(Rect2i(31, 19, 2, 26), Color(1, 1, 1)) # mullion
	image.fill_rect(Rect2i(11, 47, 42, 2), Color(0.7, 0.7, 0.7)) # sill
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
