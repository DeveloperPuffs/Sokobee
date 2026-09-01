class_name Piece
extends Sprite2D


var _entity: Entity


func _bind_entity(entity: Entity) -> void:
	_entity = entity

	_entity.tile_changed.connect(func(_previous_tile: Tile, current_tile: Tile) -> void:
		_set_current_tile(current_tile)
	)

	_set_current_tile(_entity.current_tile, false)


func _set_current_tile(tile: Tile, animate: bool = true) -> void:
	var tile_position := tile.position

	var target_position := Hexagon.get_tile_world_position(tile_position, _entity.get_elevation())
	var target_z_index := Hexagon.get_tile_z_index(tile_position) + 2

	if not animate:
		position = target_position
		z_index = target_z_index
		return

	var movement_tween := create_tween()
	movement_tween.tween_property(self, ^":position", target_position, 0.2)

	# Draw in front of the source and destination tiles for the duration
	# of the movement to avoid clipping behind tiles
	if z_index < target_z_index:
		z_index = target_z_index
	elif z_index > target_z_index:
		movement_tween.tween_callback(func() -> void:
			z_index = target_z_index
		)
