class_name Coins
extends Node3D
## Gold coins popping out of whatever the player just smashed. They hop, settle on
## the ground spinning, and fly into the player who walks up to them; each one
## adds its value to Game.money. Local to the player who smashed the thing.

const COIN_SOUND: AudioStream = preload("res://audio/coin.wav")
const COIN_VALUE := 5
const MAX_COINS := 10
const LIFETIME := 45.0
const MAGNET_RANGE := 2.4
const PICKUP_RANGE := 0.55
const GRAVITY := 14.0

static var _mesh: CylinderMesh
static var _material: StandardMaterial3D

var value := COIN_VALUE
var _velocity := Vector3.ZERO
var _ground_y := 0.0
var _age := 0.0
var _resting := false
var _flying := false
var _coin: MeshInstance3D


## Coins worth `total` at `at`, flung up and out (a little toward `toward`, if given).
static func spawn(root: Node, at: Vector3, total: int, toward := Vector3.INF) -> void:
	if total <= 0 or root == null:
		return
	var count := clampi(total / COIN_VALUE, 1, MAX_COINS)
	var ground := minf(at.y, 0.0) # the streets are at y = 0 where nothing is hit below
	var space := (root as Node3D).get_world_3d().direct_space_state if root is Node3D else null
	if space != null:
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 8.0)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			ground = (hit["position"] as Vector3).y
	var out := Vector3.ZERO
	if toward != Vector3.INF:
		out = toward - at
		out.y = 0.0
		out = out.normalized()
	var left := total
	for k in count:
		var coin := Coins.new()
		coin.value = left / (count - k)
		left -= coin.value
		root.add_child(coin)
		coin.global_position = at + Vector3.UP * 0.2
		var angle := randf() * TAU
		var spread := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(1.2, 3.0)
		coin._velocity = spread + out * 2.0 + Vector3.UP * randf_range(3.5, 5.5)
		coin._ground_y = ground


func _ready() -> void:
	if _mesh == null:
		_mesh = CylinderMesh.new()
		_mesh.top_radius = 0.09
		_mesh.bottom_radius = 0.09
		_mesh.height = 0.022
		_mesh.radial_segments = 14
		_mesh.rings = 1
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(1.0, 0.76, 0.18)
		_material.metallic = 0.9
		_material.roughness = 0.25
		_material.emission_enabled = true
		_material.emission = Color(0.55, 0.36, 0.02)
		_material.emission_energy_multiplier = 0.6
		_mesh.material = _material
	_coin = MeshInstance3D.new()
	_coin.mesh = _mesh
	_coin.rotation.x = PI / 2.0 # stand on its edge
	_coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_coin)
	rotation.y = randf() * TAU


func _process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	if _age > LIFETIME - 5.0:
		visible = fmod(_age * 6.0, 1.0) < 0.6
	rotate_y(delta * (9.0 if _flying else 4.0))

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var playing := player != null and bool(player.call("is_playing"))
	var target := player.global_position + Vector3.UP * 0.2 if player != null else Vector3.ZERO
	if playing and _age > 0.45 and global_position.distance_to(target) < MAGNET_RANGE:
		_flying = true
	if _flying and playing:
		var to_player := target - global_position
		if to_player.length() < PICKUP_RANGE:
			_collect()
			return
		global_position += to_player.normalized() * minf(to_player.length(), (6.0 + _age * 2.0) * delta)
		return
	_flying = false
	if _resting:
		_coin.position.y = 0.12 + sin(_age * 3.0) * 0.03
		return
	_velocity.y -= GRAVITY * delta
	global_position += _velocity * delta
	if global_position.y <= _ground_y + 0.02 and _velocity.y < 0.0:
		global_position.y = _ground_y + 0.02
		if _velocity.y < -2.5:
			_velocity = Vector3(_velocity.x * 0.45, -_velocity.y * 0.35, _velocity.z * 0.45)
		else:
			_resting = true


func _collect() -> void:
	get_tree().root.get_node("Game").call("add_money", value)
	var sound := AudioStreamPlayer.new()
	sound.stream = COIN_SOUND
	sound.volume_db = -9.0
	sound.pitch_scale = randf_range(0.95, 1.12)
	get_parent().add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
	queue_free()
