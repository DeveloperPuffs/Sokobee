class_name Game
extends Node2D


signal exited_game

@export var _inputs: Inputs
@export var _honeycomb: Honeycomb

var _state: State
var _history: History
var _current_level: int

func _ready() -> void:
	_inputs.moved_forward.connect(_on_move_forward)
	_inputs.moved_backward.connect(_on_move_backward)
	_inputs.turned_left.connect(_on_turn_left)
	_inputs.turned_right.connect(_on_turn_right)
	_inputs.undid_step.connect(_on_undo_step)
	_inputs.redid_step.connect(_on_redo_step)
	_inputs.restarted_level.connect(_on_restart_level)
	_inputs.clicked_tile.connect(_on_click_tile)

	_current_level = 1
	_load_level()

func _load_level() -> void:
	var level_data_file_path := "res://assets/levels/testing" + str(_current_level) + ".json"
	_state = Loader.load_level_state(level_data_file_path)
	if _state == null:
		exited_game.emit()
		return

	_history = History.new()
	_honeycomb.load(_state)

func _on_move_forward() -> void:
	var snapshot := Snapshot.new(_state)
	var facing_direction := _state.active_character.facing_direction
	if Logic.try_move_character(_state, _state.active_character, facing_direction):
		if Logic.win_check(_state):
			_current_level += 1
			_load_level()
		else:
			_history.save_snapshot(snapshot)

func _on_move_backward() -> void:
	var snapshot := Snapshot.new(_state)
	var facing_direction := _state.active_character.facing_direction
	var opposite_direction := Hexagon.get_opposite_direction(facing_direction)
	if Logic.try_move_character(_state, _state.active_character, opposite_direction):
		if Logic.win_check(_state):
			_current_level += 1
			_load_level()
		else:
			_history.save_snapshot(snapshot)

func _on_turn_left() -> void:
	_history.take_snapshot(_state)
	Logic.rotate_character_left(_state.active_character)

func _on_turn_right() -> void:
	_history.take_snapshot(_state)
	Logic.rotate_character_right(_state.active_character)

func _on_undo_step() -> void:
	_history.undo_snapshot(_state)

func _on_redo_step() -> void:
	_history.redo_snapshot(_state)

func _on_restart_level() -> void:
	_load_level()

func _on_click_tile() -> void:
	var world_position := get_global_mouse_position()
	var clicked_tile := _honeycomb.get_tile_at(world_position)
	if clicked_tile == null:
		return

	var active_character := _state.active_character
	if clicked_tile == active_character.current_tile:
		return

	for other_character in _state.characters:
		if other_character == active_character:
			continue

		if clicked_tile == other_character.current_tile:
			var snapshot := Snapshot.new(_state)
			if Logic.select_character(_state, other_character):
				_history.save_snapshot(snapshot)
			return
