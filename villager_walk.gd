extends "res://addons/cogito/CogitoNPC/cogito_npc.gd"
## A person in the estate. Three roles:
##   villager - roams the street graph (bot_crowd.gd) carrying a foam pistol; on the
##              host it is simulated for real, on other clients it is a puppet that
##              follows the host's network updates. Foam knocks it out, a bat knocks
##              it to the ground first. Runs away from armed players.
##   civilian - an unarmed grown-up who wanders a small zone (playground, shop) or
##              stands still; can't be hurt, but runs from armed players too.
##   child    - like a civilian, smaller and quicker on its feet.
## Civilians and children are local to each client (not networked).

const FOAM_PISTOL_SCENE: PackedScene = preload("res://foam_pistol_model.tscn")
const OUTFIT = preload("res://villager_outfit.gd")
const FOAM_FIRE_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Spray.ogg")
const PUPPET_SNAP_DISTANCE := 5.0
const HIT_GRACE := 1.5
const STUCK_TIME := 2.5
const FLEE_RANGE := 22.0
const FLEE_TIME := 5.0
const KNOCKED_TIME := 2.6
const CHILD_SCALE := 0.62

@export_enum("villager", "civilian", "child") var role := "villager"
## Villagers only carry their pistols around; turn this on to let them fire at players again.
@export var shoots_back := false
@export var firing_range := 26.0
@export var fire_interval := 2.8
@export var respawn_delay := 6.0
@export var flee_speed := 4.3

var bot_index := 0
var crowd: Node
var puppet := false
var alive := true
## Civilians: game-space XZ area they wander in; `stay` keeps them standing where they are.
var zone := Rect2()
var stay := false

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
var _flee_from: Node3D
var _flee_timer := 0.0
var _flee_check := 0.0
var _flee_turn := 0.0
var _zone_target := Vector3.ZERO
var _knocked := 0.0
var _rig: Node3D


func _ready() -> void:
	super._ready()
	_rig = get_node_or_null("Rig") as Node3D
	OUTFIT.apply(self, bot_index)
	_rng.seed = hash(bot_index * 7919 + Time.get_ticks_usec())
	_attack_timer = _rng.randf_range(0.5, fire_interval)
	_spawn_collision_layer = collision_layer
	_spawn_collision_mask = collision_mask
	if role == "villager":
		add_to_group("villagers")
		var pistol := FOAM_PISTOL_SCENE.instantiate() as Node3D
		pistol.name = "VillagerFoamPistol"
		pistol.scale = Vector3.ONE * 0.65
		pistol.rotation.y = -PI / 2.0
		hand_slot.add_child(pistol)
		_fire_sound = AudioStreamPlayer3D.new()
		_fire_sound.stream = FOAM_FIRE_SOUND
		_fire_sound.volume_db = -8.0
		add_child(_fire_sound)
	else:
		add_to_group("civilians")
		_zone_target = global_position
		_pause_remaining = _rng.randf_range(0.0, 3.0)
	if role == "child":
		_make_child()


func _make_child() -> void:
	if _rig != null:
		_rig.scale = Vector3.ONE * CHILD_SCALE
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		var capsule := (shape_node.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		capsule.height *= CHILD_SCALE
		capsule.radius *= 0.8
		shape_node.shape = capsule
		shape_node.position.y *= CHILD_SCALE
	walk_speed *= 1.25
	flee_speed *= 0.9
	walk_volume_db -= 6.0


## True for anyone a player can knock out (adult villagers only).
func can_be_hit() -> bool:
	return role == "villager" and alive and _knocked <= 0.0


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
	if _knocked > 0.0:
		_knocked -= delta
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
		move_and_slide()
		if _knocked <= 0.0:
			_set_alive(false)
			_respawn_timer = respawn_delay
		return

	_update_flee(delta)
	if _flee_timer > 0.0:
		_flee(delta)
	elif role == "villager":
		_wander(delta)
	else:
		_wander_zone(delta)
	move_and_slide()
	if role == "villager" and shoots_back and _flee_timer <= 0.0:
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


## Civilians: stroll between random points of their zone, with pauses; or just stand.
func _wander_zone(delta: float) -> void:
	if stay or _pause_remaining > 0.0:
		_pause_remaining -= delta
		_stop_horizontal_motion(delta)
		if stay and zone.has_area():
			var home := Vector3(zone.get_center().x, global_position.y, zone.get_center().y)
			if global_position.distance_to(home) > 1.5:
				_walk_towards(home, walk_speed)
		return
	var to_target := _zone_target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.6 or not zone.has_area():
		if zone.has_area():
			_zone_target = Vector3(_rng.randf_range(zone.position.x, zone.end.x), global_position.y,
				_rng.randf_range(zone.position.y, zone.end.y))
		_pause_remaining = _rng.randf_range(0.5, 2.5) if role == "child" else _rng.randf_range(2.0, 7.0)
		return
	if get_real_velocity().length() < 0.2:
		_stuck_timer += delta
		if _stuck_timer > 1.5:
			_stuck_timer = 0.0
			_zone_target = global_position
	else:
		_stuck_timer = 0.0
	_walk_towards(_zone_target, walk_speed)


func _walk_towards(target: Vector3, speed: float) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		return
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	face_direction(global_position + direction)


func _stop_horizontal_motion(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, walk_speed * delta * 4.0)
	velocity.z = move_toward(velocity.z, 0.0, walk_speed * delta * 4.0)


## Look around a few times a second for an armed player in sight and close enough.
func _update_flee(delta: float) -> void:
	_flee_timer = maxf(_flee_timer - delta, 0.0)
	_flee_check -= delta
	if _flee_check > 0.0 or crowd == null:
		return
	_flee_check = 0.25
	var eye := global_position + Vector3.UP * (1.0 if role == "child" else 1.55)
	for player in crowd.call("armed_players"):
		var target := (player as Node3D).global_position + Vector3.UP * 1.0
		if eye.distance_to(target) > FLEE_RANGE:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, target)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.get("collider") != player:
			continue
		if _flee_timer <= 0.0:
			_flee_turn = _rng.randf_range(-0.5, 0.5)
		_flee_from = player
		_flee_timer = FLEE_TIME
		_pause_remaining = 0.0
		return


