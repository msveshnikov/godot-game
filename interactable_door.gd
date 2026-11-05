extends StaticBody3D

const DOOR_OPEN_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Kenney/doorOpen_1.ogg")
const DOOR_CLOSE_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Kenney/doorClose_4.ogg")

@export var open_angle := -100.0
@export var animation_duration := 0.45

@onready var prompt: Label3D = $Prompt

var is_open := false
var _hinge: Node3D
var _closed_rotation: Vector3
var _audio_player: AudioStreamPlayer3D
var _door_tween: Tween


func _ready() -> void:
	_hinge = get_parent() as Node3D
	_closed_rotation = _hinge.rotation_degrees
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.unit_size = 3.0
	_audio_player.max_distance = 15.0
	add_child(_audio_player)


func interact() -> void:
	if _door_tween and _door_tween.is_running():
		return

	is_open = not is_open
	prompt.text = "E - CLOSE" if is_open else "E - OPEN"
	_audio_player.stream = DOOR_OPEN_SOUND if is_open else DOOR_CLOSE_SOUND
	_audio_player.play()

	var target_rotation := _closed_rotation
	if is_open:
		target_rotation.y += open_angle
	_door_tween = create_tween()
	_door_tween.tween_property(_hinge, "rotation_degrees", target_rotation, animation_duration)
