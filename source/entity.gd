class_name Entity


@warning_ignore("unused_signal")
signal moved(movement: Movement)

var current_tile: Tile = null
var links: Array[Link] = []


func _init(_current_tile: Tile) -> void:
	current_tile = _current_tile


func get_elevation() -> int:
	return current_tile.height


class Movement:
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
	var dragging_delay_count: int
	var blocking_delay_count: int

	func _init(_kind: Kind, _dragging_delay_count: int = 0, _blocking_delay_count: int = 0) -> void:
		kind = _kind
		dragging_delay_count = _dragging_delay_count
		blocking_delay_count = _blocking_delay_count
