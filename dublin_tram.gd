class_name DublinTram
extends Node3D
## Short two-section Luas shuttle, with a cab at each end and a seated interior.

const SECTION_OFFSET := 3.69
const SECTION_LENGTH := 7.10
const END_CLEARANCE := 8.30
const MIN_TRIP_SECONDS := 24.0
const AVERAGE_SPEED := 5.4
const DWELL_SECONDS := 3.0
const WRECK_SECONDS := 45.0
const ROUTES := {"tram": "Tram", "tram_dawson_west": "TramDawsonWest", "tram_dawson_east": "TramDawsonEast"}
const BURGUNDY := Color(0.63, 0.075, 0.13)
const GOLD := Color(0.96, 0.70, 0.20)
const SILVER := Color(0.78, 0.81, 0.83)
const RUBBER := Color(0.12, 0.14, 0.17)
const FLOOR := Color(0.30, 0.34, 0.40)
const SEAT := Color(0.18, 0.35, 0.51)
const GLASS := Color(0.42, 0.62, 0.68)
const OUTFIT = preload("res://villager_outfit.gd")

var rail: PackedVector2Array
var rocket_surface := "tram"
var _track := Curve2D.new()
var _trip_seconds := MIN_TRIP_SECONDS
var _distance := 0.0
var _sections: Array[AnimatableBody3D] = []
var _shells: Array[MeshInstance3D] = []
var _lamps: Array[Array] = []
var _coupling: AnimatableBody3D
var _joint: MeshInstance3D
var _wreck: Node3D
var _passenger_count := 0
var _cube: Array
var _sphere: Array
var _wheel: Array
var _paint: StandardMaterial3D
var _glass: StandardMaterial3D
var _headlight: StandardMaterial3D
var _tail_light: StandardMaterial3D


func _ready() -> void:
	_track.bake_interval = 0.35
	for point in rail:
		_track.add_point(point)
	_trip_seconds = maxf(MIN_TRIP_SECONDS, (_track.get_baked_length() - END_CLEARANCE * 2.0) / AVERAGE_SPEED)
	add_to_group("street_trams")
	var cube := BoxMesh.new()
	_cube = cube.get_mesh_arrays()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 10
	sphere.rings = 6
	_sphere = sphere.get_mesh_arrays()
	var wheel := CylinderMesh.new()
	wheel.height = 1.0
	wheel.radial_segments = 12
	wheel.rings = 1
	_wheel = wheel.get_mesh_arrays()
	_paint = StandardMaterial3D.new()
	_paint.vertex_color_use_as_albedo = true
	_paint.vertex_color_is_srgb = true
	_paint.roughness = 0.67
	_glass = StandardMaterial3D.new()
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.albedo_color = Color(GLASS, 0.24)
	_glass.roughness = 0.21
	_headlight = _light(Color(0.96, 0.94, 0.80))
	_tail_light = _light(Color(0.82, 0.036, 0.062))
	for index in 2:
		_build_section(index)
	var bellows := _surface()
	_box(bellows, Vector3(0, 1.88, 0), Vector3(2.25, 2.62, 0.92), RUBBER)
	for i in range(-4, 5):
		_box(bellows, Vector3(0, 1.88, i * 0.09), Vector3(2.30, 2.66, 0.032), RUBBER.lightened(0.17))
	_coupling = AnimatableBody3D.new()
	_coupling.name = "Coupling"
	_coupling.sync_to_physics = false
	add_child(_coupling)
	_add_hitbox(_coupling, Vector3(2.24, 2.61, 0.64), 1.88)
	_joint = _mesh(_coupling, bellows, _paint, "Bellows")
	_physics_process(0.0)


func _physics_process(_delta: float) -> void:
	if is_instance_valid(_wreck):
		return
	var state := _service_at(Time.get_unix_time_from_system())
	_distance = state.x
	_set_pose()
	for index in _lamps.size():
		var leading := index == int(state.y)
		_lamps[index][0].visible = leading
		_lamps[index][1].visible = not leading


