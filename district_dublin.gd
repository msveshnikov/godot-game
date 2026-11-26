extends "res://district_europe.gd"
## Grafton Street, its side lanes, and the ends at St Stephen’s Green and Suffolk Street.

const OCHRE := Color(0.82, 0.69, 0.46)
const DARK_WOOD := Color(0.25, 0.11, 0.071)
const CAFE_RED := Color(0.56, 0.095, 0.13)
const ENAMEL := Color(0.13, 0.32, 0.34)
const IVORY := Color(0.93, 0.87, 0.74)
const TILE := [Color(0.79, 0.47, 0.22), Color(0.40, 0.18, 0.13), Color(0.13, 0.37, 0.37), Color(0.87, 0.78, 0.52)]


func _data_path() -> String:
	return "res://assets/europe/dublin.json"


func intro_text() -> String:
	return "Grafton Street, Dublin. Follow the pedestrian street past Bewley’s, turn into Harry Street or walk to the Gaiety and St Stephen’s Green. Map data © OpenStreetMap contributors."


func _patrol_spots() -> Array[Vector2]:
	return [
		# Grafton Street and the approach to the park.
		Vector2(43, -148), Vector2(36, -112), Vector2(28, -89), Vector2(17, -53),
		Vector2(9, -27), Vector2(-3, 12), Vector2(-14, 46), Vector2(-31, 81),
		Vector2(-42, 115), Vector2(-44, 145), Vector2(-43, 182),
		# West of Grafton Street, including Harry Street and the Gaiety.
		Vector2(-43, 48), Vector2(-69, 51), Vector2(-89, 69), Vector2(-112, 80),
		Vector2(-134, 90), Vector2(-168, 77), Vector2(-123, 47), Vector2(-97, 6),
		Vector2(-76, -30), Vector2(-58, -67), Vector2(-44, -98), Vector2(-104, 151),
		Vector2(-69, 165),
		# East of Grafton Street, with patrols on both sides of Anne Street.
		Vector2(50, 59), Vector2(83, 66), Vector2(112, 73), Vector2(151, 61),
		Vector2(117, 43), Vector2(130, 15), Vector2(129, -23), Vector2(139, -68),
		Vector2(150, -110), Vector2(63, -21), Vector2(58, 16), Vector2(110, 143),
	]


func _parked_rows() -> Array:
	return [
		[Vector2(-72, -134.7), Vector2(-110, -144.7)],
		[Vector2(-96, -47.9), Vector2(-110, -3.4)],
	]


func _build_tram() -> void:
	# The continuous eastern rail at St Stephen's Green, from the terminal curve
	# beside the shopping centre to the last mapped length before the wall.
	var track := PackedVector2Array()
	for start in [Vector2(-50.53, 228.50), Vector2(16.13, 224.66)]:
		for raw in _data["rail"]:
			var line := _points(raw)
			if line[0].distance_squared_to(start) < 0.04 and line[-1].x > start.x + 10.0:
				track.append_array(line if track.is_empty() else line.slice(1))
				break
	if track.size() > 2:
		_tram_wire(track)
		var tram := DublinTram.new()
		tram.name = "Tram"
		tram.rail = track
		add_child(tram)


func _tram_wire(track: PackedVector2Array) -> void:
	for i in range(1, track.size()):
		var f := _edge_frame(track[i - 1], track[i])
		var half := track[i - 1].distance_to(track[i]) * 0.5 + 0.02
		_obox(f, -half, -0.015, half, 0.015, 4.26, 4.287, CAST_IRON.lightened(0.17))
	for i in range(5, track.size(), 5):
		var f := _edge_frame(track[i - 1], track[i])
		var at := _fp(f, 0, 6.4)
		if not _fits_street(at, 0.55):
			continue
		_cyl("solid", _w(at.x, at.y), 0.07, 4.95, CAST_IRON, 10)
		_obox(f, -0.035, 0.0, 0.035, 6.43, 4.70, 4.77, CAST_IRON)
		_obox(f, -0.016, -0.016, 0.016, 0.016, 4.265, 4.73, CAST_IRON)


func _build_landmarks() -> void:
	_bewleys()
	_gaiety()
	_brown_thomas()
	_bruxelles()
	_stephens_centre()
	_st_anns()
	_fusiliers_arch()
	_grafton_shops()
	for raw in _data["props"]["statues"]:
		_statue(_point(raw[0]), str(raw[1]))
	_grafton_furniture()
	_flower_stall()
	_build_tram()


