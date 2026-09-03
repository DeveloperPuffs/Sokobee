class_name AxesOverlay
extends Node2D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	const Q_AXIS_COLOR_R := Color(0.9, 0.35, 0.35, 0.6)
	const R_AXIS_COLOR_G := Color(0.4, 0.85, 0.45, 0.6)
	const S_AXIS_COLOR_B := Color(0.4, 0.55, 0.95, 0.6)

	var canvas_transform := get_viewport().get_canvas_transform()
	var center := canvas_transform * Vector2.ZERO

	_draw_axis(canvas_transform, center, Hexagon.Direction.BOTTOM_RIGHT, Q_AXIS_COLOR_R)
	_draw_axis(canvas_transform, center, Hexagon.Direction.BOTTOM_CENTER, R_AXIS_COLOR_G)
	_draw_axis(canvas_transform, center, Hexagon.Direction.TOP_RIGHT, S_AXIS_COLOR_B)


func _draw_axis(canvas_transform: Transform2D, center: Vector2, direction: Hexagon.Direction, color: Color) -> void:
	var direction_vector := Hexagon.get_direction_vector(direction)
	var world_direction := Hexagon.get_tile_world_position(direction_vector)
	var screen_direction := canvas_transform.basis_xform(world_direction).normalized()

	var distance := get_viewport_rect().size.length() + center.length()
	var endpoint_a := center - screen_direction * distance
	var endpoint_b := center + screen_direction * distance
	draw_line(endpoint_a, endpoint_b, color, 1.0)
