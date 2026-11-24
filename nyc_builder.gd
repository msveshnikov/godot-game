extends "res://district_omsk.gd"
## Geometry toolkit for the New York island (district_nyc.gd): street surfaces in
## the pavement shader, buildings extruded from OpenStreetMap footprints with the
## procedural facade shader, LED screens and tickers, neon, cylinders and cones.
##
## Frame (as in district_omsk.gd): u = metres "Manhattan east" = game +X, n = metres
## "Manhattan south" = game +Z. Footprints are counter-clockwise in (u, n), so the
## outward normal of an edge a -> b is (d.n, -d.u).
##
## Chunk kinds (each committed with its own material): "solid" and "glass" as in
## the estates, "ground" (pavement.gdshader), "facade" (facade.gdshader),
## "screen" (screen.gdshader), "glow" (self-lit neon and bulbs), "sig<axis><colour>"
## (traffic light lamps switched by the signal cycle).

const FACADE_SHADER := preload("res://facade.gdshader")
const PAVEMENT_SHADER := preload("res://pavement.gdshader")
const SCREEN_SHADER := preload("res://screen.gdshader")
const ADS := preload("res://nyc_ads.gd")

enum Surface { SIDEWALK, PLAZA, ASPHALT, HEX, GRANITE, PAINT }
enum Style { BRICK, STONE, GLASS, RIBBON, GRID, DARK_GLASS, BLANK, SEAWALL }

## Merged meshes here cover 96 m cells (the estates use 48 m): the island has far
## more kinds of detail, so bigger cells keep the draw calls down.
const NYC_CHUNK := 96.0

## Collision faces of the buildings, per chunk (ConcavePolygonShape3D each).
var _wall_faces := {}
## Walls with shop fronts at street level: [a, b (game xz), s at a, facade seed], for
## smash_window(). The shader draws the windows; which ones are broken it reads
## from _damage (one texel per window, at the window's middle; 1 m texels).
var _shop_walls: Array = []
var _damage: Image
var _damage_texture: ImageTexture
var _damage_origin := Vector2.ZERO
var _screen_material: ShaderMaterial
var _signal_materials := {}


# -------------------------------------------------------------- ground ----

## Triangle facing up (clockwise seen from above, Godot's front face).
func _up_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var cross_y := (b.z - a.z) * (c.x - a.x) - (b.x - a.x) * (c.z - a.z)
	if cross_y > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Flat polygon of (u, n) points at height y on the ground chunks.
func _gpoly(points: PackedVector2Array, y: float, color: Color, surface: int) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		return
	var centre := Vector2.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	var st := _tool("ground", _w(centre.x, centre.y))
	st.set_color(Color(color.r, color.g, color.b, surface / 10.0))
	st.set_normal(Vector3.UP)
	for k in range(0, indices.size(), 3):
		var a := points[indices[k]]
		var b := points[indices[k + 1]]
		var c := points[indices[k + 2]]
		_up_tri(st, _w(a.x, a.y, y), _w(b.x, b.y, y), _w(c.x, c.y, y))


func _grect(u0: float, n0: float, u1: float, n1: float, y: float, color: Color, surface: int) -> void:
	_gpoly(PackedVector2Array([Vector2(u0, n0), Vector2(u1, n0), Vector2(u1, n1), Vector2(u0, n1)]), y, color, surface)


## Oriented strip from a to b, `width` wide, at height y.
func _gstrip(a: Vector2, b: Vector2, width: float, y: float, color: Color, surface: int) -> void:
	var side := (b - a).normalized().orthogonal() * width * 0.5
	_gpoly(PackedVector2Array([a - side, b - side, b + side, a + side]), y, color, surface)


## Box on the ground chunks (kerbs, coping stones) between (u, n, y) corners.
func _gbox(u0: float, n0: float, u1: float, n1: float, y0: float, y1: float, color: Color, surface: int) -> void:
	_add_box(_tool("ground", _w((u0 + u1) * 0.5, (n0 + n1) * 0.5)), _w(u0, n0, y0), _w(u1, n1, y1), Color(color.r, color.g, color.b, surface / 10.0))


