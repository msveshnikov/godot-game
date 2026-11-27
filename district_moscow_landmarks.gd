extends "res://district_europe.gd"
## Walkable landmarks in the stylized Moscow district.

const BRICK_RED := Color(0.60, 0.20, 0.15)
const BRICK_SHADE := Color(0.42, 0.10, 0.085)
const WHITE_STONE := Color(0.92, 0.83, 0.70)
const ROOF_GREEN := Color(0.12, 0.30, 0.22)
const GILT := Color(0.98, 0.70, 0.26)
const WINDOW := Color(0.13, 0.18, 0.20)
const PARK_BOUNDS := Rect2(95, 14, 72, 124)
const PARK_WALK := [
	Vector2(91, 96), Vector2(104, 96), Vector2(113, 81), Vector2(111, 62),
	Vector2(116, 47), Vector2(127, 37), Vector2(147, 43), Vector2(154, 58),
	Vector2(149, 76), Vector2(154, 92), Vector2(146, 108), Vector2(126, 115),
	Vector2(112, 107),
]
const KREMLIN_WALK := [
	Vector2(-42, 33), Vector2(-56, 33), Vector2(-65, 33), Vector2(-65, 48),
	Vector2(-71, 48), Vector2(-71, 19), Vector2(-66, 8), Vector2(-64, -8),
	Vector2(-67, -21), Vector2(-67, -31),
]
const KREMLIN_HALL_WALK := [
	Vector2(-67, -34), Vector2(-67, -42), Vector2(-67, -49), Vector2(-67, -55),
]
const PARK_PAVING := Color(0.72, 0.67, 0.57)
const PARK_LEAVES := Color(0.37, 0.55, 0.23)
const PARK_STEEL := Color(0.34, 0.39, 0.37)
const COURT_PAVING := Color(0.56, 0.50, 0.45)
const AMPHITHEATRE_CENTRE := Vector2(130, 67)
const TERRACE_ROWS := 5
const TERRACE_RADIUS := 4.8
const TERRACE_DEPTH := 1.75
const TERRACE_RISE := 0.29
const AISLE_HALF_WIDTH := 1.55
const AMPHITHEATRE_APPROACH := Vector2(130, 45)
const AMPHITHEATRE_APRON := Vector2(130, 63.6)
const BRIDGE_HALF_WIDTH := 1.95
const BRIDGE_CORNERS := [Vector2(125, 118), Vector2(135, 124), Vector2(150, 135),
	Vector2(155, 122), Vector2(155, 110)]


func _build_zaryadye() -> void:
	var park_edge := PackedVector2Array([Vector2(95, 23), Vector2(107, 14), Vector2(155, 18),
		Vector2(167, 41), Vector2(165, 108), Vector2(157, 138), Vector2(109, 132), Vector2(95, 115)])
	_gpoly(park_edge, 0.023, PARK_LEAVES, Surface.GRASS)
	for i in PARK_WALK.size() - 1:
		_gstrip(PARK_WALK[i], PARK_WALK[i + 1], 4.7, 0.049, PARK_PAVING, Surface.GRANITE)
	for i in range(1, PARK_WALK.size()):
		_park_path_rounding(PARK_WALK[i], 2.35, 0.049)
	_gstrip(PARK_WALK[-1], PARK_WALK[1], 4.7, 0.049, PARK_PAVING, Surface.GRANITE)
	_gstrip(Vector2(83, 96), PARK_WALK[0], 4.7, 0.053, PARK_PAVING, Surface.GRANITE)
	_grect(97, 92, 111, 100, 0.053, PARK_PAVING, Surface.GRANITE)
	_park_entrance()
	_zaryadye_amphitheatre()
	_zaryadye_bridge()
	_park_planting()


func _park_entrance() -> void:
	var sign := _frame(Vector2(99, 91), -60)
	_obox(sign, -2.9, -0.16, 2.9, 0.18, 0.08, 2.65, PARK_STEEL)
	_sign_panel(sign, 0, -0.17, 1.78, 5.45, 0.9, "ЗАРЯДЬЕ", ROOF_GREEN, WHITE_STONE)
	_lantern(Vector2(96.2, 100.4), 4.15)
	_lantern(Vector2(106.4, 91.5), 4.15)