func _flee(delta: float) -> void:
	if _flee_from == null or not is_instance_valid(_flee_from):
		_flee_timer = 0.0
		return
	var away := global_position - _flee_from.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = -global_basis.z
	away = away.normalized().rotated(Vector3.UP, _flee_turn)
	# Ran into a wall or a car: veer off to one side.
	if get_real_velocity().length() < 0.6:
		_stuck_timer += delta
		if _stuck_timer > 0.5:
			_stuck_timer = 0.0
			_flee_turn = wrapf(_flee_turn + (PI * 0.5 if _rng.randf() < 0.5 else -PI * 0.5), -PI, PI)
	else:
		_stuck_timer = 0.0
	velocity.x = away.x * flee_speed
	velocity.z = away.z * flee_speed
	face_direction(global_position + away)
	if _flee_timer <= 0.1:
		_target_node = -1 # pick the nearest street node again once calm


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


## Foam knocks a villager out at once; a bat first knocks it to the ground.
func receive_hit(kind := "foam") -> void:
	if not can_be_hit():
		return
	if puppet:
		# Someone else simulates this bot: tell the host, show it right away.
		crowd.report_hit(bot_index, kind)
		_hit_grace = HIT_GRACE
		if kind == "bat":
			_set_knocked(true)
		else:
			_set_alive(false)
		return
	if kind == "bat":
		_set_knocked(true)
		_knocked = KNOCKED_TIME
	else:
		_set_alive(false)
		_respawn_timer = respawn_delay


## Fall flat on the back (or get up again); no collisions while lying there.
func _set_knocked(value: bool) -> void:
	if _rig == null:
		return
	var tween := create_tween()
	if value:
		_flee_timer = 0.0
		collision_layer = 0
		tween.tween_property(_rig, "rotation:x", -PI * 0.5, 0.35).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(_rig, "position:y", 0.22, 0.35)
	else:
		_rig.rotation.x = 0.0
		_rig.position.y = 0.0
		_knocked = 0.0
		tween.kill()


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
	_set_knocked(false)
	collision_layer = _spawn_collision_layer if value else 0
	collision_mask = _spawn_collision_mask if value else 0
	if not value and _fire_sound != null:
		_fire_sound.stop()
	for collision_shape in find_children("", "CollisionShape3D", true, false):
		(collision_shape as CollisionShape3D).set_deferred("disabled", not value)


# ------------------------------------------------------------- networking ----

## [x, y, z, yaw, vx, vz, state] streamed by the host; state 1 up, 0 gone, 2 knocked down.
func net_state() -> Array:
	var state := 0
	if alive:
		state = 2 if _knocked > 0.0 else 1
	return [
		snappedf(global_position.x, 0.01), snappedf(global_position.y, 0.01), snappedf(global_position.z, 0.01),
		snappedf(rotation.y, 0.01), snappedf(velocity.x, 0.01), snappedf(velocity.z, 0.01), state,
	]


func apply_net_state(state: Array) -> void:
	if state.size() < 7:
		return
	_net_position = Vector3(state[0], state[1], state[2])
	_net_yaw = float(state[3])
	_net_velocity = Vector3(state[4], 0.0, state[5])
	var net_state_value := int(state[6])
	if not _net_has_state or global_position.distance_to(_net_position) > PUPPET_SNAP_DISTANCE:
		global_position = _net_position
		rotation.y = _net_yaw
	_net_has_state = true
	_net_age = 0.0
	if _hit_grace > 0.0 and net_state_value == 1:
		return # our own hit hasn't reached the host yet
	var net_alive := net_state_value != 0
	if net_alive != alive:
		_set_alive(net_alive)
	var lying := _rig != null and _rig.rotation.x < -0.5
	if net_state_value == 2 and not lying:
		_set_knocked(true)
	elif net_state_value == 1 and lying:
		_set_knocked(false)


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