# ----------------------------------------------------------- buildings ----

## Extrude a footprint between y0 and y1 with the facade shader. `style` picks the
## facade, `seed` (0..1) varies it, `shops` puts shop fronts at street level.
## Walls also go into the collision faces. Returns the perimeter length.
func _extrude(points: PackedVector2Array, y0: float, y1: float, style: int, seed: float, tint: Color, shops: bool, collide := true) -> float:
	var centre := Vector2.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	var at := _w(centre.x, centre.y)
	var st := _tool("facade", at)
	var color := Color(tint.r, tint.g, tint.b, 1.0 if shops else 0.0)
	var uv2 := Vector2(float(style) + clampf(seed, 0.0, 0.99), y1)
	var s := 0.0
	var faces: PackedVector3Array = _faces_for(at) if collide else PackedVector3Array()
	for index in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var d := (b - a) / length
		var normal := Vector3(d.y, 0.0, -d.x)
		var a0 := _w(a.x, a.y, y0)
		var b0 := _w(b.x, b.y, y0)
		var b1 := _w(b.x, b.y, y1)
		var a1 := _w(a.x, a.y, y1)
		st.set_color(color)
		st.set_uv2(uv2)
		st.set_normal(normal)
		# Front face is clockwise seen from outside: A is on the viewer's right.
		for corner in [[a0, s, y0], [b1, s + length, y1], [a1, s, y1], [a0, s, y0], [b0, s + length, y0], [b1, s + length, y1]]:
			st.set_uv(Vector2(corner[1], corner[2]))
			st.add_vertex(corner[0])
		if collide:
			faces.append_array([a0, b1, a1, a0, b0, b1])
		if shops and y0 < 0.5 and style != Style.BLANK:
			_shop_walls.append([Vector2(a0.x, a0.z), Vector2(b0.x, b0.z), s, clampf(seed, 0.0, 0.99)])
		s += length
	if collide:
		_wall_faces[_chunk_key(at)] = faces
	return s


## Trees and parked cars: one multimesh per 150 m cell instead of per 48 m.
func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], _cell := CHUNK) -> void:
	super._add_multimesh(node_name, mesh, transforms, colors, 150.0)


func _chunk_key(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / NYC_CHUNK), floori(at.z / NYC_CHUNK))


func _tool(kind: String, at: Vector3) -> SurfaceTool:
	# Small scattered things (signal lamps, neon, bulbs, glass) in a few big meshes.
	var cell := NYC_CHUNK
	if kind.begins_with("sig"):
		cell = 4000.0
	elif kind in ["glow", "neon", "glass", "screen"]:
		cell = 300.0
	var key := "%s|%d|%d" % [kind, floori(at.x / cell), floori(at.z / cell)]
	if not _chunks.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_chunks[key] = st
	return _chunks[key]


func _faces_for(at: Vector3) -> PackedVector3Array:
	return _wall_faces.get(_chunk_key(at), PackedVector3Array())


## Flat roof (or any horizontal cap) over a footprint, into the solid chunks.
func _cap(points: PackedVector2Array, y: float, color: Color, kind := "solid") -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		return
	var centre := Vector2.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	var st := _tool(kind, _w(centre.x, centre.y))
	st.set_color(color)
	st.set_normal(Vector3.UP)
	for k in range(0, indices.size(), 3):
		var a := points[indices[k]]
		var b := points[indices[k + 1]]
		var c := points[indices[k + 2]]
		_up_tri(st, _w(a.x, a.y, y), _w(b.x, b.y, y), _w(c.x, c.y, y))


## Parapet: a low wall along every edge of a roof.
func _parapet(points: PackedVector2Array, y: float, height: float, color: Color) -> void:
	for index in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		var length := a.distance_to(b)
		if length < 0.5:
			continue
		var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
		# Inside of a CCW footprint is +t in the edge frame.
		_obox(f, -length * 0.5, 0.0, length * 0.5, 0.3, y, y + height, color)