func _park_planting() -> void:
	for point in [Vector2(103, 39), Vector2(102, 61), Vector2(101, 77), Vector2(116, 27),
			Vector2(132, 23), Vector2(149, 29), Vector2(159, 38), Vector2(161, 64),
			Vector2(160, 81), Vector2(163, 100), Vector2(107, 117), Vector2(119, 126)]:
		var kind := "birch" if _rng.randf() < 0.42 else "street_tree"
		_trees.append([kind, _w(point.x, point.y), _rng.randf_range(0.73, 1.08)])
	for point in [Vector2(105, 67), Vector2(124, 29), Vector2(151, 49), Vector2(156, 84),
			Vector2(107, 103), Vector2(119, 116)]:
		_city_bench(_frame(point, 25), 0)
		_lantern(point + Vector2(2.7, 1.5), 3.8)
	for meadow in [Rect2(117, 74, 28, 10), Rect2(118, 93, 23, 10), Rect2(100, 108, 8, 20),
			Rect2(103, 18, 51, 7), Rect2(156, 49, 8, 32)]:
		for sprig in 22:
			var point := Vector2(_rng.randf_range(meadow.position.x, meadow.end.x),
				_rng.randf_range(meadow.position.y, meadow.end.y))
			var base := _w(point.x, point.y, 0.032)
			var height := _rng.randf_range(0.21, 0.62)
			_cone("solid", base, 0.12, 0.045, height, PARK_LEAVES.darkened(_rng.randf_range(0.0, 0.24)), 5)
			if sprig % 3 == 0:
				_globe("solid", base + Vector3.UP * height, 0.087, GILT if sprig % 2 == 0 else WHITE_STONE)


func _zaryadye_amphitheatre() -> void:
	var stage := _frame(AMPHITHEATRE_CENTRE, 0)
	_obox(stage, -9.5, -2.1, 9.5, 4.3, 0.04, 0.25, WHITE_STONE)
	_obox(stage, -8.9, -2.0, 8.9, 4.15, 0.24, 0.29, Color(0.56, 0.40, 0.26))
	_sign_panel(_frame(Vector2(130, 70.1), 0), 0, -0.05, 0.72, 8.4, 0.63,
		"ЛЕТНИЙ АМФИТЕАТР", PARK_STEEL, WHITE_STONE)
	_gstrip(PARK_WALK[5], AMPHITHEATRE_APPROACH, 3.1, 0.052, PARK_PAVING, Surface.GRANITE)
	_park_path_rounding(AMPHITHEATRE_APPROACH, AISLE_HALF_WIDTH, 0.052)
	var faces := PackedVector3Array()
	for side: float in [-1.0, 1.0]:
		for row in TERRACE_ROWS:
			var radius := TERRACE_RADIUS + row * TERRACE_DEPTH
			var height := (row + 1) * TERRACE_RISE
			_terrace_band(radius, radius + TERRACE_DEPTH, height - TERRACE_RISE, height, side,
				PARK_PAVING, WHITE_STONE, faces, 0.0, row == TERRACE_ROWS - 1)
			_terrace_band(radius + 1.10, radius + 1.57, height, height + 0.20, side,
				Color(0.49, 0.31, 0.18), Color(0.38, 0.24, 0.16), faces, height, true)
	_amphitheatre_stairs(faces)
	_park_collider("Amphitheatre", faces)
	_glass_canopy(Vector2(130, 56))


func _terrace_band(inner: float, outer: float, bottom: float, top: float, side: float,
		paving: Color, edge: Color, faces: PackedVector3Array, base: float, close_back: bool) -> void:
	const SEGMENTS := 24
	for i in SEGMENTS:
		var t0 := float(i) / SEGMENTS
		var t1 := float(i + 1) / SEGMENTS
		var a := _terrace_point(inner, top, side, t0)
		var b := _terrace_point(inner, top, side, t1)
		var c := _terrace_point(outer, top, side, t1)
		var d := _terrace_point(outer, top, side, t0)
		var inward := Vector3(AMPHITHEATRE_CENTRE.x - (a.x + b.x) * 0.5, 0,
			AMPHITHEATRE_CENTRE.y - (a.z + b.z) * 0.5).normalized()
		_park_face(a, b, c, d, Vector3.UP, paving, faces)
		_park_face(a, b, _at_height(b, bottom), _at_height(a, bottom), inward, edge, faces)
		if close_back:
			_park_face(c, d, _at_height(d, base), _at_height(c, base), -inward, edge, faces)
		if i == 0:
			_park_face(d, a, _at_height(a, base), _at_height(d, base), Vector3.BACK, edge, faces)
		if i == SEGMENTS - 1:
			_park_face(b, c, _at_height(c, base), _at_height(b, base), -Vector3.RIGHT * side, edge, faces)


