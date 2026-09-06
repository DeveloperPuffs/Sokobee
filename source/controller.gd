class_name Controller
extends Node2D


signal level_completed()
signal restart_requested()

@export var _inputs: Inputs

var _state: State
var _history: History

var active: bool:
	set(_active):
		active = _active
		_inputs.set_process_unhandled_input(_active)


func _ready() -> void:
	active = false

	_inputs.moved_forward.connect(func() -> void:
		if _can_control_character():
			_move_character(_state.active_character.facing_direction)
	)

	_inputs.moved_backward.connect(func() -> void:
		if _can_control_character():
			var facing_direction := _state.active_character.facing_direction
			_move_character(Hexagon.get_opposite_direction(facing_direction))
	)

	_inputs.turned_left.connect(func() -> void:
		if _can_control_character():
			_history.take_snapshot(_state)
			Logic.rotate_character_left(_state.active_character)
	)

	_inputs.turned_right.connect(func() -> void:
		if _can_control_character():
			_history.take_snapshot(_state)
			Logic.rotate_character_right(_state.active_character)
	)

	_inputs.undid_step.connect(undo_step)
	_inputs.redid_step.connect(redo_step)

	_inputs.restarted_level.connect(restart_requested.emit)
	_inputs.clicked_tile.connect(_on_clicked_tile)


func load(state: State) -> void:
	_state = state
	_history = History.new()


func undo_step() -> void:
	_history.undo_snapshot(_state)


func redo_step() -> void:
	_history.redo_snapshot(_state)


func _can_control_character() -> bool:
	return _state.active_character != null and not _state.active_character.asleep


func _move_character(direction: Hexagon.Direction) -> void:
	var snapshot := Snapshot.new(_state)
	if Logic.try_move_character(_state, _state.active_character, direction):
		_history.save_snapshot(snapshot)
		if Logic.win_check(_state):
			level_completed.emit()


func _on_clicked_tile() -> void:
	var world_position := get_global_mouse_position()
	var clicked_tile := _state.get_tile_at(world_position)
	if clicked_tile == null:
		return

	for character in _state.characters:
		if character.current_tile == clicked_tile:
			character.clicked.emit()

			var snapshot := Snapshot.new(_state)
			if Logic.select_character(_state, character):
				_history.save_snapshot(snapshot)

			break
