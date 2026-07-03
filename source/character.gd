class_name Character
extends Entity


var facing_direction: Hexagon.Direction

func _init(_tile_position: Vector2i, _facing_direction: Hexagon.Direction) -> void:
	super._init(_tile_position)
	facing_direction = _facing_direction