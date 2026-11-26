extends "res://district.gd"
## Shared builder for the two Omsk estates (district_omsk1.gd, district_omsk2.gd):
## Siberian panel housing measured from the satellite map and Street View.
##
## Frame: u = metres east (game +X), n = metres south (game +Z), origin at the
## home block, so layout numbers read straight off the map. Unlike Neratovice,
## buildings here can stand at any angle: each one gets a frame (centre, axis
## along it, axis across it) and its walls, balconies and roof are built in
## that frame (s along, t across). Detail still merges into the chunked
## vertex-coloured meshes; walls are textured boxes; colliders are rotated boxes.

const KHRUSH_DEPTH := 12.0
const PANEL_DEPTH := 13.0
const KHRUSH_WALL := Color(0.66, 0.64, 0.6) # grey-beige concrete panels
const PANEL_WALL := Color(0.78, 0.78, 0.77) # light grey nine-storey panels
const RED_ROOF := Color(0.66, 0.2, 0.16) # the new pitched roofs
const OMSK_ASPHALT := Color(0.29, 0.29, 0.3)
const WALK_ASPHALT := Color(0.4, 0.39, 0.38)
const DIRT := Color(0.42, 0.36, 0.29)
const KERB := Color(0.72, 0.72, 0.7)
const WHITE_PVC := Color(0.92, 0.92, 0.9)
## Balcony railings and cladding: grey and white profiled sheet, painted steel, brown, blue.
const OMSK_RAILINGS := [
	[Color(0.78, 0.79, 0.8), 0.3], [Color(0.92, 0.92, 0.9), 0.2], [Color(0.45, 0.47, 0.5), 0.15],
	[Color(0.5, 0.33, 0.22), 0.13], [Color(0.3, 0.45, 0.65), 0.1], [Color(0.35, 0.55, 0.4), 0.06], [Color(0.75, 0.62, 0.35), 0.06],
]
const HOUSE_WALLS := [
	Color(0.55, 0.38, 0.24), Color(0.86, 0.84, 0.76), Color(0.83, 0.72, 0.42), Color(0.5, 0.62, 0.48),
	Color(0.62, 0.7, 0.78), Color(0.72, 0.5, 0.36), Color(0.9, 0.88, 0.82),
]
const HOUSE_ROOFS := [Color(0.45, 0.47, 0.5), Color(0.25, 0.38, 0.55), Color(0.55, 0.2, 0.15), Color(0.36, 0.28, 0.22), Color(0.3, 0.45, 0.32)]


func _ready() -> void:
	_rng.seed = _layout_seed()
	_collision = StaticBody3D.new()
	_collision.name = "DistrictCollision"
	add_child(_collision)

	_build_layout()
	_index_rects()
	_build_terrain()
	_build_trees()
	_build_leaves()
	for key in _chunks:
		var kind := str(key).get_slice("|", 0)
		_commit(_chunks[key], "Detail_" + str(key).replace("|", "_"), _glass_material() if kind == "glass" else _vertex_material())
	_spawn_cars()
	_build_traffic()
	var birds := MultiMeshInstance3D.new()
	birds.name = "Birds"
	birds.set_script(load("res://birds.gd"))
	add_child(birds)
	var ambience := Node.new()
	ambience.name = "Ambience"
	ambience.set_script(load("res://ambience.gd"))
	ambience.set("swing_position", _swing_spot())
	add_child(ambience)


## Game position of a map point: u east, n south.
func _w(u: float, n: float, y := 0.0) -> Vector3:
	return Vector3(u, y, n)


# Overridden by each estate.
func _layout_seed() -> int:
	return 55


func _build_layout() -> void:
	pass


func _swing_spot() -> Vector3:
	return Vector3.ZERO


## Hand-placed trees go into _trees from the layout; this scatters the rest.
func _tree_count() -> int:
	return 300


func _hill_list() -> Array:
	return []


func _build_trees() -> void:
	# Omsk yards: birches, poplars, maples and elms, a few spruces, all in autumn.
	var attempts := 0
	var placed := 0
	var target := _tree_count()
	while placed < target and attempts < target * 40:
		attempts += 1
		var point := Vector2(_rng.randf_range(-205.0, 205.0), _rng.randf_range(-205.0, 205.0))
		if _is_blocked(point, 2.5):
			continue
		var too_close := false
		for tree in _trees:
			if (tree[1] as Vector3).distance_squared_to(Vector3(point.x, 0, point.y)) < 5.0 * 5.0:
				too_close = true
				break
		if too_close:
			continue
		var roll := _rng.randf()
		var kind := "leafy"
		if roll < 0.28:
			kind = "birch"
		elif roll < 0.46:
			kind = "poplar"
		elif roll < 0.52:
			kind = "spruce"
		_trees.append([kind, Vector3(point.x, 0, point.y), _rng.randf_range(0.85, 1.3)])
		placed += 1
	_build_tree_meshes()


## A row of trees from a to b every `step` metres (poplars along a street, birches by a path).
func _tree_row(kind: String, a: Vector2, b: Vector2, step: float) -> void:
	var count := maxi(1, int(a.distance_to(b) / step))
	for index in count + 1:
		var p := a.lerp(b, float(index) / count)
		_trees.append([kind, Vector3(p.x, 0, p.y), _rng.randf_range(0.9, 1.2)])


# ----------------------------------------------------------------- frames ----

