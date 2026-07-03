class_name Camera
extends Camera2D


func frame(bounds: Rect2, padding: float) -> void:
	var screen_size := get_viewport_rect().size
	var zoom_x := screen_size.x / bounds.size.x
	var zoom_y := screen_size.y / bounds.size.y
	var zoom_value := (min(zoom_x, zoom_y) as float) / padding

	zoom = Vector2(zoom_value, zoom_value)
	position = bounds.position + bounds.size / 2.0