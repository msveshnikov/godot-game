extends "res://district_montmartre.gd"
## Grands Boulevards around the Grévin and the streets leading up to Montmartre.

const WINE := Color(0.47, 0.10, 0.095)
const GILT := Color(0.91, 0.70, 0.33)
const CREAM := Color(0.91, 0.84, 0.70)
const POSTER_GREEN := Color(0.09, 0.24, 0.20)


func _data_path() -> String:
	return "res://assets/europe/paris.json"


func _is_paris() -> bool:
	return true


func intro_text() -> String:
	return "Explore the Grands Boulevards, then follow Rue du Faubourg Montmartre north for the Moulin Rouge and the hilltop Sacré-Cœur. Map data © OpenStreetMap contributors."


func _patrol_spots() -> Array[Vector2]:
	return [
		# Boulevard and the two theatre entrances.
		Vector2(-125, -34), Vector2(-98, -22), Vector2(-64, -9), Vector2(-35, -5),
		Vector2(0, 5), Vector2(29, 12), Vector2(59, 23), Vector2(96, 27), Vector2(130, 37),
		# Streets behind the north side of the boulevard.
		Vector2(-136, -57), Vector2(-125, -82), Vector2(-116, -110), Vector2(-108, -142),
		Vector2(-85, -168), Vector2(-47, -161), Vector2(-13, -153), Vector2(29, -149),
		Vector2(73, -52), Vector2(78, -82), Vector2(77, -112), Vector2(127, -104), Vector2(152, -99),
		# Passages and adjoining streets south of the boulevard.
		Vector2(-39, 37), Vector2(-51, 71), Vector2(-60, 103), Vector2(-77, 131),
		Vector2(-116, 132), Vector2(-145, 123), Vector2(-35, 145), Vector2(9, 155),
		Vector2(51, 63), Vector2(43, 100), Vector2(39, 132), Vector2(28, 158),
		Vector2(86, 104), Vector2(121, 117),
		Vector2(27, -270), Vector2(-124, -319), Vector2(-94, -319),
		Vector2(-48, -319), Vector2(4, -318), Vector2(56, -331), Vector2(100, -326),
	]


func _parked_rows() -> Array:
	return [
		[Vector2(-99, -13.7), Vector2(-71, -6.8)],
		[Vector2(109, 37.0), Vector2(148, 46.7)],
		[Vector2(65.9, -55), Vector2(58.6, -84)],
	]


func _traffic_lanes() -> Array:
	# The one-way link at Richelieu connects the two boulevard carriageways.
	var richelieu := [Vector2(-146.52, -35.39), Vector2(-149.10, -27.02),
		Vector2(-135.4, -26.4), Vector2(-120.49, -25.23)]
	var outbound := [Vector2(-111.0, -20.1), Vector2(60.2, 22.2), Vector2(73.9, 25.0)]
	var inbound := [Vector2(75.2, 19.2), Vector2(61.6, 16.2), Vector2(-118.8, -28.0)]
	var boulevard := outbound + [Vector2(114.8, 35.2), Vector2(194.5, 55.15)]
	# Rounded U-turn on the existing pavement, before the eastern perimeter.
	var east := Vector2(156.27, 39.26).normalized()
	var turn := Vector2(207.0, 55.31)
	for step in 9:
		var angle := PI * step / 8.0
		boulevard.append(turn + (east * sin(angle) + east.orthogonal() * cos(angle)) * 3.8)
	boulevard.append_array([Vector2(195.55, 49.55), Vector2(117.9, 29.9)])
	boulevard.append_array(inbound + [Vector2(-133.9, -32.31)] + richelieu)

	# Boulevard Montmartre → Faubourg Montmartre → Grange Batelière → Drouot.
	var north := outbound + [
		Vector2(77.6, 5.5), Vector2(82.65, -36.41), Vector2(84.19, -54.67),
		Vector2(83.51, -68.96), Vector2(78.9, -112.3), Vector2(75.7, -141.6),
		Vector2(13.8, -153.0), Vector2(-74.1, -169.2), Vector2(-110.5, -176.5),
		Vector2(-116.6, -129.5), Vector2(-144.9, -40.0),
	] + richelieu

	# Boulevard Montmartre → Vivienne → Feydeau → Rue Montmartre.
	var south := [
		Vector2(75.2, 19.2), Vector2(61.6, 16.2), Vector2(-32.0, -6.65),
		Vector2(-36.4, 7.1), Vector2(-61.29, 78.48), Vector2(-85.69, 150.74),
		Vector2(-100.0, 186.73), Vector2(-102.6, 194.3), Vector2(-95.5, 192.7),
		Vector2(-64.6, 185.6), Vector2(12.9, 169.0), Vector2(47.6, 161.14),
		Vector2(46.96, 154.13), Vector2(49.87, 134.34), Vector2(59.5, 91.4),
		Vector2(70.4, 40.6), Vector2(73.4, 27.2),
	]
	return [[boulevard, 7], [north, 6], [south, 6], [_clichy_traffic_loop(), 4]]


