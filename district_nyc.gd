extends "res://nyc_builder.gd"
## Times Square, New York: the blocks from West 41st to West 48th Street between
## 6th and 8th Avenue, about 300 m round the "bowtie" where Broadway crosses 7th
## Avenue, cut out of Manhattan and set adrift as an island in the ocean.
##
## Every building is extruded from its OpenStreetMap footprint and height
## (assets/nyc/times_square.json, made by tools/nyc/osm_to_json.py); setbacks come
## from the building parts. On top of that, from the map and Street View: the
## streets with their real widths and one-way directions, the pedestrian plazas
## of the bowtie, the LED screens wrapped round the buildings that face the
## square, the One Times Square tower with its ball and news ticker, the red
## TKTS steps, the Cohan and Father Duffy statues, the NYPD station and the
## neon-flag recruiting booth, the Broadway theatres with marquees and blade
## signs, subway entrances, traffic lights, steam stacks, water towers on the
## roofs and the construction site of The Torch on 8th Avenue. The boundary
## streets (48th, 41st, 8th and 6th) run along a waterfront promenade.
##
## Frame (district_omsk.gd): u = metres east across the avenues = game +X,
## n = metres south down the avenues = game +Z; origin where 7th Avenue crosses
## West 45th Street. The real grid is turned 29 degrees; here it is square.

const DATA_PATH := "res://assets/nyc/times_square.json"

## Street centre lines (n) and roadway half widths, measured from the building lines.
const STREETS := [[48, -231.5], [47, -153.3], [46, -73.8], [45, 5.0], [44, 84.8], [43, 163.8], [42, 249.2], [41, 333.0]]
const STREET_HALF := 5.2
const WIDE_HALF := 8.5 # 42nd Street
## Avenue centre lines (u).
const AVE_8 := -275.1
const AVE_7 := -1.2
const AVE_6 := 271.8
## The island: its edge (the sea wall) and the corner radius.
const EDGE_W := -298.0
const EDGE_E := 296.0
const EDGE_N := -250.0
const EDGE_S := 352.0
const EDGE_CORNER := 22.0
const SEA_LEVEL := -2.2
## Roadway extents: streets run between the outer kerbs of 8th and 6th Avenue,
## avenues between the outer kerbs of 48th and 41st Street.
const CARRIAGE_W := -284.6
const CARRIAGE_E := 282.3
const CARRIAGE_N := -236.7
const CARRIAGE_S := 338.2

const SIDEWALK := Color(0.72, 0.71, 0.68)
const PLAZA := Color(0.32, 0.33, 0.35)
const ASPHALT := Color(0.3, 0.3, 0.3)
const PROMENADE := Color(0.5, 0.48, 0.45)
const GRANITE := Color(0.66, 0.65, 0.63)
const PAINT_WHITE := Color(0.9, 0.9, 0.87)
const PAINT_YELLOW := Color(0.95, 0.75, 0.15)
const IRON := Color(0.09, 0.1, 0.1)
const POLE := Color(0.18, 0.2, 0.19)
const BRONZE := Color(0.3, 0.24, 0.16)
const TAXI_YELLOW := Color(0.98, 0.72, 0.05)

## Building looks fixed by name (from Street View): [style, tint].
const NAMED := {
	"Times Square Tower": [Style.GLASS, Color(0.58, 0.68, 0.78)],
	"4 Times Square": [Style.GLASS, Color(0.62, 0.68, 0.72)],
	"Bank of America Tower": [Style.GLASS, Color(0.66, 0.74, 0.76)],
	"3 Times Square": [Style.GLASS, Color(0.42, 0.62, 0.66)],
	"5 Times Square": [Style.DARK_GLASS, Color(0.45, 0.52, 0.6)],
	"11 Times Square": [Style.GLASS, Color(0.6, 0.68, 0.74)],
	"New York Marriott Marquis": [Style.GRID, Color(0.82, 0.78, 0.7)],
	"One Astor Place": [Style.RIBBON, Color(0.9, 0.9, 0.87)],
	"Bertelsmann Building": [Style.GLASS, Color(0.5, 0.66, 0.64)],
	"Morgan Stanley Building": [Style.DARK_GLASS, Color(0.3, 0.4, 0.55)],
	"1501 Broadway": [Style.STONE, Color(0.86, 0.79, 0.66)],
	"Candler Building": [Style.STONE, Color(0.93, 0.91, 0.85)],
	"Bush Tower": [Style.BRICK, Color(0.6, 0.4, 0.3)],
	"The Knickerbocker Hotel": [Style.BRICK, Color(0.62, 0.3, 0.22)],
	"Times Square Building": [Style.BRICK, Color(0.76, 0.63, 0.48)],
	"Salesforce Tower": [Style.DARK_GLASS, Color(0.36, 0.4, 0.44)],
	"Americas Tower": [Style.GLASS, Color(0.56, 0.62, 0.62)],
	"Hard Rock Hotel New York": [Style.GLASS, Color(0.45, 0.5, 0.56)],
	"One Times Square": [Style.DARK_GLASS, Color(0.3, 0.3, 0.32)],
	"Paramount Hotel": [Style.BRICK, Color(0.66, 0.48, 0.36)],
	"The Hotel Edison NYC": [Style.BRICK, Color(0.7, 0.55, 0.42)],
	"Brill Building": [Style.STONE, Color(0.85, 0.82, 0.74)],
	"Lyceum Theatre": [Style.STONE, Color(0.86, 0.82, 0.74)],
	"New Amsterdam Theatre": [Style.STONE, Color(0.85, 0.8, 0.7)],
	"Millennium Hotel Broadway Times Square": [Style.DARK_GLASS, Color(0.35, 0.38, 0.42)],
	"1155 Avenue of the Americas": [Style.GLASS, Color(0.5, 0.6, 0.66)],
	"Tower 45": [Style.GLASS, Color(0.55, 0.6, 0.62)],
	"Hyatt Centric Times Square": [Style.GRID, Color(0.78, 0.76, 0.72)],
	"The Westin": [Style.GLASS, Color(0.55, 0.45, 0.55)],
	"Interchem Building": [Style.RIBBON, Color(0.82, 0.82, 0.8)],
	"J.P. Stevens Company Tower": [Style.DARK_GLASS, Color(0.3, 0.32, 0.36)],
	"News Corp. Building": [Style.RIBBON, Color(0.8, 0.8, 0.78)],
	"Biltmore Tower": [Style.BRICK, Color(0.7, 0.6, 0.5)],
	"Platinum": [Style.GLASS, Color(0.6, 0.66, 0.7)],
	"ROW NYC": [Style.BRICK, Color(0.66, 0.42, 0.32)],
}
const BRICKS := [Color(0.58, 0.3, 0.22), Color(0.64, 0.38, 0.27), Color(0.72, 0.58, 0.44), Color(0.47, 0.27, 0.21), Color(0.8, 0.7, 0.56), Color(0.55, 0.42, 0.35)]
const STONES := [Color(0.86, 0.81, 0.71), Color(0.79, 0.75, 0.67), Color(0.9, 0.88, 0.82), Color(0.72, 0.7, 0.66)]
const GLASSES := [Color(0.5, 0.62, 0.7), Color(0.58, 0.66, 0.64), Color(0.44, 0.48, 0.54), Color(0.62, 0.7, 0.76)]
const PANELS := [Color(0.86, 0.85, 0.82), Color(0.72, 0.72, 0.72), Color(0.8, 0.76, 0.68)]
const SHOP_NAMES := [
	"DELI", "PIZZA", "GIFTS", "PHARMACY", "BANK", "COFFEE", "SUSHI", "BAGELS", "DINER", "SOUVENIRS",
	"NAIL SPA", "WINE & LIQUOR", "HALAL GRILL", "STEAKHOUSE", "BURGERS", "THEATRE TICKETS", "ELECTRONICS",
	"CHECK CASHING", "SHOES", "HOTEL", "RAMEN", "TACOS", "CANDY", "PUB", "JEWELRY", "OPTICIAN", "BAKERY",
]

var _data: Dictionary = {}
## Outline polygons (named buildings drawn by their parts) for grouping parts.
var _outlines: Array = [] # [name, PackedVector2Array]
var _looks := {} # group key -> [style, tint, seed]
var _water_tower_groups := {}
var _boats: Array = [] # [node, radius, speed, phase, bob]
var _clock := 0.0


func _ready() -> void:
	_rng.seed = 4245
	_collision = StaticBody3D.new()
	_collision.name = "DistrictCollision"
	add_child(_collision)
	_prepare_scene()
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if _data == null:
		push_error("Missing %s" % DATA_PATH)
		_data = {}
	for outline in _data.get("outlines", []):
		_outlines.append([str(outline["name"]), _poly(outline["p"])])

	_build_island()
	_build_ocean()
	_build_roads()
	_build_buildings()
	_build_screens()
	_build_one_times_square()
	_build_tkts()
	_build_monuments()
	_build_booths()
	_build_torch_site()
	_build_subway()
	_build_street_furniture()
	_build_signals()
	_build_plaza_furniture()
	_build_promenade()
	_plant_trees()
	_index_rects()
	_build_tree_meshes()
	_commit_chunks()
	_commit_wall_faces()
	ADS.bake(self, _screens_material())
	_spawn_cars()
	_build_traffic()
	_build_boats()
	var birds := MultiMeshInstance3D.new()
	birds.name = "Birds"
	birds.set_script(load("res://birds.gd"))
	add_child(birds)
	var ambience := Node.new()
	ambience.name = "Ambience"
	ambience.set_script(load("res://ambience.gd"))
	ambience.set("layers", [["res://audio/city_hum.wav", -9.0], ["res://audio/wind.wav", -24.0], ["res://audio/birds.ogg", -26.0]])
	add_child(ambience)


func _process(delta: float) -> void:
	_update_signals()
	_clock += delta
	for boat in _boats:
		var node := boat[0] as Node3D
		var angle: float = boat[3] + _clock * float(boat[2]) / float(boat[1])
		var centre := Vector3((EDGE_W + EDGE_E) * 0.5, SEA_LEVEL, (EDGE_N + EDGE_S) * 0.5)
		var pos := centre + Vector3(cos(angle), 0, sin(angle)) * float(boat[1])
		pos.y = SEA_LEVEL - 0.3 + sin(_clock * 1.3 + float(boat[3]) * 5.0) * float(boat[4])
		var heading := Vector3(-sin(angle), 0, cos(angle)) * signf(float(boat[2]))
		node.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP).rotated(heading, sin(_clock * 0.9 + float(boat[3])) * 0.03), pos)


# ---------------------------------------------------------- location data ----

func intro_text() -> String:
	return "Times Square, New York: 41st to 48th Street between 6th and 8th Avenue, rebuilt from the map and Street View and set adrift as an island in the ocean. The villagers carry pistols but won't shoot; they run when they see you armed. Map data (c) OpenStreetMap contributors."


func spawn_points() -> Array[Vector2]:
	# On the plazas of the bowtie, looking south down the square to One Times Square.
	return [
		Vector2(-14.0, -112.0), Vector2(-20.0, -64.0), Vector2(-14.0, -40.0), Vector2(-22.0, -20.0),
		Vector2(12.0, 30.0), Vector2(16.0, 60.0), Vector2(18.0, 110.0), Vector2(-8.0, -100.0),
	]


func spawn_yaw() -> float:
	return PI