func _bewleys() -> void:
	var front := _front("bewleys", 5.42)
	if front.is_empty():
		return
	var f: Array = front[0]
	var h: float = front[1]
	_obox(f, -h, -0.07, h, 0.01, 0.03, 7.95, OCHRE)
	_obox(f, -h + 0.41, -0.10, h - 0.41, -0.072, 0.22, 5.88, DARK_WOOD)
	for edge in [-h + 0.23, h - 0.23]:
		_obox(f, edge - 0.20, -0.20, edge + 0.20, -0.068, 0.35, 7.73, IVORY)
		for j in 15:
			var y := 0.60 + 0.46 * j
			_obox(f, edge - 0.12, -0.215, edge + 0.12, -0.20, y, y + 0.22, TILE[(j + 1) % TILE.size()])
	for i in 5:
		var s := lerpf(-h + 0.56, h - 0.56, i / 4.0)
		_obox(f, s - 0.085, -0.19, s + 0.085, -0.08, 0.24, 5.71, DARK_WOOD.lightened(0.09))
		if i == 4:
			continue
		var half_step := (h - 0.56) * 0.25
		var mid := s + half_step
		_obox(f, mid - half_step + 0.1, -0.132, mid + half_step - 0.10, -0.102, 0.51, 3.0, Color(0.24, 0.21, 0.16))
		_obox(f, mid - half_step + 0.1, -0.147, mid + half_step - 0.10, -0.132, 1.29, 1.38, OCHRE.darkened(0.21))
		_obox(f, mid - half_step + 0.11, -0.14, mid + half_step - 0.11, -0.104, 4.53, 5.79, Color(0.27, 0.25, 0.21))
		_obox(f, mid - 0.043, -0.165, mid + 0.043, -0.133, 4.53, 5.79, OCHRE.darkened(0.24))
	_obox(f, -h + 0.4, -0.45, h - 0.4, -0.045, 3.55, 4.28, OCHRE.lightened(0.11))
	_engraving(f, 0.0, -0.46, 3.93, "BEWLEY’S ORIENTAL CAFÉS LTD.", DARK_WOOD, h * 1.75)
	_railing(f, -h + 0.5, h - 0.5, -0.38, 4.28, 0.53, 0.20)
	_obox(f, -h + 0.4, -0.19, h - 0.4, -0.07, 6.13, 7.14, ENAMEL)
	for i in 27:
		var s := lerpf(-h + 0.52, h - 0.52, i / 26.0)
		var y := 6.40 + 0.30 * cos(s / h * PI * 0.5)
		_obox(f, s - 0.126, -0.207, s + 0.126, -0.19, y, y + 0.18, TILE[i % TILE.size()])
		_obox(f, s - 0.085, -0.207, s + 0.085, -0.19, y + 0.19, y + 0.33, TILE[(i + 1) % TILE.size()])
	var disc := _front_point(f, 0.0, -0.226, 6.77)
	_globe("solid", disc, 0.24, OCHRE.lightened(0.20))
	for s in [-h * 0.54, h * 0.54]:
		_awning(f, s, h * 0.34, 3.34, 1.31, CAFE_RED)
		for petal in 6:
			var petal_angle := petal * TAU / 6.0
			var y := 3.05 + sin(petal_angle) * 0.088
			var t := -0.53 + (y - 3.05) * 1.4
			_globe("solid", _front_point(f, s + cos(petal_angle) * 0.11, t, y), 0.041, IVORY)
	_flower_box(f, -h * 0.63, -0.29, 4.48, 1.65)
	_flower_box(f, h * 0.63, -0.29, 4.48, 1.65)
	for s in [-h * 0.74, h * 0.74]:
		_sign_panel(f, s, -0.246, 1.49, 0.69, 0.49, "BEWLEY’S", DARK_WOOD, IVORY)
	for s in [-h + 0.62, h - 0.62, 0.0]:
		var p := _fp(f, s, -0.86)
		_cone("solid", _w(p.x, p.y, 2.02), 0.22, 0.36, 0.27, Color(0.32, 0.23, 0.15), 8)
		for i in 5:
			var shift := Vector2.from_angle(i * TAU / 5.0) * 0.22
			_globe("solid", _w(p.x + shift.x, p.y + shift.y, 2.37), 0.24, Color(0.29, 0.38, 0.18))
			_globe("solid", _w(p.x + 1.4 * shift.x, p.y + 1.4 * shift.y, 2.49), 0.084, CAFE_RED.lightened(0.21))


