class_name Bee
extends Node2D


var _character: Character

func _process(_delta: float) -> void:
	var current_tile := _character.current_tile
	position = Hexagon.get_tile_world_position(current_tile.position, current_tile.height)
	rotation = Hexagon.get_direction_rotation(_character.facing_direction)
	z_index = Hexagon.get_tile_z_index(current_tile.position) + 1

func initialize(character: Character) -> void:
	_character = character
