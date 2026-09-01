class_name Piece
extends Sprite2D


const _MOVEMENT_DURATION := 0.2


var _entity: Entity

var _ground_position := Vector2.ZERO:
	set(ground_position):
		_ground_position = ground_position
		_refresh_position()

var _elevation := 0.0:
	set(elevation_offset):
		_elevation = elevation_offset
		_refresh_position()


func _bind_entity(entity: Entity) -> void:
	_entity = entity

	_entity.tile_changed.connect(func(_previous_tile: Tile, current_tile: Tile) -> void:
		_set_current_tile(current_tile)
	)

	_set_current_tile(_entity.current_tile, false)


func _refresh_position() -> void:
	position = _ground_position
	position.y -= _elevation


func _set_current_tile(tile: Tile, animate: bool = true) -> void:
	var tile_position := tile.position

	var target_ground_position := Hexagon.get_tile_world_position(tile_position, 0)
	var target_elevation := _entity.get_elevation() * Hexagon.HEIGHT_OFFSET
	var target_z_index := Hexagon.get_tile_z_index(tile_position) + 2

	if not animate:
		_ground_position = target_ground_position
		_elevation = target_elevation
		z_index = target_z_index
		return

	var movement_tween := create_tween()
	movement_tween.set_parallel()

	movement_tween.tween_property(self, ^":_ground_position", target_ground_position, _MOVEMENT_DURATION)

	if _elevation != target_elevation:
		var elevation_tweener := movement_tween.tween_property(self, ^":_elevation", target_elevation, _MOVEMENT_DURATION)
		elevation_tweener.set_trans(Tween.TRANS_EXPO)

		# Fall off the tile late when descending, but rise early when ascending
		if _elevation > target_elevation:
			elevation_tweener.set_ease(Tween.EASE_IN)
		elif _elevation < target_elevation:
			elevation_tweener.set_ease(Tween.EASE_OUT)

	# Draw in front of the source and destination tiles for the duration
	# of the movement to avoid clipping behind tiles
	if z_index < target_z_index:
		z_index = target_z_index
	elif z_index > target_z_index:
		var movement_ended := movement_tween.chain()
		movement_ended.tween_callback(func() -> void:
			z_index = target_z_index
		)
