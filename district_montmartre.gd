extends "res://district_europe.gd"
## A compact, walkable extension north of the mapped Grands Boulevards.

const FAUBOURG_LINK := [Vector2(43, -233.5), Vector2(30, -253), Vector2(19, -278), Vector2(19, -310)]
const CLICHY_Z := -310.0
const HILL_X := 56.0
const HILL_TOP := 15.0
const HILL_BANDS := [
	Vector2(-333, 0), Vector2(-350, 3.8), Vector2(-356, 3.8), Vector2(-374, 8.2),
	Vector2(-381, 8.2), Vector2(-401, HILL_TOP), Vector2(-470, HILL_TOP), Vector2(-492, 0),
]
const BASILICA_STONE := Color(0.93, 0.90, 0.81)
const BASILICA_TRIM := Color(0.98, 0.95, 0.87)
const MILL_RED := Color(0.58, 0.042, 0.060)
const MILL_LIGHT := Color(1.0, 0.31, 0.17)
const MONTMARTRE_PAVING := Color(0.62, 0.57, 0.50)

var _montmartre_outline := PackedVector2Array()


func _boundary_outline() -> PackedVector2Array:
	if not _montmartre_outline.is_empty():
		return _montmartre_outline
	var circle := super._boundary_outline()
	var north := PackedVector2Array([
		circle[67], Vector2(-105, -273), Vector2(-177, -285), Vector2(-182, -347),
		Vector2(-146, -402), Vector2(-35, -489), Vector2(12, -509), Vector2(108, -509),
		Vector2(128, -485), Vector2(128, -298), Vector2(107, -263), circle[79],
	])
	_montmartre_outline = circle.slice(0, 67)
	for i in north.size() - 1:
		var pieces := ceili(north[i].distance_to(north[i + 1]) / 16.0)
		for step in pieces:
			_montmartre_outline.append(north[i].lerp(north[i + 1], float(step) / pieces))
	_montmartre_outline.append_array(circle.slice(79))
	return _montmartre_outline


func _inside_street_limits(at: Vector2) -> bool:
	return super._inside_street_limits(at) or (at.y < -232.0 and Geometry2D.is_point_in_polygon(at, _boundary_outline()))


func bot_graph() -> Dictionary:
	var graph := super.bot_graph()
	var nodes: Array = graph["nodes"]
	var edges: Array = graph["edges"]
	# Continue the existing west pavement of Rue du Faubourg Montmartre.
	var previous := nodes.find(Vector2(34.57, -236.47))
	for p in [Vector2(25, -251), Vector2(13, -278), Vector2(13, -299), Vector2(13, -320)]:
		edges.append([previous, nodes.size()])
		previous = nodes.size()
		nodes.append(p)
	var junction := previous
	for x in range(1, -151, -12):
		edges.append([previous, nodes.size()])
		previous = nodes.size()
		nodes.append(Vector2(x, -319))
	previous = junction
	for p in [Vector2(31, -320), Vector2(47, -325), Vector2(56, -331), Vector2(65, -325),
			Vector2(83, -321), Vector2(99, -323), Vector2(108, -331), Vector2(108, -348)]:
		edges.append([previous, nodes.size()])
		previous = nodes.size()
		nodes.append(p)
	return graph


func _clichy_traffic_loop() -> Array:
	var lane := [Vector2(-148, CLICHY_Z + 3.0), Vector2(92, CLICHY_Z + 3.0)]
	for step in range(1, 9):
		var angle := PI * (0.5 - float(step) / 8.0)
		lane.append(Vector2(92, CLICHY_Z) + Vector2.from_angle(angle) * 3.0)
	lane.append(Vector2(-148, CLICHY_Z - 3.0))
	for step in range(1, 8):
		var angle := PI * (-0.5 - float(step) / 8.0)
		lane.append(Vector2(-148, CLICHY_Z) + Vector2.from_angle(angle) * 3.0)
	return lane