## Collision for all extruded walls, one concave shape per chunk.
func _commit_wall_faces() -> void:
	for key in _wall_faces:
		var faces: PackedVector3Array = _wall_faces[key]
		if faces.is_empty():
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var node := CollisionShape3D.new()
		node.name = "Walls_%d_%d" % [key.x, key.y]
		node.shape = shape
		_collision.add_child(node)


func _point_in(points: PackedVector2Array, p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, points)


func _area(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		total += a.x * b.y - b.x * a.y
	return total * 0.5


func _centroid(points: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in points:
		c += p
	return c / maxf(1.0, points.size())


# ----------------------------------------------------- shop windows ----

## Shop width as facade.gdshader lays the fronts out for a building's seed.
static func shop_unit(seed: float) -> float:
	return 7.0 + fposmod(seed * 3.1, 1.0) * 3.0


## A blow (bat or bullet) landing on a wall at `point`: if that is a shop window,
## the first one cracks it, the next smashes it out, glass all over the pavement.
## Returns the window's state after the blow: 1 cracked, 2 smashed, 0 not a window
## (or one already gone). Everyone replays the same point (net_world.gd), so all
## see the same pane go.
func smash_window(point: Vector3) -> int:
	var p := Vector2(point.x, point.z)
	var best := 0.3
	var wall: Array = []
	var along := 0.0
	for w in _shop_walls:
		var a: Vector2 = w[0]
		var ab: Vector2 = (w[1] as Vector2) - a
		var length_sq := ab.length_squared()
		if length_sq < 0.0001:
			continue
		var t := clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
		var d := (a + ab * t).distance_to(p)
		if d < best:
			best = d
			wall = w
			along = t * sqrt(length_sq)
	if wall.is_empty():
		return 0
	var unit := shop_unit(wall[3])
	var s: float = float(wall[2]) + along
	var index := floorf(s / unit)
	var x := s - index * unit
	var y := point.y
	var in_window := x > 0.2 and x < unit - 0.2 and y > 0.45 and y < 3.5
	var in_door := x > unit * 0.62 and x < unit * 0.62 + 1.6 and y < 2.6
	if not (in_window or in_door):
		return 0
	var a: Vector2 = wall[0]
	var d := ((wall[1] as Vector2) - a).normalized()
	var middle := a + d * ((index + 0.5) * unit - float(wall[2]))
	_ensure_damage_map()
	var texel := Vector2i(((middle - _damage_origin)).floor())
	if texel.x < 1 or texel.y < 1 or texel.x >= _damage.get_width() - 1 or texel.y >= _damage.get_height() - 1:
		return 0
	var before := _damage.get_pixelv(texel)
	if before.r > 0.75:
		return 0
	var stage := 2 if before.r > 0.25 else 1
	var mark := Color(1.0 if stage == 2 else 0.5, x / unit, clampf(y / 4.0, 0.0, 1.0), fposmod(middle.x * 0.37 + middle.y * 0.71, 1.0))
	if stage == 2:
		mark.g = before.g # the cracks stay centred where the first blow landed
		mark.b = before.b
		mark.a = before.a
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_damage.set_pixelv(texel + Vector2i(dx, dy), mark)
	_damage_texture.update(_damage)
	var out := Vector3(d.y, 0.0, -d.x)
	var pane_middle := Vector3(middle.x, 0.45, middle.y)
	if stage == 1:
		GlassFx.crack_sound(self, point)
	else:
		var ground := GlassFx.ground_below(self, pane_middle + out * 0.6)
		GlassFx.shatter(self, pane_middle + out * 0.03, Vector3(d.x, 0.0, d.y), unit * 0.5 - 0.25, 3.0, out, ground, 110)
	return stage


## A blast at `centre`: every shop window along the walls within `radius` is blown
## out at once. Returns the points hit (each window's middle), for the network:
## smash_window at each, twice, does the same on another screen.
func blow_out_windows(centre: Vector3, radius: float) -> Array[Vector3]:
	var hit: Array[Vector3] = []
	if centre.y > 3.5 + radius:
		return hit
	var c := Vector2(centre.x, centre.z)
	for w in _shop_walls:
		var a: Vector2 = w[0]
		var ab: Vector2 = (w[1] as Vector2) - a
		var length := ab.length()
		if length < 0.01:
			continue
		var d := ab / length
		var t := clampf((c - a).dot(d), 0.0, length)
		if (a + d * t).distance_to(c) > radius:
			continue
		var unit := shop_unit(w[3])
		var s0 := float(w[2])
		var first := floori((s0 + maxf(t - radius, 0.0)) / unit)
		var last := floori((s0 + minf(t + radius, length)) / unit)
		for index in range(first, last + 1):
			var along := (index + 0.4) * unit - s0
			if along < 0.0 or along > length:
				continue
			var spot := a + d * along
			var point := Vector3(spot.x, 1.6, spot.y)
			if point.distance_to(centre) > radius + 1.0:
				continue
			var stage := smash_window(point)
			if stage == 1:
				stage = smash_window(point)
			if stage == 2:
				hit.append(point)
	return hit


## The damage map over the island, made at the first blow: one RGBA8 texel per
## metre (r: 0 whole, 0.5 cracked, 1 smashed; g, b: where the first blow landed
## across and up the window; a: a random seed for the crack pattern).
func _ensure_damage_map() -> void:
	if _damage != null:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for w in _shop_walls:
		for corner in [w[0], w[1]]:
			lo = lo.min(corner)
			hi = hi.max(corner)
	if lo.x > hi.x:
		lo = Vector2.ZERO
		hi = Vector2.ONE
	_damage_origin = (lo - Vector2(8, 8)).floor()
	var size := Vector2i((hi - _damage_origin + Vector2(8, 8)).ceil())
	_damage = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	_damage_texture = ImageTexture.create_from_image(_damage)
	var material := _facade_material()
	material.set_shader_parameter("damage_map", _damage_texture)
	material.set_shader_parameter("damage_origin", _damage_origin)
	material.set_shader_parameter("damage_on", true)


# ------------------------------------------------------- round things ----

## Vertical cylinder (prism) in a chunk kind, centre of its base at `base`.
func _cyl(kind: String, base: Vector3, radius: float, height: float, color: Color, segments := 12, top_cap := true) -> void:
	var st := _tool(kind, base)
	st.set_color(color)
	for k in segments:
		var a0 := TAU * k / segments
		var a1 := TAU * (k + 1) / segments
		var p0 := base + Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := base + Vector3(cos(a1), 0, sin(a1)) * radius
		var normal := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		st.set_normal(normal)
		_front_quad(st, p0, p1, p1 + Vector3.UP * height, p0 + Vector3.UP * height, normal)
		if top_cap:
			st.set_normal(Vector3.UP)
			_up_tri(st, base + Vector3.UP * height, p0 + Vector3.UP * height, p1 + Vector3.UP * height)


## Cone (or a frustum when top_radius > 0) standing on `base`.
func _cone(kind: String, base: Vector3, radius: float, top_radius: float, height: float, color: Color, segments := 12) -> void:
	var st := _tool(kind, base)
	st.set_color(color)
	for k in segments:
		var a0 := TAU * k / segments
		var a1 := TAU * (k + 1) / segments
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var normal := (Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5)) * height + Vector3.UP * (radius - top_radius)).normalized()
		st.set_normal(normal)
		var top := base + Vector3.UP * height
		if top_radius <= 0.001:
			_front_tri(st, base + d0 * radius, base + d1 * radius, top, normal)
		else:
			_front_quad(st, base + d0 * radius, base + d1 * radius, top + d1 * top_radius, top + d0 * top_radius, normal)


