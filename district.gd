extends Node3D
## The panel estate around Na Skalkách 939, Neratovice, built 1:1 in metres from
## the satellite map and Street View (~100 m around the home block).
##
## Frame: the long blocks run along X (real heading 121.5°, so game -X points
## south-east along Na Skalkách and +Z points north-east, away from the street).
## Origin is the middle of the home block. Positions below are given as (u, n):
## u = metres along the blocks towards the south-east, n = metres towards the
## north-east; _w() turns them into game coordinates.
##
## Repeated detail (loggia slabs, fins, railings, garages, props) is merged into
## a few vertex-coloured meshes so the web build stays light. Only the big
## volumes, walls, cars, poles and tree trunks get colliders.

const U0 := -5.0 # u of the game origin (centre of the home block)
const FLOOR := 2.8
const PLINTH := 0.5

# Real layout (u, n) measured on the map.
const HOME_CENTRE := Vector2(-5.05, 3.9)
const MIDDLE_CENTRE := Vector2(-0.6, 38.3)
const NORTH_CENTRE := Vector2(-2.1, 85.9)
const SLAB_LENGTH := 107.3
const SLAB_DEPTH := 12.0
const LOGGIA_DEPTH := 1.4
const SECTIONS := 6
const BAYS_PER_SECTION := 3
const TOWER_W := Vector2(-64.6, -37.8)
const TOWER_S := Vector2(3.9, -38.5)
const TOWER_SE := Vector2(66.2, -42.3)
const TOWER_SIZE := 19.0
const TOWER_FLOORS := 12
const ROAD_N := -18.75 # Na Skalkách centre line
const ROAD_HALF := 2.75
const BRANCH_U := 44.5 # Na Skalkách branch running south-west
const ZA_JEDNOTOU_N := 63.5

const ROAD_COLOR := Color(0.62, 0.62, 0.6) # concrete slab road
const ASPHALT_COLOR := Color(0.27, 0.28, 0.3)
const PAVER_COLOR := Color(0.6, 0.55, 0.52) # interlocking pavers
const PATH_COLOR := Color(0.66, 0.64, 0.6)
const CURB_COLOR := Color(0.78, 0.78, 0.76)
const LINE_COLOR := Color(0.9, 0.9, 0.88)
const CONCRETE := Color(0.7, 0.69, 0.66)
const GLASS := Color(0.32, 0.4, 0.46)
const DOOR := Color(0.28, 0.2, 0.15)
const ROOF := Color(0.55, 0.55, 0.54)

## Car models built by blender/scripts/build_vehicles.py: [path, share, collision size].
const CAR_MODELS := [
	["res://assets/vehicles/car_octavia_combi.glb", 0.3, Vector3(1.81, 1.5, 4.69)],
	["res://assets/vehicles/car_fabia.glb", 0.24, Vector3(1.73, 1.47, 4.0)],
	["res://assets/vehicles/car_suv.glb", 0.2, Vector3(1.86, 1.65, 4.48)],
	["res://assets/vehicles/car_octavia.glb", 0.16, Vector3(1.81, 1.46, 4.69)],
	["res://assets/vehicles/car_mpv.glb", 0.1, Vector3(1.81, 1.62, 4.4)],
]
## Paint as seen on the street: mostly silver, white, greys and black, some blues and reds.
const CAR_COLORS := [
	[Color(0.66, 0.68, 0.7), 0.2], [Color(0.93, 0.93, 0.92), 0.18], [Color(0.36, 0.37, 0.4), 0.16],
	[Color(0.06, 0.06, 0.07), 0.13], [Color(0.12, 0.2, 0.42), 0.09], [Color(0.25, 0.42, 0.7), 0.07],
	[Color(0.62, 0.07, 0.07), 0.08], [Color(0.2, 0.36, 0.26), 0.04], [Color(0.52, 0.47, 0.4), 0.05],
]
## Loggia railings seen on the blocks: mostly brown wood-look panels, some white,
## a few red, some glass.
const RAILINGS := [
	[Color(0.47, 0.32, 0.2), 0.42], [Color(0.32, 0.23, 0.17), 0.14], [Color(0.9, 0.9, 0.87), 0.2],
	[Color(0.72, 0.2, 0.17), 0.06], [Color(0.55, 0.63, 0.67), 0.18],
]

var _materials := {}
var _solid := SurfaceTool.new()
var _glass := SurfaceTool.new()
var _collision: StaticBody3D
## Footprints (game XZ) of everything solid or paved, used to keep scattered trees off them.
var _blocked: Array[Rect2] = []
var _rng := RandomNumberGenerator.new()
var _car_spots: Array[Transform3D] = []
var _trees: Array = [] # [kind, Vector2 game xz, scale]


func _ready() -> void:
	_rng.seed = 939
	_solid.begin(Mesh.PRIMITIVE_TRIANGLES)
	_glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	_collision = StaticBody3D.new()
	_collision.name = "DistrictCollision"
	add_child(_collision)

	_build_streets()
	_build_slab_block("HomeBlock", HOME_CENTRE, {
		"wall": Color(0.93, 0.87, 0.7), "fin": Color(0.89, 0.67, 0.27), "entrance": Color(0.96, 0.8, 0.33),
		"plinth": Color(0.6, 0.37, 0.26), "end": Color(0.92, 0.76, 0.42), "back": Color(0.93, 0.88, 0.74),
	}, true)
	_build_slab_block("MiddleBlock", MIDDLE_CENTRE, {
		"wall": Color(0.9, 0.85, 0.72), "fin": Color(0.78, 0.53, 0.3), "entrance": Color(0.92, 0.57, 0.27),
		"plinth": Color(0.55, 0.36, 0.26), "end": Color(0.84, 0.62, 0.4), "back": Color(0.9, 0.86, 0.76),
	})
	_build_slab_block("NorthBlock", NORTH_CENTRE, {
		"wall": Color(0.94, 0.91, 0.84), "fin": Color(0.87, 0.5, 0.24), "entrance": Color(0.9, 0.5, 0.22),
		"plinth": Color(0.87, 0.5, 0.24), "end": Color(0.88, 0.58, 0.33), "back": Color(0.92, 0.9, 0.84),
	})
	_build_tower("TowerW", TOWER_W, Color(0.8, 0.46, 0.38), "")
	_build_tower("TowerS", TOWER_S, Color(0.88, 0.83, 0.71), "PÁNSKÝ, DÁMSKÝ SALON")
	_build_tower("TowerSE", TOWER_SE, Color(0.86, 0.62, 0.5), "KVĚTINÁŘSTVÍ KVĚTKA")
	_build_garages()
	_build_bins()
	_build_other_buildings()
	_build_playground()
	_build_street_furniture()
	_build_parking()
	_build_trees()

	_commit(_solid, "DistrictDetail", _vertex_material())
	_commit(_glass, "DistrictGlass", _glass_material())
	_spawn_cars()


## Game position of a real (u, n) point.
func _w(u: float, n: float, y := 0.0) -> Vector3:
	return Vector3(-(u - U0), y, n)


# ---------------------------------------------------------------- streets ----