func _build_montmartre() -> void:
	var asphalt := Color(0.38, 0.37, 0.36)
	_gpoly(_boundary_outline(), 0.011, MONTMARTRE_PAVING.darkened(0.13), Surface.ASPHALT)
	for i in FAUBOURG_LINK.size() - 1:
		var a: Vector2 = FAUBOURG_LINK[i]
		var b: Vector2 = FAUBOURG_LINK[i + 1]
		var along := (b - a).normalized()
		_gstrip(a - along, b + along, 14, 0.023, MONTMARTRE_PAVING, Surface.SETTS)
		_gstrip(a - along, b + along, 7.5, 0.037, asphalt, Surface.ASPHALT)
	_grect(-164, -325, 111, -296, 0.026, MONTMARTRE_PAVING, Surface.SETTS)
	_grect(-161, -317, 106, -303, 0.038, asphalt, Surface.ASPHALT)
	for x in range(-155, 105, 7):
		if absf(x - 19) > 7.0:
			_grect(x, -310.08, x + 2.8, -309.92, 0.055, PAINT, Surface.PAINT)
	for x in [-105, 56]:
		for offset in range(-3, 4):
			var stripe: float = x + offset * 0.69
			_grect(stripe, -317.0, stripe + 0.34, -303.0, 0.053, PAINT, Surface.PAINT)
	for x in range(-151, 108, 24):
		if absf(x - 56) > 8.0:
			_lantern(Vector2(x, -321.5), 4.5)
		_lantern(Vector2(x + 2, -299), 4.5)
	_grect(25, -339, 89, -316, 0.028, MONTMARTRE_PAVING.lightened(0.08), Surface.SETTS)
	_grect(99, -365, 116, -316, 0.029, MONTMARTRE_PAVING, Surface.SETTS)
	_montmartre_blocks()
	_louise_michel()
	_sacre_coeur()
	_moulin_rouge()
	_montmartre_sign(Vector2(57, -198), 0, "↑  MONTMARTRE")
	_montmartre_sign(Vector2(36, -254), 0, "↑  MOULIN ROUGE · SACRÉ-CŒUR")
	_montmartre_sign(Vector2(28, -321), 180, "MOULIN ROUGE  ←     ↑  SACRÉ-CŒUR")
	_montmartre_sign(Vector2(48, -331), 180, "SQUARE LOUISE MICHEL")
	_street_name(Vector2(-53, -310), Vector2.LEFT, 14.0, "Boulevard de Clichy")


func _montmartre_blocks() -> void:
	for row in [
		[Vector2(-157, -344), 2, 14.5, 15.0], [Vector2(-90, -342), 5, 16.0, 17.0],
		[Vector2(-104, -289), 6, 16.0, 14.0], [Vector2(33, -282), 4, 18.0, 15.0],
		[Vector2(-85, -372), 5, 16.0, 14.0], [Vector2(108, -382), 1, 16.0, 17.0],
	]:
		var start: Vector2 = row[0]
		var width: float = row[2]
		for i in int(row[1]):
			var p := start + Vector2(i * (width + 0.35), 0)
			var h := float(row[3]) + (i * 7 % 5)
			var outline := PackedVector2Array([
				p, p + Vector2(width, 0), p + Vector2(width, 15), p + Vector2(0, 15),
			])
			var tint: Color = PALE_STONE[i % PALE_STONE.size()]
			_register_ground(outline, [])
			_extrude(outline, 0.0, h, Style.PARIS_STONE, (i + 0.5) / 10.0, tint, true)
			_build_roof({"roof": "mansard"}, outline, h, tint, i / 10.0)


func _montmartre_sign(at: Vector2, yaw: float, title: String) -> void:
	var f := _frame(at, yaw)
	var half := title.length() * 0.085
	_cyl("solid", _w(at.x, at.y), 0.055, 2.75, CAST_IRON, 10)
	_obox(f, -half, -0.043, half, 0.043, 2.25, 2.76, STREET_SIGN)
	_engraving(f, 0, -0.049, 2.51, title, PAINT, half * 1.91)
	_engraving(f, 0, 0.049, 2.51, title, PAINT, half * 1.91, 1.0)


