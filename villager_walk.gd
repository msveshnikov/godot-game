extends "res://addons/cogito/CogitoNPC/cogito_npc.gd"
## A villager bot roaming the estate graph (bot_crowd.gd). On the host it walks,
## hangs around and shoots for real; on other clients it is a puppet that
## follows the host's network updates.

const FOAM_PISTOL_SCENE: PackedScene = preload("res://foam_pistol_model.tscn")
const OUTFIT = preload("res://villager_outfit.gd")
const FOAM_FIRE_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Spray.ogg")
const PUPPET_SNAP_DISTANCE := 5.0
const HIT_GRACE := 1.5
const STUCK_TIME := 2.5

## Villagers only carry their pistols around; turn this on to let them fire at players again.
@export var shoots_back := false
@export var firing_range := 26.0
@export var fire_interval := 2.8
@export var respawn_delay := 6.0

var bot_index := 0
var crowd: Node
var puppet := false
var alive := true

var _rng := RandomNumberGenerator.new()
var _target_node := -1
var _previous_node := -1
var _pause_remaining := 0.0
var _stuck_timer := 0.0
var _attack_timer := 1.0
var _respawn_timer := 0.0
var _hit_grace := 0.0
var _spawn_collision_layer := 0
var _spawn_collision_mask := 0
var _fire_sound: AudioStreamPlayer3D
var _net_position := Vector3.ZERO
var _net_velocity := Vector3.ZERO
var _net_yaw := 0.0
var _net_has_state := false
var _net_age := 0.0


func _ready() -> void:
	super._ready()
	add_to_group("villagers")
	OUTFIT.apply(self, bot_index)
	_rng.seed = hash(bot_index * 7919 + Time.get_ticks_usec())
	_attack_timer = _rng.randf_range(0.5, fire_interval)
	_spawn_collision_layer = collision_layer
	_spawn_collision_mask = collision_mask

	var pistol := FOAM_PISTOL_SCENE.instantiate() as Node3D
	pistol.name = "VillagerFoamPistol"
	pistol.scale = Vector3.ONE * 0.65
	pistol.rotation.y = -PI / 2.0
	hand_slot.add_child(pistol)
	_fire_sound = AudioStreamPlayer3D.new()
	_fire_sound.stream = FOAM_FIRE_SOUND
	_fire_sound.volume_db = -8.0
	add_child(_fire_sound)


func _physics_process(delta: float) -> void:
	_hit_grace = maxf(_hit_grace - delta, 0.0)
	if puppet:
		_puppet_process(delta)
		return
	if not alive:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	super._physics_process(delta)
	_wander(delta)
	move_and_slide()
	if shoots_back:
		_update_attack(delta)


# ------------------------------------------------------------ simulation ----

func _wander(delta: float) -> void:
	if crowd == null:
		return
	if _pause_remaining > 0.0:
		_pause_remaining -= delta
		_stop_horizontal_motion(delta)
		return

	if _target_node < 0:
		_target_node = crowd.nearest_node(global_position)
	var direction: Vector3 = crowd.node_position(_target_node) - global_position
	direction.y = 0.0

	if direction.length() < 0.8:
		var next: int = crowd.pick_next(_target_node, _previous_node, _rng)
		_previous_node = _target_node
		_target_node = next
		_stuck_timer = 0.0
		# Sometimes stop and loiter for a while.
		if _rng.randf() < 0.35:
			_pause_remaining = _rng.randf_range(2.0, 8.0)
		return

	# Blocked by a player or a parked car for too long: turn back.
	if get_real_velocity().length() < 0.3:
		_stuck_timer += delta
		if _stuck_timer > STUCK_TIME:
			_stuck_timer = 0.0
			var back: int = _previous_node if _previous_node >= 0 else crowd.nearest_node(global_position)
			_previous_node = _target_node
			_target_node = back
	else:
		_stuck_timer = 0.0

	direction = direction.normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	face_direction(global_position + direction)