## Absolute time keeps the intact shuttle in the same part of the route for each
## player. At the ends both velocity and acceleration ease into the pause.
func _service_at(clock: float) -> Vector2:
	var leg := _trip_seconds + DWELL_SECONDS
	var phase := fposmod(clock, leg * 2.0)
	var returning := phase >= leg
	var t := clampf((fposmod(phase, leg) - DWELL_SECONDS) / _trip_seconds, 0.0, 1.0)
	var eased := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	var at := lerpf(END_CLEARANCE, _track.get_baked_length() - END_CLEARANCE, 1.0 - eased if returning else eased)
	return Vector2(at, 1.0 if returning else 0.0)


func _set_pose() -> void:
	var first := _rail_pose(_distance + SECTION_OFFSET, SECTION_LENGTH * 0.37, 1.0)
	var second := _rail_pose(_distance - SECTION_OFFSET, SECTION_LENGTH * 0.37, -1.0)
	_sections[0].transform = first
	_sections[1].transform = second
	var a := first * Vector3(0.0, 0.0, -SECTION_LENGTH * 0.5)
	var b := second * Vector3(0.0, 0.0, -SECTION_LENGTH * 0.5)
	var gap := a - b
	_coupling.transform = Transform3D(Basis.looking_at(-gap, Vector3.UP), (a + b) * 0.5)
	_joint.scale.z = 0.55 + gap.length()


func _rail_pose(at: float, chord: float, sign: float) -> Transform3D:
	var centre := _track.sample_baked(at)
	var direction := (_track.sample_baked(at + chord) - _track.sample_baked(at - chord)).normalized() * sign
	return Transform3D(Basis.looking_at(Vector3(-direction.x, 0, -direction.y), Vector3.UP), Vector3(centre.x, 0.056, centre.y))


func progress() -> float:
	return _distance


func crossing_offset(at: Vector2) -> float:
	if _track.get_closest_point(at).distance_squared_to(at) > 25.0:
		return -1.0
	return _track.get_closest_offset(at)


## The player and relay call this only for a direct rocket hit. The collider
## stays at the wreck until it is cleared. The replacement resumes the service.
func wreck_by_rocket(at := -1.0) -> bool:
	if is_instance_valid(_wreck) or not is_finite(at):
		return false
	if at >= 0.0:
		_distance = clampf(at, END_CLEARANCE, _track.get_baked_length() - END_CLEARANCE)
		_set_pose()
	_wreck = CarFire.explode(self, _coupling.global_transform, Vector3(2.45, 3.36, 2.8), null)
	var charcoal := StandardMaterial3D.new()
	charcoal.albedo_color = Color(0.13, 0.105, 0.10)
	charcoal.roughness = 0.95
	for i in _sections.size():
		var shell := MeshInstance3D.new()
		shell.mesh = _shells[i].mesh
		shell.material_override = charcoal
		_wreck.add_child(shell)
		shell.global_transform = _sections[i].global_transform
		_sections[i].hide()
	_joint.hide()
	get_tree().create_timer(WRECK_SECONDS, false).timeout.connect(_restore_service)
	return true


func _restore_service() -> void:
	_wreck.queue_free()
	_wreck = null
	_physics_process(0.0)
	for section in _sections:
		section.show()
	_joint.show()


