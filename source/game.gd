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
	var level_data_string := FileAccess.get_file_as_string(level_data_file_path)
	if level_data_string == "":
		exited_game.emit()
		return

	var json_parser := JSON.new()
	var json_parsing_result := json_parser.parse(level_data_string)
	if json_parsing_result != OK:
		print("JSON Parsing Error {error} at {path}:{line} - {message}".format({
			"error": json_parsing_result,
			"path": level_data_file_path,
			"line": json_parser.get_error_line(),
			"message": json_parser.get_error_message()
		}))

		exited_game.emit()
		return

	var level_data := json_parser.data as Dictionary
	var state := Serializer.load_level(level_data)
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
