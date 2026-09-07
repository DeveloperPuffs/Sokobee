@tool
class_name LinkAttachmentMarker
extends Node2D


signal transform_changed()

@export var radius := 60.0:
	set(_radius):
		if not Engine.is_editor_hint():
			return

		radius = _radius
		queue_redraw()


func _ready() -> void:
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		transform_changed.emit()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.0, 0.84, 1.0, 0.87), 2.0)