func _stop_horizontal_motion(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, walk_speed * delta * 4.0)
	velocity.z = move_toward(velocity.z, 0.0, walk_speed * delta * 4.0)


func _update_attack(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0 or crowd == null:
		return

	var target: Node3D = crowd.pick_target(global_position, firing_range)
	if target == null:
		_attack_timer = 0.5
		return

	var muzzle_position := global_position + Vector3.UP * 1.3
	var target_position := target.global_position + Vector3.UP * 0.45
	# Don't shoot through buildings.
	var query := PhysicsRayQueryParameters3D.create(muzzle_position, target_position)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.get("collider") != target:
		_attack_timer = 0.5
		return

	_attack_timer = fire_interval * _rng.randf_range(0.8, 1.3)
	face_direction(target.global_position)
	crowd.fire(self, muzzle_position, muzzle_position.direction_to(target_position))


func play_fire_sound() -> void:
	if _fire_sound != null:
		_fire_sound.play()


func receive_hit() -> void:
	if not alive:
		return
	if puppet:
		# Someone else simulates this bot: tell the host, hide it right away.
		crowd.report_hit(bot_index)
		_hit_grace = HIT_GRACE
		_set_alive(false)
		return
	_set_alive(false)
	_respawn_timer = respawn_delay


func _respawn() -> void:
	global_position = crowd.respawn_position(_rng)
	velocity = Vector3.ZERO
	_target_node = -1
	_previous_node = -1
	_pause_remaining = _rng.randf_range(0.0, 2.0)
	_attack_timer = 1.5
	_set_alive(true)


func _set_alive(value: bool) -> void:
	alive = value
	visible = value
	collision_layer = _spawn_collision_layer if value else 0
	collision_mask = _spawn_collision_mask if value else 0
	if not value and _fire_sound != null:
		_fire_sound.stop()
	for collision_shape in find_children("", "CollisionShape3D", true, false):
		(collision_shape as CollisionShape3D).set_deferred("disabled", not value)


# ------------------------------------------------------------- networking ----

## [x, y, z, yaw, vx, vz, alive] streamed by the host.
func net_state() -> Array:
	return [
		snappedf(global_position.x, 0.01), snappedf(global_position.y, 0.01), snappedf(global_position.z, 0.01),
		snappedf(rotation.y, 0.01), snappedf(velocity.x, 0.01), snappedf(velocity.z, 0.01), 1 if alive else 0,
	]


func apply_net_state(state: Array) -> void:
	if state.size() < 7:
		return
	_net_position = Vector3(state[0], state[1], state[2])
	_net_yaw = float(state[3])
	_net_velocity = Vector3(state[4], 0.0, state[5])
	var net_alive := int(state[6]) == 1
	if not _net_has_state or global_position.distance_to(_net_position) > PUPPET_SNAP_DISTANCE:
		global_position = _net_position
		rotation.y = _net_yaw
	_net_has_state = true
	_net_age = 0.0
	if net_alive != alive and not (net_alive and _hit_grace > 0.0):
		_set_alive(net_alive)


func set_puppet(value: bool) -> void:
	if puppet == value:
		return
	puppet = value
	if puppet:
		_net_has_state = false
		return
	# Taking over the simulation: carry on from wherever the puppet stands.
	velocity = Vector3.ZERO
	_target_node = -1
	_previous_node = -1
	_pause_remaining = 0.0
	if not alive:
		_respawn_timer = respawn_delay * 0.5


func _puppet_process(delta: float) -> void:
	if not _net_has_state:
		return
	# Dead-reckon briefly between packets, but don't wander off if the host goes quiet.
	_net_age += delta
	if _net_age < 0.3:
		_net_position += _net_velocity * delta
	global_position = global_position.lerp(_net_position, 1.0 - exp(-10.0 * delta))
	rotation.y = lerp_angle(rotation.y, _net_yaw, 1.0 - exp(-10.0 * delta))
	velocity = _net_velocity if _net_age < 0.5 else Vector3.ZERO # drives the walk animation
	if alive and footsteps_enabled:
		npc_footsteps(delta)