func _terrace_point(radius: float, height: float, side: float, fraction: float) -> Vector3:
	var angle := lerpf(0.0, acos(AISLE_HALF_WIDTH / radius), fraction)
	return Vector3(AMPHITHEATRE_CENTRE.x + side * radius * cos(angle), height,
		AMPHITHEATRE_CENTRE.y - radius * sin(angle))


func _amphitheatre_stairs(faces: PackedVector3Array) -> void:
	var left := _terrace_point(TERRACE_RADIUS, 0.0, -1.0, 1.0)
	var right := _terrace_point(TERRACE_RADIUS, 0.0, 1.0, 1.0)
	var grade := PackedVector3Array([Vector3(AMPHITHEATRE_CENTRE.x, 0, AMPHITHEATRE_APRON.y)])
	var visual_only := PackedVector3Array()
	for step in TERRACE_ROWS * 2:
		var radius := TERRACE_RADIUS + (step + 1) * TERRACE_DEPTH * 0.5
		var height := (step + 1) * TERRACE_RISE * 0.5
		var a := _at_height(left, height)
		var b := _at_height(right, height)
		var c := _terrace_point(radius, height, 1.0, 1.0)
		var d := _terrace_point(radius, height, -1.0, 1.0)
		_park_face(a, b, c, d, Vector3.UP, PARK_PAVING.lightened(0.13), visual_only, "solid", false)
		_park_face(left, right, b, a, Vector3.BACK, WHITE_STONE, visual_only, "solid", false)
		grade.append((a + b) * 0.5)
		left = d
		right = c
	grade.append((left + right) * 0.5)
	# A continuous floor under the stair profile lets characters climb without jumping.
	for i in grade.size() - 1:
		var offset := Vector3.RIGHT * AISLE_HALF_WIDTH
		var a := grade[i]
		var b := grade[i + 1]
		_park_collision_quad(faces, a - offset, a + offset, b + offset, b - offset, Vector3.UP)
	var landing := grade[-1]
	for i in 12:
		var t0 := float(i) / 12.0
		var t1 := float(i + 1) / 12.0
		var a := landing.lerp(_w(AMPHITHEATRE_APPROACH.x, AMPHITHEATRE_APPROACH.y), t0)
		var b := landing.lerp(_w(AMPHITHEATRE_APPROACH.x, AMPHITHEATRE_APPROACH.y), t1)
		a.y = landing.y * (1.0 - smoothstep(0.0, 1.0, t0))
		b.y = landing.y * (1.0 - smoothstep(0.0, 1.0, t1))
		var offset := Vector3.RIGHT * AISLE_HALF_WIDTH
		var normal := Vector3.RIGHT.cross(b - a).normalized()
		_park_face(a - offset, a + offset, b + offset, b - offset, normal, PARK_PAVING, faces)
		for side: float in [-1.0, 1.0]:
			var p := a + offset * side
			var q := b + offset * side
			_park_face(p, q, _at_height(q, -0.04), _at_height(p, -0.04), Vector3.RIGHT * side, WHITE_STONE, faces)


func _amphitheatre_walk() -> Array[Vector2]:
	var walk: Array[Vector2] = [PARK_WALK[5].lerp(AMPHITHEATRE_APPROACH, 0.35), AMPHITHEATRE_APPROACH]
	for z in [49.0, 52.5, 55.5, 59.0]:
		walk.append(Vector2(AMPHITHEATRE_CENTRE.x, z))
	walk.append(AMPHITHEATRE_APRON)
	return walk


