class_name Bee
extends Sprite2D


@export var _sleeping_indicator: Sprite2D

var _character: Character


func _process(_delta: float) -> void:
	_refresh()


func initialize(character: Character) -> void:
	_character = character
	_sleeping_indicator.visible = _character.asleep
	_refresh()


func _refresh() -> void:
	var current_tile := _character.current_tile
	position = Hexagon.get_tile_world_position(current_tile.position, _character.get_elevation())
	rotation = Hexagon.get_direction_rotation(_character.facing_direction)
	z_index = Hexagon.get_tile_z_index(current_tile.position) + 2

	_sleeping_indicator.rotation = -rotation
