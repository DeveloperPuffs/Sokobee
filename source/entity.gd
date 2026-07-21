class_name Entity


var current_tile: Tile
var links: Array[Link] = []


func _init(_current_tile: Tile) -> void:
	current_tile = _current_tile


func get_elevation() -> int:
	return current_tile.height
