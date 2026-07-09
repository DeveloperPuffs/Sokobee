class_name Inputs
extends Node


signal moved_forward
signal moved_backward
signal turned_left
signal turned_right
signal undid_step
signal redid_step
signal restarted_level
signal clicked_tile

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_forward"):
		moved_forward.emit()
	elif event.is_action_pressed("move_backward"):
		moved_backward.emit()
	elif event.is_action_pressed("turn_left"):
		turned_left.emit()
	elif event.is_action_pressed("turn_right"):
		turned_right.emit()
	elif event.is_action_pressed("undo_step"):
		undid_step.emit()
	elif event.is_action_pressed("redo_step"):
		redid_step.emit()
	elif event.is_action_pressed("restart_level"):
		restarted_level.emit()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			clicked_tile.emit()
