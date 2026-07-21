class_name Game
extends Node2D


signal exited_game

@export var _controller: Controller
@export var _honeycomb: Honeycomb

var _current_level: int = 1


func _ready() -> void:
	_controller.restart_requested.connect(_on_restart_requested)
	_controller.level_completed.connect(_on_level_completed)
	_controller.set_active(true)
	_load_level()


func _load_level() -> void:
	var level_data_file_path := "res://assets/levels/testing" + str(_current_level) + ".json"
	var state := Loader.load_level_state(level_data_file_path)
	if state == null:
		exited_game.emit()
		return

	_controller.load(state)
	_honeycomb.load(state)


func _on_level_completed() -> void:
	_current_level += 1
	_load_level()


func _on_restart_requested() -> void:
	_load_level()