func _build_streets() -> void:
	# Na Skalkách: concrete-slab lane in front of the home block, from the north-west
	# bend to the junction where it turns south-west between the towers.
	_ground("NaSkalkach", -112.0, ROAD_N - ROAD_HALF, BRANCH_U + ROAD_HALF, ROAD_N + ROAD_HALF, 0.02, ROAD_COLOR)
	for u in range(-110, int(BRANCH_U), 6): # slab joints
		_ground("Joint", u, ROAD_N - ROAD_HALF, u + 0.08, ROAD_N + ROAD_HALF, 0.022, ROAD_COLOR.darkened(0.25), false)
	_ground("NaSkalkachSouth", BRANCH_U - ROAD_HALF, -104.0, BRANCH_U + ROAD_HALF, ROAD_N - ROAD_HALF, 0.02, ROAD_COLOR)
	# Za Jednotou behind the middle block, asphalt, with a parking strip on the north side.
	_ground("ZaJednotou", -75.0, ZA_JEDNOTOU_N - 2.75, 66.0, ZA_JEDNOTOU_N + 2.75, 0.02, ASPHALT_COLOR)
	_ground("ZaJednotouParking", -60.0, ZA_JEDNOTOU_N + 2.75, 50.0, ZA_JEDNOTOU_N + 5.0, 0.025, PAVER_COLOR.darkened(0.1))
	_ground("ZaJednotouWalk", -70.0, ZA_JEDNOTOU_N + 5.0, 55.0, ZA_JEDNOTOU_N + 6.8, 0.035, PAVER_COLOR)
	_ground("ZaJednotouWalkSouth", -70.0, ZA_JEDNOTOU_N - 4.6, 60.0, ZA_JEDNOTOU_N - 2.75, 0.035, PAVER_COLOR)
	# Link road east of the blocks, past the playground to Za Jednotou.
	_ground("EastLink", 60.0, ROAD_N + ROAD_HALF, 65.5, ZA_JEDNOTOU_N + 2.75, 0.02, ASPHALT_COLOR)
	_ground("EastLinkJoin", BRANCH_U + ROAD_HALF, ROAD_N - ROAD_HALF, 65.5, ROAD_N + ROAD_HALF, 0.021, ASPHALT_COLOR)

	# Home side: parking strip, paver sidewalk and kerb, then lawn up to the loggias.
	_ground("HomeParkingStrip", -62.0, ROAD_N + ROAD_HALF, 46.0, -13.6, 0.03, PAVER_COLOR.darkened(0.12))
	_ground("HomeSidewalk", -66.0, -13.6, 50.0, -11.6, 0.04, PAVER_COLOR)
	_ground("HomeKerb", -66.0, -11.75, 50.0, -11.6, 0.09, CURB_COLOR)
	# Sidewalk on the garage side.
	_ground("GarageApron", -26.0, -23.4, 30.5, ROAD_N - ROAD_HALF, 0.03, CONCRETE.darkened(0.1))

	# Footpaths: one to every entrance of the home block, around its ends and across the yard.
	for section in SECTIONS:
		var u := _entrance_u(HOME_CENTRE, section)
		_ground("EntrancePath", u - 1.1, -11.6, u + 1.1, -2.1, 0.045, PAVER_COLOR.lightened(0.05))
	_ground("PathNWEnd", -66.0, -11.6, -63.8, ZA_JEDNOTOU_N - 4.6, 0.045, PATH_COLOR)
	_ground("PathSEEnd", 55.0, -11.6, 57.0, ZA_JEDNOTOU_N - 4.6, 0.045, PATH_COLOR)
	_ground("PathSEEndLink", 50.0, -13.6, 57.0, -11.6, 0.04, PAVER_COLOR)
	_ground("YardPath", -63.8, 19.0, 55.0, 20.8, 0.045, PATH_COLOR)
	for section in SECTIONS:
		var u := _entrance_u(MIDDLE_CENTRE, section)
		_ground("MiddleEntrancePath", u - 1.0, 20.8, u + 1.0, MIDDLE_CENTRE.y - SLAB_DEPTH * 0.5, 0.045, PATH_COLOR)
		var nu := _entrance_u(NORTH_CENTRE, section)
		_ground("NorthEntrancePath", nu - 1.0, ZA_JEDNOTOU_N + 6.8, nu + 1.0, NORTH_CENTRE.y - SLAB_DEPTH * 0.5, 0.045, PATH_COLOR)
	# Walk past the garages round to the towers' back doors.
	_ground("TowerWalk", -70.0, -57.0, 40.0, -55.0, 0.045, PATH_COLOR)
	_ground("TowerWalkLink", -31.0, -55.0, -29.0, ROAD_N - ROAD_HALF, 0.045, PATH_COLOR)
	_ground("TowerWPath", -66.0, -28.3, -63.0, ROAD_N - ROAD_HALF, 0.045, PATH_COLOR)


func _entrance_u(centre: Vector2, section: int) -> float:
	var section_length := SLAB_LENGTH / SECTIONS
	return centre.x - SLAB_LENGTH * 0.5 + section_length * (section + 0.5)


# ------------------------------------------------------------ panel slabs ----

