class_name History


var _step_history: Array[Snapshot]
var _undo_history: Array[Snapshot]

func _init() -> void:
	_step_history = []
	_undo_history = []

func save_snapshot(snapshot: Snapshot) -> void:
	_step_history.append(snapshot)
	_undo_history = []

func take_snapshot(state: State) -> void:
	var snapshot := Snapshot.new(state)
	save_snapshot(snapshot)

func undo_snapshot(state: State) -> bool:
	if _step_history.is_empty():
		return false

	var previous_snapshot := Snapshot.new(state)
	_undo_history.append(previous_snapshot)

	var current_snapshot: Snapshot = _step_history.pop_back()
	current_snapshot.apply(state)

	return true

func redo_snapshot(state: State) -> bool:
	if _undo_history.is_empty():
		return false

	var previous_snapshot := Snapshot.new(state)
	_step_history.append(previous_snapshot)

	var current_snapshot: Snapshot = _undo_history.pop_back()
	current_snapshot.apply(state)

	return true
