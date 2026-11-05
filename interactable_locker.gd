extends StaticBody3D

@export var pull_distance := 0.65
@export var pull_duration := 0.3

@onready var prompt: Label3D = $Prompt

var is_open := false
var _closed_position: Vector3
var _pull_tween: Tween


func _ready() -> void:
	_closed_position = position


func interact() -> void:
	if _pull_tween and _pull_tween.is_running():
		return

	is_open = not is_open
	prompt.text = "E - PUSH" if is_open else "E - PULL"
	var target_position := _closed_position
	if is_open:
		target_position.z += pull_distance
	_pull_tween = create_tween()
	_pull_tween.tween_property(self, "position", target_position, pull_duration)
