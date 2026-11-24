class_name WeaponIcons
extends RefCounted
## Flat silhouettes of the weapons, drawn on any CanvasItem: for the weapon bar
## (weapon_bar.gd) and the touch WEAPON button (mobile_controls.gd). Drawn in a
## box about 48 x 28 units round `centre`, times `size`.


static func draw(canvas: CanvasItem, kind: String, centre: Vector2, size: float, color: Color, accent := Color(0.85, 0.2, 0.12)) -> void:
	match kind:
		"pistol":
			_pistol(canvas, centre, size, color)
		"bat":
			_bat(canvas, centre, size, color)
		"bazooka":
			_bazooka(canvas, centre, size, color, accent)
		_:
			_fist(canvas, centre, size, color)


static func _poly(canvas: CanvasItem, centre: Vector2, size: float, points: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for p in points:
		packed.append(centre + (p as Vector2) * size)
	canvas.draw_colored_polygon(packed, color)


static func _pistol(canvas: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	# Slide and barrel, pointing right; grip slanting back; trigger guard.
	_poly(canvas, c, s, [Vector2(-15, -9), Vector2(16, -9), Vector2(16, -2), Vector2(-15, -2)], color)
	_poly(canvas, c, s, [Vector2(-15, -2), Vector2(-4, -2), Vector2(-7, 12), Vector2(-17, 12), Vector2(-16, 3)], color)
	canvas.draw_arc(c + Vector2(-1, 1) * s, 4.5 * s, 0.0, PI, 10, color, 2.0 * s, true)


static func _bat(canvas: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	# Knob bottom-left, the barrel thickening up to the right.
	var dir := Vector2(1.0, -0.55).normalized()
	var side := Vector2(-dir.y, dir.x)
	var a := Vector2(-20, 11)
	var b := Vector2(20, -11)
	var points := [a + side * 1.8, a.lerp(b, 0.45) + side * 2.4, b + side * 5.0 - dir * 1.0, b + dir * 0.5,
		b - side * 5.0 - dir * 1.0, a.lerp(b, 0.45) - side * 2.4, a - side * 1.8]
	_poly(canvas, c, s, points, color)
	canvas.draw_circle(c + (a - dir * 0.6) * s, 3.0 * s, color)


static func _bazooka(canvas: CanvasItem, c: Vector2, s: float, color: Color, accent: Color) -> void:
	_poly(canvas, c, s, [Vector2(-19, -4), Vector2(14, -4), Vector2(14, 4), Vector2(-19, 4)], color)
	_poly(canvas, c, s, [Vector2(14, -5.5), Vector2(19, -6.5), Vector2(19, 6.5), Vector2(14, 5.5)], color)
	_poly(canvas, c, s, [Vector2(-24, -7), Vector2(-19, -4.5), Vector2(-19, 4.5), Vector2(-24, 7)], color)
	_poly(canvas, c, s, [Vector2(-5, 4), Vector2(-1, 4), Vector2(-2, 12), Vector2(-6, 12)], color)
	_poly(canvas, c, s, [Vector2(4, -4), Vector2(9, -4), Vector2(9, -8), Vector2(4, -8)], color)
	if accent.a > 0.0:
		_poly(canvas, c, s, [Vector2(19, -4), Vector2(23, -3), Vector2(27, 0), Vector2(23, 3), Vector2(19, 4)], accent)


static func _fist(canvas: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	# An open hand, fingers up.
	_poly(canvas, c, s, [Vector2(-9, -1), Vector2(9, -1), Vector2(8, 10), Vector2(4, 13), Vector2(-5, 13), Vector2(-8, 9)], color)
	for k in 4:
		var x := -7.0 + k * 4.6
		var top := -11.0 if k == 1 or k == 2 else -8.5
		canvas.draw_rect(Rect2(c + Vector2(x - 1.6, top) * s, Vector2(3.4, -top) * s), color)
		canvas.draw_circle(c + Vector2(x + 0.1, top) * s, 1.7 * s, color)
	_poly(canvas, c, s, [Vector2(-9, 2), Vector2(-15, -3), Vector2(-16, -1), Vector2(-9, 7)], color)