func _build_landmarks() -> void:
	_grevin()
	_varietes()
	_passage_portal("panoramas", "PASSAGE DES PANORAMAS", Color(0.14, 0.27, 0.22))
	_passage_portal("jouffroy", "PASSAGE JOUFFROY", Color(0.11, 0.14, 0.14))
	_chartier()
	_boulevard_shops()
	_passage_lights()
	_arcade_shopfronts()
	_curb_details()
	for raw in _data["props"]["metro"]:
		_metro(_point(raw))
	for p in [Vector2(24.4, -7.6), Vector2(-55.1, -7.0), Vector2(-125.4, -39.8), Vector2(91.0, 31.6)]:
		if _fits_street(p, 0.8):
			_poster_column(p)
	_build_montmartre()


func _grevin() -> void:
	var door := _front("grevin", 2.05)
	if door.is_empty():
		return
	var f: Array = door[0]
	var half: float = door[1]
	_obox(f, -half, -0.073, half, 0.02, 0.03, 5.6, WINE.darkened(0.13))
	_arch_face(f, half - 0.43, 2.48, 1.10, GILT, Color(0.08, 0.056, 0.045))
	var relief := _frame(_fp(f, 0, -0.14), rad_to_deg((f[1] as Vector2).angle()))
	_arch_face(relief, half - 0.29, 2.48, 1.29, GILT.darkened(0.14), WINE, true)
	for s in [-half + 0.15, half - 0.15]:
		var p := _fp(f, s, -0.14)
		_cyl("solid", _w(p.x, p.y, 0.12), 0.13, 4.25, WINE.lightened(0.13), 12)
		_cyl("solid", _w(p.x, p.y, 4.29), 0.18, 0.22, GILT, 10)
		_cyl("solid", _w(p.x, p.y, 0.14), 0.17, 0.20, GILT, 10)
		_disc_face(f, s * 0.82, -0.095, 4.35, 0.13, 0.089, GILT)
		_obox(f, s * 0.82 - 0.069, -0.127, s * 0.82 + 0.068, -0.082, 3.91, 4.30, GILT.darkened(0.08))
		_globe("solid", _front_point(f, s * 0.82, -0.124, 4.48), 0.09, GILT.lightened(0.10))
	_obox(f, -half - 0.07, -0.27, half + 0.07, 0.02, 5.40, 5.57, GILT)
	_obox(f, -half, -0.24, half, 0.04, 4.75, 4.91, GILT.darkened(0.15))
	_engraving(f, 0.0, -0.086, 5.12, "MUSÉE GRÉVIN", GILT, 3.44)
	_sign_panel(f, 0, -0.091, 4.28, 1.18, 0.53, "GRÉVIN", WINE, GILT.lightened(0.15))
	_engraving(f, 0.0, -0.096, 3.96, "PALAIS DES MIRAGES", GILT.lightened(0.2), 2.56)
	for s in [-0.98, 0.98]:
		_obox(f, s - 0.37, -0.107, s + 0.37, -0.081, 0.04, 2.41, Color(0.13, 0.083, 0.064))
		_obox(f, s - 0.29, -0.115, s + 0.29, -0.106, 0.49, 2.24, Color(0.23, 0.22, 0.18))
	for s in [-1.16, 1.16]:
		var end := _fp(f, s, -1.1)
		_cyl("solid", _w(end.x, end.y), 0.11, 0.085, GILT.darkened(0.18), 9)
		_cyl("solid", _w(end.x, end.y), 0.028, 0.96, GILT, 8)
		_globe("solid", _w(end.x, end.y, 0.95), 0.057, GILT)
	# A long red frontage and gilded transoms sit beside the historical entrance.
	for s in [-4.1, -6.13, -8.16]:
		_obox(f, s - 0.92, -0.084, s + 0.92, -0.022, 0.49, 3.93, WINE)
		_obox(f, s - 0.74, -0.098, s + 0.74, -0.084, 1.01, 3.54, WINE.lightened(0.08))
		_obox(f, s - 0.82, -0.103, s + 0.82, -0.086, 3.64, 3.69, GILT)
		_obox(f, s - 0.67, -0.107, s + 0.67, -0.098, 1.16, 3.15, Color(0.22, 0.13, 0.09))
		for k in range(-3, 4):
			var bar: float = s + k * 0.17
			_obox(f, bar - 0.015, -0.13, bar + 0.015, -0.098, 1.16, 3.15, GILT.darkened(0.24))
		_awning(f, s, 0.97, 3.49, 1.32, WINE)
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
	for k in range(-2, 3):
		var s := h * 0.35 * k
		_obox(f, s - 0.27, -0.095, s + 0.27, -0.07, 6.52, 7.75, Color(0.24, 0.26, 0.22))
		_obox(f, s - 0.038, -0.113, s + 0.038, -0.09, 6.52, 7.73, CREAM)
	_obox(f, -h + 0.21, -0.10, h - 0.21, -0.08, 5.43, 6.39, Color(0.13, 0.10, 0.10))
	_engraving(f, 0.0, -0.11, 5.91, "THÉÂTRE DES VARIÉTÉS", Color(0.94, 0.28, 0.22), h * 1.90)
	for s in [-h + 0.38, h - 0.38]:
		_show_poster(f, s, -0.24, 1.73, "VARIÉTÉS", WINE)


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