func _gaiety() -> void:
	var front := _front("gaiety", 7.0)
	if front.is_empty():
		return
	var f: Array = front[0]
	var h: float = front[1]
	_obox(f, -h, -0.075, h, 0.01, 0.05, 10.38, LIMESTONE)
	for i in 5:
		var s := lerpf(-h * 0.79, h * 0.79, i / 4.0)
		_arch_face(_frame(_fp(f, s, -0.12), rad_to_deg((f[1] as Vector2).angle())),
			0.83, 2.60, 0.78, IVORY, DARK_WOOD.darkened(0.37))
		_obox(f, s - 0.58, -0.13, s + 0.58, -0.08, 5.68, 8.40, Color(0.23, 0.26, 0.27))
		_obox(f, s - 0.62, -0.19, s + 0.62, -0.08, 5.58, 5.78, IVORY)
	_obox(f, -h, -0.91, h, -0.09, 3.50, 4.52, CAST_IRON)
	_engraving(f, 0.0, -0.936, 4.01, "THE GAIETY THEATRE", OCHRE.lightened(0.2), h * 1.68)
	for i in range(-9, 10):
		_globe("glow", _front_point(f, i * h / 9.5, -0.78, 3.47), 0.044, Color(0.70, 0.49, 0.22))
	for s in [-h + 0.35, h - 0.35]:
		_obox(f, s - 0.26, -0.25, s + 0.26, -0.04, 0.3, 9.07, IVORY)
		_sign_panel(f, s * 0.85, -0.17, 2.10, 0.86, 1.39, "GAIETY", CAFE_RED, IVORY)


func _brown_thomas() -> void:
	var front := _front("brown_thomas", 6.5)
	if front.is_empty():
		return
	var f: Array = front[0]
	var h: float = front[1]
	_obox(f, -h, -0.12, h, 0.01, 3.51, 4.55, Color(0.17, 0.17, 0.16))
	_engraving(f, 0.0, -0.135, 4.02, "BROWN THOMAS", IVORY, h * 1.58)
	for i in range(-2, 3):
		var s := i * h * 0.39
		_obox(f, s - 0.074, -0.15, s + 0.074, -0.007, 0.17, 3.55, CAST_IRON)
		_obox(f, s - h * 0.145, -0.094, s + h * 0.145, -0.06, 4.76, 7.46, Color(0.19, 0.25, 0.26))
		_obox(f, s - h * 0.164, -0.24, s + h * 0.164, -0.067, 4.63, 4.78, LIMESTONE)
		_obox(f, s - 0.045, -0.10, s + 0.045, -0.07, 4.78, 7.43, IVORY)


func _bruxelles() -> void:
	var front := _front("bruxelles", 2.59)
	if front.is_empty():
		return
	var f: Array = front[0]
	var h: float = front[1]
	_obox(f, -h, -0.16, h, 0.03, 3.23, 4.15, CAFE_RED.darkened(0.44))
	_engraving(f, 0, -0.176, 3.73, "BRUXELLES", OCHRE.lightened(0.25), h * 1.73)
	_awning(f, 0, h * 0.85, 3.37, 0.92, CAFE_RED.darkened(0.25))


func _stephens_centre() -> void:
	# The layered iron facade follows both street faces and the curved corner.
	var front := PackedVector2Array([
		Vector2(-105.0, 173.0), Vector2(-75.0, 182.98), Vector2(-56.4, 189.57),
		Vector2(-53.85, 192.28), Vector2(-53.46, 194.96), Vector2(-54.41, 199.1),
		Vector2(-57.08, 206.17), Vector2(-60.67, 215.45), Vector2(-63.7, 222.75),
	])
	for i in range(1, front.size()):
		_shopping_arcade(_edge_frame(front[i - 1], front[i]), front[i - 1].distance_to(front[i]) * 0.5)
	var entrance := _edge_frame(Vector2(-56.4, 189.57), Vector2(-53.46, 194.96))
	_sign_panel(entrance, 0, -0.78, 3.84, 5.7, 0.57, "STEPHEN’S GREEN", IVORY, DARK_WOOD)
	var cupola := Vector2(-60.9, 196.35)
	_cyl("solid", _w(cupola.x, cupola.y, 18.0), 6.08, 1.15, IVORY.darkened(0.18), 24)
	_glass_cupola(cupola, 19.15)
	_stephens_kiosk()


