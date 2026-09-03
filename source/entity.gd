class_name Entity


enum MoveFailCause {
	NONE,
	NO_GROUND_AHEAD,
	WALL_AHEAD,
}

@warning_ignore("unused_signal")
signal moved(movement: Movement)

@warning_ignore("unused_signal")
signal move_failed(direction: Hexagon.Direction, cause: MoveFailCause)

var current_tile: Tile = null
var links: Array[Link] = []
var cluster: Cluster


func _init(_current_tile: Tile) -> void:
	current_tile = _current_tile

	cluster = Cluster.new()
	cluster.entities.append(self)


class Movement:
	# How much of the movement duration each delay type lasts
	const _PUSHED_DELAY_FACTOR := 0.2
	const _DRAGGED_DELAY_FACTOR := 0.5

	enum Kind {
		# A character moving without pushing or dragging
		WALKING,

		# A character pushing or draging other entities
		INITIATOR,

		# An entity being pushed or dragged
		CARRIED,

		# Put back by an undo or a redo
		RESTORED,
	}

	var kind: Kind
	var dragged_delay_count: int
	var pushed_delay_count: int


	func _init(_kind: Kind, _pushed_delay_count: int = 0, _dragged_delay_count: int = 0) -> void:
		kind = _kind
		pushed_delay_count = _pushed_delay_count
		dragged_delay_count = _dragged_delay_count


	func get_delay_factor() -> float:
		return pushed_delay_count * _PUSHED_DELAY_FACTOR + dragged_delay_count * _DRAGGED_DELAY_FACTOR