func _boulevard_shops() -> void:
	_shopfront("brebant", "LE BRÉBANT", Color(0.13, 0.22, 0.18), GILT, 8.5, true)
	_shopfront("brioche", "BRIOCHE DORÉE", Color(0.53, 0.35, 0.16), CREAM, 5.0, false)
	_shopfront("land_monkeys", "LAND & MONKEYS", Color(0.16, 0.35, 0.30), CREAM, 4.5, true)
	_shopfront("change_vivienne", "CHANGE VIVIENNE", Color(0.15, 0.24, 0.38), CREAM, 3.8, false)
	var place := _front("brebant", 4.0)
	if not place.is_empty():
		var f: Array = place[0]
		for t in [-2.0, -3.3]:
			var at := _fp(f, 0, t)
			if _fits_street(at, 1.3):
				_cafe_terrace(_frame(at, rad_to_deg((f[1] as Vector2).angle())), 4, POSTER_GREEN)


func _show_poster(f: Array, s: float, t: float, y: float, title: String, poster: Color) -> void:
	_obox(f, s - 0.33, t, s + 0.33, t + 0.065, y - 0.54, y + 0.55, CAST_IRON)
	_obox(f, s - 0.29, t - 0.01, s + 0.29, t, y - 0.49, y + 0.49, poster)
	_engraving(f, s, t - 0.024, y + 0.32, title, CREAM, 0.54)
	_disc_face(f, s, t - 0.024, y + 0.01, 0.18, 0.0, GILT.darkened(0.06))
	for i in 4:
		_obox(f, s - 0.17, t - 0.017, s + 0.17, t - 0.011, y - 0.26 - i * 0.045, y - 0.245 - i * 0.045, CREAM)


