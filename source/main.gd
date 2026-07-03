class_name Main
extends Node2D


@export var scenes: Scenes

func _ready() -> void:
	scenes.exited_application.connect(_on_application_exit)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _on_application_exit() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)