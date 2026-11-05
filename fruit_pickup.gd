extends Area3D

const PICKUP_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Kenney/woosh1.ogg")


func interact() -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = PICKUP_SOUND
	sound.volume_db = -3.0
	sound.unit_size = 3.0
	sound.max_distance = 15.0
	get_tree().current_scene.add_child(sound)
	sound.global_position = global_position
	sound.finished.connect(sound.queue_free)
	sound.play()
	queue_free()
