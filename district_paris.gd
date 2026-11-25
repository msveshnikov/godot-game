extends "res://district_europe.gd"
## Grands Boulevards around the Grévin, with the two covered passages.

const WINE := Color(0.47, 0.10, 0.095)
const GILT := Color(0.91, 0.70, 0.33)
const CREAM := Color(0.91, 0.84, 0.70)
const POSTER_GREEN := Color(0.09, 0.24, 0.20)


func _data_path() -> String:
	return "res://assets/europe/paris.json"


func _is_paris() -> bool:
	return true


func intro_text() -> String:
	return "Boulevard Montmartre, Paris. Walk from the Grévin and Théâtre des Variétés to the covered Passages Jouffroy and des Panoramas. Map data © OpenStreetMap contributors."


func _pedestrian_spots() -> Array[Vector2]:
	return [Vector2(10.7, -8.8), Vector2(15.8, -6.7), Vector2(21.4, -4.8), Vector2(-22.9, -13.3),
		Vector2(-26.5, 8.6), Vector2(-10.9, 12.9), Vector2(10.9, 18.8), Vector2(37.4, -5.2),
		Vector2(53.0, 24.5), Vector2(73.4, 31.3), Vector2(-58.6, -24.0), Vector2(-65.1, -3.92)]


func _parked_rows() -> Array:
	return [
		[Vector2(-99, -13.7), Vector2(-71, -6.8)],
		[Vector2(109, 37.0), Vector2(148, 46.7)],
		[Vector2(65.9, -55), Vector2(58.6, -84)],
	]


func _build_landmarks() -> void:
	_grevin()
	_varietes()
	_passage_portal("panoramas", "PASSAGE DES PANORAMAS", Color(0.14, 0.27, 0.22))
	_passage_portal("jouffroy", "PASSAGE JOUFFROY", Color(0.11, 0.14, 0.14))
	_chartier()
	_passage_lights()
	for raw in _data["props"]["metro"]:
		_metro(_point(raw))
	for p in [Vector2(24.4, -7.6), Vector2(-55.1, -7.0), Vector2(-125.4, -39.8), Vector2(91.0, 31.6)]:
		if _fits_street(p, 0.8):
			_poster_column(p)


func _grevin() -> void:
	var door := _front("grevin", 2.05)
	if door.is_empty():
		return
	var f: Array = door[0]
	var half: float = door[1]
	_obox(f, -half, -0.07, half, 0.02, 0.03, 5.6, WINE)
	_arch_face(f, half - 0.43, 2.48, 1.10, GILT, Color(0.10, 0.07, 0.08))
	for s in [-half + 0.15, half - 0.15]:
		var p := _fp(f, s, -0.14)
		_cyl("solid", _w(p.x, p.y, 0.12), 0.13, 4.25, WINE.lightened(0.13), 12)
		_cyl("solid", _w(p.x, p.y, 4.29), 0.18, 0.22, GILT, 10)
		_cyl("solid", _w(p.x, p.y, 0.14), 0.17, 0.20, GILT, 10)
	_obox(f, -half - 0.07, -0.27, half + 0.07, 0.02, 5.40, 5.57, GILT)
	_obox(f, -half, -0.24, half, 0.04, 4.75, 4.91, GILT.darkened(0.15))
	_engraving(f, 0.0, -0.086, 5.12, "MUSÉE GRÉVIN", GILT, 3.44)
	_engraving(f, 0.0, -0.084, 3.89, "ENTRÉE", GILT.lightened(0.2), 0.95)
	# A long red frontage and gilded transoms sit beside the historical entrance.
	for s in [-4.1, -6.13, -8.16]:
		_obox(f, s - 0.92, -0.084, s + 0.92, -0.022, 0.49, 3.93, WINE)
		_obox(f, s - 0.74, -0.098, s + 0.74, -0.084, 1.01, 3.54, WINE.lightened(0.08))
		_obox(f, s - 0.82, -0.103, s + 0.82, -0.086, 3.64, 3.69, GILT)
	var terrace := _fp(f, -9.8, -3.12)
	if _fits_street(terrace, 1.8):
		_cafe_terrace(_frame(terrace, rad_to_deg((f[1] as Vector2).angle())), 3, POSTER_GREEN)