func _stephens_kiosk() -> void:
	var rim := PackedVector2Array([Vector2(-48.09, 198.6), Vector2(-45.79, 200.37),
		Vector2(-52.21, 208.64), Vector2(-54.5, 206.88)])
	var metal := Color(0.23, 0.25, 0.23)
	_cap(rim, 2.71, metal)
	for i in rim.size():
		var a := rim[i]
		var b := rim[(i + 1) % rim.size()]
		var f := _edge_frame(a, b)
		var half := a.distance_to(b) * 0.5
		_obox(f, -half, -0.055, half, -0.010, 0.20, 2.66, metal)
		for j in ceili(2.0 * half / 0.19):
			var s := -half + j * 0.19
			_obox(f, s, -0.085, s + 0.063, -0.053, 0.26, 2.55, metal.lightened(0.20 if j % 2 == 0 else 0.13))
		_obox(f, -half - 0.04, -0.10, half + 0.04, 0.04, 2.63, 2.71, metal.darkened(0.12))


func _shopping_arcade(f: Array, half: float) -> void:
	var yaw := rad_to_deg((f[1] as Vector2).angle())
	var bays := maxi(1, roundi(half * 0.88))
	var pitch := 2.0 * half / bays
	_obox(f, -half, -0.41, half, -0.05, 0.28, 4.1, Color(0.18, 0.25, 0.24))
	_obox(f, -half, -0.55, half, 0.06, 4.11, 4.65, IVORY.darkened(0.09))
	for i in bays + 1:
		var s := -half + pitch * i
		_obox(f, s - 0.09, -0.47, s + 0.09, 0.03, 0.21, 4.12, IVORY.darkened(0.21))
	for y in [4.64, 8.78, 12.92]:
		for i in bays:
			var s := -half + pitch * (i + 0.5)
			var frame := _frame(_fp(f, s, -0.43), yaw)
			var opening := pitch * 0.5 - 0.21
			_obox(frame, -pitch * 0.5, -0.043, pitch * 0.5, 0.13, y, y + 3.97, IVORY.darkened(0.16))
			var glass := Color(0.12, 0.21, 0.25).lightened(0.023 * (i % 3))
			_arch_face(frame, opening, y + 2.94, 0.65, IVORY, glass)
			_obox(frame, -0.034, -0.112, 0.034, -0.083, y + 0.10, y + 3.47, IVORY)
			_obox(frame, -opening, -0.112, opening, -0.083, y + 2.05, y + 2.11, IVORY)
			for j in 4:
				var bar := s - pitch * 0.48 + pitch * j / 4.0
				_obox(f, bar - 0.024, -0.81, bar + 0.024, -0.75, y + 0.07, y + 0.71, IVORY)
				_disc_face(f, bar + pitch * 0.12, -0.83, y + 0.39, 0.13, 0.098, IVORY)
			if i % 2 == 0 or half < 4.0:
				_flower_box(frame, 0, -0.34, y + 0.34, minf(1.42, pitch - 0.28))
		_obox(f, -half, -0.85, half, 0.10, y - 0.06, y + 0.11, IVORY)
		_obox(f, -half, -0.84, half, -0.71, y + 0.68, y + 0.76, IVORY)
		_obox(f, -half, -0.69, half, 0.12, y + 3.97, y + 4.17, IVORY)
	_shopping_glass_roof(f, half, bays)


func _shopping_glass_roof(f: Array, half: float, bays: int) -> void:
	var roof := [Vector2(-0.69, 17.07), Vector2(-0.36, 18.08), Vector2(0.38, 18.79), Vector2(1.66, 19.15)]
	var st := _tool("solid", _front_point(f, 0.0, 0.0, 17.1))
	for i in range(1, roof.size()):
		var low: Vector2 = roof[i - 1]
		var high: Vector2 = roof[i]
		for bay in bays:
			var left := lerpf(-half, half, float(bay) / bays)
			var right := lerpf(-half, half, float(bay + 1) / bays)
			var a := _front_point(f, left, low.x, low.y)
			var b := _front_point(f, right, low.x, low.y)
			var c := _front_point(f, right, high.x, high.y)
			var d := _front_point(f, left, high.x, high.y)
			var normal := (d - a).cross(b - a).normalized()
			st.set_normal(normal)
			st.set_color(Color(0.33, 0.46, 0.49).lightened(0.07 * ((bay + i) % 3)))
			_front_quad(st, a, b, c, d, normal)
			st.set_color(IVORY.darkened(0.14))
			var offset := normal * 0.026
			_front_quad(st, a + offset, a.lerp(b, 0.045) + offset,
				d.lerp(c, 0.045) + offset, d + offset, normal)
		_obox(f, -half, high.x - 0.055, half, high.x + 0.062, high.y - 0.043, high.y + 0.04, IVORY.darkened(0.1))