## Five-storey panel block: full-width loggias on the street (south-west) face,
## split into bays by vertical fins, with the stair entrance in the middle bay of
## every section; plain windowed back, painted ends, flat roof.
func _build_slab_block(block_name: String, centre: Vector2, palette: Dictionary, is_home := false) -> void:
	var u0 := centre.x - SLAB_LENGTH * 0.5
	var u1 := centre.x + SLAB_LENGTH * 0.5
	var front := centre.y - SLAB_DEPTH * 0.5 # fin / slab line
	var wall_n := front + LOGGIA_DEPTH # recessed wall behind the loggias
	var back := centre.y + SLAB_DEPTH * 0.5
	var top := PLINTH + 5 * FLOOR
	var bays := SECTIONS * BAYS_PER_SECTION
	var bay := SLAB_LENGTH / bays

	# Main volume (collides) with a windowed back, painted ends and a loggia wall.
	_textured_box(block_name, u0, wall_n, u1, back, 0.0, top, _facade(palette["back"], "back"))
	_collider_between(_w(u1, wall_n), _w(u0, back, top))
	# Blocks the loggia zone too, so nobody walks into the recess.
	_collider_between(_w(u1, front, 0.0), _w(u0, wall_n, PLINTH + FLOOR))
	_textured_box(block_name + "LoggiaWall", u0 + 0.05, wall_n - 0.04, u1 - 0.05, wall_n, PLINTH, top, _facade(palette["wall"], "loggia"))
	_box_un(u0 - 0.06, front, u0, back, 0.0, top + 0.5, palette["end"])
	_box_un(u1, front, u1 + 0.06, back, 0.0, top + 0.5, palette["end"])
	_blocked_un(u0, front, u1, back)

	# Stairwell windows up the back of every section.
	for section in SECTIONS:
		var eu := _entrance_u(centre, section)
		_glass_un(eu - 0.6, back, eu + 0.6, back + 0.04, PLINTH + 1.4, top - 0.6)
		_box_un(eu - 1.4, back, eu + 1.4, back + 0.9, PLINTH + 2.6, PLINTH + 2.75, ROOF) # back door canopy
		_box_un(eu - 0.8, back, eu + 0.8, back + 0.05, 0.0, PLINTH + 2.2, DOOR)

	# Roof: parapet ring, a few vents and lift rooms.
	_box_un(u0 - 0.1, front - 0.1, u1 + 0.1, back + 0.1, top, top + 0.15, ROOF)
	_box_un(u0 - 0.1, front - 0.1, u1 + 0.1, front + 0.25, top, top + 0.55, palette["fin"].darkened(0.1))
	_box_un(u0 - 0.1, back - 0.25, u1 + 0.1, back + 0.1, top, top + 0.55, palette["back"].darkened(0.2))
	for section in SECTIONS:
		var eu := _entrance_u(centre, section)
		_box_un(eu - 1.3, centre.y + 1.0, eu + 1.3, centre.y + 3.6, top, top + 1.8, palette["back"].darkened(0.08))
		_box_un(eu + 4.0, centre.y - 2.0, eu + 4.6, centre.y - 1.4, top, top + 0.9, ROOF.darkened(0.2))

	# Plinth band along the front.
	_box_un(u0, front - 0.02, u1, wall_n, 0.0, PLINTH, palette["plinth"])

	# Fins between bays, full height.
	for index in bays + 1:
		var fu := u0 + index * bay
		_box_un(fu - 0.16, front, fu + 0.16, wall_n, 0.0, top + 0.35, palette["fin"])

	# Floor slabs, railings and some glazed loggias, bay by bay.
	for index in bays:
		var bu0 := u0 + index * bay + 0.16
		var bu1 := u0 + (index + 1) * bay - 0.16
		var is_entrance := index % BAYS_PER_SECTION == 1
		for floor_index in 5:
			var y := PLINTH + floor_index * FLOOR
			if floor_index > 0 or not is_entrance:
				_box_un(bu0, front, bu1, wall_n, y - 0.2, y, Color(0.93, 0.93, 0.9))
			if floor_index == 0 and is_entrance:
				continue
			var railing_index := _pick_railing()
			var railing: Color = RAILINGS[railing_index][0]
			if railing_index == RAILINGS.size() - 1:
				# Glass railing: thin frame plus a glass pane.
				_glass_un(bu0, front + 0.02, bu1, front + 0.06, y, y + 1.05)
				_box_un(bu0, front, bu1, front + 0.08, y + 1.0, y + 1.08, Color(0.85, 0.85, 0.82))
			else:
				_box_un(bu0, front, bu1, front + 0.08, y, y + 1.05, railing)
			if _rng.randf() < 0.42:
				_glass_un(bu0, front + 0.03, bu1, front + 0.06, y + 1.08, y + FLOOR - 0.25)
				for mullion in 3:
					var mu := lerpf(bu0, bu1, (mullion + 1) / 4.0)
					_box_un(mu - 0.03, front + 0.02, mu + 0.03, front + 0.07, y + 1.05, y + FLOOR - 0.25, Color(0.9, 0.9, 0.88))
		# Top slab.
		_box_un(bu0, front, bu1, wall_n, top - 0.05, top + 0.15, Color(0.93, 0.93, 0.9))

	# Entrances: yellow vestibule wall in the middle bay of each section.
	for section in SECTIONS:
		var eu := _entrance_u(centre, section)
		var half := bay * 0.5 - 0.16
		_box_un(eu - half, front + 0.1, eu + half, wall_n, 0.0, PLINTH + FLOOR - 0.2, palette["entrance"])
		_box_un(eu - 0.75, front + 0.05, eu + 0.75, front + 0.1, PLINTH, PLINTH + 2.15, DOOR)
		_glass_un(eu - 0.62, front + 0.03, eu + 0.62, front + 0.06, PLINTH + 0.25, PLINTH + 1.95)
		_box_un(eu - 1.35, front + 0.04, eu - 0.95, front + 0.1, PLINTH + 1.8, PLINTH + 2.2, Color(0.85, 0.82, 0.7)) # bell plate
		_glass_un(eu + 1.0, front + 0.05, eu + 1.6, front + 0.08, PLINTH + 1.6, PLINTH + 2.2)
		_glass_un(eu - 1.9, front + 0.05, eu - 1.3, front + 0.08, PLINTH + 1.6, PLINTH + 2.2)
		_box_un(eu - 1.2, front - 1.2, eu + 1.2, front, 0.0, 0.18, CONCRETE) # step
		_box_un(eu - 1.2, front - 0.6, eu + 1.2, front, 0.18, PLINTH, CONCRETE)

	if is_home:
		var eu := _entrance_u(centre, 3) # Na Skalkách 939
		_add_sign("939", _w(eu + 1.3, front + 0.02, PLINTH + 2.45), 180.0, Color(0.9, 0.15, 0.12), 0.006, 48)
		_add_sign("Na Skalkách", _w(eu - 1.6, front + 0.02, PLINTH + 2.45), 180.0, Color(0.15, 0.3, 0.75), 0.004, 48)


## Index into RAILINGS by weight; the last entry is glass.
func _pick_railing() -> int:
	var roll := _rng.randf()
	for index in RAILINGS.size():
		roll -= RAILINGS[index][1]
		if roll <= 0.0:
			return index
	return 0


# ---------------------------------------------------------------- towers ----

## Twelve-storey point tower (19 x 19 m): loggia bands on the north-east and
## south-west faces, coloured blank end walls, lift room on the roof.
func _build_tower(tower_name: String, centre: Vector2, end_color: Color, shop: String) -> void:
	var half := TOWER_SIZE * 0.5
	var u0 := centre.x - half
	var u1 := centre.x + half
	var n0 := centre.y - half
	var n1 := centre.y + half
	var top := PLINTH + TOWER_FLOORS * FLOOR
	var core_n0 := n0 + 1.3
	var core_n1 := n1 - 1.3
	_textured_box(tower_name, u0, core_n0, u1, core_n1, 0.0, top, _facade(Color(0.86, 0.84, 0.78), "loggia"))
	_collider_between(_w(u1, n0), _w(u0, n1, top))
	_blocked_un(u0, n0, u1, n1)
	# Blank end walls with a darker edge strip, as on the real towers.
	for side: float in [-1.0, 1.0]:
		var eu := u0 if side < 0.0 else u1
		var outer := eu + side * 0.12
		_box_un(minf(eu, outer), n0, maxf(eu, outer), n1, 0.0, top + 0.6, end_color)
		_box_un(minf(eu, outer) - 0.02, n0, maxf(eu, outer) + 0.02, n0 + 0.6, 0.0, top + 0.6, end_color.darkened(0.25))
		_box_un(minf(eu, outer) - 0.02, n1 - 0.6, maxf(eu, outer) + 0.02, n1, 0.0, top + 0.6, end_color.darkened(0.25))
	# Loggia bands on both long faces.
	for face: float in [-1.0, 1.0]:
		var outer_n := n0 if face < 0.0 else n1
		var inner_n := core_n0 if face < 0.0 else core_n1
		var lo := minf(outer_n, inner_n)
		var hi := maxf(outer_n, inner_n)
		var rail_lo := outer_n if face < 0.0 else outer_n - 0.08
		for floor_index in TOWER_FLOORS:
			var y := PLINTH + floor_index * FLOOR
			_box_un(u0, lo, u1, hi, y - 0.2, y, Color(0.9, 0.9, 0.87))
			if floor_index == 0:
				continue
			_box_un(u0, rail_lo, u1, rail_lo + 0.08, y, y + 1.0, Color(0.5, 0.48, 0.45) if floor_index % 2 == 0 else Color(0.58, 0.55, 0.5))
			# Most loggias here are glazed with dark aluminium frames.
			_glass_un(u0 + 0.1, rail_lo + 0.01, u1 - 0.1, rail_lo + 0.05, y + 1.0, y + FLOOR - 0.22)
			for mullion in 8:
				var mu := lerpf(u0, u1, mullion / 7.0)
				_box_un(mu - 0.04, rail_lo, mu + 0.04, rail_lo + 0.07, y + 1.0, y + FLOOR - 0.2, Color(0.25, 0.25, 0.26))
		_box_un(u0, lo, u1, hi, top - 0.05, top + 0.3, Color(0.9, 0.9, 0.87))
	# Roof and lift room.
	_box_un(u0, n0, u1, n1, top, top + 0.4, ROOF)
	_box_un(centre.x - 2.5, centre.y - 2.0, centre.x + 2.5, centre.y + 2.5, top, top + 3.0, end_color.lightened(0.15))

	# Ground floor: shop window or the residents' entrance on the south-west face.
	if shop.is_empty():
		_box_un(centre.x - 1.0, n1 - 0.02, centre.x + 1.0, n1 + 0.02, PLINTH, PLINTH + 2.2, DOOR)
		_box_un(centre.x - 1.6, n1, centre.x + 1.6, n1 + 1.5, PLINTH + 2.5, PLINTH + 2.65, ROOF)
		_box_un(centre.x - 1.6, n1, centre.x + 1.6, n1 + 1.5, 0.0, PLINTH, CONCRETE)
	else:
		_glass_un(u0 + 1.5, n0 - 0.04, centre.x + 3.0, n0, PLINTH + 0.2, PLINTH + 2.5)
		_box_un(centre.x + 3.5, n0 - 0.04, centre.x + 5.0, n0, PLINTH, PLINTH + 2.2, Color(0.45, 0.28, 0.18))
		_add_sign(shop, _w(centre.x - 2.5, n0 - 0.06, PLINTH + 2.75), 180.0, Color(0.95, 0.95, 0.92), 0.006, 48)
		# Wheelchair ramp with a railing up to the shop door.
		_box_un(centre.x + 5.2, n0 - 4.5, centre.x + 6.4, n0, 0.0, PLINTH * 0.6, Color(0.2, 0.2, 0.2))
		_box_un(centre.x + 6.4, n0 - 4.5, centre.x + 6.47, n0, 0.0, 1.0, Color(0.6, 0.62, 0.62))
		_box_un(centre.x - 1.6, n1 - 0.02, centre.x + 0.4, n1 + 0.02, PLINTH, PLINTH + 2.2, DOOR)