## Building frame: [centre (u, n), unit vector along, unit vector across]. Yaw is
## measured from east towards south (clockwise on the map).
func _frame(c: Vector2, yaw_degrees: float) -> Array:
	var a := Vector2(cos(deg_to_rad(yaw_degrees)), sin(deg_to_rad(yaw_degrees)))
	return [c, a, Vector2(-a.y, a.x)]


## Map point at (s along, t across) in a frame.
func _fp(f: Array, s: float, t: float) -> Vector2:
	return (f[0] as Vector2) + (f[1] as Vector2) * s + (f[2] as Vector2) * t


func _fbasis(f: Array) -> Basis:
	var a: Vector2 = f[1]
	var p: Vector2 = f[2]
	return Basis(Vector3(a.x, 0, a.y), Vector3.UP, Vector3(p.x, 0, p.y))


## Game-space yaw for a Label3D facing out of the +t side of a frame.
func _face_yaw(f: Array, side: float) -> float:
	var p: Vector2 = (f[2] as Vector2) * side
	return rad_to_deg(atan2(p.x, p.y))


## Box in frame coordinates, merged into the detail mesh ("solid" or "glass").
func _obox(f: Array, s0: float, t0: float, s1: float, t1: float, y0: float, y1: float, color: Color, kind := "solid") -> void:
	var lo := Vector3(minf(s0, s1), minf(y0, y1), minf(t0, t1))
	var hi := Vector3(maxf(s0, s1), maxf(y0, y1), maxf(t0, t1))
	if hi.x - lo.x < 0.001 or hi.y - lo.y < 0.001 or hi.z - lo.z < 0.001:
		return
	var mid := _fp(f, (lo.x + hi.x) * 0.5, (lo.z + hi.z) * 0.5)
	var st := _tool(kind, _w(mid.x, mid.y))
	var xf := Transform3D(_fbasis(f), _w((f[0] as Vector2).x, (f[0] as Vector2).y))
	var c := (lo + hi) * 0.5
	var h := (hi - lo) * 0.5
	st.set_color(color)
	for face in [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]:
		var normal: Vector3 = face[0]
		var t1v: Vector3 = face[1] * h
		var t2v: Vector3 = face[2] * h
		var centre: Vector3 = c + normal * h
		st.set_normal(xf.basis * normal)
		for p in [centre - t1v - t2v, centre + t1v + t2v, centre + t1v - t2v, centre - t1v - t2v, centre - t1v + t2v, centre + t1v + t2v]:
			st.add_vertex(xf * p)