func _louise_michel() -> void:
	var columns := [Vector2(7, 0), Vector2(29, 1), Vector2(50, 1), Vector2(62, 1),
		Vector2(83, 1), Vector2(105, 0)]
	var faces := PackedVector3Array()
	for i in HILL_BANDS.size() - 1:
		var lower: Vector2 = HILL_BANDS[i]
		var upper: Vector2 = HILL_BANDS[i + 1]
		var flight := lower.y < upper.y
		for j in columns.size() - 1:
			var left: Vector2 = columns[j]
			var right: Vector2 = columns[j + 1]
			var a := Vector3(left.x, lower.y * left.y + 0.035, lower.x)
			var b := Vector3(right.x, lower.y * right.y + 0.035, lower.x)
			var c := Vector3(right.x, upper.y * right.y + 0.035, upper.x)
			var d := Vector3(left.x, upper.y * left.y + 0.035, upper.x)
			faces.append_array(PackedVector3Array([a, c, b, a, d, c]))
			if j == 2 and flight:
				continue
			var paved := j == 2 or (j > 0 and j < 4 and i in [1, 3, 5])
			var tone := MONTMARTRE_PAVING.lightened(0.16) if paved else Color(0.33, 0.46, 0.23)
			var surface := Surface.SETTS if paved else Surface.GRASS
			var st := _tool("ground", (a + c) * 0.5)
			st.set_color(Color(tone.r, tone.g, tone.b, surface / 10.0))
			st.set_normal((c - a).cross(b - a).normalized() * -1.0)
			for vertex in [a, c, b]:
				st.add_vertex(vertex)
			st.set_normal((d - a).cross(c - a).normalized() * -1.0)
			for vertex in [a, d, c]:
				st.add_vertex(vertex)
		if flight:
			# Each flight uses stone treads over the continuous walkable collision surface.
			var steps := ceili((lower.x - upper.x) / 0.68)
			for step in steps:
				var start := float(step) / steps
				var finish := float(step + 1) / steps
				var z_near := lerpf(lower.x, upper.x, start)
				var z_far := lerpf(lower.x, upper.x, finish)
				var bottom := lerpf(lower.y, upper.y, start) - 0.18
				var top := lerpf(lower.y, upper.y, (start + finish) * 0.5) + 0.035
				_gbox(50, z_far, 62, z_near, bottom, top, MONTMARTRE_PAVING.lightened(0.23), Surface.GRANITE)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var terrain := CollisionShape3D.new()
	terrain.name = "LouiseMichelHill"
	terrain.shape = shape
	_collision.add_child(terrain)
	for tier in [Vector2(-353, 3.8), Vector2(-378, 8.2), Vector2(-410, HILL_TOP)]:
		for x in [34.0, 78.0]:
			_montmartre_tree(Vector3(x, tier.y + 0.04, tier.x))
			_ybox("solid", Vector3(x, tier.y + 0.46, tier.x + 2.9), Vector3(2.25, 0.16, 0.53), 0, Color(0.30, 0.21, 0.12))
			for side in [-0.81, 0.81]:
				_ybox("solid", Vector3(x + side, tier.y + 0.22, tier.x + 2.9), Vector3(0.13, 0.40, 0.48), 0, CAST_IRON)


func _montmartre_tree(at: Vector3) -> void:
	_cyl("solid", at, 0.21, 4.8, Color(0.34, 0.25, 0.16), 9)
	for offset in [Vector3(-1.18, 4.9, 0.1), Vector3(1.25, 5.0, 0.38), Vector3(0.15, 5.9, -0.55)]:
		_globe("solid", at + offset, 2.25, Color(0.25, 0.39, 0.20).lightened(offset.y * 0.022))


