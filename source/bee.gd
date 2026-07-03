class_name Bee
extends Node2D


var _character: Character

func _process(_delta: float) -> void:
	position = Hexagon.get_world_position(_character.tile_position)
	rotation = Hexagon.get_direction_rotation(_character.facing_direction)

func initialize(character: Character) -> void:
	_character = character