func _build_section(index: int) -> void:
	var body := AnimatableBody3D.new()
	body.name = "Cab%d" % (index + 1)
	body.sync_to_physics = false
	add_child(body)
	_sections.append(body)
	_add_hitbox(body, Vector3(2.40, 3.05, SECTION_LENGTH), 1.68)

	var shell := _surface()
	var glazing := _surface()
	var salon := _surface()
	_box(shell, Vector3(0, 0.60, -0.43), Vector3(2.39, 0.23, 6.22), FLOOR)
	_box(shell, Vector3(0, 3.14, -0.43), Vector3(2.35, 0.26, 6.22), SILVER)
	_box(shell, Vector3(0, 3.31, -0.53), Vector3(2.07, 0.14, 5.90), SILVER.darkened(0.11))
	_box(shell, Vector3(0, 0.33, -0.36), Vector3(1.89, 0.32, 6.06), RUBBER)
	_box(shell, Vector3(0, 3.46, -0.96), Vector3(1.34, 0.20, 1.66), SILVER.darkened(0.19))
	for k in 11:
		_box(shell, Vector3(0, 3.565, -1.67 + k * 0.143), Vector3(1.23, 0.019, 0.027), RUBBER.lightened(0.21))
	for side in [-1.0, 1.0]:
		_build_side(shell, glazing, side)
		for z in [-2.03, 1.97]:
			var axle := Basis(Vector3.FORWARD, PI * 0.5)
			var wheel_at := Vector3(side * 0.72, 0.32, z)
			_part(shell, _wheel, wheel_at, Vector3(0.66, 0.21, 0.66), RUBBER, axle)
			_part(shell, _wheel, wheel_at + Vector3.RIGHT * side * 0.112, Vector3(0.37, 0.035, 0.37), SILVER.darkened(0.37), axle)
		for row in 4:
			var z: float = [-2.87, -2.12, 0.64, 1.40][row]
			var seed := 7 * index + row * 2 + (0 if side > 0.0 else 1)
			_build_seat(salon, Vector3(0.83 * side, 0.71, z), 1.0 if row % 2 == 0 else -1.0, seed)
		for z in [-1.52, 0.15, 2.04]:
			_box(salon, Vector3(side * 0.53, 1.93, z), Vector3(0.047, 2.42, 0.047), GOLD)
		_box(salon, Vector3(side * 0.54, 2.79, -0.45), Vector3(0.052, 0.052, 5.43), GOLD)
		var label := _display(body, Vector3(side * 1.24, 1.02, -2.36), "LUAS", Color(0.98, 0.85, 0.51), 0.0048)
		label.rotation.y = side * PI * 0.5
	_build_nose(shell)
	if index == 0:
		_build_pantograph(shell)
	_shells.append(_mesh(body, shell, _paint, "Bodywork"))
	_mesh(body, glazing, _glass, "Windows").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh(body, salon, _paint, "SeatedPassengers").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_display(body, Vector3(0, 2.83, 3.43), "ST STEPHEN’S GREEN", Color(0.94, 0.78, 0.32), 0.0023)
	_display(body, Vector3(0, 1.05, 3.59), "LUAS", Color(0.97, 0.93, 0.85), 0.0045)
	_display(body, Vector3(0, 0.75, 3.59), "507", Color(0.98, 0.92, 0.84), 0.0026)
	_lamps.append([_build_lamps(body, _headlight, 0.86), _build_lamps(body, _tail_light, 0.76)])


func _build_side(shell: SurfaceTool, glazing: SurfaceTool, side: float) -> void:
	var x := 1.17 * side
	_box(shell, Vector3(x, 0.94, -0.43), Vector3(0.101, 0.48, 6.22), BURGUNDY)
	_box(shell, Vector3(x, 1.26, -0.43), Vector3(0.103, 0.14, 6.22), GOLD)
	_box(shell, Vector3(x, 2.91, -0.43), Vector3(0.111, 0.30, 6.22), SILVER)
	_box(shell, Vector3(x, 2.82, -0.43), Vector3(0.113, 0.044, 6.20), BURGUNDY)
	for z in [-3.47, -1.50, 0.20, 1.79, 2.64]:
		_box(shell, Vector3(x, 2.03, z), Vector3(0.103, 1.52, 0.13), SILVER.darkened(0.14))
	for panel in [[-3.40, -1.57], [-1.43, 0.13], [0.27, 1.72], [1.86, 2.57]]:
		var n := Vector3.RIGHT * side
		var a := Vector3(1.206 * side, 1.34, panel[0])
		var b := Vector3(1.206 * side, 1.34, panel[1])
		_quad(glazing, a, b, b + Vector3.UP * 1.41, a + Vector3.UP * 1.41, n, Color.WHITE)
	_box(shell, Vector3(x, 2.02, -0.65), Vector3(0.104, 1.42, 0.06), RUBBER)
	for z in [-1.44, 0.14]:
		_box(shell, Vector3(side * 1.222, 0.97, z), Vector3(0.028, 0.58, 0.035), RUBBER)
	_box(shell, Vector3(side * 1.224, 1.53, -0.74), Vector3(0.034, 0.135, 0.145), GOLD)
	_box(shell, Vector3(side * 1.243, 1.53, -0.74), Vector3(0.007, 0.065, 0.073), Color(0.18, 0.26, 0.22))