func _varietes() -> void:
	var door := _front("varietes", 3.46)
	if door.is_empty():
		return
	var f: Array = door[0]
	var h: float = door[1]
	_obox(f, -h, -0.075, h, 0.01, 0.05, 9.10, CREAM.darkened(0.08))
	for i in 3:
		var s := lerpf(-h * 0.68, h * 0.68, i / 2.0)
		_arch_face(_frame(_fp(f, s, -0.13), rad_to_deg((f[1] as Vector2).angle())), 0.70, 2.60, 0.65,
			CREAM, Color(0.10, 0.08, 0.06))
	for s in [-h, -h / 3.0, h / 3.0, h]:
		var p := _fp(f, s, -0.32)
		_cyl("solid", _w(p.x, p.y, 0.22), 0.23, 3.76, CREAM, 12)
		_obox(f, s - 0.29, -0.6, s + 0.29, -0.065, 0.08, 0.30, CREAM)
		_obox(f, s - 0.28, -0.6, s + 0.28, -0.065, 3.86, 4.13, CREAM)
	_obox(f, -h - 0.12, -0.82, h + 0.12, 0.05, 4.11, 4.34, CREAM)
	_railing(f, -h + 0.1, h - 0.1, -0.72, 4.34, 0.75, 0.25)
	_obox(f, -h + 0.21, -0.10, h - 0.21, -0.08, 5.43, 6.39, Color(0.13, 0.10, 0.10))
	_engraving(f, 0.0, -0.11, 5.91, "THÉÂTRE DES VARIÉTÉS", Color(0.94, 0.28, 0.22), h * 1.90)
	_engraving(f, 0.0, -0.113, 7.89, "VARIÉTÉS", GILT, h * 1.1)


func _passage_portal(key: String, title: String, board: Color) -> void:
	var door := _front(key, 1.40)
	if door.is_empty():
		return
	var f: Array = door[0]
	var h: float = door[1]
	_arch_face(f, h - 0.14, 2.72, 0.75, LIMESTONE.lightened(0.12), board, true)
	_obox(f, -h - 0.22, -0.21, h + 0.22, 0.06, 3.71, 4.26, board)
	_engraving(f, 0.0, -0.223, 3.99, title, CREAM, 2.77)
	_obox(f, -h - 0.23, -0.24, h + 0.23, 0.07, 4.23, 4.32, GILT.darkened(0.20))


func _chartier() -> void:
	var door := _front("chartier", 2.65)
	if door.is_empty():
		return
	var f: Array = door[0]
	var h: float = door[1]
	_arch_face(f, h - 0.17, 2.89, 0.94, CREAM, POSTER_GREEN)
	_obox(f, -h, -0.16, h, 0.02, 4.11, 4.62, POSTER_GREEN)
	_engraving(f, 0, -0.173, 4.38, "BOUILLON CHARTIER", GILT, h * 1.82)
	_engraving(f, 0, -0.12, 2.56, "DEPUIS 1896", GILT, 1.7)


