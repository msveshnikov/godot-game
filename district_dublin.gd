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


func _pedestrian_spots() -> Array[Vector2]:
	return [Vector2(2, -5), Vector2(4, -14), Vector2(-4, 11), Vector2(-11, 23), Vector2(-16, 34),
		Vector2(-17, 43), Vector2(-35, 53), Vector2(-44, 48.6), Vector2(15, -42), Vector2(24.6, -65.7),
		Vector2(42, -130.2), Vector2(-44, 160.3), Vector2(-80, 174), Vector2(-100, 167)]


func _parked_rows() -> Array:
	return [
		[Vector2(-72, -134.7), Vector2(-110, -144.7)],
		[Vector2(-96, -47.9), Vector2(-110, -3.4)],
	]


func _build_landmarks() -> void:
	_bewleys()
	_gaiety()
	_brown_thomas()
	_bruxelles()
	_stephens_centre()
	for raw in _data["props"]["statues"]:
		_statue(_point(raw[0]), str(raw[1]))
	_grafton_furniture()


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
	for s in [-h + 0.35, h - 0.35]:
		_obox(f, s - 0.26, -0.25, s + 0.26, -0.04, 0.3, 9.07, IVORY)


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
	var front := _front("stephens_centre", 7.0)
	if front.is_empty():
		return
	var f: Array = front[0]
	var h: float = front[1]
	for y in [0.2, 4.62, 8.96]:
		for i in 4:
			var s := lerpf(-h * 0.71, h * 0.71, i / 3.0)
			var frame := _frame(_fp(f, s, -0.12), rad_to_deg((f[1] as Vector2).angle()))
			_obox(frame, -1.24, -0.071, 1.24, 0.02, y, y + 3.63, OCHRE.lightened(0.3))
			_arch_face(frame, 0.99, y + 2.46, 0.84, IVORY, Color(0.26, 0.32, 0.33))
	_obox(f, -h, -0.37, h, 0.02, 4.0, 4.55, IVORY)
	_engraving(f, 0, -0.389, 4.27, "STEPHEN’S GREEN", DARK_WOOD, h * 1.54)


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
