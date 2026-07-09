class_name Entity


var links: Array[Link]
var current_tile: Tile

func _init(_current_tile: Tile) -> void:
	current_tile = _current_tile
	links = []

func get_elevation() -> int:
	return current_tile.height
