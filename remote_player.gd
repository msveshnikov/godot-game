extends CharacterBody3D
## Another player seen over the network: the same character model as the local
## player, driven by position updates instead of input.

const MODEL_SCENE: PackedScene = preload("res://main_player.glb")
const MODEL_ANIMATOR = preload("res://player_model_animator.gd")
const SNAP_DISTANCE := 6.0
const MAX_EXTRAPOLATION := 0.25

var peer_id := 0
var active := false
var last_update_msec := 0

var _target_position := Vector3.ZERO
var _target_yaw := 0.0
var _grounded := true
var _has_state := false
var _since_update := 0.0
var _label: Label3D
var _animator: Node3D
var weapon := "pistol"


func _init() -> void:
	add_to_group("remote_players")


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	shape_node.shape = capsule
	add_child(shape_node)

	_animator = MODEL_SCENE.instantiate() as Node3D
	_animator.set_script(MODEL_ANIMATOR)
	_animator.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, -0.9, 0.0))
	add_child(_animator)
	_animator.call("set_tint", Color.from_hsv(fmod(peer_id * 0.37, 1.0), 0.35, 1.0))

	_label = Label3D.new()
	_label.name = "NameLabel"
	_label.position = Vector3(0.0, 1.35, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.005
	_label.font_size = 48
	_label.outline_size = 12
	_label.modulate = Color(1.0, 0.92, 0.6)
	add_child(_label)
	visible = false


## People run from remote players too when they hold a weapon.
func is_armed() -> bool:
	return weapon != "none"


func show_swing() -> void:
	_animator.call("swing")


## Their shot just arrived: snap the arm up toward where the foam is flying.
func show_shot(origin: Vector3, direction: Vector3) -> void:
	_animator.set("aim_point", origin + direction.normalized() * 30.0)
	_animator.set("has_aim_point", true)
	_animator.call("raise_gun")


## Used by the model animator instead of is_on_floor(), since this body never moves itself.
func net_grounded() -> bool:
	return _grounded


func apply_state(data: Dictionary) -> void:
	var pos: Array = data.get("p", [0, 0, 0])
	var vel: Array = data.get("v", [0, 0, 0])
	_target_position = Vector3(pos[0], pos[1], pos[2])
	velocity = Vector3(vel[0], vel[1], vel[2])
	_target_yaw = float(data.get("r", 0.0))
	_grounded = bool(data.get("g", true))
	active = bool(data.get("a", false))
	var held := str(data.get("w", "pistol"))
	if held != weapon:
		weapon = held
		_animator.call("set_weapon", weapon)
	_label.text = str(data.get("n", "Player"))
	last_update_msec = Time.get_ticks_msec()
	_since_update = 0.0
	if not _has_state or global_position.distance_to(_target_position) > SNAP_DISTANCE:
		global_position = _target_position
		rotation.y = _target_yaw
	_has_state = true
	visible = active


func _physics_process(delta: float) -> void:
	if not _has_state:
		return
	_since_update += delta
	# Dead-reckon a little past the last packet so movement stays smooth between updates.
	var lead := minf(_since_update, MAX_EXTRAPOLATION)
	var predicted := _target_position + Vector3(velocity.x, 0.0, velocity.z) * lead
	global_position = global_position.lerp(predicted, 1.0 - exp(-14.0 * delta))
	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-14.0 * delta))