# --------------------------------------------------------------- garages ----

## Old garage row across the street from the home block: concrete frame, flat
## slab roof, dark corrugated steel doors (a few green, a few barred).
func _build_garages() -> void:
	# The street is on the +n side: `front` is the face towards it, `back` towards tower S.
	var u0 := -20.0
	var count := 16
	var width := 3.0
	var front := -23.4
	var back := -28.9
	var height := 2.45
	var u1 := u0 + count * width
	var body_front := front - 0.3 # doors are set in front of the body
	_box_un(u0, back, u1, body_front, 0.0, height, Color(0.66, 0.66, 0.63))
	_collider_between(_w(u1, back), _w(u0, front, height))
	_blocked_un(u0, back, u1, front)
	_box_un(u0 - 0.2, back - 0.1, u1 + 0.2, front + 0.35, height, height + 0.22, Color(0.58, 0.58, 0.55)) # roof slab
	_box_un(u0 - 0.2, front + 0.15, u1 + 0.2, front + 0.35, height - 0.05, height + 0.3, Color(0.45, 0.42, 0.38)) # roof edge
	for index in count + 1:
		var pu := u0 + index * width
		_box_un(pu - 0.18, body_front, pu + 0.18, front + 0.05, 0.0, height, Color(0.72, 0.71, 0.68))
	for index in count:
		var du0 := u0 + index * width + 0.18
		var du1 := du0 + width - 0.36
		var roll := _rng.randf()
		var door := Color(0.2, 0.15, 0.12) if roll < 0.55 else (Color(0.12, 0.12, 0.13) if roll < 0.82 else Color(0.2, 0.38, 0.26))
		_box_un(du0, body_front, du1, body_front + 0.08, 0.0, height - 0.12, door)
		var ribs := 10 if roll < 0.82 else 6 # barred doors have fewer, chunkier bars
		for rib in ribs:
			var ru := lerpf(du0 + 0.1, du1 - 0.1, rib / float(ribs - 1))
			_box_un(ru - 0.025, body_front + 0.08, ru + 0.025, body_front + 0.12, 0.05, height - 0.2, door.lightened(0.18))
		var mid := lerpf(du0, du1, 0.5)
		_box_un(mid - 0.05, body_front + 0.12, mid + 0.05, body_front + 0.15, 1.0, 1.2, Color(0.75, 0.75, 0.72)) # handle


func _build_bins() -> void:
	# Concrete U-pen by the street at the north-west end of the garages: two grey 1100 l bins and a blue one.
	var pen_u := -24.5
	var pen_n := -24.2
	_wall_un(pen_u - 3.2, pen_n - 2.6, pen_u - 3.0, pen_n + 0.1, 1.5, CONCRETE)
	_wall_un(pen_u + 3.0, pen_n - 2.6, pen_u + 3.2, pen_n + 0.1, 1.5, CONCRETE)
	_wall_un(pen_u - 3.2, pen_n - 2.8, pen_u + 3.2, pen_n - 2.6, 1.5, CONCRETE)
	_bin(pen_u - 1.9, pen_n - 1.6, Color(0.42, 0.44, 0.45), true)
	_bin(pen_u - 0.3, pen_n - 1.6, Color(0.42, 0.44, 0.45), true)
	_bin(pen_u + 1.6, pen_n - 1.5, Color(0.15, 0.35, 0.75), false)
	# Mesh-fenced pen behind tower S: green, blue and yellow sorting bins.
	var mesh_u := -9.0
	var mesh_n := -53.0
	var fence := Color(0.62, 0.64, 0.64)
	_wall_un(mesh_u - 4.0, mesh_n - 1.6, mesh_u + 4.0, mesh_n - 1.55, 1.6, fence)
	_wall_un(mesh_u - 4.0, mesh_n - 1.6, mesh_u - 3.95, mesh_n + 1.6, 1.6, fence)
	_wall_un(mesh_u + 3.95, mesh_n - 1.6, mesh_u + 4.0, mesh_n + 1.6, 1.6, fence)
	_bin(mesh_u - 2.6, mesh_n, Color(0.18, 0.45, 0.22), true)
	_bin(mesh_u - 0.9, mesh_n, Color(0.15, 0.35, 0.75), true)
	_bin(mesh_u + 0.8, mesh_n, Color(0.9, 0.78, 0.15), true)
	_bin(mesh_u + 2.5, mesh_n, Color(0.42, 0.44, 0.45), true)
	# Sorting bins at the foot of tower W and a single green bin by tower S's path.
	_bin(-61.0, -25.0, Color(0.42, 0.44, 0.45), true)
	_bin(-59.4, -25.0, Color(0.15, 0.35, 0.75), true)
	_bin(-57.8, -25.0, Color(0.9, 0.78, 0.15), true)
	_bin(-32.6, -58.2, Color(0.18, 0.45, 0.22), false)


## A wheelie bin: large (1100 l, with a curved lid) or small (240 l).
func _bin(u: float, n: float, color: Color, large: bool) -> void:
	var w := 1.35 if large else 0.6
	var d := 1.05 if large else 0.7
	var h := 1.25 if large else 1.05
	_box_un(u - w * 0.5, n - d * 0.5, u + w * 0.5, n + d * 0.5, 0.15, h, color)
	_box_un(u - w * 0.52, n - d * 0.55, u + w * 0.52, n + d * 0.52, h, h + 0.1, color.darkened(0.2))
	_box_un(u - w * 0.45, n - d * 0.4, u - w * 0.3, n - d * 0.25, 0.0, 0.15, Color(0.08, 0.08, 0.08))
	_box_un(u + w * 0.3, n - d * 0.4, u + w * 0.45, n - d * 0.25, 0.0, 0.15, Color(0.08, 0.08, 0.08))
	_collider_between(_w(u + w * 0.5, n - d * 0.5), _w(u - w * 0.5, n + d * 0.5, h))


