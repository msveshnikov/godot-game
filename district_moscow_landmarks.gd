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


func _build_zaryadye() -> void:
	var park_edge := PackedVector2Array([Vector2(95, 23), Vector2(107, 14), Vector2(155, 18),
		Vector2(167, 41), Vector2(165, 108), Vector2(157, 138), Vector2(109, 132), Vector2(95, 115)])
	_gpoly(park_edge, 0.023, PARK_LEAVES, Surface.GRASS)
	for i in PARK_WALK.size() - 1:
		_gstrip(PARK_WALK[i], PARK_WALK[i + 1], 4.7, 0.049, PARK_PAVING, Surface.GRANITE)
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
			Vector2(107, 103), Vector2(130, 120)]:
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
	var centre := Vector2(130, 67)
	var stage := _frame(centre, 0)
	_obox(stage, -9.5, -2.1, 9.5, 4.3, 0.04, 0.25, WHITE_STONE)
	_obox(stage, -8.9, -2.0, 8.9, 4.15, 0.24, 0.29, Color(0.56, 0.40, 0.26))
	_sign_panel(_frame(Vector2(130, 70.1), 0), 0, -0.05, 0.72, 8.4, 0.63,
		"ЛЕТНИЙ АМФИТЕАТР", PARK_STEEL, WHITE_STONE)
	for row in 5:
		var radius := 4.8 + row * 1.75
		var height := 0.28 + row * 0.29
		for bay in 12:
			var a := Vector2.from_angle(PI + bay * PI / 12.0)
			var b := Vector2.from_angle(PI + (bay + 1) * PI / 12.0)
			var p := centre + a * radius
			var q := centre + b * radius
			var band := PackedVector2Array([p, q, centre + b * (radius + 1.65), centre + a * (radius + 1.65)])
			_gpoly(band, height, PARK_PAVING, Surface.GRANITE)
			var riser := _edge_frame(p, q)
			var half := p.distance_to(q) * 0.5
			_obox(riser, -half, -0.09, half, 0.09, maxf(0.04, height - 0.32), height, WHITE_STONE)
			if bay != 5 and bay != 6:
				var seat := _edge_frame(p.lerp(centre, -0.095), q.lerp(centre, -0.095))
				_obox(seat, -half * 0.9, -0.24, half * 0.9, 0.25, height, height + 0.20, Color(0.48, 0.30, 0.17))
	_glass_canopy(Vector2(130, 56))


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
	var walk := [
		Vector3(125, 0.10, 118), Vector3(133, 2.1, 122), Vector3(147, 2.9, 133),
		Vector3(152, 2.9, 131), Vector3(154, 2.1, 120), Vector3(155, 0.10, 110),
	]
	for i in walk.size() - 1:
		var a: Vector3 = walk[i]
		var b: Vector3 = walk[i + 1]
		var offset := (b - a).normalized().cross(Vector3.UP).normalized()
		_sloped_box(a - Vector3.UP * 0.27, b - Vector3.UP * 0.27, 3.9, 0.48, WHITE_STONE, true)
		for side: float in [-1.0, 1.0]:
			var rail := offset * side * 1.87
			_sloped_box(a + rail + Vector3.UP * 1.03, b + rail + Vector3.UP * 1.03, 0.10, 0.08, PARK_STEEL)
			_sloped_box(a + rail + Vector3.UP * 0.52, b + rail + Vector3.UP * 0.52, 0.09, 0.92,
				Color(0.42, 0.59, 0.61), true, "glass")
			for step in range(1, ceili(a.distance_to(b) / 2.1)):
				var p := a.lerp(b, minf(step * 2.1 / a.distance_to(b), 0.98)) + rail
				_cyl("solid", p, 0.039, 1.05, PARK_STEEL, 6)
		# Flare the deck at the corners so the two sloping boxes meet underfoot.
		if i > 0:
			var f := _frame(Vector2(a.x, a.z), 0)
			_obox(f, -1.22, -1.22, 1.22, 1.22, a.y - 0.45, a.y - 0.08, WHITE_STONE)
			_ocollider(f, -1.22, -1.22, 1.22, 1.22, a.y - 0.45, a.y - 0.08)


func _sloped_box(a: Vector3, b: Vector3, width: float, thickness: float, colour: Color, collide := false, kind := "solid") -> void:
	var centre := a.lerp(b, 0.5)
	var basis := Basis.looking_at(b - a)
	var half := Vector3(width, thickness, a.distance_to(b)) * 0.5
	var surface := _tool(kind, centre)
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
	if collide:
		var shape := BoxShape3D.new()
		shape.size = half * 2.0
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.transform = Transform3D(basis, centre)
		_collision.add_child(collider)


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