func _sacre_coeur() -> void:
	var f := _frame(Vector2(HILL_X, -420), 180.0)
	var y := HILL_TOP + 0.035
	_grect(29, -465, 83, -404, y + 0.018, MONTMARTRE_PAVING.lightened(0.28), Surface.SETTS)
	_obox(f, -17.2, -1.1, 17.2, 37, y, y + 0.45, BASILICA_TRIM)
	_obox(f, -16, 1.1, 16, 32, y + 0.4, y + 14.9, BASILICA_STONE)
	_ocollider(f, -16, 1.1, 16, 32, y, y + 15.1)
	_obox(f, -16.55, 0.65, 16.55, 32.5, y + 13.4, y + 14.2, BASILICA_TRIM)
	_obox(f, -16.4, 0.8, 16.4, 32.3, y + 14.6, y + 15.2, BASILICA_TRIM)
	_oroof(f, -15.8, 2.0, 15.8, 32.0, y + 15.1, 5.1, BASILICA_STONE.darkened(0.21), BASILICA_STONE)
	# The projecting portico carries the three round arches and the upper gable.
	_obox(f, -11.6, -4.2, 11.6, 2.8, y + 0.42, y + 11.9, BASILICA_STONE)
	_ocollider(f, -11.6, -4.2, 11.6, 2.8, y, y + 12.1)
	for width in [11.95, 12.25]:
		var lift: float = (width - 11.95) * 3.1
		_obox(f, -width, -4.46, width, 3.15, y + 10.7 + lift, y + 11.06 + lift, BASILICA_TRIM)
	_obox(f, -11.9, -4.45, 11.9, 3.3, y + 11.84, y + 12.15, BASILICA_TRIM)
	var gable := _tool("solid", _front_point(f, 0, -3.1, y + 12.1))
	var normal := Vector3.BACK
	gable.set_normal(normal)
	gable.set_color(BASILICA_STONE.darkened(0.10))
	_front_tri(gable, _front_point(f, -8.0, -3.1, y + 12), _front_point(f, 8.0, -3.1, y + 12),
		_front_point(f, 0, -3.1, y + 17), normal)
	gable.set_color(BASILICA_TRIM)
	for side in [-1.0, 1.0]:
		_front_quad(gable, _front_point(f, side * 8.2, -3.16, y + 12),
			_front_point(f, 0, -3.16, y + 17.2), _front_point(f, 0, -3.16, y + 16.65),
			_front_point(f, side * 7.35, -3.16, y + 12), normal)
	_oroof(f, -8.17, -3.09, 8.17, 3.3, y + 12.1, 4.85, BASILICA_STONE.darkened(0.16), BASILICA_TRIM)
	for s in [-7.15, 0.0, 7.15]:
		var portal := _frame(_fp(f, s, -4.27), 180.0)
		_basilica_arch(portal, y + 0.42, 2.40, 4.7, 2.4)
		_obox(portal, -1.57, -0.09, 1.57, -0.026, y + 0.45, y + 3.8, Color(0.19, 0.13, 0.10))
		_obox(portal, -0.055, -0.14, 0.055, -0.092, y + 0.45, y + 3.8, BRONZE)
	for s in [-11.35, -3.6, 3.6, 11.35]:
		var base := _front_point(f, s, -4.42, y + 0.52)
		_cyl("solid", base, 0.54, 6.65, BASILICA_TRIM, 14)
		_cyl("solid", base, 0.71, 0.31, BASILICA_STONE, 14)
		_cyl("solid", base + Vector3.UP * 6.5, 0.76, 0.38, BASILICA_TRIM, 14)
	for s in [-13.7, 13.7]:
		_basilica_arch(_frame(_fp(f, s, 1.05), 180), y + 3.2, 1.03, 3.5, 1.16)
	for side in [-1, 1]:
		for t in [8.0, 15.0, 22.0, 29.0]:
			var bay := _frame(_fp(f, side * 16.06, t), 180.0 + side * 90.0)
			_basilica_arch(bay, y + 5.3, 1.25, 4.0, 1.35)
	var rose := _frame(_fp(f, 0, -4.51), 180.0)
	_disc_face(rose, 0, 0, y + 9.0, 1.39, 0.0, Color(0.20, 0.21, 0.20))
	_disc_face(rose, 0, -0.02, y + 9.0, 1.5, 1.20, BASILICA_TRIM)
	_engraving(f, 0, -4.48, y + 10.18, "BASILIQUE DU SACRÉ-CŒUR", BRONZE, 12.5)
	_basilica_dome(_front_point(f, 0, 17.25, y + 14.9), 8.05, 7.2, 13.5)
	for s in [-10.7, 10.7]:
		for t in [7.8, 25.3]:
			_basilica_dome(_front_point(f, s, t, y + 14.9), 3.18, 4.5, 5.4)
	# The tall square campanile stands behind the central dome.
	_obox(f, -4.9, 31.5, 4.9, 41.4, y + 0.35, y + 31.0, BASILICA_STONE)
	_ocollider(f, -4.9, 31.5, 4.9, 41.4, y, y + 31.0)
	for height in [18.2, 24.1, 30.4]:
		_obox(f, -5.13, 31.28, 5.13, 41.63, y + height, y + height + 0.48, BASILICA_TRIM)
	for i in 4:
		var tower_face := _frame(_fp(f, 0, 36.45), i * 90.0)
		for s in [-2.15, 2.15]:
			_basilica_arch(_frame(_fp(tower_face, s, -4.99), i * 90.0), y + 25.1, 1.14, 3.0, 0.9)
	_basilica_dome(_front_point(f, 0, 36.45, y + 30.8), 4.55, 1.2, 5.65)


