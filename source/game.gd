class_name Game
extends Node2D


signal exited_game

@export var _controller: Controller
@export var _honeycomb: Honeycomb

var _manifest: Manifest
var _level_number := 1


func _ready() -> void:
	_manifest = Manifest.new("res://assets/levels/manifest.json")
	if _manifest == null:
		exited_game.emit()
		return

	_controller.restart_requested.connect(_on_restart_requested)
	_controller.level_completed.connect(_on_level_completed)
	_controller.set_active(true)

	_load_level()


func _load_level() -> void:
	if _level_number > _manifest.levels.size():
		exited_game.emit()
		return

	var level: Level = _manifest.levels[_level_number - 1]
	var result := level.load_state()
	if result.has_errors():
		exited_game.emit()
		return

	_controller.load(result.state)
	_honeycomb.load(result.state)


func _on_level_completed() -> void:
	_level_number += 1
	_load_level()


func _on_restart_requested() -> void:
	_load_level()