func _build_nose(shell: SurfaceTool) -> void:
	_quad(shell, Vector3(-0.93, 0.60, 3.44), Vector3(0.93, 0.60, 3.44),
		Vector3(1.04, 1.48, 3.56), Vector3(-1.04, 1.48, 3.56), Vector3.BACK, BURGUNDY)
	_quad(shell, Vector3(-1.04, 1.48, 3.55), Vector3(1.04, 1.48, 3.55),
		Vector3(0.97, 3.00, 3.27), Vector3(-0.97, 3.00, 3.27), Vector3(0, 0.18, 0.98), RUBBER)
	_quad(shell, Vector3(-0.95, 1.63, 3.535), Vector3(0.95, 1.63, 3.535),
		Vector3(0.88, 2.93, 3.294), Vector3(-0.88, 2.93, 3.294), Vector3(0, 0.18, 0.98), Color(0.13, 0.24, 0.29))
	_box(shell, Vector3(0, 1.44, 3.55), Vector3(2.05, 0.16, 0.024), GOLD)
	_box(shell, Vector3(0, 0.58, 3.37), Vector3(1.89, 0.17, 0.18), RUBBER)
	_box(shell, Vector3(0, 3.05, 2.94), Vector3(2.00, 0.20, 0.67), SILVER)
	for side in [-1.0, 1.0]:
		var n := Vector3(0.97 * side, 0.0, 0.19)
		var a := Vector3(1.2 * side, 0.70, 2.64)
		var b := Vector3(0.94 * side, 0.70, 3.45)
		var c := Vector3(1.04 * side, 1.48, 3.56)
		var d := Vector3(1.2 * side, 1.48, 2.64)
		_quad(shell, a, b, c, d, n, BURGUNDY)
		_quad(shell, d, c, Vector3(0.97 * side, 3.00, 3.27), Vector3(1.2 * side, 3.00, 2.64), n, SILVER.darkened(0.22))
		_beam(shell, Vector3(0.58 * side, 1.72, 3.534), Vector3(0.16 * side, 2.44, 3.402), 0.022, RUBBER)
		_box(shell, Vector3(0.76 * side, 0.85, 3.535), Vector3(0.28, 0.22, 0.061), RUBBER)


func _build_pantograph(shell: SurfaceTool) -> void:
	for x in [-0.34, 0.34]:
		_box(shell, Vector3(x, 3.44, 0.10), Vector3(0.24, 0.16, 1.26), RUBBER)
		_beam(shell, Vector3(x, 3.53, 0.62), Vector3(x, 3.83, -0.22), 0.062, SILVER.darkened(0.35))
		_beam(shell, Vector3(x, 3.83, -0.22), Vector3(x, 4.20, 0.36), 0.061, SILVER.darkened(0.30))
	_box(shell, Vector3(0, 4.21, 0.36), Vector3(1.39, 0.062, 0.17), RUBBER)


