extends MultiMeshInstance3D
## Flocks of crows and pigeons wheeling over the estate: each bird is a little
## V of two wings that flap, circling its flock's centre at its own radius,
## height and pace, while the flock centre drifts slowly.

const FLOCKS := [
	# [game x, game z, height, radius, birds, angular speed]
	[10.0, 20.0, 34.0, 38.0, 9, 0.22],
	[-90.0, -60.0, 46.0, 30.0, 7, -0.28],
	[80.0, 90.0, 28.0, 24.0, 6, 0.33],
]

var _birds: Array = [] # [flock, radius offset, height offset, phase, speed, flap rate]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4041
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var total := 0
	for flock in FLOCKS:
		total += int(flock[4])
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _bird_mesh()
	multimesh.instance_count = total
	for flock_index in FLOCKS.size():
		for k in int(FLOCKS[flock_index][4]):
			_birds.append([flock_index, _rng.randf_range(-6.0, 6.0), _rng.randf_range(-4.0, 4.0),
				_rng.randf_range(0.0, TAU), _rng.randf_range(0.85, 1.15), _rng.randf_range(5.5, 8.0)])


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for index in _birds.size():
		var bird: Array = _birds[index]
		var flock: Array = FLOCKS[bird[0]]
		var drift := Vector3(sin(t * 0.03 + bird[0]) * 25.0, 0.0, cos(t * 0.025 + bird[0] * 2.0) * 25.0)
		var centre := Vector3(flock[0], flock[2], flock[1]) + drift
		var angle: float = bird[3] + t * float(flock[5]) * float(bird[4])
		var radius: float = float(flock[3]) + float(bird[1])
		var pos := centre + Vector3(cos(angle) * radius, float(bird[2]) + sin(t * 0.7 + bird[3]) * 1.5, sin(angle) * radius)
		# Fly along the circle's tangent, banking into the turn.
		var forward := Vector3(-sin(angle), 0.0, cos(angle)) * signf(float(flock[5]))
		var basis := Basis.looking_at(forward, Vector3.UP).rotated(forward, 0.35 * signf(float(flock[5])))
		var flap := 0.35 + 0.65 * absf(sin(t * float(bird[5]) + bird[3]))
		multimesh.set_instance_transform(index, Transform3D(basis.scaled(Vector3(1.0, flap, 1.0)), pos))


## A dark V: two thin wing triangles meeting at the body, raised a little.
func _bird_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.08, 0.09)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	st.set_material(material)
	var body_front := Vector3(0, 0, -0.25)
	var body_back := Vector3(0, 0, 0.2)
	for side in [-1.0, 1.0]:
		var tip := Vector3(side * 0.55, 0.22, 0.05)
		st.set_normal(Vector3.UP)
		st.add_vertex(body_front)
		st.add_vertex(tip)
		st.add_vertex(body_back)
	return st.commit()
