class_name Entity


signal tile_changed(previous_tile, current_tile)

var current_tile: Tile:
	set(_current_tile):
		var previous_tile := current_tile
		current_tile = _current_tile
		tile_changed.emit(previous_tile, current_tile)

var links: Array[Link] = []


func _init(_current_tile: Tile) -> void:
	current_tile = _current_tile


func get_elevation() -> int:
	return current_tile.height
