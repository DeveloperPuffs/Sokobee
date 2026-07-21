class_name Character
extends Entity


var facing_direction: Hexagon.Direction
var asleep: bool


func _init(_current_tile: Tile, _facing_direction: Hexagon.Direction, _asleep: bool) -> void:
	super._init(_current_tile)
	facing_direction = _facing_direction
	asleep = _asleep