func _passage_lights() -> void:
	for raw in _data["passages"]:
		var line := _points(raw)
		for i in range(1, line.size()):
			var a := line[i - 1]
			var b := line[i]
			if a.distance_to(b) < 4.0:
				continue
			var f := _edge_frame(a, b)
			var length := a.distance_to(b)
			for k in range(2, int(length) - 1, 4):
				var s := float(k) - length * 0.5
				var p := _fp(f, s, 0.0)
				_obox(f, s - 0.035, -1.46, s + 0.035, 1.46, 3.88, 3.94, CAST_IRON)
				_cyl("solid", _w(p.x, p.y, 3.37), 0.028, 0.53, CAST_IRON, 8)
				_globe("glow", _w(p.x, p.y, 3.33), 0.13, Color(0.89, 0.70, 0.39))
				for side in [-1.0, 1.0]:
					var pa := _front_point(f, s - 1.9, side * 1.44, 3.89)
					var pb := _front_point(f, s + 1.9, side * 1.44, 3.89)
					var pc := _front_point(f, s + 1.9, 0.0, 4.60)
					var pd := _front_point(f, s - 1.9, 0.0, 4.60)
					var st := _tool("glass", pa)
					st.set_color(Color(0.55, 0.63, 0.60))
					st.set_normal(Vector3.DOWN)
					_front_quad(st, pa, pb, pc, pd, Vector3.DOWN)


func _poster_column(p: Vector2) -> void:
	var at := _w(p.x, p.y)
	_cyl("solid", at, 0.81, 0.22, POSTER_GREEN, 18)
	_cyl("solid", at + Vector3.UP * 0.18, 0.70, 2.80, POSTER_GREEN, 18)
	_cyl("solid", at + Vector3.UP * 2.94, 0.86, 0.21, POSTER_GREEN, 18)
	_cone("solid", at + Vector3.UP * 3.11, 0.76, 0.48, 0.35, POSTER_GREEN, 18)
	_cone("solid", at + Vector3.UP * 3.46, 0.48, 0.08, 0.39, POSTER_GREEN, 18)
	var posters := [["CONCERTS", WINE], ["THÉÂTRE", Color(0.24, 0.31, 0.45)], ["EXPOSITIONS", Color(0.44, 0.30, 0.14)]]
	for i in posters.size():
		var f := _frame(p, 120.0 * i)
		var spec: Array = posters[i]
		_obox(f, -0.43, -0.716, 0.43, -0.56, 0.48, 2.66, spec[1])
		_obox(f, -0.37, -0.721, 0.37, -0.715, 0.54, 0.82, CREAM)
		_engraving(f, 0, -0.727, 2.27, spec[0], CREAM, 0.76)


func _metro(p: Vector2) -> void:
	if not _fits_street(p, 1.15):
		return
	var f := _frame(p, 14.0)
	var rail := POSTER_GREEN
	_obox(f, -1.49, -0.85, 1.49, 0.85, 0.04, 0.10, Color(0.24, 0.23, 0.21))
	for s in [-1.44, 1.44]:
		for t in [-0.86, 0.86]:
			var bar := _fp(f, s, t)
			_cyl("solid", _w(bar.x, bar.y, 0.04), 0.080, 1.18, rail, 8)
	_railing(f, -1.50, 1.50, 0.87, 0.08, 0.95, 0.18)
	_railing(f, -1.50, 1.50, -0.87, 0.08, 0.95, 0.18)
	_obox(f, -1.50, 0.76, -1.42, 0.84, 0.95, 3.0, rail)
	_obox(f, -1.54, 0.69, 0.16, 0.84, 2.57, 2.94, WINE)
	_engraving(f, -0.69, 0.68, 2.75, "MÉTRO", CREAM, 1.36)


func _cafe_terrace(f: Array, count: int, cloth: Color) -> void:
	for i in count:
		var s := (i - (count - 1) * 0.5) * 1.55
		var p := _fp(f, s, 0.0)
		if not _fits_street(p, 0.8):
			continue
		_cyl("solid", _w(p.x, p.y), 0.055, 0.72, CAST_IRON, 8)
		_cyl("solid", _w(p.x, p.y, 0.73), 0.34, 0.048, cloth, 12)
		for t in [-0.62, 0.62]:
			for leg in [s - 0.14, s + 0.14]:
				_obox(f, leg - 0.025, t - 0.021, leg + 0.025, t + 0.021, 0.02, 0.76, CAST_IRON)
			_obox(f, s - 0.17, t - 0.14, s + 0.17, t + 0.14, 0.43, 0.49, CREAM.darkened(0.22))