func _basilica_arch(f: Array, base: float, half: float, spring: float, rise: float) -> void:
	var at := _front_point(f, 0, 0, base)
	var st := _tool("solid", at)
	var facing: Vector2 = -f[2]
	var normal := Vector3(facing.x, 0, facing.y)
	var shade := Color(0.25, 0.24, 0.22)
	_obox(f, -half - 0.20, -0.074, half + 0.20, -0.002, base, base + spring, BASILICA_TRIM)
	_obox(f, -half, -0.081, half, -0.071, base + 0.08, base + spring + 0.015, shade)
	st.set_normal(normal)
	for i in 18:
		var a := Vector2.from_angle(PI * i / 18.0)
		var b := Vector2.from_angle(PI * (i + 1) / 18.0)
		var p := _front_point(f, a.x * half, -0.084, base + spring + a.y * rise)
		var q := _front_point(f, b.x * half, -0.084, base + spring + b.y * rise)
		st.set_color(shade)
		_front_tri(st, _front_point(f, 0, -0.084, base + spring), p, q, normal)
		st.set_color(BASILICA_TRIM.darkened(0.035 * (i % 2)))
		_front_quad(st, p, q, _front_point(f, b.x * (half + 0.20), -0.084, base + spring + b.y * (rise + 0.20)),
			_front_point(f, a.x * (half + 0.20), -0.084, base + spring + a.y * (rise + 0.20)), normal)


func _basilica_dome(base: Vector3, radius: float, drum: float, height: float) -> void:
	_cyl("solid", base, radius, drum, BASILICA_STONE, 32)
	for fraction in [0.10, 0.86, 0.98]:
		_cyl("solid", base + Vector3.UP * drum * fraction, radius * 1.045, 0.29, BASILICA_TRIM, 32)
	for i in 10:
		var direction := Vector2.from_angle(TAU * i / 10.0)
		var at := Vector2(base.x, base.z) + direction * (radius + 0.015)
		var f := _frame(at, rad_to_deg(direction.angle() + PI * 0.5))
		_basilica_arch(f, base.y + drum * 0.22, radius * 0.107, drum * 0.31, radius * 0.125)
	var crown := base + Vector3.UP * drum
	var profile := [Vector2(1.0, 0), Vector2(1.0, 0.12), Vector2(0.96, 0.29),
		Vector2(0.86, 0.48), Vector2(0.70, 0.65), Vector2(0.51, 0.81),
		Vector2(0.33, 0.91), Vector2(0.20, 1.0)]
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		_cone("solid", crown + Vector3.UP * (height * a.y), radius * a.x, radius * b.x,
			height * (b.y - a.y), BASILICA_TRIM, 40)
	var lantern := crown + Vector3.UP * height
	_cyl("solid", lantern, radius * 0.214, radius * 0.54, BASILICA_STONE, 16)
	_cyl("solid", lantern + Vector3.UP * radius * 0.49, radius * 0.239, radius * 0.11, BASILICA_TRIM, 16)
	_cone("solid", lantern + Vector3.UP * radius * 0.60, radius * 0.24, radius * 0.055,
		radius * 0.31, BASILICA_STONE, 16)
	var cross_at := lantern + Vector3.UP * radius * 1.03
	var metal := BRONZE.lightened(0.17)
	_ybox("solid", cross_at, Vector3(radius * 0.049, radius * 0.30, radius * 0.049), 0, metal)
	_ybox("solid", cross_at + Vector3.UP * radius * 0.035, Vector3(radius * 0.21, radius * 0.045, radius * 0.042), 0, metal)