## Sphere-ish ball (two cones round the middle and a band) for lamps and globes.
func _globe(kind: String, centre: Vector3, radius: float, color: Color) -> void:
	_cone(kind, centre - Vector3.UP * radius, radius * 0.45, radius, radius * 0.7, color, 10)
	_cone(kind, centre + Vector3.UP * radius * 0.3, radius, radius * 0.45, radius * 0.7, color, 10)
	_cyl(kind, centre - Vector3.UP * radius * 0.3, radius, radius * 0.6, color, 10, false)


func _front_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _front_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_front_tri(st, a, b, c, normal)
	_front_tri(st, a, c, d, normal)


## Box rotated about Y (yaw in degrees, map convention) in a chunk kind.
func _ybox(kind: String, centre: Vector3, size: Vector3, yaw: float, color: Color) -> void:
	var f := _frame(Vector2(centre.x, centre.z), yaw)
	_obox(f, -size.x * 0.5, -size.z * 0.5, size.x * 0.5, size.z * 0.5, centre.y - size.y * 0.5, centre.y + size.y * 0.5, color, kind)


# ------------------------------------------------------------- screens ----

## An LED screen hung `out` metres off a run of facade edges. `run` is a list of
## (u, n) points along the facade (in footprint order), y0..y1 its height.
## `ads` = Vector2(ad A, ad B). The frame behind it goes into the solid chunks.
func _screen_run(run: PackedVector2Array, y0: float, y1: float, ads: Vector2, phase: float, out := 0.35, brightness := 2.2) -> void:
	var total := 0.0
	for index in run.size() - 1:
		total += run[index].distance_to(run[index + 1])
	if total < 0.5:
		return
	var aspect := total / maxf(0.5, y1 - y0)
	var info := Color(phase, 0.0, clampf(aspect / 8.0, 0.0, 1.0), brightness)
	var s := 0.0
	for index in run.size() - 1:
		var a := run[index]
		var b := run[index + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var d := (b - a) / length
		var out2 := Vector2(d.y, -d.x)
		var pa := a + out2 * out
		var pb := b + out2 * out
		var normal := Vector3(out2.x, 0, out2.y)
		var st := _tool("screen", _w(pa.x, pa.y))
		st.set_color(info)
		st.set_uv2(ads)
		st.set_normal(normal)
		var ua := 1.0 - s / total
		var ub := 1.0 - (s + length) / total
		var corners := [
			[_w(pa.x, pa.y, y0), Vector2(ua, 1.0)], [_w(pb.x, pb.y, y1), Vector2(ub, 0.0)], [_w(pa.x, pa.y, y1), Vector2(ua, 0.0)],
			[_w(pa.x, pa.y, y0), Vector2(ua, 1.0)], [_w(pb.x, pb.y, y0), Vector2(ub, 1.0)], [_w(pb.x, pb.y, y1), Vector2(ub, 0.0)],
		]
		for corner in corners:
			st.set_uv(corner[1])
			st.add_vertex(corner[0])
		# Dark frame between the facade and the screen.
		var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
		_obox(f, -length * 0.5 - 0.05, -out + 0.02, length * 0.5 + 0.05, 0.02, y0 - 0.3, y1 + 0.3, Color(0.06, 0.06, 0.07))
		s += length


## Scrolling ticker band along a run of facade points (strip 32-35 of the atlas).
func _ticker_run(run: PackedVector2Array, y0: float, y1: float, strip: int, phase: float, out := 0.4) -> void:
	var band := y1 - y0
	var s := 0.0
	for index in run.size() - 1:
		var a := run[index]
		var b := run[index + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var d := (b - a) / length
		var out2 := Vector2(d.y, -d.x)
		var pa := a + out2 * out
		var pb := b + out2 * out
		var normal := Vector3(out2.x, 0, out2.y)
		var st := _tool("screen", _w(pa.x, pa.y))
		st.set_color(Color(phase, 1.0, 0.0, 2.4))
		st.set_uv2(Vector2(strip, -1.0))
		st.set_normal(normal)
		var ua := -s / band
		var ub := -(s + length) / band
		for corner in [
			[_w(pa.x, pa.y, y0), Vector2(ua, 1.0)], [_w(pb.x, pb.y, y1), Vector2(ub, 0.0)], [_w(pa.x, pa.y, y1), Vector2(ua, 0.0)],
			[_w(pa.x, pa.y, y0), Vector2(ua, 1.0)], [_w(pb.x, pb.y, y0), Vector2(ub, 1.0)], [_w(pb.x, pb.y, y1), Vector2(ub, 0.0)],
		]:
			st.set_uv(corner[1])
			st.add_vertex(corner[0])
		var f := _frame((a + b) * 0.5, rad_to_deg((b - a).angle()))
		_obox(f, -length * 0.5, -out + 0.02, length * 0.5, 0.02, y0 - 0.15, y1 + 0.15, Color(0.04, 0.04, 0.05))
		s += length


# ----------------------------------------------------------- materials ----

func _facade_material() -> ShaderMaterial:
	if not _materials.has("facade_shader"):
		var material := ShaderMaterial.new()
		material.shader = FACADE_SHADER
		_materials["facade_shader"] = material
	return _materials["facade_shader"]


func _pavement_material() -> ShaderMaterial:
	if not _materials.has("pavement_shader"):
		var material := ShaderMaterial.new()
		material.shader = PAVEMENT_SHADER
		_materials["pavement_shader"] = material
	return _materials["pavement_shader"]


func _screens_material() -> ShaderMaterial:
	if _screen_material == null:
		_screen_material = ShaderMaterial.new()
		_screen_material.shader = SCREEN_SHADER
	return _screen_material


## Self-lit vertex colour: neon tubes, marquee bulbs, the TKTS steps.
func _glow_material(energy := 3.0) -> ShaderMaterial:
	var key := "glow_%s" % energy
	if not _materials.has(key):
		var shader := Shader.new()
		shader.code = """shader_type spatial;
uniform float energy = 3.0;
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = c * 0.25;
	ROUGHNESS = 0.4;
	EMISSION = c * energy;
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("energy", energy)
		_materials[key] = material
	return _materials[key]


## Lamp material for one signal colour (0 red, 1 yellow, 2 green) of one axis; lit by _process.
func _signal_material(axis: int, colour: int) -> ShaderMaterial:
	var key := "sig%d%d" % [axis, colour]
	if not _signal_materials.has(key):
		var shader := Shader.new()
		shader.code = """shader_type spatial;
uniform float on = 0.0;
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = c * mix(0.12, 0.3, on);
	ROUGHNESS = 0.3;
	EMISSION = c * on * 4.0;
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		_signal_materials[key] = material
	return _signal_materials[key]


## Commit every chunk with the material of its kind.
func _commit_chunks() -> void:
	for key in _chunks:
		var kind := str(key).get_slice("|", 0)
		var material: Material
		match kind:
			"glass":
				material = _glass_material()
			"ground":
				material = _pavement_material()
			"facade":
				material = _facade_material()
			"screen":
				material = _screens_material()
			"glow":
				material = _glow_material(3.0)
			"neon":
				material = _glow_material(6.0)
			_:
				if kind.begins_with("sig"):
					material = _signal_material(int(kind[3]), int(kind[4]))
				else:
					material = _vertex_material()
		_commit(_chunks[key], "Detail_" + str(key).replace("|", "_"), material)
		# Only buildings and solid detail throw shadows; flat ground and lights don't need to.
		if kind not in ["solid", "facade"]:
			var node := get_node_or_null("Detail_" + str(key).replace("|", "_")) as GeometryInstance3D
			if node != null:
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chunks.clear()


## Light the signal lamps for the current phase (traffic.gd's cycle).
func _update_signals() -> void:
	for axis in 2:
		var state: int = TRAFFIC.light_state(axis)
		# Lamp colour index: 0 red, 1 yellow, 2 green; state: 0 green, 1 yellow, 2 red.
		for colour in 3:
			var key := "sig%d%d" % [axis, colour]
			if _signal_materials.has(key):
				var lit := (colour == 2 and state == 0) or (colour == 1 and state == 1) or (colour == 0 and state == 2)
				(_signal_materials[key] as ShaderMaterial).set_shader_parameter("on", 1.0 if lit else 0.0)


const TRAFFIC := preload("res://traffic.gd")
