class_name Bee
extends Sprite2D


@export var _sleeping_indicator: Sprite2D

var _character: Character


func _process(_delta: float) -> void:
	_refresh()


func initialize(character: Character) -> void:
	_character = character
	_sleeping_indicator.visible = _character.asleep

	_character.tile_changed.connect(func(_previous_tile: Tile, current_tile: Tile) -> void:
		_set_current_tile(current_tile)
	)

	_set_current_tile(_character.current_tile, false)
	_refresh()


func _refresh() -> void:
	rotation = Hexagon.get_direction_rotation(_character.facing_direction)
	_sleeping_indicator.rotation = -rotation


func _set_current_tile(tile: Tile, animate: bool = true) -> void:
	var tile_position := tile.position
	z_index = Hexagon.get_tile_z_index(tile_position) + 2

	var target_position := Hexagon.get_tile_world_position(tile_position, _character.get_elevation())

	if not animate:
		position = target_position
		return

	var movement_tween := create_tween()
	movement_tween.tween_property(self, ^":position", target_position, 0.2)
