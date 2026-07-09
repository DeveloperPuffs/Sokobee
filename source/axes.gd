class_name AxesOverlay
extends Node2D


func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	const _Q_AXIS_COLOR := Color(0.9, 0.35, 0.35, 0.6)
	const _R_AXIS_COLOR := Color(0.4, 0.85, 0.45, 0.6)
	const _S_AXIS_COLOR := Color(0.4, 0.55, 0.95, 0.6)

	var canvas_transform := get_viewport().get_canvas_transform()
	var center := canvas_transform * Vector2.ZERO

	_draw_axis(canvas_transform, center, Hexagon.Direction.BOTTOM_RIGHT, _Q_AXIS_COLOR)
	_draw_axis(canvas_transform, center, Hexagon.Direction.BOTTOM_CENTER, _R_AXIS_COLOR)
	_draw_axis(canvas_transform, center, Hexagon.Direction.TOP_RIGHT, _S_AXIS_COLOR)

func _draw_axis(canvas_transform: Transform2D, center: Vector2, direction: Hexagon.Direction, color: Color) -> void:
	const _AXIS_WIDTH := 3.0

	var direction_vector := Hexagon.get_direction_vector(direction)
	var world_direction := Hexagon.get_tile_world_position(direction_vector, 0)
	var screen_direction := canvas_transform.basis_xform(world_direction).normalized()

	var distance := get_viewport_rect().size.length() + center.length()
	var endpoint_a = center - screen_direction * distance
	var endpoint_b = center + screen_direction * distance
	draw_line(endpoint_a, endpoint_b, color, _AXIS_WIDTH)