func _glass_cupola(centre: Vector2, base_y: float) -> void:
	var st := _tool("solid", _w(centre.x, centre.y, base_y))
	for band in 7:
		var a := PI * 0.5 * band / 7.0
		var b := PI * 0.5 * (band + 1) / 7.0
		for pane in 24:
			var l := Vector2.from_angle(TAU * pane / 24.0)
			var r := Vector2.from_angle(TAU * (pane + 1) / 24.0)
			var vertices := []
			for corner in [[a, l], [a, r], [b, r], [b, l]]:
				var offset: Vector2 = corner[1] * cos(corner[0]) * 6.04
				vertices.append(_w(centre.x + offset.x, centre.y + offset.y, base_y + 5.55 * sin(corner[0])))
			var normal := ((vertices[0] as Vector3) - _w(centre.x, centre.y, base_y)).normalized()
			st.set_color(Color(0.32, 0.48, 0.49).lightened(0.12 * ((pane + band) % 3)))
			st.set_normal(normal)
			_front_quad(st, vertices[0], vertices[1], vertices[2], vertices[3], normal)
			st.set_color(IVORY)
			var edge_a: Vector3 = vertices[0].lerp(vertices[1], 0.062)
			var edge_b: Vector3 = vertices[3].lerp(vertices[2], 0.062)
			_front_quad(st, vertices[0] + normal * 0.023, edge_a + normal * 0.023,
				edge_b + normal * 0.023, vertices[3] + normal * 0.023, normal)
			var ring_a: Vector3 = vertices[0].lerp(vertices[3], 0.073)
			var ring_b: Vector3 = vertices[1].lerp(vertices[2], 0.073)
			_front_quad(st, vertices[0] + normal * 0.024, vertices[1] + normal * 0.024,
				ring_b + normal * 0.024, ring_a + normal * 0.024, normal)
	_cyl("solid", _w(centre.x, centre.y, base_y + 5.49), 0.075, 0.55, IVORY, 8)
	_globe("solid", _w(centre.x, centre.y, base_y + 6.04), 0.13, OCHRE)


func _st_anns() -> void:
	# Dawson Street facade at the end of the view along Anne Street South.
	var f := _frame(Vector2(129.1, 82.6), -79.2)
	var dark := Color(0.24, 0.19, 0.15)
	var stone := Color(0.69, 0.61, 0.52)
	_obox(f, -9.25, 0.03, 9.25, 0.56, 0.26, 12.48, stone)
	for side in [-1.0, 1.0]:
		var t: float = side * 6.5
		_obox(f, t - 1.76, -0.32, t + 1.76, 0.74, 0.14, 14.17 + side * 1.1, stone.darkened(0.04))
		var pier := _frame(_fp(f, t, -0.32), -79.2)
		for y in [1.3, 7.1, 11.8]:
			_arch_face(pier, 0.88, y + 1.30, 0.72, LIMESTONE, dark)
		_obox(f, t - 1.94, -0.48, t + 1.94, 0.78, 12.52, 12.77, LIMESTONE)
	_arch_face(f, 1.57, 2.66, 1.15, LIMESTONE, CAFE_RED.darkened(0.45))
	_obox(f, -0.054, -0.09, 0.054, -0.075, 0.39, 2.66, CAFE_RED.darkened(0.66))
	_disc_face(f, 0, -0.051, 8.40, 1.51, 0.0, Color(0.27, 0.20, 0.15))
	_disc_face(f, 0, -0.073, 8.40, 1.68, 1.44, LIMESTONE)
	_disc_face(f, 0, -0.081, 8.40, 0.38, 0.22, IVORY.darkened(0.20))
	for i in 8:
		var a := Vector2.from_angle(TAU * i / 8.0)
		_disc_face(f, a.x * 0.97, -0.064, 8.40 + a.y * 0.97, 0.41, 0.24, LIMESTONE)
	for s in [-4.4, -2.2, 2.2, 4.4]:
		var pier := _frame(_fp(f, s, -0.06), -79.2)
		_arch_face(pier, 0.59, 4.39, 0.49, LIMESTONE, dark)
	_obox(f, -5.5, -0.21, 5.5, 0.40, 10.79, 11.02, LIMESTONE)
	var st := _tool("solid", _front_point(f, 0, 0, 11.0))
	st.set_color(stone)
	var facing: Vector2 = -f[2]
	var normal := Vector3(facing.x, 0, facing.y)
	st.set_normal(normal)
	_front_tri(st, _front_point(f, -5.15, -0.046, 11.01), _front_point(f, 5.15, -0.046, 11.01),
		_front_point(f, 0, -0.046, 16.16), normal)
	_obox(f, -0.10, -0.125, 0.10, 0.16, 16.07, 17.30, LIMESTONE)
	_obox(f, -0.38, -0.125, 0.38, 0.16, 16.79, 16.99, LIMESTONE)
	for i in 4:
		_obox(f, -2.9, -1.4 + i * 0.24, 2.9, 0.20, 0.01, 0.11 + i * 0.09, GRANITE_GREY)
	_engraving(f, 0, -0.14, 4.14, "ST ANN’S", IVORY, 1.85)