func _arcade_shopfronts() -> void:
	var passages := [
		[Vector2(-16.65, 16.56), Vector2(-36.14, 120.15), [
			[6.0, 1.0, "ESTAMPES"], [12.0, -1.0, "CARTES POSTALES"],
			[27.0, 1.0, "LIBRAIRIE ANCIENNE"], [65.0, -1.0, "PHILATÉLIE"],
			[83.0, 1.0, "GALERIE DES VARIÉTÉS"]]],
		[Vector2(-9.63, -17.66), Vector2(12.8, -103.61), [
			[9.5, -1.0, "LE VALENTIN"], [18.0, 1.0, "ANTIQUITÉS"],
			[36.0, -1.0, "LIBRAIRIE"], [55.0, 1.0, "GRÉVIN • LA BOUTIQUE"],
			[79.0, -1.0, "HÔTEL CHOPIN"]]],
	]
	for passage in passages:
		var start: Vector2 = passage[0]
		var along := ((passage[1] as Vector2) - start).normalized()
		var normal := Vector2(-along.y, along.x)
		for stall in passage[2]:
			var side: float = stall[1]
			var centre := start + along * float(stall[0])
			var at := centre + normal * side * 1.46
			if _fits_street(centre + normal * side * 1.7, 0.0):
				continue
			var f := _frame(at, rad_to_deg((along * side).angle()))
			var frame_color := WINE.darkened(0.42) if side > 0.0 else POSTER_GREEN
			_sign_panel(f, 0, -0.044, 3.19, 2.75, 0.47, stall[2], frame_color, GILT)
			_obox(f, -1.31, -0.048, 1.31, 0.05, 0.35, 0.53, frame_color)
			_obox(f, -1.28, -0.019, 1.28, 0.025, 0.53, 2.97, Color(0.23, 0.19, 0.15))
			for s in [-1.28, -0.42, 0.42, 1.28]:
				_obox(f, s - 0.036, -0.050, s + 0.036, 0.02, 0.53, 3.0, frame_color)
			for y in [0.82, 1.54, 2.26]:
				_obox(f, -1.24, -0.051, 1.24, -0.020, y, y + 0.037, GILT.darkened(0.31))
				for i in 18:
					var s := -1.17 + i * 0.137
					var tint := [CREAM, GILT.darkened(0.24), WINE, POSTER_GREEN][i % 4] as Color
					_obox(f, s, -0.033, s + 0.075, -0.021, y + 0.039, y + 0.26 + 0.054 * (i % 5), tint)


func _curb_details() -> void:
	for raw in _data["props"]["trees"]:
		var p := _point(raw)
		if p.length() > 122 or not _fits_street(p, 0.85):
			continue
		_grect(p.x - 0.69, p.y - 0.65, p.x + 0.69, p.y + 0.65, 0.061, Color(0.23, 0.22, 0.18), Surface.GRANITE)
		for i in range(-3, 4):
			_gstrip(p + Vector2(-0.62, i * 0.17), p + Vector2(0.62, i * 0.17), 0.019, 0.065, CAST_IRON, Surface.PAINT)
	for p in [Vector2(-31.1, -8.9), Vector2(34.0, 16.1), Vector2(48.0, 8.2), Vector2(-70.0, -16.2)]:
		if _fits_street(p, 0.35):
			_bollard(p)


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
				_gstrip(_fp(f, s - 1.9, 0), _fp(f, s + 1.9, 0), 2.56, 0.058, Color(0.68, 0.59, 0.48), Surface.SETTS)
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
		_disc_face(f, 0, -0.728, 1.63, 0.30, 0.17, CREAM.darkened(0.26))
		for n in 4:
			_obox(f, -0.27, -0.727, 0.27, -0.719, 1.04 - n * 0.072, 1.058 - n * 0.072, CREAM)


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