func _glass_canopy(centre: Vector2) -> void:
	const SIDES := 18
	const BANDS := 4
	for ring in BANDS:
		for spoke in SIDES:
			var a := _canopy_point(centre, ring, spoke)
			var b := _canopy_point(centre, ring + 1, spoke)
			var c := _canopy_point(centre, ring + 1, spoke + 1)
			var d := _canopy_point(centre, ring, spoke + 1)
			var surface := _tool("glass", b)
			surface.set_color(Color(0.58, 0.79, 0.78) if (ring + spoke) % 3 == 0 else Color(0.70, 0.82, 0.82))
			var normal := (c - b).cross(a - b).normalized()
			if normal.y < 0.0:
				normal = -normal
			surface.set_normal(normal)
			_front_quad(surface, a, b, c, d, normal)
			_sloped_box(a, b, 0.058, 0.058, PARK_STEEL)
			_sloped_box(b, c, 0.058, 0.058, PARK_STEEL)
	for spoke in [1, 5, 9, 13, 16]:
		var top := _canopy_point(centre, BANDS, spoke)
		_cyl("solid", Vector3(top.x, 0.05, top.z), 0.15, top.y, PARK_STEEL, 8)


func _canopy_point(centre: Vector2, ring: int, spoke: int) -> Vector3:
	var angle := TAU * spoke / 18.0
	var radius := 0.13 + float(ring) * (0.87 / 4.0)
	var plan := centre + Vector2(cos(angle) * 13.3, sin(angle) * 13.3) * radius
	return _w(plan.x, plan.y, 3.65 + 4.6 * (1.0 - radius * radius) + 0.37 * cos(angle))


func _zaryadye_bridge() -> void:
	var water := PackedVector2Array([Vector2(135, 118), Vector2(148, 111), Vector2(160, 114),
		Vector2(164, 125), Vector2(155, 137), Vector2(139, 136), Vector2(131, 128)])
	_gpoly(water, 0.048, Color(0.13, 0.29, 0.32), Surface.GRANITE)
	for i in water.size():
		_gstrip(water[i], water[(i + 1) % water.size()], 0.65, 0.052, PARK_PAVING, Surface.GRANITE)
	_gstrip(PARK_WALK[11], BRIDGE_CORNERS[0], BRIDGE_HALF_WIDTH * 2.0, 0.052, PARK_PAVING, Surface.GRANITE)
	_gstrip(PARK_WALK[10], BRIDGE_CORNERS[-1], BRIDGE_HALF_WIDTH * 2.0, 0.052, PARK_PAVING, Surface.GRANITE)
	_park_path_rounding(BRIDGE_CORNERS[0], BRIDGE_HALF_WIDTH + 0.25, 0.052)
	_park_path_rounding(BRIDGE_CORNERS[-1], BRIDGE_HALF_WIDTH + 0.25, 0.052)
	var plan := _bridge_plan()
	var distance := PackedFloat32Array([0.0])
	for i in range(1, plan.size()):
		distance.append(distance[-1] + plan[i - 1].distance_to(plan[i]))
	var centres := PackedVector3Array()
	var offsets := PackedVector3Array()
	for i in plan.size():
		var tangent := (plan[i] - plan[maxi(i - 1, 0)]).normalized()
		tangent += (plan[mini(i + 1, plan.size() - 1)] - plan[i]).normalized()
		var side := tangent.normalized().orthogonal()
		offsets.append(Vector3(side.x, 0, side.y))
		var from_end := minf(distance[i], distance[-1] - distance[i])
		var y := 2.9 * smoothstep(0.0, 15.0, from_end)
		centres.append(_w(plan[i].x, plan[i].y, y))
	var faces := PackedVector3Array()
	var rail_faces := PackedVector3Array()
	for i in plan.size() - 1:
		var a := centres[i]
		var b := centres[i + 1]
		var offset_a := offsets[i] * BRIDGE_HALF_WIDTH
		var offset_b := offsets[i + 1] * BRIDGE_HALF_WIDTH
		var normal := (b - a).cross(offset_a + offset_b).normalized()
		if normal.y < 0.0:
			normal = -normal
		_park_face(a - offset_a, a + offset_a, b + offset_b, b - offset_b, normal,
			PARK_PAVING.lightened(0.18), faces)
		for side: float in [-1.0, 1.0]:
			var p := a + offset_a * side
			var q := b + offset_b * side
			var outward := (offsets[i] + offsets[i + 1]).normalized() * side
			_park_face(p, q, q - Vector3.UP * 0.40, p - Vector3.UP * 0.40, outward, WHITE_STONE, faces)
			_bridge_rail(p - offsets[i] * side * 0.07, q - offsets[i + 1] * side * 0.07,
				offsets[i] * side, offsets[i + 1] * side, rail_faces)
			if i % 4 == 0:
				_cyl("solid", p - offsets[i] * side * 0.07, 0.045, 1.06, PARK_STEEL, 8)
			if i == plan.size() - 2:
				_cyl("solid", q - offsets[i + 1] * side * 0.07, 0.045, 1.06, PARK_STEEL, 8)
		_park_face(a - offset_a - Vector3.UP * 0.40, a + offset_a - Vector3.UP * 0.40,
			b + offset_b - Vector3.UP * 0.40, b - offset_b - Vector3.UP * 0.40,
			-normal, WHITE_STONE.darkened(0.22), faces)
	_park_collider("FloatingBridgeDeck", faces)
	_park_collider("FloatingBridgeRails", rail_faces, true)