## Solid box collider in frame coordinates.
func _ocollider(f: Array, s0: float, t0: float, s1: float, t1: float, y0: float, y1: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(absf(s1 - s0), absf(y1 - y0), absf(t1 - t0))
	var node := CollisionShape3D.new()
	node.shape = shape
	var mid := _fp(f, (s0 + s1) * 0.5, (t0 + t1) * 0.5)
	node.transform = Transform3D(_fbasis(f), _w(mid.x, mid.y, (y0 + y1) * 0.5))
	_collision.add_child(node)


## Mark a frame rectangle as built-on (or paved) for trees, leaves and hills: as
## axis-aligned pieces at most ~6 m long, so slanted buildings don't block a big square.
func _oblocked(f: Array, s0: float, t0: float, s1: float, t1: float, paved := false) -> void:
	var pieces := maxi(1, ceili(absf(s1 - s0) / 6.0))
	var across := maxi(1, ceili(absf(t1 - t0) / 6.0))
	var axis_aligned := absf((f[1] as Vector2).x) > 0.999 or absf((f[1] as Vector2).y) > 0.999
	if axis_aligned:
		pieces = 1
		across = 1
	for i in pieces:
		for j in across:
			var sa := lerpf(s0, s1, float(i) / pieces)
			var sb := lerpf(s0, s1, float(i + 1) / pieces)
			var ta := lerpf(t0, t1, float(j) / across)
			var tb := lerpf(t0, t1, float(j + 1) / across)
			var rect := Rect2(_fp(f, sa, ta), Vector2.ZERO)
			for corner in [_fp(f, sb, ta), _fp(f, sb, tb), _fp(f, sa, tb)]:
				rect = rect.expand(corner)
			_blocked.append(rect)
			if paved:
				_paved.append(rect)


## Textured wall box (its own mesh) in a frame, with the facade texture laid out in that frame.
func _owall(node_name: String, f: Array, s0: float, t0: float, s1: float, t1: float, y0: float, y1: float, tint: Color, kind := "back") -> void:
	var size := Vector3(absf(s1 - s0), absf(y1 - y0), absf(t1 - t0))
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _ofacade(tint, kind, size, (y0 + y1) * 0.5)
	var mid := _fp(f, (s0 + s1) * 0.5, (t0 + t1) * 0.5)
	instance.transform = Transform3D(_fbasis(f), _w(mid.x, mid.y, (y0 + y1) * 0.5))
	add_child(instance)


## Facade in object space: one tile = 3 m x FLOOR, floors starting at PLINTH, tiles
## starting at the box's corner, so the windows sit right on any rotated block.
func _ofacade(tint: Color, kind: String, size: Vector3, centre_y: float) -> StandardMaterial3D:
	var offset := Vector3(fposmod(size.x / 6.0, 1.0), fposmod((centre_y - PLINTH) / FLOOR, 1.0), fposmod(size.z / 6.0, 1.0))
	offset = offset.snapped(Vector3.ONE * 0.02)
	var key := "ofacade_%s_%s_%s" % [kind, tint.to_html(), offset]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.albedo_texture = _facade_texture(kind)
		material.roughness = 0.88
		material.uv1_triplanar = true
		material.uv1_triplanar_sharpness = 8.0
		material.uv1_scale = Vector3(1.0 / 3.0, 1.0 / FLOOR, 1.0 / 3.0)
		material.uv1_offset = offset
		_materials[key] = material
	return _materials[key]


## Pitched roof over a frame rectangle, ridge along s; gables in `gable` colour.
func _oroof(f: Array, s0: float, t0: float, s1: float, t1: float, base: float, rise: float, color: Color, gable: Color) -> void:
	var tm := (t0 + t1) * 0.5
	var mid := _fp(f, (s0 + s1) * 0.5, tm)
	var st := _tool("solid", _w(mid.x, mid.y))
	var p := func(s: float, t: float, y: float) -> Vector3:
		var q := _fp(f, s, t)
		return _w(q.x, q.y, y)
	var a0: Vector3 = p.call(s0, t0, base)
	var a1: Vector3 = p.call(s1, t0, base)
	var b0: Vector3 = p.call(s0, t1, base)
	var b1: Vector3 = p.call(s1, t1, base)
	var r0: Vector3 = p.call(s0, tm, base + rise)
	var r1: Vector3 = p.call(s1, tm, base + rise)
	_quad(st, a0, a1, r1, r0, color)
	_quad(st, b0, b1, r1, r0, color.darkened(0.12))
	_tri(st, a0, b0, r0, gable)
	_tri(st, a1, b1, r1, gable)
	# Ridge cap.
	_obox(f, s0, tm - 0.15, s1, tm + 0.15, base + rise - 0.08, base + rise + 0.06, color.darkened(0.25))


## Thin paved strip in a frame (no collider), top just above the grass like _ground().
func _ostrip(f: Array, s0: float, t0: float, s1: float, t1: float, top: float, color: Color, paved := true) -> void:
	top += 0.045
	_obox(f, s0, t0, s1, t1, top - 0.1, top, color)
	if paved:
		_oblocked(f, s0, t0, s1, t1, true)


## Road or path from a to b (map points), `width` wide, optional kerbs and centre dashes.
func _road(a: Vector2, b: Vector2, width: float, color := OMSK_ASPHALT, top := 0.02, kerbs := false, dashes := false) -> void:
	var length := a.distance_to(b)
	var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
	var hs := length * 0.5
	var ht := width * 0.5
	_ostrip(f, -hs, -ht, hs, ht, top, color)
	if kerbs:
		for side in [-1.0, 1.0]:
			_obox(f, -hs, side * ht, hs, side * (ht + 0.15), 0.0, top + 0.17, KERB)
	if dashes:
		var s := -hs + 2.0
		while s < hs - 3.0:
			_obox(f, s, -0.07, s + 3.0, 0.07, top + 0.04, top + 0.056, LINE_COLOR)
			s += 9.0


## Zebra crossing across a road at `at`, road running along `yaw`.
func _zebra(at: Vector2, yaw: float, road_width: float) -> void:
	var f := _frame(at, yaw)
	var t := -road_width * 0.5 + 0.3
	while t < road_width * 0.5 - 0.3:
		_obox(f, -1.8, t, 1.8, t + 0.5, 0.06, 0.076, Color(0.93, 0.93, 0.9))
		t += 1.0


# -------------------------------------------------------------- buildings ----

## Five-storey "khrushchyovka": grey panel walls, small balconies stacked on the
## `balcony_side` long face (+1 = +t), entrances with concrete canopies on the other,
## and a red pitched roof (the new ones) or the old flat one with a parapet.
func _khrushchyovka(block_name: String, c: Vector2, length: float, yaw: float, balcony_side := 1.0,
		wall := KHRUSH_WALL, pitched := true, floors := 5, depth := KHRUSH_DEPTH) -> Array:
	var f := _frame(c, yaw)
	var hs := length * 0.5
	var ht := depth * 0.5
	var top := PLINTH + floors * FLOOR
	var tint := wall * _rng.randf_range(0.95, 1.04)
	_owall(block_name, f, -hs, -ht, hs, ht, 0.0, top, tint)
	_ocollider(f, -hs, -ht, hs, ht, 0.0, top)
	_oblocked(f, -hs, -ht, hs, ht)
	_obox(f, -hs - 0.06, -ht - 0.06, hs + 0.06, ht + 0.06, 0.0, PLINTH, tint.darkened(0.38))
	# Darker sealant lines along every floor slab.
	for floor_index in range(1, floors):
		var y := PLINTH + floor_index * FLOOR
		_obox(f, -hs - 0.02, -ht - 0.02, hs + 0.02, ht + 0.02, y - 0.04, y + 0.03, tint.darkened(0.25))
	var sections := maxi(1, roundi(length / 15.0))
	var section_length := length / sections
	var entrance_t := -balcony_side * ht
	var balcony_t := balcony_side * ht
	for k in sections:
		var sc := -hs + section_length * (k + 0.5)
		_entrance(f, sc, entrance_t, -balcony_side, floors)
		for offset in [-section_length * 0.28, section_length * 0.28]:
			for floor_index in range(1, floors):
				if _rng.randf() < 0.9:
					_balcony(f, sc + offset, balcony_t, balcony_side, PLINTH + floor_index * FLOOR, 2.7)
	if pitched:
		_obox(f, -hs - 0.1, -ht - 0.1, hs + 0.1, ht + 0.1, top, top + 0.25, tint.darkened(0.1))
		_oroof(f, -hs - 0.45, -ht - 0.55, hs + 0.45, ht + 0.55, top + 0.25, 2.1, RED_ROOF, tint.darkened(0.05))
	else:
		_flat_roof(f, hs, ht, top, tint)
	return f


## Nine-storey panel slab: light grey panels, loggias in two of every three bays on
## `loggia_side`, entrances with canopies on the other, flat roof with lift rooms.
## A ground-floor shop gets `shop_sign` over the entrance side near the +s end.
func _panel_slab(block_name: String, c: Vector2, length: float, yaw: float, loggia_side := 1.0,
		floors := 9, wall := PANEL_WALL, shop_sign := "") -> Array:
	var f := _frame(c, yaw)
	var hs := length * 0.5
	var ht := PANEL_DEPTH * 0.5
	var top := PLINTH + floors * FLOOR
	var tint := wall * _rng.randf_range(0.96, 1.03)
	_owall(block_name, f, -hs, -ht, hs, ht, 0.0, top, tint)
	_ocollider(f, -hs, -ht, hs, ht, 0.0, top)
	_oblocked(f, -hs, -ht, hs, ht)
	_obox(f, -hs - 0.06, -ht - 0.06, hs + 0.06, ht + 0.06, 0.0, PLINTH, tint.darkened(0.42))
	# Panel joints: a thin line at every floor and every 3.6 m (sealed in red-brown in places).
	for floor_index in range(1, floors):
		var y := PLINTH + floor_index * FLOOR
		_obox(f, -hs - 0.02, -ht - 0.02, hs + 0.02, ht + 0.02, y - 0.03, y + 0.03, tint.darkened(0.22))
	var bays := maxi(2, roundi(length / 3.6))
	var bay := length / bays
	var loggia_t := loggia_side * ht
	for index in bays:
		if index % 3 == 1:
			continue
		var bc := -hs + bay * (index + 0.5)
		for floor_index in range(1, floors):
			_balcony(f, bc, loggia_t, loggia_side, PLINTH + floor_index * FLOOR, bay - 0.4, true)
	var sections := maxi(1, roundi(length / 24.0))
	var section_length := length / sections
	for k in sections:
		var sc := -hs + section_length * (k + 0.5)
		_entrance(f, sc, -loggia_side * ht, -loggia_side, floors)
		_obox(f, sc - 1.6, -1.6, sc + 1.6, 1.6, top, top + 2.6, tint.darkened(0.12)) # lift room
	_flat_roof(f, hs, ht, top, tint)
	if not shop_sign.is_empty():
		var shop_s := hs - 7.0
		var face := -loggia_side * ht
		_obox(f, shop_s - 5.0, face, shop_s + 5.0, face - loggia_side * 0.05, 0.3, 2.8, GLASS, "glass")
		_obox(f, shop_s - 5.4, face, shop_s + 5.4, face - loggia_side * 0.25, 2.9, 3.6, Color(0.15, 0.35, 0.65))
		var at := _fp(f, shop_s, face - loggia_side * 0.27)
		_add_sign(shop_sign, _w(at.x, at.y, 3.25), _face_yaw(f, -loggia_side), Color(1, 1, 1), 0.012, 64)
	return f


## Flat roof: tar-grey top and a low parapet.
func _flat_roof(f: Array, hs: float, ht: float, top: float, tint: Color) -> void:
	_obox(f, -hs, -ht, hs, ht, top, top + 0.12, Color(0.32, 0.32, 0.33))
	for side in [-1.0, 1.0]:
		_obox(f, -hs - 0.08, side * (ht - 0.2), hs + 0.08, side * (ht + 0.08), top, top + 0.6, tint.darkened(0.15))
		_obox(f, side * (hs - 0.2), -ht, side * (hs + 0.08), ht, top, top + 0.6, tint.darkened(0.15))


## Stair entrance on a long face at s = sc: door, canopy, steps and the stairwell
## windows between floors. `side` is the direction the face looks (+1 = +t).
func _entrance(f: Array, sc: float, face: float, side: float, floors: int) -> void:
	_obox(f, sc - 0.65, face, sc + 0.65, face + side * 0.08, 0.0, 2.25, Color(0.3, 0.24, 0.2))
	_obox(f, sc - 0.75, face, sc + 0.75, face + side * 0.05, 2.25, 2.35, Color(0.25, 0.25, 0.25))
	_obox(f, sc - 1.4, face, sc + 1.4, face + side * 1.4, 2.6, 2.78, CONCRETE)
	_obox(f, sc - 1.3, face, sc + 1.3, face + side * 1.6, 0.0, 0.18, CONCRETE.darkened(0.12))
	_obox(f, sc - 1.3, face, sc + 1.3, face + side * 1.0, 0.18, 0.34, CONCRETE.darkened(0.08))
	for floor_index in range(1, floors):
		var y := PLINTH + floor_index * FLOOR - 1.0
		_obox(f, sc - 0.7, face, sc + 0.7, face + side * 0.05, y, y + 1.3, GLASS, "glass")
		_obox(f, sc - 0.78, face, sc + 0.78, face + side * 0.07, y - 0.1, y, WHITE_PVC)
	# Benches by the door, a bin and an intercom box.
	_obox(f, sc + 0.85, face + side * 0.02, sc + 1.05, face + side * 0.1, 1.1, 1.4, Color(0.2, 0.2, 0.22))
	if _rng.randf() < 0.7:
		_frame_bench(f, sc - 3.0, face + side * 1.2)
		if _rng.randf() < 0.5:
			_obox(f, sc + 2.2, face + side * 0.9, sc + 2.7, face + side * 1.4, 0.0, 0.7, Color(0.25, 0.4, 0.3))


## Soviet-style bench along a frame: two concrete legs, wooden slats, low backrest.
func _frame_bench(f: Array, s: float, t: float) -> void:
	var wood := Color(0.48, 0.32, 0.2).lerp(Color(0.25, 0.45, 0.3), _rng.randf() * 0.5)
	_obox(f, s - 0.9, t - 0.22, s + 0.9, t + 0.22, 0.42, 0.48, wood)
	_obox(f, s - 0.9, t + 0.18, s + 0.9, t + 0.24, 0.52, 0.86, wood)
	for leg in [-0.75, 0.75]:
		_obox(f, s + leg - 0.06, t - 0.2, s + leg + 0.06, t + 0.22, 0.0, 0.42, CONCRETE.darkened(0.1))


## A balcony or loggia hung on a facade at s = bc, `side` pointing out of the wall:
## floor slab, railing (sheet or painted steel), often glazed with white PVC or old wood.
func _balcony(f: Array, bc: float, face: float, side: float, y: float, width: float, deep := false) -> void:
	var d := 1.25 if deep else 1.0
	var s0 := bc - width * 0.5
	var s1 := bc + width * 0.5
	var t1 := face + side * d
	_obox(f, s0, face, s1, t1, y - 0.16, y, CONCRETE.lightened(0.05))
	var railing: Color = OMSK_RAILINGS[_weighted_pick(OMSK_RAILINGS)][0]
	_obox(f, s0, t1 - side * 0.06, s1, t1, y, y + 1.05, railing)
	_obox(f, s0, face, s0 + 0.06, t1, y, y + 1.05, railing)
	_obox(f, s1 - 0.06, face, s1, t1, y, y + 1.05, railing)
	var roll := _rng.randf()
	if roll < 0.5:
		# Glazed: white PVC frames, glass up to the slab above.
		var frame := WHITE_PVC if roll < 0.38 else Color(0.45, 0.3, 0.2)
		_obox(f, s0, t1 - side * 0.05, s1, t1 - side * 0.02, y + 1.05, y + FLOOR - 0.3, GLASS, "glass")
		_obox(f, s0, face, s0 + 0.05, t1, y + 1.05, y + FLOOR - 0.3, GLASS, "glass")
		_obox(f, s1 - 0.05, face, s1, t1, y + 1.05, y + FLOOR - 0.3, GLASS, "glass")
		_obox(f, s0, t1 - side * 0.07, s1, t1, y + 1.0, y + 1.1, frame)
		_obox(f, s0, t1 - side * 0.07, s1, t1, y + FLOOR - 0.36, y + FLOOR - 0.16, frame)
		for mullion in 3:
			var ms := lerpf(s0, s1, (mullion + 1) / 4.0)
			_obox(f, ms - 0.03, t1 - side * 0.07, ms + 0.03, t1, y + 1.05, y + FLOOR - 0.3, frame)
	elif roll < 0.62:
		# Washing on a line, or skis and a box.
		var clothes: Color = [Color(0.95, 0.95, 0.95), Color(0.3, 0.45, 0.8), Color(0.9, 0.3, 0.3), Color(0.95, 0.85, 0.3)][_rng.randi() % 4]
		_obox(f, s0 + 0.4, t1 - side * 0.5, s0 + 1.1, t1 - side * 0.45, y + 1.1, y + 1.9, clothes)
		_obox(f, s0 + 1.3, t1 - side * 0.5, s0 + 1.8, t1 - side * 0.45, y + 1.3, y + 1.9, clothes.darkened(0.3))
	elif roll < 0.68:
		_obox(f, s1 - 0.9, face + side * 0.1, s1 - 0.2, face + side * 0.6, y, y + 0.7, Color(0.5, 0.36, 0.22))


## Plain box building (school wing, shop, kindergarten) with a flat roof.
func _block(block_name: String, c: Vector2, size: Vector2, yaw: float, floors: int, wall: Color, kind := "back") -> Array:
	var f := _frame(c, yaw)
	var hs := size.x * 0.5
	var ht := size.y * 0.5
	var top := PLINTH + floors * FLOOR
	_owall(block_name, f, -hs, -ht, hs, ht, 0.0, top, wall, kind)
	_ocollider(f, -hs, -ht, hs, ht, 0.0, top)
	_oblocked(f, -hs, -ht, hs, ht)
	_obox(f, -hs - 0.05, -ht - 0.05, hs + 0.05, ht + 0.05, 0.0, PLINTH, wall.darkened(0.35))
	_flat_roof(f, hs, ht, top, wall)
	return f


## Door with a small canopy on the +side face of a box at s.
func _door(f: Array, s: float, face: float, side: float, color := Color(0.35, 0.3, 0.26)) -> void:
	_obox(f, s - 0.8, face, s + 0.8, face + side * 0.08, 0.0, 2.3, color)
	_obox(f, s - 1.5, face, s + 1.5, face + side * 1.3, 2.7, 2.85, CONCRETE)
	_obox(f, s - 1.4, face, s + 1.4, face + side * 1.5, 0.0, 0.2, CONCRETE.darkened(0.1))


## Row of brick garages along s, doors on the +t face (and the -t face too if double).
func _garages(c: Vector2, length: float, yaw: float, double := true) -> void:
	var depth := 12.0 if double else 6.0
	var f := _frame(c, yaw)
	var hs := length * 0.5
	var ht := depth * 0.5
	var height := 2.6
	var brick: Color = [Color(0.62, 0.33, 0.24), Color(0.8, 0.78, 0.72), Color(0.55, 0.55, 0.55)][_rng.randi() % 3]
	_obox(f, -hs, -ht, hs, ht, 0.0, height, brick)
	_ocollider(f, -hs, -ht, hs, ht, 0.0, height)
	_oblocked(f, -hs, -ht, hs, ht)
	_obox(f, -hs - 0.3, -ht - 0.4, hs + 0.3, ht + 0.4, height, height + 0.25, Color(0.2, 0.2, 0.22))
	var doors := [Color(0.35, 0.37, 0.4), Color(0.25, 0.4, 0.3), Color(0.45, 0.3, 0.2), Color(0.3, 0.38, 0.55), Color(0.55, 0.35, 0.25), Color(0.6, 0.6, 0.58)]
	var count := maxi(1, int(length / 3.4))
	var w := length / count
	for side in ([1.0, -1.0] if double else [1.0]):
		for index in count:
			var s := -hs + w * (index + 0.5)
			var door: Color = doors[_rng.randi() % doors.size()]
			_obox(f, s - w * 0.5 + 0.15, side * ht, s + w * 0.5 - 0.15, side * (ht + 0.05), 0.0, 2.2, door)
			_obox(f, s - 0.05, side * (ht + 0.04), s + 0.05, side * (ht + 0.07), 0.0, 2.2, door.darkened(0.3))
			if _rng.randf() < 0.25: # rust streak
				_obox(f, s + 0.3, side * (ht + 0.05), s + 0.6, side * (ht + 0.06), 0.0, 1.2, Color(0.5, 0.28, 0.15))
	# Graffiti now and then.
	if _rng.randf() < 0.6:
		var tags := ["ОМСК", "55", "ЦСКА?", "ЛЮБЛЮ", "ZENIT", "ОМЧ", "КРЫЛЬЯ"]
		var at := _fp(f, _rng.randf_range(-hs + 3.0, hs - 3.0), ht + 0.09)
		var label := Label3D.new()
		label.text = tags[_rng.randi() % tags.size()]
		label.position = _w(at.x, at.y, 1.35)
		label.rotation_degrees = Vector3(0, _face_yaw(f, 1.0), _rng.randf_range(-10.0, 10.0))
		label.pixel_size = 0.01
		label.font_size = 96
		label.outline_size = 20
		label.modulate = [Color(0.95, 0.3, 0.6), Color(0.2, 0.75, 0.95), Color(0.98, 0.85, 0.15), Color(0.4, 0.9, 0.35)][_rng.randi() % 4]
		label.outline_modulate = Color(0.05, 0.05, 0.05)
		label.double_sided = false
		add_child(label)


## One-storey private house with a gable roof on its plot, a fence round the plot
## and the gate on the street side (-t of the plot frame).
func _house_plot(c: Vector2, yaw: float, plot := Vector2(20.0, 24.0)) -> void:
	var f := _frame(c, yaw)
	var hs := plot.x * 0.5
	var ht := plot.y * 0.5
	var size := Vector2(_rng.randf_range(7.0, 10.0), _rng.randf_range(6.5, 8.5))
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hc := Vector2(_rng.randf_range(-hs + hx + 1.0, hs - hx - 1.0), -ht + hy + _rng.randf_range(2.0, 5.0))
	var wall: Color = HOUSE_WALLS[_rng.randi() % HOUSE_WALLS.size()]
	var roof: Color = HOUSE_ROOFS[_rng.randi() % HOUSE_ROOFS.size()]
	var height := 3.0
	_owall("House", f, hc.x - hx, hc.y - hy, hc.x + hx, hc.y + hy, 0.0, height, wall)
	_ocollider(f, hc.x - hx, hc.y - hy, hc.x + hx, hc.y + hy, 0.0, height)
	_oblocked(f, hc.x - hx, hc.y - hy, hc.x + hx, hc.y + hy)
	_oroof(f, hc.x - hx - 0.5, hc.y - hy - 0.5, hc.x + hx + 0.5, hc.y + hy + 0.5, height, 2.4, roof, wall.darkened(0.08))
	# Window shutters on the street side, a chimney.
	for ws in [hc.x - hx * 0.5, hc.x + hx * 0.5]:
		_obox(f, ws - 0.6, hc.y - hy - 0.05, ws + 0.6, hc.y - hy, 1.0, 2.2, Color(0.9, 0.9, 0.86))
		_obox(f, ws - 0.5, hc.y - hy - 0.07, ws + 0.5, hc.y - hy - 0.03, 1.1, 2.1, GLASS, "glass")
	_obox(f, hc.x + hx * 0.4, hc.y - 0.4, hc.x + hx * 0.4 + 0.6, hc.y + 0.4, height + 1.0, height + 3.2, Color(0.55, 0.3, 0.22))
	# Fence: profiled sheet or boards, on the street side and both plot sides.
	var fence: Color = [Color(0.4, 0.28, 0.18), Color(0.3, 0.42, 0.35), Color(0.55, 0.2, 0.15), Color(0.6, 0.6, 0.6), Color(0.3, 0.38, 0.55)][_rng.randi() % 5]
	var fh := _rng.randf_range(1.5, 2.0)
	var gate := _rng.randf_range(-hs + 3.0, hs - 6.0)
	_ofence(f, -hs, -ht, gate, -ht, fh, fence)
	_ofence(f, gate + 3.5, -ht, hs, -ht, fh, fence)
	_ofence(f, -hs, -ht, -hs, ht, fh, fence.darkened(0.1))
	_ofence(f, hs, -ht, hs, ht, fh, fence.darkened(0.1))
	_ofence(f, -hs, ht, hs, ht, fh, fence.darkened(0.15))
	# A shed or a banya at the back, a vegetable bed.
	if _rng.randf() < 0.7:
		var sc := Vector2(_rng.randf_range(-hs + 3.0, hs - 3.0), ht - 3.0)
		_obox(f, sc.x - 1.8, sc.y - 1.6, sc.x + 1.8, sc.y + 1.6, 0.0, 2.3, Color(0.42, 0.3, 0.2))
		_obox(f, sc.x - 2.0, sc.y - 1.8, sc.x + 2.0, sc.y + 1.8, 2.3, 2.45, roof.darkened(0.2))
		_ocollider(f, sc.x - 1.8, sc.y - 1.6, sc.x + 1.8, sc.y + 1.6, 0.0, 2.3)
		_oblocked(f, sc.x - 1.8, sc.y - 1.6, sc.x + 1.8, sc.y + 1.6)
	_obox(f, -hs + 1.5, ht - 9.0, -hs + 6.0, ht - 6.0, 0.0, 0.25, DIRT)
	# One apple or birch tree in most gardens.
	if _rng.randf() < 0.75:
		var tp := _fp(f, _rng.randf_range(-hs + 2.0, hs - 2.0), _rng.randf_range(1.0, ht - 2.0))
		_trees.append(["birch" if _rng.randf() < 0.4 else "leafy", Vector3(tp.x, 0, tp.y), _rng.randf_range(0.7, 1.0)])


## Fence panel between two frame points, with a collider.
func _ofence(f: Array, s0: float, t0: float, s1: float, t1: float, height: float, color: Color) -> void:
	var length := Vector2(s0, t0).distance_to(Vector2(s1, t1))
	if length < 0.1:
		return
	var a := _fp(f, s0, t0)
	var b := _fp(f, s1, t1)
	var g := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
	_obox(g, -length * 0.5, -0.04, length * 0.5, 0.04, 0.0, height, color)
	_ocollider(g, -length * 0.5, -0.05, length * 0.5, 0.05, 0.0, height)
	_oblocked(g, -length * 0.5, -0.3, length * 0.5, 0.3)


## Low green mesh fence round a rectangle (school, kindergarten), gaps for gates on -t.
func _mesh_fence(c: Vector2, size: Vector2, yaw: float, gates: Array = []) -> void:
	var f := _frame(c, yaw)
	var hs := size.x * 0.5
	var ht := size.y * 0.5
	var color := Color(0.22, 0.4, 0.28)
	var s := -hs
	var cuts := gates.duplicate()
	cuts.sort()
	for gate in cuts:
		_ofence(f, s, -ht, float(gate) - 2.0, -ht, 1.6, color)
		s = float(gate) + 2.0
	_ofence(f, s, -ht, hs, -ht, 1.6, color)
	_ofence(f, -hs, ht, hs, ht, 1.6, color)
	_ofence(f, -hs, -ht, -hs, ht, 1.6, color)
	_ofence(f, hs, -ht, hs, ht, 1.6, color)


## Yard playground: soft surface, swings (animated), a slide, climbing frame, sandpit, carousel.
func _yard_playground(c: Vector2, animate_swings := false) -> void:
	_ground("Playground", c.x - 8.0, c.y - 6.0, c.x + 8.0, c.y + 6.0, 0.03, Color(0.3, 0.5, 0.62))
	var red := Color(0.85, 0.2, 0.15)
	var yellow := Color(0.95, 0.78, 0.15)
	var blue := Color(0.2, 0.45, 0.8)
	# Swings: a red bar along u on two A-frames, seats swinging along n.
	var bar_n := c.y - 2.6
	for su in [c.x - 6.5, c.x - 2.5]:
		for leg in [-0.8, 0.8]:
			_box_un(su - 0.06, bar_n + leg - 0.06, su + 0.06, bar_n + leg + 0.06, 0.0, 2.4, red)
	_box_un(c.x - 6.6, bar_n - 0.06, c.x - 2.4, bar_n + 0.06, 2.35, 2.47, red)
	for seat_u in [c.x - 5.3, c.x - 3.7]:
		if animate_swings:
			_swings.append(_swing_seat(_w(seat_u, bar_n, 2.4)))
		else:
			_box_un(seat_u - 0.3, bar_n - 0.12, seat_u + 0.3, bar_n + 0.12, 0.5, 0.56, yellow)
	# Climbing tower with a slide.
	_box_un(c.x + 1.0, c.y - 4.5, c.x + 3.5, c.y - 2.0, 1.4, 1.55, yellow)
	for corner in [[1.0, -4.5], [3.5, -4.5], [1.0, -2.0], [3.5, -2.0]]:
		_box_un(c.x + corner[0] - 0.07, c.y + corner[1] - 0.07, c.x + corner[0] + 0.07, c.y + corner[1] + 0.07, 0.0, 3.0, blue)
	_box_un(c.x + 0.9, c.y - 4.6, c.x + 3.6, c.y - 1.9, 3.0, 3.2, red)
	_box_un(c.x + 3.5, c.y - 3.6, c.x + 6.5, c.y - 2.9, 0.4, 0.5, yellow)
	_box_un(c.x + 3.5, c.y - 3.6, c.x + 4.2, c.y - 2.9, 0.5, 1.4, yellow)
	_collider_between(_w(c.x + 1.0, c.y - 4.5), _w(c.x + 3.5, c.y - 2.0, 1.55))
	# Sandpit and a carousel.
	_box_un(c.x - 7.0, c.y + 1.5, c.x - 3.0, c.y + 5.0, 0.0, 0.3, Color(0.6, 0.4, 0.22))
	_box_un(c.x - 6.7, c.y + 1.8, c.x - 3.3, c.y + 4.7, 0.0, 0.32, Color(0.88, 0.8, 0.6))
	var carousel := MeshInstance3D.new()
	carousel.name = "Carousel"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.2
	disc.bottom_radius = 1.2
	disc.height = 0.1
	carousel.mesh = disc
	carousel.material_override = _plain(blue)
	carousel.position = _w(c.x + 3.0, c.y + 3.0, 0.45)
	add_child(carousel)
	_box_un(c.x + 2.9, c.y + 2.9, c.x + 3.1, c.y + 3.1, 0.0, 1.1, red)
	_bench(c.x - 1.0, c.y + 5.4, 180.0)
	_bench(c.x + 5.5, c.y - 5.4, 0.0)


## Container site: concrete slab, green sheet walls on three sides, four euro containers.
func _bin_site(u: float, n: float) -> void:
	_ground("BinSlab", u - 3.5, n - 1.8, u + 3.5, n + 1.8, 0.03, CONCRETE.darkened(0.15))
	var wall := Color(0.3, 0.5, 0.35)
	_wall_un(u - 3.5, n + 1.6, u + 3.5, n + 1.8, 1.8, wall)
	_wall_un(u - 3.5, n - 1.8, u - 3.3, n + 1.8, 1.8, wall)
	_wall_un(u + 3.3, n - 1.8, u + 3.5, n + 1.8, 1.8, wall)
	for index in 4:
		var color: Color = [Color(0.2, 0.42, 0.25), Color(0.2, 0.42, 0.25), Color(0.15, 0.35, 0.75), Color(0.45, 0.47, 0.48)][index]
		_bin(u - 2.4 + index * 1.6, n + 0.7, color, true)


## Bus shelter facing -n (towards the road on its north side).
func _bus_stop(u: float, n: float) -> void:
	_glass_un(u - 2.5, n + 0.9, u + 2.5, n + 0.96, 0.15, 2.3)
	_glass_un(u - 2.56, n - 0.4, u - 2.5, n + 0.96, 0.15, 2.3)
	_glass_un(u + 2.5, n - 0.4, u + 2.56, n + 0.96, 0.15, 2.3)
	_box_un(u - 2.7, n - 0.6, u + 2.7, n + 1.1, 2.3, 2.45, Color(0.2, 0.35, 0.6))
	_bench(u, n + 0.5, 0.0)
	_wall_un(u - 2.56, n + 0.9, u + 2.56, n + 0.96, 2.3, Color(0.4, 0.5, 0.55))
	_box_un(u + 3.3, n - 0.6, u + 3.38, n - 0.52, 0.0, 2.8, Color(0.6, 0.62, 0.62))
	_box_un(u + 3.0, n - 0.64, u + 3.7, n - 0.6, 2.2, 2.8, Color(0.95, 0.95, 0.95))
	_add_sign("А", _w(u + 3.34, n - 0.66, 2.5), 180.0, Color(0.1, 0.2, 0.55), 0.008, 64)


## Concrete street lamp with a cobra-head arm reaching towards `towards` (map direction).
func _street_lamp(u: float, n: float, towards: Vector2) -> void:
	var f := _frame(Vector2(u, n), rad_to_deg(towards.angle()))
	var pole := Color(0.6, 0.6, 0.58)
	_obox(f, -0.13, -0.13, 0.13, 0.13, 0.0, 8.0, pole)
	_obox(f, 0.0, -0.05, 1.6, 0.05, 7.8, 7.9, Color(0.4, 0.42, 0.44))
	_obox(f, 1.3, -0.2, 2.0, 0.2, 7.65, 7.85, Color(0.3, 0.32, 0.34))
	_obox(f, 1.35, -0.16, 1.95, 0.16, 7.6, 7.65, Color(0.95, 0.9, 0.75), "glass")
	_ocollider(f, -0.15, -0.15, 0.15, 0.15, 0.0, 8.0)


## Shop sign on a frame face.
func _frame_sign(f: Array, s: float, face: float, side: float, y: float, text: String, board: Color, ink: Color, width := 6.0) -> void:
	_obox(f, s - width * 0.5, face, s + width * 0.5, face + side * 0.12, y - 0.45, y + 0.45, board)
	var at := _fp(f, s, face + side * 0.14)
	_add_sign(text, _w(at.x, at.y, y), _face_yaw(f, side), ink, 0.009, 64)


## Cars parked along a frame line from s0 to s1 at t, nose along s (or across if `across`).
func _park_row(f: Array, s0: float, s1: float, t: float, across := false, fill := 0.75) -> void:
	var step := 2.7 if across else 5.4
	var s := s0
	var base_yaw := rad_to_deg(atan2((f[1] as Vector2).x, (f[1] as Vector2).y))
	while s <= s1:
		if _rng.randf() < fill:
			var p := _fp(f, s, t)
			_car_spots.append(_car_transform(p.x, p.y, base_yaw + (90.0 if across else 0.0)))
		s += step