func _build_seat(salon: SurfaceTool, at: Vector3, forward: float, seed: int) -> void:
	_box(salon, at + Vector3(0, 0.16, 0), Vector3(0.31, 0.32, 0.30), RUBBER.lightened(0.48))
	_box(salon, at + Vector3(0, 0.37, 0), Vector3(0.45, 0.13, 0.47), SEAT)
	_box(salon, at + Vector3(0, 0.64, -forward * 0.21), Vector3(0.45, 0.57, 0.11), SEAT.lightened(0.11))
	if seed % 5 == 3:
		return
	_passenger_count += 1
	var shirt: Color = OUTFIT.SHIRTS[(seed * 3 + 1) % OUTFIT.SHIRTS.size()]
	var skin: Color = OUTFIT.SKIN[(seed + seed / 3) % OUTFIT.SKIN.size()]
	var hair: Color = OUTFIT.HAIR[(seed * 5 + 2) % OUTFIT.HAIR.size()]
	var jeans: Color = OUTFIT.TROUSERS[seed % OUTFIT.TROUSERS.size()]
	_part(salon, _sphere, at + Vector3(0, 0.67, -0.025 * forward), Vector3(0.37, 0.62, 0.32), shirt)
	_part(salon, _sphere, at + Vector3(0, 1.13, 0.02 * forward), Vector3(0.219, 0.301, 0.232), skin)
	_part(salon, _sphere, at + Vector3(0, 1.218, -0.018 * forward), Vector3(0.229, 0.186, 0.233), hair)
	_part(salon, _sphere, at + Vector3(0, 1.117, 0.128 * forward), Vector3(0.063, 0.065, 0.045), skin)
	for leg in [-0.099, 0.099]:
		var knee := at + Vector3(leg, 0.39, 0.31 * forward)
		var heel := at + Vector3(leg, 0.045, 0.36 * forward)
		_beam(salon, at + Vector3(leg, 0.43, -0.04 * forward), knee, 0.141, jeans)
		_beam(salon, knee, heel, 0.105, jeans)
		_box(salon, heel + Vector3(0, -0.007, 0.047 * forward), Vector3(0.13, 0.073, 0.21), RUBBER)
		var elbow := at + Vector3(leg * 1.91, 0.57, 0.105 * forward)
		var hand := at + Vector3(leg * 1.08, 0.51, 0.24 * forward)
		_beam(salon, at + Vector3(leg * 1.69, 0.86, 0), elbow, 0.081, shirt.darkened(0.08))
		_beam(salon, elbow, hand, 0.065, skin)


func _build_lamps(parent: Node3D, material: Material, y: float) -> MeshInstance3D:
	var st := _surface()
	for x in [-0.76, 0.76]:
		_box(st, Vector3(x, y, 3.572), Vector3(0.21, 0.060, 0.022), Color.WHITE)
	return _mesh(parent, st, material, "SignalLights")


func _display(parent: Node3D, at: Vector3, caption: String, tint: Color, pixel: float) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.position = at
	label.font_size = 42
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = tint
	label.visibility_range_end = 80.0
	parent.add_child(label)
	return label


func _box(st: SurfaceTool, at: Vector3, size: Vector3, tint: Color) -> void:
	_part(st, _cube, at, size, tint)


func _beam(st: SurfaceTool, a: Vector3, b: Vector3, width: float, tint: Color) -> void:
	var delta := b - a
	var pose := Basis(Quaternion(Vector3.UP, delta.normalized()))
	_part(st, _cube, (a + b) * 0.5, Vector3(width, delta.length(), width), tint, pose)


func _part(st: SurfaceTool, arrays: Array, at: Vector3, size: Vector3, tint: Color, pose := Basis.IDENTITY) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var shape := pose.scaled_local(size)
	st.set_color(tint)
	for index in indices:
		st.set_normal(pose * (normals[index] / size).normalized())
		st.add_vertex(at + shape * vertices[index])


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	st.set_normal(normal.normalized())
	st.set_color(color)
	var points := [a, c, b, a, d, c] if (b - a).cross(c - a).dot(normal) > 0 else [a, b, c, a, c, d]
	for point in points:
		st.add_vertex(point)


static func _surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _mesh(parent: Node3D, st: SurfaceTool, material: Material, label: String) -> MeshInstance3D:
	st.set_material(material)
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.name = label
	parent.add_child(node)
	return node


static func _light(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	return material


static func _add_hitbox(body: AnimatableBody3D, size: Vector3, y: float) -> void:
	var hitbox := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	hitbox.position.y = y
	hitbox.shape = shape
	body.add_child(hitbox)