func bot_graph() -> Dictionary:
	var nodes: Array[Vector2] = []
	var index_of := {}
	var add := func(p: Vector2) -> int:
		var key := Vector2i(roundi(p.x * 10.0), roundi(p.y * 10.0))
		if index_of.has(key):
			return index_of[key]
		nodes.append(p)
		index_of[key] = nodes.size() - 1
		return nodes.size() - 1
	var edges: Array = []
	var aves := [AVE_8, AVE_7, AVE_6]
	# Corner nodes: [avenue][street][corner 0 NW, 1 NE, 2 SW, 3 SE].
	var corners := {}
	for ai in aves.size():
		for si in STREETS.size():
			var s: float = STREETS[si][1]
			var h := _street_half(int(STREETS[si][0]))
			var north := s - h - 2.3
			var south := s + h + 2.3
			var span_n := _walk_span(ai, north - 3.0)
			var span_s := _walk_span(ai, south + 3.0)
			corners[Vector2i(ai, si)] = [
				add.call(Vector2(span_n.x, north)), add.call(Vector2(span_n.y, north)),
				add.call(Vector2(span_s.x, south)), add.call(Vector2(span_s.y, south)),
			]
	for ai in aves.size():
		for si in STREETS.size():
			var c: Array = corners[Vector2i(ai, si)]
			edges.append([c[0], c[1]]) # across the avenue, north crosswalk
			edges.append([c[2], c[3]]) # south crosswalk
			edges.append([c[0], c[2]]) # across the street, west side
			edges.append([c[1], c[3]]) # east side
			if si + 1 < STREETS.size():
				var below: Array = corners[Vector2i(ai, si + 1)]
				edges.append([c[2], below[0]]) # down the avenue's west sidewalk
				edges.append([c[3], below[1]]) # east sidewalk
			if ai + 1 < aves.size():
				var right: Array = corners[Vector2i(ai + 1, si)]
				# Along the street sidewalks, with a node in the middle of the block.
				for pair in [[c[1], right[0]], [c[3], right[2]]]:
					var a: Vector2 = nodes[pair[0]]
					var b: Vector2 = nodes[pair[1]]
					var m: int = add.call((a + b) * 0.5)
					edges.append([pair[0], m])
					edges.append([m, pair[1]])
	# Across the plazas of the bowtie.
	var plaza := [
		[Vector2(-16.0, -140.0), Vector2(-24.0, -100.0), Vector2(-22.0, -60.0), Vector2(-18.0, -20.0)],
		[Vector2(14.0, 30.0), Vector2(18.0, 80.0), Vector2(22.0, 120.0), Vector2(26.0, 160.0), Vector2(38.0, 205.0)],
	]
	for line in plaza:
		var prev := -1
		for p in line:
			var k: int = add.call(p)
			if prev >= 0:
				edges.append([prev, k])
			prev = k
	edges.append([add.call(Vector2(-16.0, -140.0)), corners[Vector2i(1, 1)][2]])
	edges.append([add.call(Vector2(-18.0, -20.0)), corners[Vector2i(1, 3)][0]])
	edges.append([add.call(Vector2(14.0, 30.0)), corners[Vector2i(1, 3)][3]])
	edges.append([add.call(Vector2(38.0, 205.0)), corners[Vector2i(1, 6)][1]])
	# Tourists on the plazas and the TKTS forecourt; a few just stand and look up.
	var civilians := [
		["civilian", -18.0, -105.0, 5.0, false], ["civilian", -20.0, -100.0, 4.0, true], ["civilian", -12.0, -110.0, 3.0, true],
		["child", -16.0, -104.0, 4.0, false], ["civilian", -22.0, -60.0, 7.0, false], ["civilian", -18.0, -50.0, 6.0, false],
		["civilian", -16.0, -30.0, 6.0, true], ["child", -20.0, -40.0, 5.0, false], ["civilian", -24.0, -80.0, 4.0, true],
		["civilian", 14.0, 40.0, 6.0, false], ["civilian", 18.0, 70.0, 6.0, true], ["child", 16.0, 55.0, 4.0, false],
		["civilian", 20.0, 110.0, 6.0, false], ["civilian", 24.0, 150.0, 5.0, true], ["civilian", 30.0, 195.0, 5.0, false],
		["child", 22.0, 120.0, 4.0, false], ["civilian", 12.0, 100.0, 3.0, true], ["civilian", 38.0, 230.0, 3.0, true],
	]
	var street_pedestrians: Array[Vector2] = []
	# Start walkers between the existing groups on the two plazas.
	for line in plaza:
		for i in line.size() - 1:
			street_pedestrians.append(line[i].lerp(line[i + 1], 0.5))
	# One mid-block sidewalk per cross street, from 48th through 42nd.
	var cross_street_sides := [[0, 1], [1, 3], [1, 1], [0, 3], [1, 3], [0, 1], [0, 3]]
	for si in cross_street_sides.size():
		var ai: int = cross_street_sides[si][0]
		var side: int = cross_street_sides[si][1]
		var left: Vector2 = nodes[corners[Vector2i(ai, si)][side]]
		var right: Vector2 = nodes[corners[Vector2i(ai + 1, si)][side - 1]]
		street_pedestrians.append(left.lerp(right, 0.5))
	# Alternate between the inland and waterfront sides of 8th and 6th Avenue.
	for slot in [
		[0, 0, 2], [0, 1, 3], [0, 2, 0], [0, 4, 3], [0, 5, 2], [0, 7, 1],
		[2, 0, 3], [2, 1, 2], [2, 3, 3], [2, 4, 2], [2, 6, 3], [2, 7, 0],
	]:
		street_pedestrians.append(nodes[corners[Vector2i(slot[0], slot[1])][slot[2]]])
	return {"nodes": nodes, "edges": edges, "no_spawn": [], "civilians": civilians, "street_pedestrians": street_pedestrians}


func _street_half(number: int) -> float:
	return WIDE_HALF if number == 42 else STREET_HALF


## Kerbs (west, east) of avenue `ai` (0 = 8th, 1 = 7th, 2 = 6th) at n.
func _ave_span(ai: int, n: float) -> Vector2:
	match ai:
		0:
			return Vector2(AVE_8 - 9.5, AVE_8 + 9.5)
		2:
			return Vector2(AVE_6 - 10.5, AVE_6 + 10.5)
	# 7th Avenue: the full width outside the bowtie; in it, the plaza takes the
	# west half from 47th to 45th Street and the east half from 45th to 42nd.
	if n < -153.3 or n > 249.2:
		return Vector2(-10.7, 8.3)
	if n < 5.0:
		return Vector2(-4.5, 8.3)
	return Vector2(-10.7, 3.5)


## Where people walk on either side of an avenue at n (sidewalk middles, or the plaza).
func _walk_span(ai: int, n: float) -> Vector2:
	var span := _ave_span(ai, n)
	var w := span.x - 2.8
	var e := span.y + 2.8
	if ai == 1 and n >= -153.3 and n < 5.0:
		w = -9.5
	elif ai == 1 and n >= 5.0 and n < 249.2:
		e = 6.5
	return Vector2(w, e)


# ---------------------------------------------------------------- scene ----

func _prepare_scene() -> void:
	# No forest and no grass: the island is all city, ringed by the sea.
	var forest := get_node_or_null("../Forest")
	if forest != null:
		forest.queue_free()
	var ground := get_node_or_null("../Ground") as Node3D
	if ground != null:
		ground.visible = false
	var leaves := get_node_or_null("../../Player/FallingLeaves") as CPUParticles3D
	if leaves != null:
		leaves.emitting = false
		leaves.visible = false
	var world_env := get_node_or_null("../../WorldEnvironment") as WorldEnvironment
	if world_env != null and world_env.environment != null:
		var env := world_env.environment.duplicate() as Environment
		env.fog_density = 0.00055
		# Street canyons are mostly in shade: a neutral fill so they don't go navy blue.
		env.ambient_light_sky_contribution = 0.35
		env.ambient_light_color = Color(0.78, 0.77, 0.75)
		env.ambient_light_energy = 1.1
		env.fog_light_color = Color(0.74, 0.8, 0.88)
		env.glow_intensity = 0.6
		env.glow_bloom = 0.06
		if env.sky != null:
			env.sky = env.sky.duplicate() as Sky
			var sky_material := env.sky.sky_material.duplicate() as ShaderMaterial
			if sky_material != null:
				sky_material.set_shader_parameter("ground_color", Color(0.12, 0.22, 0.28))
				sky_material.set_shader_parameter("cloud_cover", 0.42)
				env.sky.sky_material = sky_material
		world_env.environment = env
	var sun := get_node_or_null("../../Sun") as DirectionalLight3D
	if sun != null:
		sun.directional_shadow_max_distance = 110.0


