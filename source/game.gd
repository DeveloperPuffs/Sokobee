class_name Game
extends Node2D


signal exited_game()

@export var _controller: Controller
@export var _honeycomb: Honeycomb

var _manifest: Manifest
var _level_number := 1


func _ready() -> void:
	_manifest = Manifest.new("res://assets/levels/manifest.json")
	if _manifest == null:
		exited_game.emit()
		return

	_controller.restart_requested.connect(_load_level)
	_controller.level_completed.connect(func() -> void:
		_controller.active = false
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			_level_number += 1
			_load_level()
		)
	)

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
	_controller.active = true