func _bridge_plan() -> PackedVector2Array:
	var plan := PackedVector2Array([BRIDGE_CORNERS[0]])
	for i in range(1, BRIDGE_CORNERS.size() - 1):
		var corner: Vector2 = BRIDGE_CORNERS[i]
		var trim := 7.0 if i == 2 else 3.5
		var start := corner.move_toward(BRIDGE_CORNERS[i - 1], trim)
		var finish := corner.move_toward(BRIDGE_CORNERS[i + 1], trim)
		_extend_bridge_plan(plan, start)
		var divisions := ceili(trim * 3.0)
		for j in range(1, divisions + 1):
			var t := float(j) / divisions
			plan.append(start.lerp(corner, t).lerp(corner.lerp(finish, t), t))
	_extend_bridge_plan(plan, BRIDGE_CORNERS[-1])
	return plan


func _extend_bridge_plan(plan: PackedVector2Array, finish: Vector2) -> void:
	var start := plan[-1]
	var divisions := ceili(start.distance_to(finish) / 0.65)
	for i in range(1, divisions + 1):
		plan.append(start.lerp(finish, float(i) / divisions))


func _bridge_walk() -> Array[Vector2]:
	var plan := _bridge_plan()
	var walk: Array[Vector2] = [PARK_WALK[11].lerp(plan[0], 0.4), plan[0]]
	for i in range(1, plan.size() - 1):
		if plan[i].distance_to(walk[-1]) >= 2.0 and plan[i].distance_to(plan[-1]) >= 1.2:
			walk.append(plan[i])
	walk.append_array([plan[-1], PARK_WALK[10].lerp(plan[-1], 0.4)])
	return walk


func _bridge_rail(a: Vector3, b: Vector3, side_a: Vector3, side_b: Vector3, faces: PackedVector3Array) -> void:
	var top_a := a + Vector3.UP * 1.04
	var top_b := b + Vector3.UP * 1.04
	var outward := (side_a + side_b).normalized()
	_park_face(a, b, top_b, top_a, outward, Color(0.42, 0.59, 0.61), faces, "glass")
	_park_face(a, b, top_b, top_a, -outward, Color(0.50, 0.65, 0.66), faces, "glass", false)
	var cap_a := side_a * 0.060
	var cap_b := side_b * 0.060
	var band := Vector3.UP * 0.055
	_park_face(top_a - cap_a + band, top_a + cap_a + band, top_b + cap_b + band, top_b - cap_b + band,
		Vector3.UP, PARK_STEEL, faces)
	_park_face(top_a + cap_a, top_b + cap_b, top_b + cap_b + band, top_a + cap_a + band, outward, PARK_STEEL, faces)
	_park_face(top_a - cap_a, top_b - cap_b, top_b - cap_b + band, top_a - cap_a + band, -outward, PARK_STEEL, faces)


func _at_height(point: Vector3, height: float) -> Vector3:
	return Vector3(point.x, height, point.z)


