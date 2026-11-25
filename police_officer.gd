extends "res://villager_walk.gd"
## One of the two officers police.gd sends after a player who went too far. They
## ride in the patrol car until it stops, get out, and fight: run in until they see
## the player, then keep 7-15 m off, side-stepping, and fire for real (hitscan, like
## the player's own pistol). Harder to put down than a villager: a headshot kills,
## a body hit doesn't. Local to the player they hunt (each client has its own).

const SHOT_SOUND: AudioStream = preload("res://audio/pistol_shot.ogg")
const MAX_HP := 100.0
const RUN_SPEED := 5.2
const STRAFE_SPEED := 2.2
const SIGHT_RANGE := 45.0
const FIGHT_RANGE := 17.0
const NEAR_RANGE := 6.5
const FIRE_MIN := 0.75
const FIRE_MAX := 1.35
const DAMAGE_MIN := 7
const DAMAGE_MAX := 12

## police.gd: told when this officer goes down.
var dispatch: Node
var target: Node3D
var hp := MAX_HP
var active := false

var _fire_timer := 1.2
var _strafe := 1.0
var _strafe_timer := 0.0
var _sees := false
var _sight_timer := 0.0
var _chase_stuck := 0.0
var _side_step := 0.0
var _shot_player: AudioStreamPlayer3D
var _posture: Node
var _rids: Array[RID] = []
var shots := 0


func _ready() -> void:
	role = "police"
	super._ready()
	remove_from_group("interactable")
	walk_speed = 2.6
	sprint_speed = RUN_SPEED
	_shot_player = AudioStreamPlayer3D.new()
	_shot_player.stream = SHOT_SOUND
	_shot_player.unit_size = 12.0
	_shot_player.max_polyphony = 2
	add_child(_shot_player)
	for node in find_children("*", "", true, false):
		if node.has_method("upper_body_travel"):
			_posture = node
			break
	_strafe = 1.0 if _rng.randf() < 0.5 else -1.0


## Out of the car: start hunting `who`.
func engage(who: Node3D) -> void:
	target = who
	active = true
	visible = true
	_fire_timer = _rng.randf_range(0.6, 1.4)
	if _posture != null:
		_posture.call("upper_body_travel", "PistolReady")


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if not active or target == null or not is_instance_valid(target):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if footsteps_enabled:
		npc_footsteps(delta)

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	var toward := to_target / maxf(distance, 0.01)
	_sight_timer -= delta
	if _sight_timer <= 0.0:
		_sight_timer = 0.2
		_sees = distance < SIGHT_RANGE and _can_see(target)

	var move := Vector3.ZERO
	var playing := bool(target.call("is_playing")) if target.has_method("is_playing") else true
	if _sees and distance < FIGHT_RANGE and playing:
		# Fight: side-step across the line of fire, back off if too close, close in if far.
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = _rng.randf_range(1.2, 2.8)
			if _rng.randf() < 0.55:
				_strafe = -_strafe
		var side := toward.cross(Vector3.UP) * _strafe
		move = side * STRAFE_SPEED
		if distance < NEAR_RANGE:
			move -= toward * STRAFE_SPEED
		elif distance > FIGHT_RANGE - 4.0:
			move += toward * STRAFE_SPEED
		# Walked into something: the other way, and stick with it for a while.
		if get_real_velocity().length() < 0.4 and move.length() > 0.5 and _strafe_timer < 1.0:
			_strafe = -_strafe
			_strafe_timer = _rng.randf_range(1.5, 2.5)
		face_direction(global_position + toward)
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_timer = _rng.randf_range(FIRE_MIN, FIRE_MAX)
			_fire_at(target, distance)
	elif playing:
		# Chase: run at the player; when blocked, step aside for a moment.
		move = toward * RUN_SPEED
		if _side_step > 0.0:
			_side_step -= delta
			move = toward.cross(Vector3.UP) * _strafe * RUN_SPEED * 0.8 + toward * 1.0
		elif get_real_velocity().length() < 1.0:
			_chase_stuck += delta
			if _chase_stuck > 0.6:
				_chase_stuck = 0.0
				_side_step = _rng.randf_range(0.6, 1.3)
				_strafe = -_strafe
		else:
			_chase_stuck = 0.0
		face_direction(global_position + move)
		_fire_timer = maxf(_fire_timer, 0.5) # a moment to aim once they see the player again
	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()


## This body and every collider in it (the ragdoll's bones), for rays to ignore.
func body_rids() -> Array[RID]:
	if _rids.is_empty():
		_rids.append(get_rid())
		for node in find_children("*", "CollisionObject3D", true, false):
			_rids.append((node as CollisionObject3D).get_rid())
	return _rids


## Clear line from the officer's eyes to the player's chest (other officers and
## the patrol car don't block it).
func _can_see(who: Node3D) -> bool:
	var eye := global_position + Vector3.UP * 1.55
	var chest := who.global_position + Vector3.UP * 0.35
	var exclude: Array[RID] = body_rids().duplicate()
	if dispatch != null:
		exclude.append_array(dispatch.call("own_rids"))
	var query := PhysicsRayQueryParameters3D.create(eye, chest)
	query.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == who


## One round at the player. The nearer and the stiller the player, the likelier it hits.
func _fire_at(who: Node3D, distance: float) -> void:
	var scene := get_parent()
	var muzzle := hand_slot.global_position + (-global_basis.z) * 0.25 if hand_slot != null else global_position + Vector3.UP * 1.35
	var chest := who.global_position + Vector3.UP * 0.3
	var speed := Vector2((who as CharacterBody3D).velocity.x, (who as CharacterBody3D).velocity.z).length() if who is CharacterBody3D else 0.0
	var chance := clampf(0.88 - distance * 0.022 - speed * 0.045, 0.22, 0.88)
	shots += 1
	_shot_player.pitch_scale = _rng.randf_range(0.93, 1.05)
	_shot_player.play()
	if _rng.randf() < chance:
		ShotFx.tracer(scene, muzzle, chest)
		ShotFx.blood(scene, chest, muzzle.direction_to(chest))
		who.call("receive_damage", float(_rng.randi_range(DAMAGE_MIN, DAMAGE_MAX)), 0, "police")
		return
	# A miss: the round goes past the player and hits whatever is behind.
	var side := muzzle.direction_to(chest).cross(Vector3.UP).normalized()
	var off := side * _rng.randf_range(-1.2, 1.2) + Vector3.UP * _rng.randf_range(-0.4, 0.9)
	var dir := muzzle.direction_to(chest + off)
	var query := PhysicsRayQueryParameters3D.create(muzzle, muzzle + dir * 80.0)
	var exclude: Array[RID] = body_rids().duplicate()
	exclude.append((who as CollisionObject3D).get_rid())
	query.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.get("position", muzzle + dir * 80.0)
	ShotFx.tracer(scene, muzzle, end)
	if not hit.is_empty():
		ShotFx.impact(scene, end, hit.get("normal", Vector3.UP))


## Hit by the player: `damage` from pistol_damage() (100 for a headshot), the bat, or a blast.
func receive_hit(kind := "pistol", _attacker := 0) -> void:
	take_damage({"bat": 45.0, "blast": MAX_HP}.get(kind, 30.0))


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	if animation_tree != null:
		animation_tree.set("parameters/Transition/transition_request", "hit")
	if not active and target == null and dispatch != null:
		engage(dispatch.call("hunted"))
	if hp <= 0.0:
		_die()
		if dispatch != null:
			dispatch.call("officer_down", self)