# --------------------------------------------------------- other places ----

func _build_other_buildings() -> void:
	# Big white commercial building east of the blocks (AlzaBox, Restaurace Skleník).
	var c := Vector2(88.0, 50.0)
	_textured_box("CommercialHall", c.x - 20.0, c.y - 20.0, c.x + 20.0, c.y + 20.0, 0.0, 7.5, _facade(Color(0.96, 0.96, 0.95), "shop"))
	_collider_between(_w(c.x + 20.0, c.y - 20.0), _w(c.x - 20.0, c.y + 20.0, 7.5))
	_blocked_un(c.x - 20.0, c.y - 20.0, c.x + 20.0, c.y + 20.0)
	_box_un(c.x - 20.3, c.y - 20.3, c.x + 20.3, c.y + 20.3, 7.5, 7.9, Color(0.85, 0.85, 0.84))
	_glass_un(c.x - 20.06, c.y - 16.0, c.x - 20.0, c.y + 4.0, 0.3, 3.2)
	_box_un(c.x - 22.0, c.y - 16.0, c.x - 20.0, c.y + 4.0, 3.3, 3.5, Color(0.2, 0.42, 0.26)) # canopy
	_add_sign("RESTAURACE SKLENÍK", _w(c.x - 20.08, c.y - 6.0, 4.6), 90.0, Color(0.2, 0.5, 0.25), 0.012, 64)
	_box_un(c.x - 20.6, c.y + 6.0, c.x - 20.0, c.y + 9.0, 0.0, 2.0, Color(0.36, 0.7, 0.18)) # AlzaBox locker
	_add_sign("AlzaBox", _w(c.x - 20.62, c.y + 7.5, 2.25), 90.0, Color(0.36, 0.7, 0.18), 0.006, 48)

	# Low shop with a purple hipped roof south-west of the towers.
	var p := Vector2(-36.0, -79.0)
	_textured_box("PurpleRoofShop", p.x - 8.0, p.y - 6.0, p.x + 8.0, p.y + 6.0, 0.0, 3.6, _facade(Color(0.95, 0.93, 0.88), "shop"))
	_collider_between(_w(p.x + 8.0, p.y - 6.0), _w(p.x - 8.0, p.y + 6.0, 3.6))
	_blocked_un(p.x - 8.0, p.y - 6.0, p.x + 8.0, p.y + 6.0)
	var roof := MeshInstance3D.new()
	roof.name = "PurpleRoof"
	var prism := PrismMesh.new()
	prism.size = Vector3(13.2, 2.6, 16.8)
	roof.mesh = prism
	roof.material_override = _plain(Color(0.44, 0.3, 0.52))
	roof.position = _w(p.x, p.y, 3.6 + 1.3)
	roof.rotation_degrees.y = 90.0
	add_child(roof)
	_add_sign("SPODNÍ PRÁDLO", _w(p.x, p.y + 6.05, 2.9), 0.0, Color(0.44, 0.3, 0.52), 0.008, 48)

	# Old concrete shelter entrance on the grass south-east of the home block.
	var mound := MeshInstance3D.new()
	mound.name = "GrassMound"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	mound.mesh = sphere
	mound.material_override = _plain(Color(0.3, 0.5, 0.22))
	mound.scale = Vector3(2.6, 1.3, 3.2)
	mound.position = _w(51.6, -5.0, -0.3)
	add_child(mound)
	_box_un(50.0, -9.8, 53.0, -7.3, 0.0, 1.9, CONCRETE.darkened(0.08))
	_box_un(49.9, -9.9, 53.1, -7.2, 1.9, 2.05, CONCRETE.darkened(0.2))
	_collider_between(_w(53.0, -9.8), _w(50.0, -7.3, 1.9))


func _build_playground() -> void:
	# Dětské hřiště Na Skalkách, east of the home block's south-east end.
	var c := Vector2(75.0, 2.0)
	var fence := Color(0.25, 0.45, 0.3)
	_ground("PlaygroundSurface", c.x - 9.0, c.y - 8.0, c.x + 9.0, c.y + 8.0, 0.03, Color(0.72, 0.42, 0.32))
	_wall_un(c.x - 9.0, c.y - 8.0, c.x + 9.0, c.y - 7.95, 0.9, fence)
	_wall_un(c.x - 9.0, c.y + 7.95, c.x + 9.0, c.y + 8.0, 0.9, fence)
	_wall_un(c.x + 8.95, c.y - 8.0, c.x + 9.0, c.y + 8.0, 0.9, fence)
	_wall_un(c.x - 9.0, c.y - 8.0, c.x - 8.95, c.y + 4.0, 0.9, fence)
	# Sandpit.
	_box_un(c.x - 7.5, c.y + 2.0, c.x - 3.0, c.y + 6.5, 0.0, 0.3, Color(0.55, 0.38, 0.22))
	_box_un(c.x - 7.2, c.y + 2.3, c.x - 3.3, c.y + 6.2, 0.0, 0.32, Color(0.88, 0.8, 0.6))
	# Swing frame with two seats.
	var wood := Color(0.55, 0.36, 0.2)
	for su in [c.x + 1.0, c.x + 5.0]:
		_box_un(su - 0.08, c.y + 3.0, su + 0.08, c.y + 3.2, 0.0, 2.4, wood)
		_box_un(su - 0.08, c.y + 5.6, su + 0.08, c.y + 5.8, 0.0, 2.4, wood)
	_box_un(c.x + 0.9, c.y + 3.0, c.x + 5.1, c.y + 5.8, 2.4, 2.55, wood)
	for seat_u in [c.x + 2.2, c.x + 3.8]:
		_box_un(seat_u - 0.02, c.y + 4.35, seat_u + 0.02, c.y + 4.45, 0.55, 2.4, Color(0.3, 0.3, 0.3))
		_box_un(seat_u - 0.3, c.y + 4.2, seat_u + 0.3, c.y + 4.6, 0.5, 0.56, Color(0.85, 0.2, 0.15))
	# Climbing tower with a slide.
	_box_un(c.x - 1.0, c.y - 6.0, c.x + 2.0, c.y - 3.0, 1.5, 1.65, wood)
	for corner in [[-1.0, -6.0], [2.0, -6.0], [-1.0, -3.0], [2.0, -3.0]]:
		_box_un(c.x + corner[0] - 0.08, c.y + corner[1] - 0.08, c.x + corner[0] + 0.08, c.y + corner[1] + 0.08, 0.0, 3.0, wood)
	_box_un(c.x - 1.1, c.y - 6.1, c.x + 2.1, c.y - 2.9, 3.0, 3.2, Color(0.2, 0.5, 0.8)) # roof
	var slide := MeshInstance3D.new()
	slide.name = "Slide"
	var slide_mesh := BoxMesh.new()
	slide_mesh.size = Vector3(0.7, 0.08, 3.2)
	slide.mesh = slide_mesh
	slide.material_override = _plain(Color(0.95, 0.75, 0.15))
	slide.position = _w(c.x + 3.4, c.y - 4.5, 0.85)
	slide.rotation_degrees = Vector3(0, 90, 28)
	add_child(slide)
	_collider_between(_w(c.x + 2.0, c.y - 6.0), _w(c.x - 1.0, c.y - 3.0, 1.65))
	# Benches round the edge.
	_bench(c.x - 6.0, c.y - 6.6, 0.0)
	_bench(c.x + 6.0, c.y + 6.6, 180.0)