func _park_path_rounding(centre: Vector2, radius: float, height: float) -> void:
	var outline := PackedVector2Array()
	for i in 24:
		outline.append(centre + Vector2.from_angle(TAU * i / 24.0) * radius)
	_gpoly(outline, height, PARK_PAVING, Surface.GRANITE)


func _park_face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, colour: Color,
		faces: PackedVector3Array, kind := "solid", collide := true) -> void:
	var surface := _tool(kind, (a + b + c + d) * 0.25)
	surface.set_color(colour)
	surface.set_normal(normal)
	_front_quad(surface, a, b, c, d, normal)
	if collide:
		_park_collision_quad(faces, a, b, c, d, normal)


func _park_collision_quad(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		faces.append_array([a, c, b, a, d, c])
	else:
		faces.append_array([a, b, c, a, c, d])


func _park_collider(label: String, faces: PackedVector3Array, two_sided := false) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = two_sided
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.name = label
	collider.shape = shape
	_collision.add_child(collider)


func _sloped_box(a: Vector3, b: Vector3, width: float, thickness: float, colour: Color) -> void:
	var centre := a.lerp(b, 0.5)
	var basis := Basis.looking_at(b - a)
	var half := Vector3(width, thickness, a.distance_to(b)) * 0.5
	var surface := _tool("solid", centre)
	surface.set_color(colour)
	for face in [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]:
		var normal: Vector3 = basis * face[0]
		var middle: Vector3 = centre + basis * (face[0] * half)
		var u: Vector3 = basis * (face[1] * half)
		var v: Vector3 = basis * (face[2] * half)
		surface.set_normal(normal)
		_front_quad(surface, middle - u - v, middle + u - v, middle + u + v, middle - u + v, normal)


func _kremlin_arch() -> void:
	for x in [-54.35, -47.66]:
		var face := _frame(Vector2(x, 33), 90 if x > -50 else -90)
		_arch_face(face, 4.4, 3.05, 2.46, WHITE_STONE, BRICK_RED, true)
		_obox(face, -4.7, -0.24, 4.7, 0.11, 5.58, 5.93, BRICK_SHADE)
		_sign_panel(face, 0, -0.26, 6.15, 6.6, 0.64, "КРЕМЛЁВСКИЙ ДВОР", ROOF_GREEN, WHITE_STONE)
	_grect(-58, 28.75, -41, 37.25, 0.075, COURT_PAVING, Surface.GRANITE)


func _brick_shell(f: Array, area: Rect2, bottom: float, top: float, colour: Color) -> void:
	var lo := area.position
	var hi := area.end
	var footprint := PackedVector2Array([_fp(f, lo.x, lo.y), _fp(f, hi.x, lo.y),
		_fp(f, hi.x, hi.y), _fp(f, lo.x, hi.y)])
	_extrude(footprint, bottom, top, Style.SOLID_BRICK, 0.32, colour, false, false)
	_cap(footprint, top, colour.darkened(0.10))


func _build_kremlin_courts() -> void:
	var frame := _frame(Vector2.ZERO, 0)
	_grect(-77.2, -95, -54.1, 70, 0.051, COURT_PAVING, Surface.SETTS)
	_grect(-74.2, -94, -57.2, 68, 0.059, COURT_PAVING.lightened(0.22), Surface.GRANITE)
	_brick_shell(frame, Rect2(-77.2, -96, 1.6, 168), -0.06, 5.4, BRICK_RED)
	_ocollider(frame, -77.2, -96, -75.6, 72, -0.12, 5.85)
	_obox(frame, -77.48, -96, -75.42, 72, 5.2, 5.56, BRICK_SHADE)
	_obox(frame, -77.3, -96, -75.35, 72, 0.04, 0.47, BRICK_SHADE)
	for z in range(-94, 72, 3):
		_obox(frame, -77.35, z, -75.54, z + 1.65, 5.50, 6.42, BRICK_RED.lightened(0.12))
	for z in [-96, 71]:
		_obox(frame, -77.4, z, -53.8, z + 1.4, -0.06, 5.6, BRICK_RED)
		_ocollider(frame, -77.4, z, -53.8, z + 1.4, -0.12, 6.05)
	for z in range(-87, 66, 14):
		_obox(frame, -75.80, z - 0.49, -75.23, z + 0.49, 0.05, 5.51, BRICK_RED.lightened(0.17))
		_obox(frame, -75.85, z - 0.59, -75.12, z + 0.59, 4.70, 5.19, WHITE_STONE.darkened(0.20))
	for z in [-25, -4, 17, 43, 58]:
		_lantern(Vector2(-57.3, z), 4.4)
		_city_bench(_frame(Vector2(-57.1, z + 2.65), 90), 0)
	for z in [-11, 21, 61]:
		_trees.append(["birch", Vector3(-58, 0, z), _rng.randf_range(0.67, 0.9)])
	for z in [-23, -7, 11, 45]:
		var f := _frame(Vector2(-73.6, z), 90)
		_obox(f, -1.75, -0.60, 1.75, 0.60, 0.07, 0.51, WHITE_STONE.darkened(0.17))
		_obox(f, -1.62, -0.47, 1.62, 0.47, 0.50, 0.55, PARK_LEAVES.darkened(0.21))
		for i in 4:
			var at := _front_point(f, -1.15 + i * 0.73, 0, 0.62)
			_globe("solid", at, 0.33, PARK_LEAVES)
	var basin := Vector3(-66, 0.06, 60)
	_cyl("solid", basin, 2.9, 0.68, WHITE_STONE, 20)
	_cyl("glass", basin + Vector3.UP * 0.685, 2.52, 0.031, Color(0.13, 0.33, 0.38), 20)
	_cyl("solid", basin + Vector3.UP * 0.68, 0.34, 1.25, WHITE_STONE, 10)
	_cone("solid", basin + Vector3.UP * 1.75, 0.42, 0.90, 0.32, WHITE_STONE, 12)
	_ocollider(_frame(Vector2(-66, 60), 0), -2.05, -2.05, 2.05, 2.05, 0, 0.70)
	_kremlin_chapel()
	_kremlin_gallery()


func _kremlin_chapel() -> void:
	var f := _frame(Vector2(-66, -77), 0)
	_obox(f, -7.8, -8.1, 7.8, 8.1, 0.06, 10.6, WHITE_STONE)
	_ocollider(f, -7.8, -8.1, 7.8, 8.1, 0, 10.6)
	_obox(f, -8.03, -8.31, 8.03, 8.31, 1.10, 1.44, WHITE_STONE.lightened(0.18))
	_obox(f, -8.16, -8.43, 8.16, 8.43, 9.42, 10.06, WHITE_STONE.lightened(0.18))
	for x in [-5.0, 0.0, 5.0]:
		var facade := _frame(Vector2(x - 66, -68.86), 180)
		_arch_face(facade, 0.94, 4.15, 2.25, Color(0.77, 0.67, 0.51), WINDOW)
	for shift in [Vector2.ZERO, Vector2(-4.45, -3.7), Vector2(4.45, -3.7), Vector2(-4.45, 4.0), Vector2(4.45, 4.0)]:
		var pos := _w(-66 + shift.x, -77 + shift.y, 10.58)
		var scale := 1.35 if shift == Vector2.ZERO else 0.8
		_cyl("solid", pos, 1.61 * scale, 2.55 * scale, WHITE_STONE, 12)
		_cone("solid", pos + Vector3.UP * 2.50 * scale, 1.42 * scale, 2.22 * scale, 0.94 * scale, GILT, 16)
		_cone("solid", pos + Vector3.UP * 3.44 * scale, 2.22 * scale, 1.72 * scale, 1.07 * scale, GILT, 16)
		_cone("solid", pos + Vector3.UP * 4.51 * scale, 1.72 * scale, 0.17 * scale, 1.63 * scale, GILT, 16)
		var tip := pos + Vector3.UP * 6.1 * scale
		_cyl("solid", tip, 0.07, 0.94 * scale, GILT, 8)
		_ybox("solid", tip + Vector3.UP * 0.63 * scale, Vector3(0.84 * scale, 0.095, 0.095), 0, GILT)


func _kremlin_gallery() -> void:
	var f := _frame(Vector2(-67, -48), 0)
	var plaster := Color(0.69, 0.55, 0.43)
	_grect(-75.4, -59.4, -58.6, -36, 0.064, WHITE_STONE, Surface.GRANITE)
	_grect(-70.25, -59.3, -63.75, -36.0, 0.079, Color(0.57, 0.19, 0.16), Surface.SETTS)
	for x in [-70.08, -64.10]:
		_grect(x, -59.3, x + 0.19, -36, 0.084, GILT.darkened(0.16), Surface.GRANITE)
	for bounds in [Rect2(-9, -12, 0.8, 24), Rect2(8.2, -12, 0.8, 24),
			Rect2(-8.2, -12, 16.4, 0.8), Rect2(-8.2, 11.2, 5.6, 0.8), Rect2(2.6, 11.2, 5.6, 0.8)]:
		_obox(f, bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y, 0, 8.2, plaster)
		_ocollider(f, bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y, -0.08, 8.2)
	_obox(f, -2.6, 11.2, 2.6, 12, 5.12, 8.2, plaster)
	_ocollider(f, -2.6, 11.2, 2.6, 12, 5.12, 8.2)
	_obox(f, -9.28, -12.25, 9.28, 12.25, 8.0, 8.45, WHITE_STONE)
	_ocollider(f, -9, -12, 9, 12, 8.0, 8.45)
	_obox(f, -7.8, -11.5, 7.8, 11.5, 8.42, 9.3, ROOF_GREEN)
	_obox(f, -6.9, -10.1, 6.9, 10.1, 9.28, 10.01, ROOF_GREEN.darkened(0.15))
	var entrance := _frame(Vector2(-67, -35.91), 180)
	_arch_face(entrance, 2.61, 3.30, 1.80, WHITE_STONE, plaster, true)
	_sign_panel(entrance, 0, -0.20, 5.76, 6.5, 0.75, "КРЕМЛЁВСКАЯ ГАЛЕРЕЯ", BRICK_SHADE, WHITE_STONE)
	var end := _frame(Vector2(-67, -59.13), 180)
	_arch_face(end, 2.4, 4.05, 1.80, WHITE_STONE, BRICK_SHADE)
	_disc_face(end, 0, -0.11, 3.77, 1.43, 1.23, GILT)
	_disc_face(end, 0, -0.12, 3.77, 1.22, 0.0, ROOF_GREEN)
	_engraving(end, 0, -0.15, 3.76, "КРЕМЛЬ", GILT, 2.20)
	_obox(end, -2.54, -0.64, 2.54, -0.01, 0.31, 1.12, WHITE_STONE)
	for direction: float in [-1.0, 1.0]:
		var edge := direction * 8.09
		_obox(f, edge - 0.16, -11.1, edge + 0.16, 11.2, 0.08, 0.63, plaster.darkened(0.25))
		_obox(f, edge - 0.20, -11.1, edge + 0.20, 11.2, 7.15, 7.54, WHITE_STONE)
		for z in [-56.9, -51.0, -45.0, -39.2]:
			var x := -67.0 + direction * 7.2
			var pillar := Vector3(x, 0.07, z)
			_cyl("solid", pillar, 0.48, 0.38, WHITE_STONE, 8)
			_cyl("solid", pillar + Vector3.UP * 0.37, 0.31, 6.4, WHITE_STONE, 8)
			_cyl("solid", pillar + Vector3.UP * 6.74, 0.46, 0.51, WHITE_STONE, 8)
			var wall := _frame(Vector2(-67 + direction * 8.15, z), 90 if direction < 0 else -90)
			_arch_face(wall, 0.95, 3.78, 1.31, WHITE_STONE, BRICK_SHADE)
			_disc_face(wall, 0, -0.12, 4.15, 0.47, 0.0, GILT)
	for z in [-54.5, -46.5, -39.0]:
		_gallery_light(Vector3(-67, 5.2, z))


func _gallery_light(at: Vector3) -> void:
	_cyl("solid", at, 0.055, 2.75, CAST_IRON, 8)
	_cyl("solid", at - Vector3.UP * 0.15, 0.53, 0.13, GILT, 10)
	_globe("glow", at, 0.27, Color(1.0, 0.77, 0.39))
	var lamp := OmniLight3D.new()
	lamp.position = at - Vector3.UP * 0.43
	lamp.light_color = Color(1.0, 0.78, 0.48)
	lamp.light_energy = 1.04
	lamp.omni_range = 10.5
	add_child(lamp)