func _fusiliers_arch() -> void:
	var f := _frame(Vector2(-25.16, 227.92), -22.0)
	var stone := Color(0.62, 0.59, 0.53)
	for side in [-1.0, 1.0]:
		var pier: float = side * 3.05
		_obox(f, pier - 1.19, -0.86, pier + 1.19, 0.88, 0.02, 7.03, stone)
		_ocollider(f, pier - 1.19, -0.86, pier + 1.19, 0.88, 0.0, 7.03)
		for s in [-0.72, 0.72]:
			_obox(f, pier + s - 0.20, -1.08, pier + s + 0.20, -0.82, 0.84, 6.61, LIMESTONE.darkened(0.12))
		_obox(f, pier - 1.27, -1.04, pier + 1.27, 1.01, 0.03, 0.77, stone.darkened(0.05))
		var edge: float = side * 7.5
		_railing(f, minf(edge, side * 4.17), maxf(edge, side * 4.17), 0.0, 0.15, 1.86, 0.19)
		_obox(f, edge - 0.26, -0.27, edge + 0.26, 0.26, 0.0, 2.18, stone)
		_globe("solid", _front_point(f, edge, 0, 2.31), 0.14, stone)
	_arch_face(_frame(_fp(f, 0, -0.85), -22.0), 1.86, 3.73, 1.87, LIMESTONE, stone, true)
	_obox(f, -1.92, -0.89, 1.92, 0.91, 5.56, 7.05, stone)
	_obox(f, -4.40, -1.11, 4.40, 1.10, 6.99, 7.46, LIMESTONE.darkened(0.05))
	_obox(f, -3.75, -0.93, 3.75, 0.93, 7.46, 9.61, stone)
	_obox(f, -3.90, -1.0, 3.90, 1.0, 9.57, 9.93, LIMESTONE.darkened(0.05))
	_sign_panel(f, 0, -0.955, 8.67, 4.38, 0.95, "ROYAL DUBLIN FUSILIERS  ·  1907", LIMESTONE, DARK_WOOD)
	_disc_face(f, 0, -0.911, 6.25, 0.31, 0.11, BRONZE)
	for i in range(-13, 14):
		_obox(f, i * 0.31 - 0.052, -1.06, i * 0.31 + 0.052, -0.89, 6.81, 7.03, LIMESTONE)
	_grect(-33.9, 231.8, -15.3, 241.0, 0.020, Color(0.34, 0.45, 0.26), Surface.GRASS)
	_gstrip(_fp(f, 0, 1), _fp(f, 0, 12.5), 3.55, 0.044, Color(0.58, 0.52, 0.43), Surface.SETTS)