func _moulin_rouge() -> void:
	var f := _frame(Vector2(-111, -324), 180.0)
	var red := MILL_RED
	var burgundy := red.darkened(0.40)
	var gold := Color(0.99, 0.78, 0.48)
	_obox(f, -15, 0, 15, 20.0, 0.045, 8.9, burgundy)
	_ocollider(f, -15, 0, 15, 20.0, 0.0, 9.0)
	_obox(f, -15.15, -0.12, 15.15, 0.16, 0.15, 7.85, red)
	_obox(f, -15.36, -0.48, 15.36, 0.37, 7.85, 8.19, red.lightened(0.18))
	_obox(f, -15.24, -0.29, 15.24, 0.28, 6.21, 6.40, gold)
	_obox(f, -14.46, -0.21, 14.46, -0.14, 4.78, 6.2, burgundy)
	_engraving(f, 0.0, -0.235, 5.46, "MOULIN ROUGE", gold.lightened(0.18), 13.1)
	for s in [-12.2, -8.2, 8.2, 12.2]:
		_show_moulin_poster(f, s, gold)
	for s in [-3.25, 0.0, 3.25]:
		_obox(f, s - 1.46, -0.17, s + 1.46, -0.11, 0.13, 4.16, gold.darkened(0.24))
		_obox(f, s - 1.33, -0.22, s + 1.33, -0.172, 0.16, 4.01, Color(0.14, 0.075, 0.083))
		_obox(f, s - 0.035, -0.255, s + 0.035, -0.222, 0.16, 4.01, gold.darkened(0.13))
	_obox(f, -5.54, -2.05, 5.54, 0.13, 4.0, 4.55, burgundy)
	_obox(f, -5.54, -2.09, 5.54, -2.06, 4.14, 4.37, MILL_LIGHT, "glow")
	for i in range(-28, 29):
		_globe("glow", _front_point(f, i * 0.49, -0.50, 8.03), 0.083, gold)
	var tower := _front_point(f, 0, 3.5, 8.9)
	_cone("solid", tower, 4.23, 2.96, 8.15, red, 24)
	_cyl("solid", tower, 4.4, 0.31, red.lightened(0.12), 24)
	_cyl("solid", tower + Vector3.UP * 7.97, 3.08, 0.33, burgundy, 24)
	_cone("solid", tower + Vector3.UP * 8.28, 3.4, 0.0, 3.05, burgundy, 24)
	_globe("solid", tower + Vector3.UP * 11.39, 0.23, gold)
	for side in [-1, 1]:
		_obox(f, side * 1.99 - 0.30, -0.15, side * 1.99 + 0.30, 0.3, 12.05, 13.15, burgundy)
		_obox(f, side * 1.99 - 0.25, -0.19, side * 1.99 + 0.25, -0.15, 12.10, 13.1, gold, "glow")
	_obox(f, -0.28, -0.62, 0.28, 1.15, 14.45, 15.0, burgundy)
	_moulin_rotor(_front_point(f, 0, -0.56, 14.72), gold)


func _show_moulin_poster(f: Array, s: float, gold: Color) -> void:
	_obox(f, s - 1.46, -0.23, s + 1.46, -0.12, 0.64, 4.30, gold.darkened(0.22))
	_obox(f, s - 1.36, -0.26, s + 1.36, -0.231, 0.75, 4.19, MILL_RED.darkened(0.34))
	_disc_face(f, s, -0.27, 2.43, 0.96, 0.0, Color(0.79, 0.40, 0.17))
	_disc_face(f, s + 0.28, -0.28, 2.75, 0.40, 0.0, gold)
	_engraving(f, s, -0.285, 3.74, "FÉERIE", gold, 2.0)


func _moulin_rotor(at: Vector3, gold: Color) -> void:
	var rotor := Node3D.new()
	rotor.name = "MoulinRougeSails"
	rotor.position = at
	add_child(rotor)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, Vector3(-0.29, 0.0, -0.13), Vector3(0.29, 8.25, 0.14), MILL_RED.lightened(0.13))
	for side in [-1, 1]:
		var x: float = side * 0.91
		_add_box(st, Vector3(x - 0.064, 2.17, 0.02), Vector3(x + 0.064, 8.19, 0.16), MILL_LIGHT)
	for i in 17:
		var y := 2.17 + i * 0.37
		_add_box(st, Vector3(-0.96, y, 0.025), Vector3(0.96, y + 0.07, 0.16), MILL_RED.lightened(0.28))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	st.set_material(material)
	var blade := st.commit()
	for i in 4:
		var sail := MeshInstance3D.new()
		sail.mesh = blade
		sail.rotation.z = TAU * i / 4.0 + PI * 0.15
		rotor.add_child(sail)
	_globe("solid", at + Vector3.BACK * 0.24, 0.60, MILL_RED.lightened(0.16))
	_globe("glow", at + Vector3.BACK * 0.74, 0.17, gold)
	var animation := rotor.create_tween().set_loops()
	animation.tween_property(rotor, "rotation:z", -TAU, 14.0).from(0.0)