func _poly(raw: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in raw:
		points.append(Vector2(float(p[0]), float(p[1])))
	return points


## The island outline: a rectangle with rounded corners, counter-clockwise in (u, n).
func _island_outline(inset := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := EDGE_CORNER - inset
	var lo := Vector2(EDGE_W + inset, EDGE_N + inset)
	var hi := Vector2(EDGE_E - inset, EDGE_S - inset)
	# Corners in turn, each arc sweeping a quarter turn outwards (angle 0 = +u, 90 = +n).
	var centres := [Vector2(hi.x - r, hi.y - r), Vector2(lo.x + r, hi.y - r), Vector2(lo.x + r, lo.y + r), Vector2(hi.x - r, lo.y + r)]
	var starts := [0.0, 90.0, 180.0, 270.0]
	for k in 4:
		for step in 7:
			var a := deg_to_rad(starts[k] + step * 15.0)
			points.append(centres[k] + Vector2(cos(a), sin(a)) * r)
	if _area(points) < 0.0:
		points.reverse()
	return points


# --------------------------------------------------------- island & sea ----

func _build_island() -> void:
	var outline := _island_outline()
	# Promenade of hexagonal pavers all round, the sidewalks of the city inside it.
	_gpoly(outline, 0.0, PROMENADE, Surface.HEX)
	_grect(-290.4, -242.4, 288.0, 342.9, 0.008, SIDEWALK, Surface.SIDEWALK)
	# The sea wall: granite blocks from below the water up to the promenade.
	_extrude(outline, -7.0, 0.0, Style.SEAWALL, 0.3, Color(0.62, 0.6, 0.56), false, false)
	_parapet(outline, 0.0, 0.32, GRANITE)
	# Keep everyone on the island: an invisible wall just inside the railing.
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var length := a.distance_to(b)
		var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
		_ocollider(f, -length * 0.5 - 0.3, 0.6, length * 0.5 + 0.3, 1.2, -1.0, 6.0)


func _build_ocean() -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://ocean.gdshader")
	material.set_shader_parameter("island_centre", Vector2((EDGE_W + EDGE_E) * 0.5, (EDGE_N + EDGE_S) * 0.5))
	material.set_shader_parameter("island_half", Vector2((EDGE_E - EDGE_W) * 0.5, (EDGE_S - EDGE_N) * 0.5))
	material.set_shader_parameter("island_corner", EDGE_CORNER)
	var centre := Vector3((EDGE_W + EDGE_E) * 0.5, SEA_LEVEL, (EDGE_N + EDGE_S) * 0.5)
	var near := PlaneMesh.new()
	near.size = Vector2(1500, 1500)
	near.subdivide_width = 299
	near.subdivide_depth = 299
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = near
	sea.material_override = material
	sea.position = centre
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	var far := PlaneMesh.new()
	far.size = Vector2(12000, 12000)
	var open_sea := MeshInstance3D.new()
	open_sea.name = "OpenSea"
	open_sea.mesh = far
	open_sea.material_override = material
	open_sea.position = centre - Vector3(0, 0.75, 0)
	open_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(open_sea)


# ---------------------------------------------------------------- roads ----

## Roadway rectangles (u0, n0, u1, n1); kerbs run round their union.
func _roadways() -> Array:
	var rects := []
	for street in STREETS:
		var h := _street_half(int(street[0]))
		rects.append(Rect2(CARRIAGE_W, float(street[1]) - h, CARRIAGE_E - CARRIAGE_W, h * 2.0))
	rects.append(Rect2(AVE_8 - 9.5, CARRIAGE_N, 19.0, CARRIAGE_S - CARRIAGE_N))
	rects.append(Rect2(AVE_6 - 10.5, CARRIAGE_N, 21.0, CARRIAGE_S - CARRIAGE_N))
	for block in [[CARRIAGE_N, -153.3], [-153.3, 5.0], [5.0, 249.2], [249.2, CARRIAGE_S]]:
		var span := _ave_span(1, (block[0] + block[1]) * 0.5)
		rects.append(Rect2(span.x, block[0], span.y - span.x, block[1] - block[0]))
	return rects


func _build_roads() -> void:
	# The bowtie plazas: dark pavers between the 7th Avenue roadway and Broadway's buildings.
	_grect(-80.0, -148.1, -4.5, -0.2, 0.014, PLAZA, Surface.PLAZA)
	_grect(3.5, 10.2, 85.0, 240.7, 0.014, PLAZA, Surface.PLAZA)
	var rects := _roadways()
	for rect in rects:
		var r: Rect2 = rect
		_grect(r.position.x, r.position.y, r.end.x, r.end.y, 0.03, ASPHALT, Surface.ASPHALT)
	# Broadway outside the bowtie: a shared street north of 47th, a roadway south of 42nd.
	_gstrip(Vector2(-50.0, -150.0), Vector2(-64.0, -236.0), 7.0, 0.03, ASPHALT, Surface.ASPHALT)
	_gstrip(Vector2(49.0, 245.0), Vector2(74.0, 336.0), 10.0, 0.03, ASPHALT, Surface.ASPHALT)
	_build_kerbs(rects)
	_build_markings()


## Granite kerbs along every roadway edge that is not inside another roadway.
func _build_kerbs(rects: Array) -> void:
	for index in rects.size():
		var r: Rect2 = rects[index]
		# Horizontal edges (along u) at n = top and bottom; vertical edges at u = left and right.
		for edge in [[r.position.y, -1.0], [r.end.y, 1.0]]:
			var n: float = edge[0]
			for interval in _uncovered(rects, index, r.position.x, r.end.x, n, true):
				var side: float = edge[1]
				_gbox(interval.x, n, interval.y, n + side * 0.25, 0.0, 0.14, GRANITE, Surface.GRANITE)
		for edge in [[r.position.x, -1.0], [r.end.x, 1.0]]:
			var u: float = edge[0]
			for interval in _uncovered(rects, index, r.position.y, r.end.y, u, false):
				var side: float = edge[1]
				_gbox(u, interval.x, u + side * 0.25, interval.y, 0.0, 0.14, GRANITE, Surface.GRANITE)
	# Kerbs of the two Broadway strips.
	for strip in [[Vector2(-50.0, -158.0), Vector2(-64.0, -236.0), 7.0], [Vector2(49.0, 258.0), Vector2(74.0, 328.0), 10.0]]:
		var a: Vector2 = strip[0]
		var b: Vector2 = strip[1]
		var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
		var half := a.distance_to(b) * 0.5
		var w: float = strip[2] * 0.5
		for side in [-1.0, 1.0]:
			_obox(f, -half, side * w, half, side * (w + 0.25), 0.0, 0.14, GRANITE)


## Parts of the segment [a, b] at `line` (n if along_u, else u) not inside any other rect.
func _uncovered(rects: Array, own: int, a: float, b: float, line: float, along_u: bool) -> Array:
	var pieces := [Vector2(a, b)]
	for index in rects.size():
		if index == own:
			continue
		var r: Rect2 = rects[index]
		var lo := r.position.y if along_u else r.position.x
		var hi := r.end.y if along_u else r.end.x
		if line <= lo + 0.01 or line >= hi - 0.01:
			continue
		var cut := Vector2(r.position.x, r.end.x) if along_u else Vector2(r.position.y, r.end.y)
		var next := []
		for piece in pieces:
			var p: Vector2 = piece
			if cut.y <= p.x or cut.x >= p.y:
				next.append(p)
				continue
			if cut.x > p.x:
				next.append(Vector2(p.x, cut.x))
			if cut.y < p.y:
				next.append(Vector2(cut.y, p.y))
		pieces = next
	return pieces.filter(func(p): return p.y - p.x > 0.3)


func _build_markings() -> void:
	var aves := [AVE_8, AVE_7, AVE_6]
	# Crosswalks at every corner: wide white bars, the NYC "high visibility" kind.
	for si in STREETS.size():
		var s: float = STREETS[si][1]
		var h := _street_half(int(STREETS[si][0]))
		for ai in aves.size():
			for side in [-1.0, 1.0]:
				var n: float = s + side * (h + 2.6)
				if n > CARRIAGE_N + 1.0 and n < CARRIAGE_S - 1.0:
					var span := _ave_span(ai, n)
					_crosswalk_across_n(span.x, span.y, n)
			var west := minf(_ave_span(ai, s - h - 1.0).x, _ave_span(ai, s + h + 1.0).x)
			var east := maxf(_ave_span(ai, s - h - 1.0).y, _ave_span(ai, s + h + 1.0).y)
			for u in [west - 2.6, east + 2.6]:
				if u > CARRIAGE_W + 1.0 and u < CARRIAGE_E - 1.0:
					_crosswalk_across_u(s - h, s + h, u)
	# Lane lines on the avenues between the crosswalks; bike lanes on 8th and 6th.
	for bi in STREETS.size() - 1:
		var n0: float = STREETS[bi][1] + _street_half(int(STREETS[bi][0])) + 5.0
		var n1: float = STREETS[bi + 1][1] - _street_half(int(STREETS[bi + 1][0])) - 5.0
		for ai in aves.size():
			var span := _ave_span(ai, (n0 + n1) * 0.5)
			var lane_start := span.x
			if ai != 1:
				# Green protected bike lane along the west kerb, a buffer stripe beside it.
				_grect(span.x, n0, span.x + 1.9, n1, 0.045, Color(0.25, 0.55, 0.35), Surface.PAINT)
				_grect(span.x + 1.9, n0, span.x + 2.1, n1, 0.045, PAINT_WHITE, Surface.PAINT)
				lane_start = span.x + 2.1
			var lanes := maxi(1, int((span.y - lane_start) / 3.4))
			var width := (span.y - lane_start) / lanes
			for k in range(1, lanes):
				var u := lane_start + width * k
				var n := n0 + 1.0
				while n < n1 - 3.0:
					_grect(u - 0.08, n, u + 0.08, minf(n + 3.0, n1), 0.045, PAINT_WHITE, Surface.PAINT)
					n += 9.0
	# 42nd Street: two-way, double yellow in the middle, red bus lanes at the kerbs.
	var s42: float = 249.2
	_grect(CARRIAGE_W + 20.0, s42 - 0.25, CARRIAGE_E - 22.0, s42 - 0.1, 0.045, PAINT_YELLOW, Surface.PAINT)
	_grect(CARRIAGE_W + 20.0, s42 + 0.1, CARRIAGE_E - 22.0, s42 + 0.25, 0.045, PAINT_YELLOW, Surface.PAINT)
	for block in [[CARRIAGE_W + 20.0, AVE_7 - 16.0], [AVE_7 + 16.0, CARRIAGE_E - 22.0]]:
		for side in [-1.0, 1.0]:
			var kerb: float = s42 + side * WIDE_HALF
			_grect(block[0], minf(kerb, kerb - side * 3.3), block[1], maxf(kerb, kerb - side * 3.3), 0.044, Color(0.6, 0.27, 0.23), Surface.PAINT)
			var u: float = block[0] + 12.0
			while u < block[1] - 10.0:
				_ground_text("BUS ONLY", Vector2(u, kerb - side * 1.65), side)
				u += 60.0


## Crosswalk for people walking along n, across a roadway running along u... and
## the other way round: bars are laid along the traffic.
func _crosswalk_across_n(u0: float, u1: float, n: float) -> void:
	# People walk along u here (crossing an avenue); bars run along n.
	var u := u0 + 0.4
	while u < u1 - 0.6:
		_grect(u, n - 1.9, u + 0.6, n + 1.9, 0.046, PAINT_WHITE, Surface.PAINT)
		u += 1.2
	_grect(u0, n - 2.15, u1, n - 1.95, 0.046, PAINT_WHITE, Surface.PAINT)
	_grect(u0, n + 1.95, u1, n + 2.15, 0.046, PAINT_WHITE, Surface.PAINT)


func _crosswalk_across_u(n0: float, n1: float, u: float) -> void:
	var n := n0 + 0.4
	while n < n1 - 0.6:
		_grect(u - 1.9, n, u + 1.9, n + 0.6, 0.046, PAINT_WHITE, Surface.PAINT)
		n += 1.2
	_grect(u - 2.15, n0, u - 1.95, n1, 0.046, PAINT_WHITE, Surface.PAINT)
	_grect(u + 1.95, n0, u + 2.15, n1, 0.046, PAINT_WHITE, Surface.PAINT)


## Words painted on the road, readable by drivers coming towards -side along u.
func _ground_text(text: String, at: Vector2, side: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.0075
	label.modulate = Color(0.95, 0.95, 0.92)
	label.outline_size = 0
	label.position = _w(at.x, at.y, 0.06)
	# Lying flat, the top of the letters pointing the way the traffic goes
	# (east in the south lanes, west in the north ones).
	label.basis = Basis(Vector3.UP, -PI * 0.5 if side > 0 else PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(1.0, 3.2, 1.0))
	label.visibility_range_end = 90.0
	add_child(label)


# ------------------------------------------------------------ buildings ----

## Which named building a part belongs to (its outline contains the part), or "".
func _group_of(points: PackedVector2Array, own_name: String, id: String) -> String:
	if not own_name.is_empty():
		for outline in _outlines:
			if outline[0] == own_name:
				return own_name
	var c := _centroid(points)
	for outline in _outlines:
		if _point_in(outline[1], c):
			return str(outline[0]) if not str(outline[0]).is_empty() else "outline_%s" % str(outline[1][0])
	return own_name if not own_name.is_empty() else id


func _look(group: String, building: Dictionary) -> Array:
	if _looks.has(group):
		return _looks[group]
	var seed := fposmod(float(hash(group)) / 9973.0, 1.0)
	var pick := func(list: Array) -> Color:
		return list[hash(group + "c") % list.size()]
	var style := Style.BRICK
	var tint: Color = pick.call(BRICKS)
	var h: float = building.get("h", 20.0)
	var kind := str(building.get("kind", ""))
	var name := str(building.get("name", ""))
	var material := str(building.get("material", ""))
	var roll := fposmod(float(hash(group + "s")) / 7919.0, 1.0)
	if NAMED.has(group):
		style = NAMED[group][0]
		tint = NAMED[group][1]
	elif kind == "theatre" or name.contains("Theat"):
		style = Style.BRICK if roll < 0.65 else Style.STONE
		tint = pick.call(BRICKS) if style == Style.BRICK else pick.call(STONES)
	elif material == "glass":
		style = Style.GLASS if roll < 0.7 else Style.DARK_GLASS
		tint = pick.call(GLASSES)
	elif material == "brick":
		style = Style.BRICK
	elif material == "concrete":
		style = Style.GRID if roll < 0.5 else Style.RIBBON
		tint = pick.call(PANELS)
	elif material in ["granite", "stone", "sandstone", "limestone"]:
		style = Style.STONE
		tint = pick.call(STONES)
	elif h > 110.0:
		style = [Style.GLASS, Style.DARK_GLASS, Style.GLASS, Style.RIBBON][int(roll * 4.0)]
		tint = pick.call(GLASSES) if style != Style.RIBBON else pick.call(PANELS)
	elif h > 45.0:
		style = [Style.STONE, Style.BRICK, Style.GRID, Style.RIBBON, Style.BRICK][int(roll * 5.0)]
		tint = pick.call(STONES) if style == Style.STONE else (pick.call(PANELS) if style in [Style.GRID, Style.RIBBON] else pick.call(BRICKS))
	else:
		style = Style.BRICK if roll < 0.7 else Style.STONE
		tint = pick.call(BRICKS) if style == Style.BRICK else pick.call(STONES)
	# The colour mapped in OSM, where there is one, pulls the tint towards it.
	var mapped := str(building.get("colour", ""))
	if not mapped.is_empty() and not NAMED.has(group):
		var c := Color.from_string(mapped, tint)
		tint = tint.lerp(c, 0.6)
	_looks[group] = [style, tint, seed]
	return _looks[group]


func _build_buildings() -> void:
	for building in _data.get("buildings", []):
		var points := _poly(building["p"])
		if points.size() < 3:
			continue
		var kind := str(building.get("kind", ""))
		var name := str(building.get("name", ""))
		var h: float = building.get("h", 18.0)
		var mh: float = building.get("mh", 0.0)
		if kind in ["steps", "construction"] or name in ["TKTS", "The Torch"] or name.begins_with("NYPD") or name.begins_with("U.S. Armed Forces"):
			continue # TKTS, The Torch and the two booths are built by hand
		if kind == "roof":
			if h < 8.0:
				_canopy(points, h)
			continue
		if h - mh < 0.5:
			continue
		var group := _group_of(points, name, str(building.get("id", "")))
		var look := _look(group, building)
		var style: int = look[0]
		var tint: Color = look[1]
		var seed: float = look[2]
		var theatre := kind == "theatre" or name.contains("Theat")
		var shops := mh < 0.5 and h > 6.0 and style != Style.BLANK and not theatre
		_extrude(points, mh, h, style, seed, tint, shops)
		var roof := Color(0.27, 0.27, 0.28).lerp(Color(0.4, 0.38, 0.34), fposmod(seed * 7.0, 1.0))
		_cap(points, h, roof)
		var area := absf(_area(points))
		_blocked_footprint(points)
		if style in [Style.BRICK, Style.STONE, Style.GRID]:
			_parapet(points, h, 0.9, tint.darkened(0.15))
		# Wooden water tanks on the older roofs, mechanical penthouses on the big ones.
		if style in [Style.BRICK, Style.STONE] and h > 18.0 and h < 110.0 and area > 160.0 \
				and not _water_tower_groups.has(group) and fposmod(seed * 13.0, 1.0) < 0.55:
			var spot := _inner_spot(points)
			if spot != Vector2.INF:
				_water_tower(_w(spot.x, spot.y, h))
				_water_tower_groups[group] = true
		elif area > 500.0 and h > 30.0:
			var spot := _inner_spot(points)
			if spot != Vector2.INF:
				var size := clampf(sqrt(area) * 0.3, 5.0, 14.0)
				_box_un(spot.x - size * 0.5, spot.y - size * 0.4, spot.x + size * 0.5, spot.y + size * 0.4, h, h + 3.5, Color(0.55, 0.55, 0.56))
				_box_un(spot.x - 1.2, spot.y - 1.2, spot.x + 1.2, spot.y + 1.2, h + 3.5, h + 4.6, Color(0.4, 0.4, 0.42))
		if theatre and mh < 0.5:
			_theatre_front(points, name, h)
		elif shops and h > 8.0 and _rng.randf() < 0.3:
			_shop_sign(points)


## Mark a footprint as built-on (for trees) by its bounding box.
func _blocked_footprint(points: PackedVector2Array) -> void:
	var rect := Rect2(points[0], Vector2.ZERO)
	for p in points:
		rect = rect.expand(p)
	_blocked.append(rect)


## A point well inside a footprint (its centroid, or the middle of its longest chord).
func _inner_spot(points: PackedVector2Array) -> Vector2:
	var c := _centroid(points)
	if _point_in(points, c):
		return c
	for k in 20:
		var p := points[_rng.randi() % points.size()].lerp(points[_rng.randi() % points.size()], 0.5)
		if _point_in(points, p):
			return p
	return Vector2.INF


## NYC rooftop water tank: wooden barrel on a steel stand, conical cap.
func _water_tower(base: Vector3) -> void:
	var r := _rng.randf_range(2.2, 3.2)
	var steel := Color(0.22, 0.2, 0.19)
	for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		var p: Vector3 = base + corner * r * 0.6
		_box_un(p.x - 0.12, p.z - 0.12, p.x + 0.12, p.z + 0.12, base.y, base.y + 3.2, steel)
	_box_un(base.x - r * 0.75, base.z - r * 0.75, base.x + r * 0.75, base.z + r * 0.75, base.y + 3.0, base.y + 3.3, steel)
	var wood := Color(0.42, 0.33, 0.25).lerp(Color(0.55, 0.5, 0.45), _rng.randf())
	var barrel := base + Vector3.UP * 3.3
	var height := _rng.randf_range(4.0, 5.5)
	_cyl("solid", barrel, r, height, wood, 14, false)
	for k in 3:
		_cyl("solid", barrel + Vector3.UP * (0.6 + k * height * 0.35), r + 0.04, 0.12, steel, 14, false)
	_cone("solid", barrel + Vector3.UP * height, r + 0.15, 0.0, r * 0.75, wood.darkened(0.25), 14)


## Theatre marquee canopies (OSM "roof" parts): a slab on the facade with bulbs round it.
func _canopy(points: PackedVector2Array, h: float) -> void:
	var top := clampf(h, 3.2, 6.0)
	_cap(points, top, Color(0.12, 0.1, 0.1))
	for index in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		var length := a.distance_to(b)
		var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
		_obox(f, -length * 0.5, -0.05, length * 0.5, 0.05, top - 0.9, top, Color(0.12, 0.1, 0.1))
		_obox(f, -length * 0.5, -0.08, length * 0.5, -0.05, top - 0.85, top - 0.75, Color(1, 0.85, 0.55), "glow")
		_obox(f, -length * 0.5, -0.08, length * 0.5, -0.05, top - 0.15, top - 0.05, Color(1, 0.85, 0.55), "glow")


## Marquee over the entrance and a vertical blade sign with the theatre's name.
func _theatre_front(points: PackedVector2Array, name: String, h: float) -> void:
	var best := -1
	var best_len := 0.0
	for index in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		var length := a.distance_to(b)
		if length < 6.0:
			continue
		var d := (b - a) / length
		var out := Vector2(d.y, -d.x)
		if absf(out.y) < 0.8:
			continue
		var mid := (a + b) * 0.5
		var faces_street := false
		for street in STREETS:
			var gap: float = (float(street[1]) - mid.y) * signf(out.y)
			if gap > 4.0 and gap < 16.0:
				faces_street = true
		if faces_street and length > best_len:
			best = index
			best_len = length
	if best < 0:
		return
	var a := points[best]
	var b := points[(best + 1) % points.size()]
	var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
	var title := name.replace(" Theatre", "").replace(" Theater", "").to_upper()
	var width := minf(best_len * 0.7, 16.0)
	# Marquee: a deep box over the doors, bulbs all round, the name on its face.
	var dark := Color(0.08, 0.06, 0.08)
	_obox(f, -width * 0.5, -2.6, width * 0.5, 0.0, 3.6, 5.0, dark)
	_obox(f, -width * 0.5 - 0.05, -2.66, width * 0.5 + 0.05, -2.6, 3.6, 3.7, Color(1, 0.88, 0.6), "glow")
	_obox(f, -width * 0.5 - 0.05, -2.66, width * 0.5 + 0.05, -2.6, 4.9, 5.0, Color(1, 0.88, 0.6), "glow")
	_obox(f, -width * 0.5 + 0.3, -2.62, width * 0.5 - 0.3, -2.6, 3.8, 4.8, Color(0.95, 0.93, 0.85), "glow")
	_face_label(f, 0.0, -2.68, 4.3, title, Color(0.08, 0.05, 0.05), 0.012, 72, -1.0)
	# Glass doors under it.
	_obox(f, -width * 0.4, -0.06, width * 0.4, 0.0, 0.0, 3.0, Color(0.15, 0.12, 0.1), "glass")
	# Blade sign at one end of the facade, sticking out over the sidewalk.
	var s := best_len * 0.5 - 1.2
	var top := clampf(h - 2.0, 9.0, 16.0)
	_obox(f, s - 0.2, -2.2, s + 0.2, 0.0, 5.6, top, Color(0.55, 0.08, 0.1))
	_obox(f, s - 0.24, -2.26, s + 0.24, -2.2, 5.6, top, Color(1, 0.85, 0.5), "glow")
	var vertical := ""
	for letter in title.replace(" ", "").left(10):
		vertical += letter + "\n"
	for side in [-1.0, 1.0]:
		var at := _fp(f, s + side * 0.23, -1.1)
		var label := Label3D.new()
		label.text = vertical.strip_edges()
		label.font_size = 64
		label.pixel_size = clampf((top - 6.0) / 10.0 / 64.0 * 0.9, 0.008, 0.014)
		label.modulate = Color(1.6, 1.4, 1.0)
		label.outline_size = 0
		label.line_spacing = -6
		label.position = _w(at.x, at.y, (5.6 + top) * 0.5)
		label.rotation_degrees.y = rad_to_deg(atan2((f[1] as Vector2).x * side, (f[1] as Vector2).y * side))
		label.visibility_range_end = 160.0
		add_child(label)


## Label on a frame face: `side` -1 is the outside of a footprint edge (-t).
func _face_label(f: Array, s: float, t: float, y: float, text: String, color: Color, pixel: float, size: int, side: float) -> void:
	var at := _fp(f, s, t)
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.position = _w(at.x, at.y, y)
	label.rotation_degrees.y = _face_yaw(f, side)
	label.visibility_range_end = 70.0
	add_child(label)


## A lit shop name on the sign band of a street-facing wall.
func _shop_sign(points: PackedVector2Array) -> void:
	var index := _rng.randi() % points.size()
	var a := points[index]
	var b := points[(index + 1) % points.size()]
	var length := a.distance_to(b)
	if length < 6.0:
		return
	var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
	var s := _rng.randf_range(-length * 0.3, length * 0.3)
	var text: String = SHOP_NAMES[_rng.randi() % SHOP_NAMES.size()]
	var colors := [Color(1.4, 1.3, 1.1), Color(1.5, 0.4, 0.3), Color(0.5, 1.2, 1.5), Color(1.5, 1.2, 0.3)]
	_face_label(f, s, -0.08, 4.1, text, colors[_rng.randi() % colors.size()], 0.01, 64, -1.0)


# ------------------------------------------------------------- screens ----

## The u of the square's middle line at n (between 7th Avenue and Broadway).
func _square_axis(n: float) -> float:
	if n < 0.0:
		return lerpf(-26.0, -8.0, clampf((n + 155.0) / 155.0, 0.0, 1.0))
	return lerpf(8.0, 26.0, clampf(n / 245.0, 0.0, 1.0))


## LED screens on every facade that looks onto the square, wrapped round corners.
func _build_screens() -> void:
	var phase := 0.0
	for building in _data.get("buildings", []):
		var name := str(building.get("name", ""))
		var mh: float = building.get("mh", 0.0)
		var h: float = building.get("h", 0.0)
		var kind := str(building.get("kind", ""))
		if mh > 0.5 or h < 9.0 or kind in ["roof", "steps", "construction"] or name in ["TKTS", "The Torch"] or name.begins_with("NYPD") or name.begins_with("U.S."):
			continue
		var points := _poly(building["p"])
		var group := _group_of(points, name, str(building.get("id", "")))
		if group == "One Times Square":
			continue # wrapped all round by _build_one_times_square()
		var round_shape := points.size() > 14
		var faces := []
		for index in points.size():
			var a := points[index]
			var b := points[(index + 1) % points.size()]
			var length := a.distance_to(b)
			var ok := false
			if length >= (0.8 if round_shape else 3.0):
				var mid := (a + b) * 0.5
				var d := (b - a) / length
				var out := Vector2(d.y, -d.x)
				if mid.y > -165.0 and mid.y < 262.0:
					var axis := _square_axis(mid.y)
					var gap := axis - mid.x
					if absf(gap) < 72.0 and out.x * signf(gap) > 0.45:
						ok = true
					elif absf(out.y) > 0.7 and absf(gap) < 46.0:
						ok = true # corners round onto the cross streets
			faces.append(ok)
		# Runs of consecutive screen faces (the list is cyclic).
		var start := faces.find(false)
		if start < 0:
			start = 0
		var run := PackedVector2Array()
		for k in points.size() + 1:
			var index := (start + k) % points.size()
			if k < points.size() and faces[index]:
				if run.is_empty():
					run.append(points[index])
				run.append(points[(index + 1) % points.size()])
			elif run.size() >= 2:
				phase += 0.137
				_screens_on_run(run, h, hash(group), phase)
				run = PackedVector2Array()


## Split a facade run into panels and tiers and hang screens on them.
func _screens_on_run(run: PackedVector2Array, h: float, seed: int, phase: float) -> void:
	var total := 0.0
	for index in run.size() - 1:
		total += run[index].distance_to(run[index + 1])
	if total < 3.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var y0 := 5.3
	var y1 := minf(h - 1.5, rng.randf_range(20.0, 46.0))
	if y1 - y0 < 4.0:
		return
	var tiers := 1 if y1 - y0 < 14.0 else (2 if y1 - y0 < 30.0 else 3)
	var panels := maxi(1, roundi(total / rng.randf_range(14.0, 26.0)))
	var tier_h := (y1 - y0) / tiers
	for tier in tiers:
		var ty0 := y0 + tier * tier_h + (0.4 if tier > 0 else 0.0)
		var ty1 := y0 + (tier + 1) * tier_h - 0.4
		for panel in panels:
			var s0 := total * panel / panels + (0.4 if panel > 0 else 0.0)
			var s1 := total * (panel + 1) / panels - (0.4 if panel < panels - 1 else 0.0)
			var piece := _sub_run(run, s0, s1)
			var aspect := (s1 - s0) / maxf(0.5, ty1 - ty0)
			var ads := Vector2(_pick_ad(rng, aspect < 1.0), _pick_ad(rng, aspect < 1.0))
			_screen_run(piece, ty0, ty1, ads, fposmod(phase + tier * 0.31 + panel * 0.17, 1.0))


## An ad for a screen: the featured ones (NOVA, MaxSoft, Claude, Anthropic) on
## about every other screen, the made-up brands on the rest.
func _pick_ad(rng: RandomNumberGenerator, tall: bool) -> int:
	if rng.randf() < 0.45:
		return ADS.ad_index(ADS.FEATURED[rng.randi() % ADS.FEATURED.size()], tall)
	return ADS.ad_index(rng.randi() % 16, tall)


## The part of a polyline between distances s0 and s1 along it.
func _sub_run(run: PackedVector2Array, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var s := 0.0
	for index in run.size() - 1:
		var a := run[index]
		var b := run[index + 1]
		var length := a.distance_to(b)
		var e := s + length
		if e > s0 and s < s1:
			var t0 := clampf((s0 - s) / length, 0.0, 1.0)
			var t1 := clampf((s1 - s) / length, 0.0, 1.0)
			if out.is_empty():
				out.append(a.lerp(b, t0))
			out.append(a.lerp(b, t1))
		s = e
	return out


## One Times Square: the narrow tower at the south end of the square, wrapped in
## screens almost to the top, the news ticker round its base, and the New Year's
## Eve ball on its mast over the lit year.
func _build_one_times_square() -> void:
	var parts := []
	for building in _data.get("buildings", []):
		var points := _poly(building["p"])
		if _group_of(points, str(building.get("name", "")), str(building.get("id", ""))) == "One Times Square":
			parts.append([points, float(building["h"]), float(building.get("mh", 0.0))])
	if parts.is_empty():
		return
	parts.sort_custom(func(a, b): return a[1] > b[1])
	var tallest: Array = parts[0]
	var top: float = tallest[1]
	var phase := 0.5
	for part in parts:
		var points: PackedVector2Array = part[0]
		var h: float = part[1]
		var ring := points.duplicate()
		ring.append(points[0])
		# Screens in stacked bands up the whole tower.
		var y := 8.6
		var band := 0
		while y < h - 6.0:
			var y_top := minf(y + 13.0, h - 5.0)
			# One panel per face so each face shows its own ads.
			for index in points.size():
				var a := points[index]
				var b := points[(index + 1) % points.size()]
				if a.distance_to(b) < 2.0:
					continue
				var tall := a.distance_to(b) / (y_top - y) < 1.0
				phase += 0.23
				# The featured ads take turns on the tower's faces, made-up ones between them.
				var featured: Array = ADS.FEATURED
				var first: int = featured[(index + band) % featured.size()]
				var second := (index * 7 + band * 5 + 3) % 16
				_screen_run(PackedVector2Array([a, b]), y, y_top, Vector2(ADS.ad_index(first, tall), ADS.ad_index(second, tall)), fposmod(phase, 1.0), 0.45, 2.4)
			y = y_top + 0.8
			band += 1
		if h == top:
			_ticker_run(ring, 6.4, 8.0, 32, 0.0, 0.7)
	# Mast with the ball and the year under it.
	var c := _centroid(tallest[0])
	var base := _w(c.x, c.y, top)
	_box_un(c.x - 3.0, c.y - 3.0, c.x + 3.0, c.y + 3.0, top, top + 2.0, Color(0.3, 0.3, 0.32))
	_cyl("solid", base + Vector3.UP * 2.0, 0.35, 22.0, Color(0.7, 0.7, 0.72), 10)
	_globe("neon", base + Vector3.UP * 25.0, 1.9, Color(0.75, 0.85, 1.0))
	var year := Label3D.new()
	year.text = "2026"
	year.font_size = 128
	year.pixel_size = 0.03
	year.modulate = Color(2.2, 1.8, 0.8)
	year.outline_size = 0
	year.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	year.position = base + Vector3.UP * 6.0
	add_child(year)


# -------------------------------------------------------------- landmarks ----

## The TKTS booth under the red steps in Duffy Square: 24 glowing red risers
## rising north to the top at 4.9 m, glass sides, the ticket booth beneath.
func _build_tkts() -> void:
	var n_low := -125.1
	var n_high := -142.9
	var steps := 24
	var rise := 4.9 / steps
	for k in steps:
		var n0 := lerpf(n_low, n_high, float(k) / steps)
		var n1 := lerpf(n_low, n_high, float(k + 1) / steps)
		var west := lerpf(-24.4, -28.9, float(k) / steps)
		var y := rise * (k + 1)
		_box_un(west, n1, -14.1, n0, 0.0, y - 0.04, Color(0.5, 0.03, 0.04))
		_add_box(_tool("glow", _w(-20.0, n0)), _w(west, n0 - 0.04, y - rise + 0.02), _w(-14.1, n0, y - 0.02), Color(1.0, 0.15, 0.12))
		_add_box(_tool("glow", _w(-20.0, n0)), _w(west, n1, y - 0.05), _w(-14.1, n0, y), Color(0.55, 0.05, 0.05))
	# Glass balustrades up both sides and across the top.
	for side in [[-24.4, -28.9], [-14.1, -14.1]]:
		var a := Vector2(side[0], n_low)
		var b := Vector2(side[1], n_high)
		var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
		var half := a.distance_to(b) * 0.5
		for k in 6:
			var s0 := -half + 2.0 * half * k / 6.0
			var y0 := 4.9 * float(k) / 6.0
			_obox(f, s0, -0.04, s0 + 2.0 * half / 6.0, 0.04, y0, y0 + 1.1, GLASS, "glass")
	_box_un(-28.9, n_high - 0.08, -14.1, n_high, 4.9, 6.0, GLASS)
	# The booth: glass box under the top of the steps, its windows facing 47th Street.
	_box_un(-27.5, n_high, -15.0, n_high + 4.5, 0.0, 2.8, Color(0.85, 0.85, 0.86))
	_add_sign("tkts", _w(-21.0, n_high - 0.12, 3.6), 180.0, Color(0.85, 0.05, 0.08), 0.03, 64)
	# A ramp under the steps so people can climb them.
	var ramp := BoxShape3D.new()
	var length := sqrt(pow(n_low - n_high, 2) + 4.9 * 4.9)
	ramp.size = Vector3(10.0, 0.3, length)
	var node := CollisionShape3D.new()
	node.shape = ramp
	var slope := atan2(4.9, n_low - n_high)
	node.transform = Transform3D(Basis(Vector3.RIGHT, slope), Vector3(-20.5, 2.45 - 0.15 * cos(slope), (n_low + n_high) * 0.5))
	_collision.add_child(node)
	var top_box := BoxShape3D.new()
	top_box.size = Vector3(13.0, 4.9, 1.0)
	var top_node := CollisionShape3D.new()
	top_node.shape = top_box
	top_node.position = Vector3(-21.5, 2.45, n_high - 0.4)
	_collision.add_child(top_node)
	_blocked_un(-29.0, n_high - 1.0, -14.0, n_low)


## George M. Cohan at the south end of Duffy Square, Father Duffy and his Celtic
## cross at the foot of the red steps.
func _build_monuments() -> void:
	_statue(Vector2(-14.8, -87.9), 1.9)
	var cross := Vector2(-19.2, -121.6)
	var stone := Color(0.55, 0.55, 0.53)
	_box_un(cross.x - 1.4, cross.y - 0.7, cross.x + 1.4, cross.y + 0.7, 0.0, 1.0, stone)
	_box_un(cross.x - 0.35, cross.y - 0.25, cross.x + 0.35, cross.y + 0.25, 1.0, 7.0, stone)
	_box_un(cross.x - 1.4, cross.y - 0.25, cross.x + 1.4, cross.y + 0.25, 5.0, 5.6, stone)
	for k in 12:
		var a := TAU * k / 12.0
		var p := Vector2(cross.x + cos(a) * 0.85, 5.3 + sin(a) * 0.85)
		_box_un(p.x - 0.14, cross.y - 0.18, p.x + 0.14, cross.y + 0.18, p.y - 0.14, p.y + 0.14, stone)
	_collider_between(_w(cross.x - 1.4, cross.y - 0.7), _w(cross.x + 1.4, cross.y + 0.7, 7.0))
	_statue(Vector2(cross.x, cross.y + 1.6), 1.6)


## Bronze figure on a granite pedestal, facing south (+n).
func _statue(at: Vector2, pedestal: float) -> void:
	var stone := Color(0.5, 0.5, 0.5)
	_box_un(at.x - 0.9, at.y - 0.9, at.x + 0.9, at.y + 0.9, 0.0, pedestal, stone)
	_box_un(at.x - 1.05, at.y - 1.05, at.x + 1.05, at.y + 1.05, pedestal, pedestal + 0.15, stone.lightened(0.1))
	_collider_between(_w(at.x - 0.9, at.y - 0.9), _w(at.x + 0.9, at.y + 0.9, pedestal + 0.15))
	var y := pedestal + 0.15
	for leg in [-0.13, 0.13]:
		_box_un(at.x + leg - 0.09, at.y - 0.1, at.x + leg + 0.09, at.y + 0.1, y, y + 0.85, BRONZE)
	_box_un(at.x - 0.27, at.y - 0.17, at.x + 0.27, at.y + 0.17, y + 0.55, y + 1.45, BRONZE) # coat
	_box_un(at.x - 0.36, at.y - 0.1, at.x - 0.24, at.y + 0.1, y + 0.75, y + 1.4, BRONZE) # arms
	_box_un(at.x + 0.24, at.y - 0.1, at.x + 0.36, at.y + 0.3, y + 0.95, y + 1.4, BRONZE)
	_globe("solid", _w(at.x, at.y, y + 1.6), 0.13, BRONZE)
	_cyl("solid", _w(at.x, at.y, y + 1.7), 0.17, 0.05, BRONZE.darkened(0.2), 10)
	_cyl("solid", _w(at.x, at.y, y + 1.72), 0.11, 0.12, BRONZE.darkened(0.2), 10)


## The NYPD Times Square station and the Armed Forces recruiting booth with its neon flag.
func _build_booths() -> void:
	for building in _data.get("buildings", []):
		var name := str(building.get("name", ""))
		var points := _poly(building["p"])
		if name.begins_with("NYPD"):
			_extrude(points, 0.0, 4.2, Style.GLASS, 0.4, Color(0.45, 0.5, 0.58), false)
			_cap(points, 4.2, Color(0.3, 0.3, 0.32))
			_parapet(points, 4.2, 0.5, Color(0.2, 0.22, 0.3))
			for index in points.size():
				var a := points[index]
				var b := points[(index + 1) % points.size()]
				var length := a.distance_to(b)
				var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
				_obox(f, -length * 0.5, -0.08, length * 0.5, 0.0, 3.4, 3.6, Color(0.2, 0.45, 1.0), "neon")
				_obox(f, -length * 0.5, -0.08, length * 0.5, 0.0, 0.9, 1.0, Color(0.2, 0.45, 1.0), "neon")
				if length > 5.0:
					_face_label(f, 0.0, -0.12, 2.6, "POLICE", Color(0.6, 1.2, 2.2), 0.014, 96, -1.0)
			var c := _centroid(points)
			_box_un(c.x - 0.8, c.y - 0.2, c.x + 0.8, c.y + 0.2, 4.7, 4.95, Color(0.9, 0.1, 0.1))
		elif name.begins_with("U.S. Armed Forces"):
			_extrude(points, 0.0, 5.5, Style.GLASS, 0.6, Color(0.7, 0.72, 0.75), false)
			_cap(points, 5.5, Color(0.6, 0.6, 0.62))
			for index in points.size():
				var a := points[index]
				var b := points[(index + 1) % points.size()]
				var length := a.distance_to(b)
				if length < 8.0:
					continue
				var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
				_neon_flag(f, length, 0.9, 5.0)


## The Stars and Stripes in neon tubes on a frame face (outside = -t).
func _neon_flag(f: Array, length: float, y0: float, y1: float) -> void:
	var s0 := -length * 0.5 + 0.4
	var s1 := length * 0.5 - 0.4
	var stripe := (y1 - y0) / 13.0
	for k in 13:
		var color := Color(1.0, 0.1, 0.1) if k % 2 == 0 else Color(1.0, 0.95, 0.9)
		var y := y1 - (k + 1) * stripe
		_obox(f, s0, -0.12, s1, -0.04, y + stripe * 0.2, y + stripe * 0.8, color, "neon")
	var canton_s := s0 + (s1 - s0) * 0.4
	var canton_y := y1 - stripe * 7.0
	_obox(f, s0, -0.16, canton_s, -0.1, canton_y, y1, Color(0.1, 0.2, 0.9), "neon")
	for row in 5:
		for col in 6:
			var s := lerpf(s0 + 0.2, canton_s - 0.2, (col + 0.5) / 6.0)
			var y := lerpf(canton_y + 0.15, y1 - 0.15, (row + 0.5) / 5.0)
			_obox(f, s - 0.06, -0.2, s + 0.06, -0.16, y - 0.06, y + 0.06, Color(1, 1, 1), "neon")


## The Torch, going up on 8th Avenue between 45th and 46th: a blue plywood fence,
## the concrete frame climbing floor by floor, the top floors in green netting
## and a yellow tower crane over it.
func _build_torch_site() -> void:
	var lot := Rect2(-260.6, -64.6, 56.1, 61.5)
	var fence := Color(0.18, 0.3, 0.6)
	var f := _frame(lot.get_center(), 0.0)
	var hs := lot.size.x * 0.5
	var ht := lot.size.y * 0.5
	for edge in [[-hs, -ht, hs, -ht], [-hs, ht, hs, ht], [-hs, -ht, -hs, ht], [hs, -ht, hs, ht]]:
		_ofence(f, edge[0], edge[1], edge[2], edge[3], 2.6, fence)
	for spot in [Vector2(lot.position.x - 0.1, -40.0), Vector2(lot.position.x - 0.1, -20.0)]:
		var label := Label3D.new()
		label.text = "POST NO BILLS"
		label.font_size = 64
		label.pixel_size = 0.012
		label.modulate = Color(0.95, 0.95, 0.95)
		label.position = _w(spot.x, spot.y, 1.6)
		label.rotation_degrees.y = -90.0
		label.visibility_range_end = 80.0
		add_child(label)
	_ground_label_rect(lot)
	var core := Rect2(-252.0, -56.0, 38.0, 44.0)
	var concrete := Color(0.62, 0.61, 0.58)
	var floors := 21
	var floor_h := 3.6
	for k in floors:
		var y := 0.8 + k * floor_h
		_box_un(core.position.x, core.position.y, core.end.x, core.end.y, y, y + 0.35, concrete)
	var top := 0.8 + floors * floor_h
	var u := core.position.x
	while u <= core.end.x + 0.01:
		var n := core.position.y
		while n <= core.end.y + 0.01:
			_box_un(u - 0.4, n - 0.4, u + 0.4, n + 0.4, 0.0, top + 3.0, concrete.darkened(0.05))
			n += core.size.y / 5.0
		u += core.size.x / 5.0
	# Lift core, netting round the working floors.
	_box_un(-238.0, -40.0, -228.0, -28.0, 0.0, top + 6.0, concrete.darkened(0.1))
	var net_y := 0.8 + (floors - 6) * floor_h
	for edge in [[core.position.x, core.position.y, core.end.x, core.position.y + 0.1], [core.position.x, core.end.y - 0.1, core.end.x, core.end.y],
			[core.position.x, core.position.y, core.position.x + 0.1, core.end.y], [core.end.x - 0.1, core.position.y, core.end.x, core.end.y]]:
		_box_un(edge[0] - 0.3, edge[1] - 0.3, edge[2] + 0.3, edge[3] + 0.3, net_y, top - 0.4, Color(0.2, 0.45, 0.3))
	_collider_between(_w(core.position.x, core.position.y), _w(core.end.x, core.end.y, top + 3.0))
	_blocked.append(lot)
	# Tower crane: mast, slewing unit, jib over the building, counter-jib with weights.
	var mast := Vector2(-210.0, -58.0)
	var yellow := Color(0.95, 0.72, 0.1)
	var mast_top := top + 30.0
	_box_un(mast.x - 1.0, mast.y - 1.0, mast.x + 1.0, mast.y + 1.0, 0.0, mast_top, yellow)
	var y := 4.0
	while y < mast_top:
		_box_un(mast.x - 1.05, mast.y - 1.05, mast.x + 1.05, mast.y + 1.05, y, y + 0.2, yellow.darkened(0.3))
		y += 4.0
	_box_un(mast.x - 1.6, mast.y - 1.6, mast.x + 1.6, mast.y + 1.6, mast_top, mast_top + 2.2, yellow.darkened(0.1))
	_box_un(mast.x - 0.5, mast.y - 0.5, mast.x + 0.5, mast.y + 0.5, mast_top + 2.2, mast_top + 9.0, yellow)
	var jib := Vector2(-1.0, 0.45).normalized()
	var jib_f := _frame(mast, rad_to_deg(jib.angle()))
	_obox(jib_f, 0.0, -0.7, 62.0, 0.7, mast_top + 1.0, mast_top + 2.4, yellow)
	_obox(jib_f, -22.0, -1.0, 0.0, 1.0, mast_top + 1.0, mast_top + 2.0, yellow)
	_obox(jib_f, -21.0, -1.2, -15.0, 1.2, mast_top - 1.5, mast_top + 1.0, concrete)
	_obox(jib_f, 1.0, -0.9, 3.5, 0.9, mast_top - 1.2, mast_top + 1.0, Color(0.85, 0.85, 0.8))
	_obox(jib_f, 38.0, -0.05, 38.1, 0.05, top + 6.0, mast_top + 1.0, Color(0.15, 0.15, 0.15))
	_obox(jib_f, 37.0, -0.6, 39.1, 0.6, top + 5.0, top + 6.0, Color(0.2, 0.2, 0.2))
	_collider_between(_w(mast.x - 1.0, mast.y - 1.0), _w(mast.x + 1.0, mast.y + 1.0, 20.0))


func _ground_label_rect(lot: Rect2) -> void:
	_grect(lot.position.x + 0.2, lot.position.y + 0.2, lot.end.x - 0.2, lot.end.y - 0.2, 0.012, Color(0.45, 0.4, 0.33), Surface.ASPHALT)


# ---------------------------------------------------------------- subway ----

## Subway entrances: [centre (u, n), runs along n, station, lines].
const SUBWAY := [
	[Vector2(11.0, 226.0), true, "Times Sq-42 St", "1 2 3 7 N Q R W S"],
	[Vector2(20.0, 102.0), true, "Times Sq-42 St", "1 2 3 7 N Q R W S"],
	[Vector2(-24.0, -44.0), true, "Times Sq-42 St", "1 2 3 7 N Q R W S"],
	[Vector2(255.7, 207.6), true, "42 St-Bryant Pk", "B D F M 7"],
	[Vector2(255.7, 229.0), true, "42 St-Bryant Pk", "B D F M 7"],
]


func _build_subway() -> void:
	for entry in SUBWAY:
		var c: Vector2 = entry[0]
		var f := _frame(c, 90.0 if entry[1] else 0.0)
		var hs := 2.4
		var ht := 0.95
		# The stairwell: dark, with the edges of the steps showing.
		_obox(f, -hs, -ht, hs, ht, 0.0, 0.02, Color(0.05, 0.05, 0.05))
		var k := 0
		var s := -hs + 0.3
		while s < hs:
			_obox(f, s, -ht + 0.1, s + 0.06, ht - 0.1, 0.02, 0.03, Color(0.35, 0.33, 0.3).darkened(k * 0.05))
			s += 0.32
			k += 1
		# Green iron railings round three sides, the open end at -s.
		var green := Color(0.1, 0.28, 0.18)
		for side in [-1.0, 1.0]:
			_obox(f, -hs, side * ht - 0.04, hs, side * ht + 0.04, 0.95, 1.05, green)
			var post := -hs
			while post <= hs + 0.01:
				_obox(f, post - 0.03, side * ht - 0.03, post + 0.03, side * ht + 0.03, 0.0, 0.95, green)
				post += 0.6
		_obox(f, hs - 0.04, -ht, hs + 0.04, ht, 0.0, 1.05, green)
		_ocollider(f, -hs, -ht - 0.05, hs + 0.05, ht + 0.05, 0.0, 1.1)
		_oblocked(f, -hs - 0.5, -ht - 0.5, hs + 0.5, ht + 0.5)
		# Lamp posts with green globes, and the station sign between them.
		for side in [-1.0, 1.0]:
			var p := _fp(f, -hs, side * ht)
			_cyl("solid", _w(p.x, p.y), 0.05, 2.3, green, 8)
			_globe("neon", _w(p.x, p.y, 2.55), 0.22, Color(0.3, 1.0, 0.45))
		_obox(f, -hs - 0.02, -ht, -hs + 0.02, ht, 1.5, 2.0, Color(0.05, 0.05, 0.05))
		var face := _fp(f, -hs - 0.04, 0.0)
		var label := Label3D.new()
		label.text = "%s\n%s" % [entry[2], entry[3]]
		label.font_size = 48
		label.pixel_size = 0.0045
		label.modulate = Color(1, 1, 1)
		label.outline_size = 0
		label.position = _w(face.x, face.y, 1.75)
		label.rotation_degrees.y = rad_to_deg(atan2(-(f[1] as Vector2).x, -(f[1] as Vector2).y))
		label.visibility_range_end = 50.0
		add_child(label)


# -------------------------------------------------------- street furniture ----

func _build_street_furniture() -> void:
	var rects := _roadways()
	# Lamps and hydrants along every kerb, a little in from it, clear of the corners.
	for index in rects.size():
		var r: Rect2 = rects[index]
		for edge in [[r.position.y, -1.0, true], [r.end.y, 1.0, true], [r.position.x, -1.0, false], [r.end.x, 1.0, false]]:
			var line: float = edge[0]
			var side: float = edge[1]
			var along_u: bool = edge[2]
			var a := r.position.x if along_u else r.position.y
			var b := r.end.x if along_u else r.end.y
			for interval in _uncovered(rects, index, a, b, line, along_u):
				var iv: Vector2 = interval
				if iv.y - iv.x < 14.0:
					continue
				var t := iv.x + 8.0
				var count := 0
				while t < iv.y - 6.0:
					var p := Vector2(t, line + side * 0.7) if along_u else Vector2(line + side * 0.7, t)
					if _on_island(p) and not _in_plaza(p):
						var toward := Vector2(0, -side) if along_u else Vector2(-side, 0)
						if count % 2 == 0:
							_nyc_lamp(p, toward)
						elif count % 4 == 1:
							_hydrant(p + (Vector2(4.0, 0) if along_u else Vector2(0, 4.0)))
						else:
							_trash_can(p)
					t += 26.0
					count += 1
	# Blue mailboxes and green newsstands on a few corners.
	for spot in [Vector2(-268.0, 93.0), Vector2(-12.6, 260.0), Vector2(262.0, 12.0), Vector2(-140.0, -82.0), Vector2(120.0, 176.0)]:
		_mailbox(spot)
	_newsstand(Vector2(260.6, 178.0), true)
	_newsstand(Vector2(-150.0, 241.6), false)
	# Con Ed steam stacks venting in the street.
	_steam_stack(Vector2(2.0, 120.0))
	_steam_stack(Vector2(-140.0, 5.6))
	_steam_stack(Vector2(150.0, 249.8))
	# Food carts with umbrellas on the plazas and corners.
	for cart in [[Vector2(-8.5, -60.0), 0.0], [Vector2(6.5, 70.0), 0.0], [Vector2(9.0, 180.0), 0.0], [Vector2(-262.0, -140.0), 0.0], [Vector2(-60.0, 12.6), 90.0]]:
		_food_cart(cart[0], cart[1])
	# Green sidewalk sheds under scaffolding on a few facades.
	_sidewalk_shed(Vector2(-200.0, 77.0), Vector2(-160.0, 77.0), -1.0)
	_sidewalk_shed(Vector2(120.0, -82.5), Vector2(160.0, -82.5), 1.0)
	_sidewalk_shed(Vector2(-256.0, 180.0), Vector2(-256.0, 220.0), 1.0)


func _on_island(p: Vector2) -> bool:
	return p.x > EDGE_W + 9.0 and p.x < EDGE_E - 9.0 and p.y > EDGE_N + 9.0 and p.y < EDGE_S - 9.0


func _in_plaza(p: Vector2) -> bool:
	return Rect2(-80.0, -148.1, 75.5, 147.9).has_point(p) or Rect2(3.5, 10.2, 81.5, 230.5).has_point(p)


## NYC street lamp: tall dark pole, an arm over the road, a flat LED head.
func _nyc_lamp(p: Vector2, toward: Vector2) -> void:
	var f := _frame(p, rad_to_deg(toward.angle()))
	_cyl("solid", _w(p.x, p.y), 0.2, 0.9, POLE.lightened(0.05), 8)
	_cyl("solid", _w(p.x, p.y), 0.12, 8.6, POLE, 8)
	_obox(f, 0.0, -0.06, 2.6, 0.06, 8.3, 8.42, POLE)
	_obox(f, 2.2, -0.22, 3.2, 0.22, 8.1, 8.32, Color(0.3, 0.32, 0.33))
	_obox(f, 2.25, -0.18, 3.15, 0.18, 8.07, 8.1, Color(0.9, 0.9, 0.85), "glow")
	_ocollider(f, -0.14, -0.14, 0.14, 0.14, 0.0, 8.6)


## NYC fire hydrant: squat iron body, silver bonnet, two side caps.
func _hydrant(p: Vector2) -> void:
	var body: Color = [Color(0.65, 0.08, 0.06), Color(0.1, 0.1, 0.1), Color(0.75, 0.6, 0.1)][_rng.randi() % 3]
	_cyl("solid", _w(p.x, p.y), 0.16, 0.12, body.darkened(0.3), 8)
	_cyl("solid", _w(p.x, p.y, 0.12), 0.12, 0.5, body, 8)
	_cone("solid", _w(p.x, p.y, 0.62), 0.14, 0.05, 0.14, Color(0.75, 0.76, 0.78), 8)
	_box_un(p.x - 0.22, p.y - 0.05, p.x + 0.22, p.y + 0.05, 0.38, 0.48, Color(0.75, 0.76, 0.78))


func _trash_can(p: Vector2) -> void:
	_cyl("solid", _w(p.x, p.y), 0.32, 0.85, Color(0.12, 0.3, 0.2), 10)
	_cyl("solid", _w(p.x, p.y, 0.85), 0.34, 0.05, Color(0.08, 0.2, 0.13), 10, true)


func _mailbox(p: Vector2) -> void:
	var blue := Color(0.1, 0.2, 0.55)
	_box_un(p.x - 0.4, p.y - 0.35, p.x + 0.4, p.y + 0.35, 0.15, 1.15, blue)
	_box_un(p.x - 0.4, p.y - 0.35, p.x + 0.4, p.y + 0.35, 1.15, 1.25, blue.lightened(0.1))
	for leg in [Vector2(-0.33, -0.28), Vector2(0.33, -0.28), Vector2(-0.33, 0.28), Vector2(0.33, 0.28)]:
		_box_un(p.x + leg.x - 0.04, p.y + leg.y - 0.04, p.x + leg.x + 0.04, p.y + leg.y + 0.04, 0.0, 0.15, blue.darkened(0.3))
	_collider_between(_w(p.x - 0.4, p.y - 0.35), _w(p.x + 0.4, p.y + 0.35, 1.25))


func _newsstand(p: Vector2, along_n: bool) -> void:
	var f := _frame(p, 90.0 if along_n else 0.0)
	var green := Color(0.15, 0.32, 0.22)
	_obox(f, -2.2, -1.0, 2.2, 1.0, 0.0, 2.5, green)
	_obox(f, -2.4, -1.25, 2.4, 1.25, 2.5, 2.7, green.darkened(0.2))
	_obox(f, -1.8, -1.02, 1.8, -1.0, 0.9, 2.1, Color(0.7, 0.6, 0.4), "glass")
	_face_label(f, 0.0, -1.27, 2.6, "NEWS", Color(1, 1, 1), 0.008, 64, -1.0)
	_ocollider(f, -2.2, -1.0, 2.2, 1.0, 0.0, 2.7)


## Orange and white striped Con Ed stack in the road, venting steam.
func _steam_stack(p: Vector2) -> void:
	for k in 6:
		var color := Color(1.0, 0.45, 0.05) if k % 2 == 0 else Color(0.95, 0.95, 0.95)
		_cone("solid", _w(p.x, p.y, k * 0.4), 0.42 - k * 0.025, 0.42 - (k + 1) * 0.025, 0.4, color, 12)
	var steam := CPUParticles3D.new()
	steam.name = "Steam"
	steam.position = _w(p.x, p.y, 2.4)
	steam.amount = 40
	steam.lifetime = 4.0
	steam.preprocess = 4.0
	steam.direction = Vector3.UP
	steam.spread = 12.0
	steam.initial_velocity_min = 1.6
	steam.initial_velocity_max = 2.6
	steam.gravity = Vector3(0.5, 0.3, 0.2)
	steam.scale_amount_min = 0.8
	steam.scale_amount_max = 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.6))
	steam.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	steam.color_ramp = fade
	var puff := QuadMesh.new()
	puff.size = Vector2(1.2, 1.2)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var tex := GradientTexture2D.new()
	var soft := Gradient.new()
	soft.set_color(0, Color(0.92, 0.92, 0.92, 1))
	soft.set_color(1, Color(0.92, 0.92, 0.92, 0))
	tex.gradient = soft
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	material.albedo_texture = tex
	puff.material = material
	steam.mesh = puff
	steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(steam)
	_collider_between(_w(p.x - 0.42, p.y - 0.42), _w(p.x + 0.42, p.y + 0.42, 2.4))


## Hot dog cart: steel box on wheels, a striped umbrella over it.
func _food_cart(p: Vector2, yaw: float) -> void:
	var f := _frame(p, yaw)
	var steel := Color(0.75, 0.76, 0.78)
	_obox(f, -0.9, -0.45, 0.9, 0.45, 0.35, 1.0, steel)
	_obox(f, -0.95, -0.5, 0.95, 0.5, 1.0, 1.08, steel.darkened(0.2))
	for wheel in [-0.6, 0.6]:
		_obox(f, wheel - 0.2, -0.5, wheel + 0.2, -0.45, 0.0, 0.4, Color(0.1, 0.1, 0.1))
		_obox(f, wheel - 0.2, 0.45, wheel + 0.2, 0.5, 0.0, 0.4, Color(0.1, 0.1, 0.1))
	_cyl("solid", _w(p.x, p.y, 1.08), 0.03, 1.2, steel, 6)
	for k in 8:
		var a0 := TAU * k / 8.0
		var color := Color(0.95, 0.8, 0.1) if k % 2 == 0 else Color(0.15, 0.35, 0.75)
		var st := _tool("solid", _w(p.x, p.y))
		st.set_color(color)
		var tip := _w(p.x, p.y, 2.75)
		var r := 1.25
		var p0 := _w(p.x + cos(a0) * r, p.y + sin(a0) * r, 2.25)
		var p1 := _w(p.x + cos(a0 + TAU / 8.0) * r, p.y + sin(a0 + TAU / 8.0) * r, 2.25)
		var normal := (p0 - tip).cross(p1 - tip).normalized()
		if normal.y < 0.0:
			normal = -normal
		st.set_normal(normal)
		_front_tri(st, tip, p0, p1, normal)
		_front_tri(st, tip, p1, p0, -normal)
	_ocollider(f, -0.9, -0.45, 0.9, 0.45, 0.0, 1.1)


## Sidewalk shed: steel posts, a deck at 3.2 m, green-painted plywood fascia.
## `side` is the street side of the line a-b (+1 = towards +n or +u).
func _sidewalk_shed(a: Vector2, b: Vector2, side: float) -> void:
	var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
	var half := a.distance_to(b) * 0.5
	var green := Color(0.17, 0.36, 0.24)
	var depth := 3.2 * side
	_obox(f, -half, 0.0, half, depth, 3.1, 3.4, Color(0.4, 0.35, 0.28))
	_obox(f, -half, depth - side * 0.05, half, depth + side * 0.05, 3.4, 4.3, green)
	var s := -half
	while s <= half + 0.01:
		_obox(f, s - 0.06, depth - 0.06, s + 0.06, depth + 0.06, 0.0, 3.1, Color(0.25, 0.25, 0.27))
		_ocollider(f, s - 0.07, depth - 0.07, s + 0.07, depth + 0.07, 0.0, 3.1)
		s += 3.0
	_obox(f, -half, depth - side * 0.08, half, depth + side * 0.08, 2.6, 2.7, Color(0.9, 0.75, 0.2), "glow")


# --------------------------------------------------------------- signals ----

## Traffic signals at every corner: a pole with a head for each direction, the
## pedestrian signal, and green street-name signs.
func _build_signals() -> void:
	var aves := [[AVE_8, "8 Av"], [AVE_7, "7 Av"], [AVE_6, "6 Av"]]
	for si in STREETS.size():
		var s: float = STREETS[si][1]
		var number: int = STREETS[si][0]
		var h := _street_half(number)
		for ai in aves.size():
			var span_n := _ave_span(ai, s - h - 1.0)
			var span_s := _ave_span(ai, s + h + 1.0)
			var corners := [
				Vector2(span_n.x - 0.8, s - h - 0.8), Vector2(span_n.y + 0.8, s - h - 0.8),
				Vector2(span_s.x - 0.8, s + h + 0.8), Vector2(span_s.y + 0.8, s + h + 0.8),
			]
			for ci in corners.size():
				var p: Vector2 = corners[ci]
				if not _on_island(p) or (_in_plaza(p) and ai == 1):
					continue
				_signal_pole(p, ci, ai, aves[ai][1], "W %d St" % number, ci == 1 or ci == 2)


func _signal_pole(p: Vector2, corner: int, _ai: int, avenue: String, street: String, with_names: bool) -> void:
	var dark := Color(0.12, 0.13, 0.12)
	_cyl("solid", _w(p.x, p.y), 0.11, 5.4, dark, 8)
	_collider_between(_w(p.x - 0.12, p.y - 0.12), _w(p.x + 0.12, p.y + 0.12, 5.4))
	# Heads: one looking along n (for avenue traffic, axis 0) and one along u (axis 1).
	var north := corner < 2
	var west := corner % 2 == 0
	_signal_head(_w(p.x, p.y, 4.2), Vector3(0, 0, -1.0 if north else 1.0), 0)
	_signal_head(_w(p.x, p.y, 3.0), Vector3(-1.0 if west else 1.0, 0, 0), 1)
	# Pedestrian heads facing across: an orange hand, a white walker.
	var ped := _w(p.x, p.y, 2.5)
	_box_un(p.x - 0.18, p.y - 0.18, p.x + 0.18, p.y + 0.18, 2.3, 2.75, Color(0.75, 0.6, 0.1))
	_add_box(_tool("glow", ped), ped + Vector3(-0.12, -0.15, -0.19), ped + Vector3(0.12, 0.15, 0.19), Color(1.0, 0.45, 0.1))
	if with_names:
		var green := Color(0.05, 0.38, 0.2)
		for sign in [[street, Vector3(1, 0, 0), 5.0], [avenue, Vector3(0, 0, 1), 5.35]]:
			var along: Vector3 = sign[1]
			var c := _w(p.x, p.y, sign[2])
			var half := along * 0.75 + Vector3(along.z, 0, along.x) * 0.02
			_add_box(_tool("solid", c), c - half - Vector3(0, 0.15, 0), c + half + Vector3(0, 0.15, 0), green)
			for face in [-1.0, 1.0]:
				var label := Label3D.new()
				label.text = sign[0]
				label.font_size = 48
				label.pixel_size = 0.006
				label.modulate = Color(1, 1, 1)
				label.outline_size = 0
				var normal: Vector3 = Vector3(along.z, 0, along.x) * face
				label.position = c + normal * 0.03
				label.rotation_degrees.y = rad_to_deg(atan2(normal.x, normal.z))
				label.visibility_range_end = 45.0
				add_child(label)


## Yellow three-lamp head on a short arm, facing `facing` (lamps on that side).
func _signal_head(at: Vector3, facing: Vector3, axis: int) -> void:
	var side := Vector3(facing.z, 0, -facing.x)
	var c := at + facing * 0.25 + side * 0.0
	var half := Vector3(0.2, 0.55, 0.2)
	_add_box(_tool("solid", c), c - half, c + half, Color(0.85, 0.68, 0.1))
	for k in 3:
		var lamp := c + facing * 0.21 + Vector3.UP * (0.35 - k * 0.35)
		var colours := [Color(1.0, 0.1, 0.05), Color(1.0, 0.7, 0.05), Color(0.1, 1.0, 0.45)]
		var r := Vector3(absf(side.x), 0, absf(side.z)) * 0.12 + Vector3(0, 0.12, 0) + Vector3(absf(facing.x), 0, absf(facing.z)) * 0.02
		_add_box(_tool("sig%d%d" % [axis, k], lamp), lamp - r, lamp + r, colours[k])


# ----------------------------------------------------------------- plaza ----

## Long granite benches, café tables and planters on the bowtie plazas.
func _build_plaza_furniture() -> void:
	var granite := Color(0.4, 0.4, 0.41)
	for bench in [[-12.0, -140.0, -100.0], [-12.0, -60.0, -15.0], [8.0, 20.0, 70.0], [8.0, 100.0, 125.0], [8.0, 155.0, 195.0]]:
		var u: float = bench[0]
		var n: float = float(bench[1])
		while n < bench[2]:
			_box_un(u - 0.35, n, u + 0.35, n + 9.0, 0.0, 0.46, granite)
			_collider_between(_w(u - 0.35, n), _w(u + 0.35, n + 9.0, 0.46))
			n += 12.0
	var red := Color(0.75, 0.12, 0.1)
	for spot in [Vector2(-28.0, -30.0), Vector2(-26.0, -20.0), Vector2(-30.0, -10.0), Vector2(26.0, 35.0), Vector2(30.0, 45.0), Vector2(24.0, 140.0), Vector2(28.0, 150.0)]:
		_cyl("solid", _w(spot.x, spot.y), 0.04, 0.72, Color(0.15, 0.15, 0.15), 6)
		_cyl("solid", _w(spot.x, spot.y, 0.72), 0.4, 0.04, Color(0.2, 0.2, 0.2), 12)
		for k in 3:
			var a: float = TAU * k / 3.0 + spot.x
			var c: Vector2 = spot + Vector2(cos(a), sin(a)) * 0.75
			_box_un(c.x - 0.22, c.y - 0.22, c.x + 0.22, c.y + 0.22, 0.42, 0.47, red)
			_box_un(c.x - 0.2, c.y - 0.2, c.x + 0.2, c.y + 0.2, 0.0, 0.42, red.darkened(0.5))
	for spot in [Vector2(-16.0, -147.0), Vector2(-26.0, -147.0), Vector2(6.0, 238.0), Vector2(14.0, 160.0)]:
		_box_un(spot.x - 1.5, spot.y - 0.8, spot.x + 1.5, spot.y + 0.8, 0.0, 0.7, Color(0.32, 0.32, 0.34))
		_box_un(spot.x - 1.4, spot.y - 0.7, spot.x + 1.4, spot.y + 0.7, 0.7, 1.2, Color(0.25, 0.5, 0.22))
		_collider_between(_w(spot.x - 1.5, spot.y - 0.8), _w(spot.x + 1.5, spot.y + 0.8, 0.7))


# ------------------------------------------------------------- promenade ----

## The waterfront: a black iron railing on the sea wall, benches looking out to
## sea, old-style lamp posts, and trees along the sidewalk.
func _build_promenade() -> void:
	var line := _island_outline(1.0)
	var lamp_every := 26.0
	var bench_every := 18.0
	var travelled := 0.0
	var next_lamp := 10.0
	var next_bench := 4.0
	for index in line.size():
		var a := line[index]
		var b := line[(index + 1) % line.size()]
		var length := a.distance_to(b)
		var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
		var half := length * 0.5
		# Railing: top rail, mid rail, posts every 1.6 m.
		_obox(f, -half, -0.04, half, 0.04, 1.02, 1.1, IRON)
		_obox(f, -half, -0.025, half, 0.025, 0.5, 0.55, IRON)
		var s := -half
		while s < half:
			_obox(f, s - 0.03, -0.03, s + 0.03, 0.03, 0.0, 1.02, IRON)
			s += 1.6
		while next_lamp < travelled + length:
			var p := _fp(f, next_lamp - travelled - half, 2.2)
			_cyl("solid", _w(p.x, p.y), 0.14, 0.6, IRON, 8)
			_cyl("solid", _w(p.x, p.y), 0.07, 3.8, IRON, 8)
			_cone("solid", _w(p.x, p.y, 3.8), 0.12, 0.25, 0.25, IRON, 8)
			_cyl("neon", _w(p.x, p.y, 4.05), 0.22, 0.45, Color(1.0, 0.92, 0.75), 8, false)
			_cone("solid", _w(p.x, p.y, 4.5), 0.3, 0.0, 0.3, IRON, 8)
			_collider_between(_w(p.x - 0.12, p.y - 0.12), _w(p.x + 0.12, p.y + 0.12, 4.0))
			next_lamp += lamp_every
		while next_bench < travelled + length:
			var bs := next_bench - travelled - half
			if absf(bs) < half - 1.2:
				_promenade_bench(f, bs, 3.4)
			next_bench += bench_every
		travelled += length
	# Trees along the sidewalk side of the promenade.
	var inner := _island_outline(6.5)
	var since := 0.0
	for index in inner.size():
		var a := inner[index]
		var b := inner[(index + 1) % inner.size()]
		var length := a.distance_to(b)
		var t := 6.0 - since
		while t < length:
			var p := a.lerp(b, t / length)
			_trees.append(["leafy", Vector3(p.x, 0, p.y), _rng.randf_range(1.0, 1.35)])
			_tree_pit(p)
			t += 14.0
		since = length - (t - 14.0)


## Bench along a frame at s, t (t inward), looking out to sea (-t).
func _promenade_bench(f: Array, s: float, t: float) -> void:
	var wood := Color(0.5, 0.34, 0.2)
	_obox(f, s - 1.0, t - 0.25, s + 1.0, t + 0.2, 0.42, 0.48, wood)
	_obox(f, s - 1.0, t + 0.15, s + 1.0, t + 0.23, 0.5, 0.9, wood)
	for leg in [-0.85, 0.85]:
		_obox(f, s + leg - 0.04, t - 0.22, s + leg + 0.04, t + 0.22, 0.0, 0.48, IRON)
	_ocollider(f, s - 1.0, t - 0.25, s + 1.0, t + 0.23, 0.0, 0.5)


## Square tree pit with a low iron guard, as on Manhattan sidewalks.
func _tree_pit(p: Vector2) -> void:
	_box_un(p.x - 0.75, p.y - 0.75, p.x + 0.75, p.y + 0.75, 0.0, 0.03, Color(0.22, 0.17, 0.12))
	for edge in [[-0.78, -0.78, 0.78, -0.74], [-0.78, 0.74, 0.78, 0.78], [-0.78, -0.78, -0.74, 0.78], [0.74, -0.78, 0.78, 0.78]]:
		_box_un(p.x + edge[0], p.y + edge[1], p.x + edge[2], p.y + edge[3], 0.35, 0.42, IRON)
	for corner in [Vector2(-0.76, -0.76), Vector2(0.76, -0.76), Vector2(-0.76, 0.76), Vector2(0.76, 0.76)]:
		_box_un(p.x + corner.x - 0.025, p.y + corner.y - 0.025, p.x + corner.x + 0.025, p.y + corner.y + 0.025, 0.0, 0.42, IRON)


## OSM street trees (Bryant Park side of 6th Avenue, Broadway north of 47th) and
## a few more along the side streets, each in its pit.
func _plant_trees() -> void:
	for point in _data.get("points", []):
		if str(point["kind"]) == "tree":
			var p := Vector2(float(point["at"][0]), float(point["at"][1]))
			if _on_island(p):
				_trees.append(["leafy", Vector3(p.x, 0, p.y), _rng.randf_range(0.95, 1.25)])
				_tree_pit(p)
	for street in [[46, -73.8], [44, 84.8], [43, 163.8], [48, -231.5]]:
		var s: float = street[1]
		for side in [-1.0, 1.0]:
			var n: float = s + side * (STREET_HALF + 1.0)
			var u := -250.0 + _rng.randf_range(0.0, 10.0)
			while u < 245.0:
				var p := Vector2(u, n)
				if absf(u - AVE_7) > 70.0 and absf(u - AVE_8) > 25.0 and absf(u - AVE_6) > 25.0 and _rng.randf() < 0.45:
					_trees.append(["leafy", Vector3(p.x, 0, p.y), _rng.randf_range(0.85, 1.15)])
					_tree_pit(p)
				u += 17.0


# ---------------------------------------------------------------- boats ----

func _build_boats() -> void:
	# A ferry, a tug and a sailing yacht circling the island at different distances.
	_boats.append([_boat_mesh("ferry"), 470.0, 6.0, 0.4, 0.15])
	_boats.append([_boat_mesh("tug"), 380.0, -4.0, 2.5, 0.25])
	_boats.append([_boat_mesh("yacht"), 560.0, 3.0, 4.4, 0.35])
	_boats.append([_boat_mesh("ferry"), 700.0, -5.0, 1.6, 0.15])


func _boat_mesh(kind: String) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := func(a: Vector3, b: Vector3, color: Color) -> void:
		_add_box(st, a, b, color)
	match kind:
		"ferry":
			var orange := Color(0.95, 0.45, 0.1)
			box.call(Vector3(-7, 0, -30), Vector3(7, 3.5, 30), orange)
			box.call(Vector3(-7.4, 3.5, -31), Vector3(7.4, 4.0, 31), Color(0.2, 0.2, 0.2))
			box.call(Vector3(-6, 4.0, -24), Vector3(6, 7.5, 24), orange)
			box.call(Vector3(-6.05, 5.0, -24), Vector3(6.05, 6.5, 24), Color(0.15, 0.2, 0.25))
			box.call(Vector3(-4, 7.5, -10), Vector3(4, 10.0, 10), Color(0.95, 0.95, 0.95))
			box.call(Vector3(-0.8, 10, -1), Vector3(0.8, 13.5, 1), Color(0.2, 0.2, 0.2))
		"tug":
			box.call(Vector3(-3.5, 0, -10), Vector3(3.5, 2.2, 10), Color(0.15, 0.15, 0.15))
			box.call(Vector3(-3.6, 2.2, -10.2), Vector3(3.6, 2.6, 10.2), Color(0.7, 0.1, 0.08))
			box.call(Vector3(-2.5, 2.6, -4), Vector3(2.5, 5.5, 3), Color(0.95, 0.95, 0.92))
			box.call(Vector3(-2.6, 4.3, -4.05), Vector3(2.6, 5.0, 3.05), Color(0.15, 0.2, 0.25))
			box.call(Vector3(-0.6, 5.5, -1), Vector3(0.6, 8.5, 0.2), Color(0.9, 0.75, 0.1))
		_:
			box.call(Vector3(-2, 0, -6), Vector3(2, 1.4, 6), Color(0.95, 0.95, 0.95))
			box.call(Vector3(-1.2, 1.4, -2), Vector3(1.2, 2.2, 2.5), Color(0.85, 0.85, 0.82))
			box.call(Vector3(-0.1, 1.4, -0.5), Vector3(0.1, 13.0, -0.3), Color(0.8, 0.8, 0.8))
			var sail := Color(0.98, 0.98, 0.96)
			st.set_color(sail)
			st.set_normal(Vector3.RIGHT)
			for tri in [[Vector3(0, 2.0, -0.2), Vector3(0, 12.5, -0.3), Vector3(0, 2.0, 5.0)]]:
				st.add_vertex(tri[0])
				st.add_vertex(tri[1])
				st.add_vertex(tri[2])
				st.add_vertex(tri[0])
				st.add_vertex(tri[2])
				st.add_vertex(tri[1])
	var node := MeshInstance3D.new()
	node.name = "Boat_" + kind
	var mesh := st.commit()
	mesh.surface_set_material(0, _vertex_material())
	node.mesh = mesh
	add_child(node)
	return node


# --------------------------------------------------------------- traffic ----

## Parked cars along the side-street kerbs of the theatre district.
func _spawn_cars() -> void:
	for street in STREETS:
		var number: int = street[0]
		if number == 42:
			continue
		var s: float = street[1]
		for side in [-1.0, 1.0]:
			var n: float = s + side * (STREET_HALF - 1.1)
			for block in [[AVE_8 + 22.0, -40.0], [24.0, AVE_6 - 24.0]]:
				var u: float = block[0]
				while u < block[1]:
					if _rng.randf() < 0.22:
						_car_spots.append(_car_transform(u, n, 90.0))
					u += 5.6
	super._spawn_cars()


func _build_traffic() -> void:
	var traffic := Node3D.new()
	traffic.name = "Traffic"
	traffic.set_script(load("res://traffic.gd"))
	var models := []
	var others := []
	for model in CAR_MODELS:
		var mesh := _car_mesh(model[0])
		if mesh != null:
			others.append([mesh, model[2], _materials.get("car_paint")])
	if others.is_empty():
		return
	# Yellow cabs (blender/scripts/build_vehicles.py "car_taxi", lit roof sign and all): half the traffic.
	var taxi_mesh := _car_mesh("res://assets/vehicles/car_taxi.glb")
	if taxi_mesh == null:
		taxi_mesh = others[0][0]
	var taxi := [taxi_mesh, Vector3(1.84, 1.75, 4.88), _materials.get("car_paint"), TAXI_YELLOW]
	for k in others.size():
		models.append(taxi)
		models.append(others[k])
	traffic.set("models", models)
	traffic.set("colors", [Color(0.05, 0.05, 0.06), Color(0.93, 0.93, 0.92), Color(0.62, 0.64, 0.66), Color(0.3, 0.31, 0.33), Color(0.12, 0.18, 0.35), Color(0.5, 0.06, 0.06)])
	var lanes := _traffic_lanes()
	traffic.set("lanes", lanes)
	traffic.set("stops", _traffic_stops(lanes))
	add_child(traffic)


## One-way loops that follow the real directions: 7th Avenue south, 8th and 6th
## north, even streets east, odd streets west, 42nd both ways.
func _traffic_lanes() -> Array:
	var l7 := -3.3
	var m7 := -0.5
	var r7 := 2.3
	return [
		# 7th south -> 41st west -> 8th north -> 48th east.
		[[Vector2(l7, -229.8), Vector2(l7, 331.3), Vector2(-276.5, 331.3), Vector2(-276.5, -229.8), Vector2(l7, -229.8)], 6],
		# 6th north -> 47th west -> 7th south -> 44th east.
		[[Vector2(269.5, 86.5), Vector2(269.5, -155.0), Vector2(r7, -155.0), Vector2(r7, 86.5), Vector2(269.5, 86.5)], 4],
		# 42nd east -> 6th north -> 45th west -> 7th south.
		[[Vector2(m7, 251.2), Vector2(273.0, 251.2), Vector2(273.0, 3.3), Vector2(m7, 3.3), Vector2(m7, 251.2)], 4],
		# 7th south -> 42nd west -> 8th north -> 46th east.
		[[Vector2(l7, -72.1), Vector2(l7, 247.2), Vector2(-273.0, 247.2), Vector2(-273.0, -72.1), Vector2(l7, -72.1)], 4],
		# 42nd east -> 6th north -> 43rd west -> 7th south.
		[[Vector2(m7, 252.8), Vector2(276.5, 252.8), Vector2(276.5, 162.1), Vector2(m7, 162.1), Vector2(m7, 252.8)], 3],
	]


## Stop lines before each crossing a lane passes, for traffic.gd's lights.
func _traffic_stops(lanes: Array) -> Array:
	var result := []
	var aves := [AVE_8, AVE_7, AVE_6]
	for lane in lanes:
		var points: Array = lane[0]
		var stops := []
		var travelled := 0.0
		for index in points.size() - 1:
			var a: Vector2 = points[index]
			var b: Vector2 = points[index + 1]
			var length := a.distance_to(b)
			var dir := (b - a) / length
			if absf(dir.y) > 0.9:
				# Along n: stop before each street.
				for street in STREETS:
					var h := _street_half(int(street[0]))
					var line: float = float(street[1]) - dir.y * (h + 5.0)
					var t := (line - a.y) / dir.y
					if t > 2.0 and t < length:
						stops.append([travelled + t, 0])
			else:
				for ai in aves.size():
					var span := _ave_span(ai, a.y)
					var line := (span.x - 5.0) if dir.x > 0.0 else (span.y + 5.0)
					var t := (line - a.x) / dir.x
					if t > 2.0 and t < length:
						stops.append([travelled + t, 1])
			travelled += length
		result.append(stops)
	return result