func _grafton_shops() -> void:
	_shopfront("weir", "WEIR & SONS", Color(0.13, 0.15, 0.14), OCHRE, 9.0, false)
	_shopfront("molton", "MOLTON BROWN", Color(0.21, 0.19, 0.17), IVORY, 6.0, false)
	_shopfront("fields", "FIELDS", Color(0.14, 0.22, 0.27), IVORY, 7.8, false)
	_shopfront("butlers", "BUTLERS CHOCOLATES", Color(0.29, 0.25, 0.17), IVORY, 6.7, true)
	_shopfront("davy_byrnes", "DAVY BYRNE’S", Color(0.19, 0.25, 0.17), OCHRE, 6.0, true)
	_shopfront("marks", "M&S", Color(0.16, 0.20, 0.21), IVORY, 6.2, false)


func _flower_stall() -> void:
	var f := _frame(Vector2(-38.8, 176.7), 22.0)
	if not _fits_street(f[0], 1.6):
		return
	for s in [-1.36, 1.36]:
		for z in [-0.70, 0.70]:
			_obox(f, s - 0.035, z - 0.035, s + 0.035, z + 0.035, 0.0, 2.65, CAST_IRON)
	for i in 8:
		var s := -1.35 + i * 0.35
		_obox(f, s, -0.82, s + 0.35, 0.83, 2.56, 2.66, ENAMEL if i % 2 == 0 else IVORY)
	_obox(f, -1.35, -0.62, 1.35, 0.54, 0.62, 0.74, DARK_WOOD)
	_flower_box(f, 0.0, -0.47, 0.74, 2.52)
	_flower_box(f, -0.48, 0.26, 0.73, 1.29)
	_flower_box(f, 0.76, 0.26, 0.73, 0.89)
	_sign_panel(f, 0, -0.84, 2.44, 1.76, 0.27, "GRAFTON FLOWERS", ENAMEL, IVORY)


func _statue(p: Vector2, title: String) -> void:
	var molly := title == "Molly Malone"
	var f := _frame(p, 23.0 if molly else -28.0)
	var base := 0.34 if molly else 0.17
	_obox(f, -0.53, -0.43, 0.55, 0.45, 0.025, base, GRANITE_GREY.darkened(0.12))
	_engraving(f, 0, -0.443, base * 0.68, title.to_upper(), IVORY, 0.87)
	var body := _w(p.x, p.y, base)
	if molly:
		_cone("solid", body, 0.29, 0.17, 0.85, BRONZE, 12)
		_obox(f, 0.57, -0.48, 1.51, 0.27, base + 0.36, base + 0.72, BRONZE)
		for t in [-0.52, 0.31]:
			_obox(f, 0.63, t, 1.56, t + 0.048, base + 0.16, base + 0.24, BRONZE)
	else:
		for s in [-0.12, 0.12]:
			_obox(f, s - 0.085, -0.09, s + 0.085, 0.10, base, base + 0.86, BRONZE)
		_globe("solid", _front_point(f, 0.25, -0.15, base + 0.79), 0.22, BRONZE)
		_obox(f, 0.36, -0.17, 0.45, -0.09, base + 0.88, base + 1.68, BRONZE)
	_cone("solid", body + Vector3.UP * 0.83, 0.18, 0.23, 0.48, BRONZE, 10)
	_globe("solid", body + Vector3.UP * 1.48, 0.13, BRONZE)
	for s in [-0.25, 0.25]:
		_obox(f, s - 0.069, -0.10, s + 0.073, 0.05, base + 0.78, base + 1.24, BRONZE)


func _grafton_furniture() -> void:
	for item in _data["focus"]:
		if item[2] != "Grafton Street":
			continue
		var line := _points(item[0])
		for i in range(1, line.size()):
			var a := line[i - 1]
			var b := line[i]
			var dir := (b - a).normalized()
			var left := dir.orthogonal()
			for k in range(5, int(a.distance_to(b)) - 4, 7):
				var p := a + dir * k
				for side in [-1.0, 1.0]:
					var foot: Vector2 = p + left * 3.36 * side
					if not _fits_street(foot, 0.26):
						continue
					var f := _frame(foot, rad_to_deg(dir.angle()))
					_obox(f, -0.29, -0.12, 0.29, 0.12, 0.025, 0.039, Color(0.35, 0.36, 0.35))
					if (k + i) % 3 == 0:
						_bollard(foot)
					elif (k + i) % 9 == 1:
						_street_bin(foot)
			_gstrip(a + left * 3.11, b + left * 3.11, 0.16, 0.048, GRANITE_GREY.lightened(0.13), Surface.GRANITE)
			_gstrip(a - left * 3.11, b - left * 3.11, 0.16, 0.048, GRANITE_GREY.lightened(0.13), Surface.GRANITE)
