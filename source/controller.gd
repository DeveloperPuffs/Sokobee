class_name Controller
extends Node2D


signal level_completed
signal restart_requested

@export var _inputs: Inputs

var _state: State
var _history: History
var _is_active: bool


func _ready() -> void:
	_inputs.moved_forward.connect(_on_move_forward)
	_inputs.moved_backward.connect(_on_move_backward)
	_inputs.turned_left.connect(_on_turn_left)
	_inputs.turned_right.connect(_on_turn_right)
	_inputs.undid_step.connect(_on_undo_step)
	_inputs.redid_step.connect(_on_redo_step)
	_inputs.restarted_level.connect(_on_restart_level)
	_inputs.clicked_tile.connect(_on_click_tile)
	set_active(false)


func load(state: State) -> void:
	_state = state
	_history = History.new()


func set_active(active: bool) -> void:
	_is_active = active
	_inputs.set_process_unhandled_input(active)


func _on_move_forward() -> void:
	if _state.active_character == null or _state.active_character.asleep:
		return

	var snapshot := Snapshot.new(_state)
	var facing_direction := _state.active_character.facing_direction
	if Logic.try_move_character(_state, _state.active_character, facing_direction):
		_history.save_snapshot(snapshot)
		if Logic.win_check(_state):
			level_completed.emit()


func _on_move_backward() -> void:
	if _state.active_character == null or _state.active_character.asleep:
		return

	var snapshot := Snapshot.new(_state)
	var facing_direction := _state.active_character.facing_direction
	var opposite_direction := Hexagon.get_opposite_direction(facing_direction)
	if Logic.try_move_character(_state, _state.active_character, opposite_direction):
		_history.save_snapshot(snapshot)
		if Logic.win_check(_state):
			level_completed.emit()


func _on_turn_left() -> void:
	if _state.active_character == null or _state.active_character.asleep:
		return

	_history.take_snapshot(_state)
	Logic.rotate_character_left(_state.active_character)


func _on_turn_right() -> void:
	if _state.active_character == null or _state.active_character.asleep:
		return

	_history.take_snapshot(_state)
	Logic.rotate_character_right(_state.active_character)


func _on_undo_step() -> void:
	_history.undo_snapshot(_state)


func _on_redo_step() -> void:
	_history.redo_snapshot(_state)


func _on_restart_level() -> void:
	restart_requested.emit()


func _on_click_tile() -> void:
	var world_position := get_global_mouse_position()
	var clicked_tile := _state.get_tile_at(world_position)
	if clicked_tile == null:
		return

	for character in _state.characters:
		if character.current_tile != clicked_tile:
			continue

		if character == _state.active_character:
			return

		var snapshot := Snapshot.new(_state)
		if Logic.select_character(_state, character):
			_history.save_snapshot(snapshot)
			return