func _build_street_furniture() -> void:
	# Street lamps on the lawn side of Na Skalkách and along Za Jednotou.
	for u in [-52.0, -27.0, -2.0, 23.0, 40.0]:
		_lamp(u + 7.0, -11.0, -1.0)
	for u in [-50.0, -20.0, 10.0, 40.0]:
		_lamp(u, ZA_JEDNOTOU_N - 3.8, 1.0)
	_lamp(BRANCH_U - 3.6, -50.0, -1.0)
	_lamp(BRANCH_U - 3.6, -80.0, -1.0)
	# Blue parking signs (P, wheelchair bay) at the north-west end and by tower S.
	_parking_sign(-60.0, -11.2)
	_parking_sign(-33.0, -24.0)
	_parking_sign(BRANCH_U + 3.4, -30.0)
	# Red pipe railing round the spruce grove at the junction.
	var red := Color(0.78, 0.15, 0.12)
	_box_un(30.5, -24.2, BRANCH_U - 3.2, -24.1, 0.85, 0.92, red)
	_box_un(BRANCH_U - 3.25, -46.0, BRANCH_U - 3.15, -24.1, 0.85, 0.92, red)
	for u in range(31, int(BRANCH_U - 3.0), 3):
		_box_un(u - 0.03, -24.18, u + 0.03, -24.12, 0.0, 0.9, red)
	for n in range(-45, -24, 3):
		_box_un(BRANCH_U - 3.23, n - 0.03, BRANCH_U - 3.17, n + 0.03, 0.0, 0.9, red)
	# Benches in the yard between the blocks.
	for u in [-40.0, -5.0, 30.0]:
		_bench(u, 21.6, 180.0)


## Street lamp whose arm reaches over the road on the `side` (-1 or +1 along n).
func _lamp(u: float, n: float, side: float) -> void:
	var pole := Color(0.55, 0.57, 0.58)
	_box_un(u - 0.09, n - 0.09, u + 0.09, n + 0.09, 0.0, 6.5, pole)
	_box_un(u - 0.14, n - 0.14, u + 0.14, n + 0.14, 0.0, 0.9, Color(0.82, 0.8, 0.72)) # concrete foot
	_box_un(u - 0.05, n, u + 0.05, n + 1.1 * side, 6.4, 6.5, pole)
	_box_un(u - 0.18, n + 0.9 * side, u + 0.18, n + 1.5 * side, 6.3, 6.45, Color(0.3, 0.32, 0.34))
	_glass_un(u - 0.15, n + 0.95 * side, u + 0.15, n + 1.45 * side, 6.26, 6.3)
	_collider_between(_w(u + 0.14, n - 0.14), _w(u - 0.14, n + 0.14, 6.5))


func _parking_sign(u: float, n: float) -> void:
	_box_un(u - 0.04, n - 0.04, u + 0.04, n + 0.04, 0.0, 2.6, Color(0.6, 0.62, 0.62))
	_box_un(u - 0.3, n - 0.06, u + 0.3, n - 0.04, 2.0, 2.6, Color(0.1, 0.35, 0.75))
	_add_sign("P", _w(u, n - 0.07, 2.32), 180.0, Color(1, 1, 1), 0.007, 64)
	_box_un(u - 0.3, n - 0.06, u + 0.3, n - 0.04, 1.6, 1.95, Color(0.95, 0.95, 0.95))


func _bench(u: float, n: float, yaw: float) -> void:
	var facing := 1.0 if yaw == 0.0 else -1.0
	_box_un(u - 0.9, n - 0.22, u + 0.9, n + 0.22, 0.42, 0.48, Color(0.5, 0.32, 0.18))
	_box_un(u - 0.9, n + 0.2 * facing - 0.04, u + 0.9, n + 0.2 * facing + 0.04, 0.5, 0.9, Color(0.5, 0.32, 0.18))
	for leg in [-0.75, 0.75]:
		_box_un(u + leg - 0.04, n - 0.2, u + leg + 0.04, n + 0.2, 0.0, 0.42, Color(0.2, 0.2, 0.2))


func _build_parking() -> void:
	# Cars along the home block, nose to tail on the paver strip, with gaps at the entrance paths.
	var entrances: Array[float] = []
	for section in SECTIONS:
		entrances.append(_entrance_u(HOME_CENTRE, section))
	var u := -60.0
	while u < 44.0:
		var clear := true
		for eu in entrances:
			if absf(u - eu) < 3.4:
				clear = false
		if clear and _rng.randf() < 0.85:
			_car_spots.append(_car_transform(u, -14.85, 90.0))
		u += 5.2
	# Za Jednotou: cars along the north kerb.
	u = -56.0
	while u < 48.0:
		var clear := true
		for section in SECTIONS:
			if absf(u - _entrance_u(NORTH_CENTRE, section)) < 3.4:
				clear = false
		if clear and _rng.randf() < 0.75:
			_car_spots.append(_car_transform(u, ZA_JEDNOTOU_N + 3.9, 90.0))
		u += 5.3
	# Along the branch towards the south and in front of tower W.
	for n in [-34.0, -39.5, -45.0, -62.0, -67.5]:
		if _rng.randf() < 0.8:
			_car_spots.append(_car_transform(BRANCH_U + 3.7, n, 0.0))
	for cu in [-74.0, -68.5, -52.0]:
		_car_spots.append(_car_transform(cu, -23.2, 90.0))


func _car_transform(u: float, n: float, yaw_degrees: float) -> Transform3D:
	var jitter := Vector3(_rng.randf_range(-0.2, 0.2), 0.0, _rng.randf_range(-0.12, 0.12))
	var flip := 180.0 if _rng.randf() < 0.5 else 0.0
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees + flip + _rng.randf_range(-2.0, 2.0))), _w(u, n) + jitter)


# ------------------------------------------------------------------ trees ----

