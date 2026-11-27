class_name Crosshair
extends Control
## A small CS-style crosshair in the middle of the screen: four short lines with
## a gap that kicks open on every shot and settles back. Hits on players flash a
## hit marker (an X) over it, red for a headshot.

const COLOR := Color(0.35, 1.0, 0.35, 0.95)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.7)
const LINE_LENGTH := 7.0
const THICKNESS := 2.0
const BASE_GAP := 4.0
const KICK_GAP := 9.0
const HIT_MARKER_TIME := 0.25

var _gap := BASE_GAP
var _hit_time := 0.0
var _hit_head := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The gap jumps open with the recoil.
func kick(amount := KICK_GAP) -> void:
	_gap = BASE_GAP + amount
	queue_redraw()


func show_hit(headshot: bool) -> void:
	_hit_time = HIT_MARKER_TIME
	_hit_head = headshot
	queue_redraw()


func _process(delta: float) -> void:
	var redraw := false
	if _gap > BASE_GAP:
		_gap = move_toward(_gap, BASE_GAP, delta * 40.0)
		redraw = true
	if _hit_time > 0.0:
		_hit_time = maxf(_hit_time - delta, 0.0)
		redraw = true
	if redraw:
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var g := _gap
	var l := LINE_LENGTH
	var segments := [
		[c + Vector2(-g - l, 0), c + Vector2(-g, 0)],
		[c + Vector2(g, 0), c + Vector2(g + l, 0)],
		[c + Vector2(0, -g - l), c + Vector2(0, -g)],
		[c + Vector2(0, g), c + Vector2(0, g + l)],
	]
	for s in segments:
		draw_line(s[0], s[1], OUTLINE, THICKNESS + 2.0)
	for s in segments:
		draw_line(s[0], s[1], COLOR, THICKNESS)
	if _hit_time > 0.0:
		var alpha := _hit_time / HIT_MARKER_TIME
		var color := Color(1.0, 0.2, 0.15, alpha) if _hit_head else Color(1.0, 1.0, 1.0, alpha)
		var r1 := 6.0
		var r2 := 13.0 if _hit_head else 11.0
		for dir in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var d: Vector2 = dir.normalized()
			draw_line(c + d * r1, c + d * r2, Color(0, 0, 0, alpha * 0.6), 4.0)
			draw_line(c + d * r1, c + d * r2, color, 2.0)
