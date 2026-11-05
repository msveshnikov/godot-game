extends Area3D

const PICKUP_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Kenney/woosh1.ogg")


func interact() -> String:
	var locker := get_parent()
	if locker.has_method("can_take_pistol") and not locker.call("can_take_pistol"):
		return ""

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("Cannot collect the foam pistol: no player node was found.")
		return ""
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		push_error("Cannot collect the foam pistol: the player has no Camera3D.")
		return ""
	if not player.has_method("collect_gun"):
		push_error("Cannot collect the foam pistol: the player cannot update its weapon state.")
		return ""

	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	$Prompt.visible = false

	reparent(camera, false)
	position = Vector3(0.34, -0.28, -0.55)
	rotation_degrees = Vector3(0, -45, 0)
	scale = Vector3.ONE * 0.55
	visible = true
	player.call("collect_gun")

	var sound := AudioStreamPlayer3D.new()
	sound.stream = PICKUP_SOUND
	sound.volume_db = -3.0
	sound.unit_size = 3.0
	sound.max_distance = 15.0
	get_tree().current_scene.add_child(sound)
	sound.global_position = camera.global_position
	sound.finished.connect(sound.queue_free)
	sound.play()
	return "Foam pistol"