func _build_trees() -> void:
	# Hand-placed from Street View: big pines on the home lawn, a thuja by 939's
	# door, the spruce grove at the junction, willows at the south-east end.
	for spot in [[-44.0, -8.0], [-36.0, -9.5], [-22.0, -8.5], [-10.0, -9.0], [12.0, -8.5], [30.0, -9.0], [-55.0, -7.0], [-61.0, -8.5]]:
		_trees.append(["pine", _w(spot[0], spot[1]), _rng.randf_range(0.9, 1.15)])
	_trees.append(["thuja", _w(_entrance_u(HOME_CENTRE, 3) + 5.5, -6.5), 1.0])
	_trees.append(["thuja", _w(_entrance_u(HOME_CENTRE, 1) + 5.5, -6.0), 0.85])
	for spot in [[33.0, -28.0], [37.0, -31.0], [33.5, -35.0], [38.5, -38.0], [34.0, -42.0], [39.0, -44.0], [36.0, -26.5]]:
		_trees.append(["spruce", _w(spot[0], spot[1]), _rng.randf_range(0.9, 1.2)])
	for spot in [[52.0, -14.5], [58.5, -12.0], [59.0, 14.0]]:
		_trees.append(["willow", _w(spot[0], spot[1]), _rng.randf_range(0.95, 1.15)])
	for spot in [[-70.0, -15.0], [-78.0, -30.0], [-48.0, -48.0], [20.0, -60.0], [52.0, -62.0], [-36.0, -40.0]]:
		_trees.append(["spruce", _w(spot[0], spot[1]), _rng.randf_range(0.8, 1.1)])

	# Deciduous trees scattered over the lawns and the yards between the blocks.
	var attempts := 0
	var placed := 0
	while placed < 120 and attempts < 5000:
		attempts += 1
		var u := _rng.randf_range(-105.0, 105.0)
		var n := _rng.randf_range(-95.0, 92.0)
		var point := Vector2(_w(u, n).x, n)
		if _is_blocked(point, 2.5):
			continue
		var too_close := false
		for tree in _trees:
			if (tree[1] as Vector3).distance_squared_to(Vector3(point.x, 0, point.y)) < 5.5 * 5.5:
				too_close = true
				break
		if too_close:
			continue
		_trees.append(["leafy", Vector3(point.x, 0, point.y), _rng.randf_range(0.8, 1.35)])
		placed += 1

	var parts := {} # mesh key -> [transforms, colours]
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.3
	trunk_shape.height = 3.0
	for tree in _trees:
		var kind: String = tree[0]
		var base: Vector3 = tree[1]
		var s: float = tree[2]
		var dark := Color.from_hsv(_rng.randf_range(0.28, 0.36), _rng.randf_range(0.45, 0.6), _rng.randf_range(0.2, 0.3))
		match kind:
			"pine": # tall bare trunk, flat dark crown on top
				_part(parts, "trunk", Vector3(1.2, 3.0, 1.2) * s, base + Vector3(0, 4.5 * s, 0), Color(0.42, 0.28, 0.2))
				_part(parts, "sphere", Vector3(3.4, 1.5, 3.0) * s, base + Vector3(0, 9.6 * s, 0), dark)
				_part(parts, "sphere", Vector3(2.4, 1.2, 2.6) * s, base + Vector3(1.2, 8.3, -0.6) * s, dark.lightened(0.05))
				_part(parts, "sphere", Vector3(2.0, 1.1, 2.2) * s, base + Vector3(-1.1, 7.6, 0.8) * s, dark.darkened(0.05))
			"spruce":
				_part(parts, "trunk", Vector3(1.0, 0.7, 1.0) * s, base + Vector3(0, 1.0 * s, 0), Color(0.35, 0.24, 0.17))
				_part(parts, "cone", Vector3(3.2, 3.2, 3.2) * s, base + Vector3(0, 4.2 * s, 0), dark)
				_part(parts, "cone", Vector3(2.5, 2.8, 2.5) * s, base + Vector3(0, 7.6 * s, 0), dark)
				_part(parts, "cone", Vector3(1.7, 2.4, 1.7) * s, base + Vector3(0, 10.6 * s, 0), dark.lightened(0.04))
			"thuja":
				_part(parts, "cone", Vector3(1.6, 4.6, 1.6) * s, base + Vector3(0, 4.6 * s, 0), Color(0.16, 0.33, 0.17))
			"willow":
				var light := Color.from_hsv(0.22, 0.45, 0.55)
				_part(parts, "trunk", Vector3(1.4, 1.5, 1.4) * s, base + Vector3(0, 2.2 * s, 0), Color(0.45, 0.38, 0.3))
				_part(parts, "sphere", Vector3(4.2, 4.4, 4.2) * s, base + Vector3(0, 6.6 * s, 0), light)
			_:
				var green := Color.from_hsv(_rng.randf_range(0.22, 0.32), _rng.randf_range(0.45, 0.65), _rng.randf_range(0.32, 0.5))
				_part(parts, "trunk", Vector3.ONE * s, base + Vector3(0, 1.5 * s, 0), Color(0.33, 0.23, 0.15))
				_part(parts, "sphere", Vector3(2.3, 2.0, 2.3) * s, base + Vector3(0, 4.3 * s, 0), green)
				_part(parts, "sphere", Vector3(1.6, 1.4, 1.6) * s, base + Vector3(0.9, 5.4, -0.6) * s, green.lightened(0.08))
		if kind != "thuja":
			var shape_node := CollisionShape3D.new()
			shape_node.shape = trunk_shape
			shape_node.position = base + Vector3(0, 1.5, 0)
			_collision.add_child(shape_node)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 3.0
	trunk_mesh.radial_segments = 7
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	sphere_mesh.radial_segments = 10
	sphere_mesh.rings = 6
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 1.0
	cone_mesh.height = 2.0
	cone_mesh.radial_segments = 9
	var meshes := {"trunk": trunk_mesh, "sphere": sphere_mesh, "cone": cone_mesh}
	for key in parts:
		var mesh: PrimitiveMesh = meshes[key]
		mesh.material = _vertex_material()
		_add_multimesh("Tree_" + key, mesh, parts[key][0], parts[key][1])


func _part(parts: Dictionary, key: String, part_scale: Vector3, at: Vector3, color: Color) -> void:
	if not parts.has(key):
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		parts[key] = [transforms, colors]
	parts[key][0].append(Transform3D(Basis().scaled(part_scale), at))
	parts[key][1].append(color)


# ------------------------------------------------------------------- cars ----

## One MultiMesh per car model; the per-instance colour repaints only the Paint surface.
func _spawn_cars() -> void:
	var per_model: Array = []
	for model in CAR_MODELS:
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		per_model.append([transforms, colors])
	var shapes := {}
	for spot in _car_spots:
		var model := _weighted_pick(CAR_MODELS)
		per_model[model][0].append(spot)
		per_model[model][1].append(CAR_COLORS[_weighted_pick(CAR_COLORS)][0])
		var size: Vector3 = CAR_MODELS[model][2]
		if not shapes.has(model):
			var shape := BoxShape3D.new()
			shape.size = Vector3(size.x, size.y - 0.15, size.z - 0.1)
			shapes[model] = shape
		var shape_node := CollisionShape3D.new()
		shape_node.shape = shapes[model]
		shape_node.transform = spot * Transform3D(Basis(), Vector3(0, size.y * 0.5 + 0.07, 0))
		_collision.add_child(shape_node)
	for model in CAR_MODELS.size():
		if per_model[model][0].is_empty():
			continue
		var mesh := _car_mesh(CAR_MODELS[model][0])
		if mesh != null:
			_add_multimesh("Cars_" + str(CAR_MODELS[model][0]).get_file().get_basename(), mesh, per_model[model][0], per_model[model][1])


func _weighted_pick(table: Array) -> int:
	var roll := _rng.randf()
	for index in table.size():
		roll -= float(table[index][1])
		if roll <= 0.0:
			return index
	return 0


## The car's joined mesh from its .glb, with the "Paint" surface switched to an instance-coloured paint.
func _car_mesh(path: String) -> Mesh:
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("Missing car model %s" % path)
		return null
	var root := scene.instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = null
	if not found.is_empty():
		mesh = ((found[0] as MeshInstance3D).mesh as Mesh).duplicate()
	root.free()
	if mesh == null:
		return null
	if not _materials.has("car_paint"):
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color.WHITE
		paint.vertex_color_use_as_albedo = true
		paint.vertex_color_is_srgb = true
		paint.metallic = 0.45
		paint.roughness = 0.28
		_materials["car_paint"] = paint
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		if material != null and material.resource_name == "Paint" and mesh is ArrayMesh:
			(mesh as ArrayMesh).surface_set_material(surface, _materials["car_paint"])
	return mesh


# ---------------------------------------------------------------- helpers ----

