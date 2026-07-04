class_name Character
extends Entity


var facing_direction: Hexagon.Direction

func _init(_current_tile: Tile, _facing_direction: Hexagon.Direction) -> void:
	super._init(_current_tile)
	facing_direction = _facing_direction