## Paved surface between two (u, n) corners: no collider, top just above the grass
## (a few millimetres per layer so crossings don't z-fight).
func _ground(_name: String, u0: float, n0: float, u1: float, n1: float, top: float, color: Color, block := true) -> void:
	_box_un(u0, n0, u1, n1, top - 0.1, top, color)
	if block:
		_blocked_un(u0, n0, u1, n1)


## Thin solid wall between two (u, n) corners, with a collider.
func _wall_un(u0: float, n0: float, u1: float, n1: float, height: float, color: Color) -> void:
	_box_un(u0, n0, u1, n1, 0.0, height, color)
	_collider_between(_w(maxf(u0, u1), minf(n0, n1)), _w(minf(u0, u1), maxf(n0, n1), height))
	_blocked_un(u0, n0, u1, n1)


## Axis-aligned vertex-coloured box between (u, n, y) corners, merged into the detail mesh.
func _box_un(u0: float, n0: float, u1: float, n1: float, y0: float, y1: float, color: Color) -> void:
	_add_box(_solid, _w(u0, n0, y0), _w(u1, n1, y1), color)


func _glass_un(u0: float, n0: float, u1: float, n1: float, y0: float, y1: float) -> void:
	_add_box(_glass, _w(u0, n0, y0), _w(u1, n1, y1), GLASS)


func _blocked_un(u0: float, n0: float, u1: float, n1: float) -> void:
	var a := _w(u0, n0)
	var b := _w(u1, n1)
	_blocked.append(Rect2(minf(a.x, b.x), minf(a.z, b.z), absf(a.x - b.x), absf(a.z - b.z)))


func _is_blocked(point: Vector2, margin: float) -> bool:
	for rect in _blocked:
		if rect.grow(margin).has_point(point):
			return true
	return false


## Box between two opposite corners into a SurfaceTool (clockwise front faces, outward normals).
func _add_box(st: SurfaceTool, a: Vector3, b: Vector3, color: Color) -> void:
	var lo := a.min(b)
	var hi := a.max(b)
	if hi.x - lo.x < 0.001 or hi.y - lo.y < 0.001 or hi.z - lo.z < 0.001:
		return
	var c := (lo + hi) * 0.5
	var h := (hi - lo) * 0.5
	st.set_color(color)
	for face in [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]:
		var normal: Vector3 = face[0]
		var t1: Vector3 = face[1] * h
		var t2: Vector3 = face[2] * h
		var centre: Vector3 = c + normal * h
		var p0 := centre - t1 - t2
		var p1 := centre + t1 - t2
		var p2 := centre + t1 + t2
		var p3 := centre - t1 + t2
		st.set_normal(normal)
		for p in [p0, p2, p1, p0, p3, p2]:
			st.add_vertex(p)


func _commit(st: SurfaceTool, node_name: String, material: Material) -> void:
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)


func _collider_between(a: Vector3, b: Vector3) -> void:
	var lo := a.min(b)
	var hi := a.max(b)
	var shape := BoxShape3D.new()
	shape.size = hi - lo
	var shape_node := CollisionShape3D.new()
	shape_node.shape = shape
	shape_node.position = (lo + hi) * 0.5
	_collision.add_child(shape_node)


## Box with a world-mapped facade texture (its own MeshInstance), between (u, n, y) corners.
func _textured_box(node_name: String, u0: float, n0: float, u1: float, n1: float, y0: float, y1: float, material: Material) -> void:
	var lo := _w(u0, n0, y0).min(_w(u1, n1, y1))
	var hi := _w(u0, n0, y0).max(_w(u1, n1, y1))
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = hi - lo
	instance.mesh = mesh
	instance.material_override = material
	instance.position = (lo + hi) * 0.5
	add_child(instance)


func _add_sign(text: String, at: Vector3, yaw: float, color: Color, pixel_size: float, font_size: int) -> void:
	var label := Label3D.new()
	label.name = "Sign"
	label.text = text
	label.position = at
	label.rotation_degrees.y = yaw # 180 faces -Z (the street side)
	label.pixel_size = pixel_size
	label.font_size = font_size
	label.outline_size = 10
	label.modulate = color
	label.outline_modulate = Color(0.1, 0.1, 0.1) if color.get_luminance() > 0.6 else Color(1, 1, 1)
	label.double_sided = false
	add_child(label)


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


func _vertex_material() -> StandardMaterial3D:
	if not _materials.has("vertex"):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 0.88
		_materials["vertex"] = material
	return _materials["vertex"]


func _glass_material() -> StandardMaterial3D:
	if not _materials.has("glass"):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 0.12
		material.metallic = 0.35
		material.metallic_specular = 0.8
		_materials["glass"] = material
	return _materials["glass"]


## World-mapped facade: one texture tile = 3 m x FLOOR, so split boxes line up.
## "back": windows; "loggia": balcony door + window; "shop": tall shop windows.
func _facade(tint: Color, kind: String) -> StandardMaterial3D:
	var key := "facade_%s_%s" % [kind, tint.to_html()]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.albedo_texture = _facade_texture(kind)
		material.roughness = 0.85
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_triplanar_sharpness = 8.0
		material.uv1_scale = Vector3(1.0 / 3.0, 1.0 / FLOOR, 1.0 / 3.0)
		material.uv1_offset = Vector3(0.0, -PLINTH / FLOOR, 0.0)
		_materials[key] = material
	return _materials[key]


func _facade_texture(kind: String) -> Texture2D:
	var key := "tex_" + kind
	if _materials.has(key):
		return _materials[key]
	# Triplanar flips V, so texture row 63 sits at floor level and row 0 at the ceiling.
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.97, 0.97, 0.96))
	var frame := Color(1, 1, 1)
	var glass := Color(0.22, 0.27, 0.32)
	var sky := Color(0.36, 0.42, 0.48)
	match kind:
		"loggia":
			image.fill_rect(Rect2i(0, 60, 64, 4), Color(0.86, 0.86, 0.84))
			image.fill_rect(Rect2i(6, 10, 20, 52), frame) # balcony door
			image.fill_rect(Rect2i(8, 12, 16, 50), glass)
			image.fill_rect(Rect2i(8, 12, 16, 8), sky)
			image.fill_rect(Rect2i(32, 14, 28, 26), frame) # window
			image.fill_rect(Rect2i(34, 16, 24, 22), glass)
			image.fill_rect(Rect2i(34, 16, 24, 5), sky)
			image.fill_rect(Rect2i(45, 16, 2, 22), frame)
		"shop":
			image.fill_rect(Rect2i(0, 0, 64, 64), Color(0.95, 0.95, 0.94))
			image.fill_rect(Rect2i(4, 14, 56, 46), Color(0.85, 0.85, 0.84))
			image.fill_rect(Rect2i(6, 16, 52, 44), glass)
			image.fill_rect(Rect2i(6, 16, 52, 8), sky)
		_:
			image.fill_rect(Rect2i(0, 61, 64, 3), Color(0.8, 0.8, 0.79)) # floor seam
			image.fill_rect(Rect2i(0, 0, 1, 64), Color(0.86, 0.86, 0.85)) # panel seam
			image.fill_rect(Rect2i(13, 17, 38, 30), frame)
			image.fill_rect(Rect2i(15, 19, 34, 26), glass)
			image.fill_rect(Rect2i(15, 19, 34, 6), sky)
			image.fill_rect(Rect2i(31, 19, 2, 26), frame)
			image.fill_rect(Rect2i(11, 47, 42, 2), Color(0.7, 0.7, 0.7))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_materials[key] = texture
	return texture
