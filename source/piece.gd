class_name Piece
extends Node2D


const _MOVEMENT_DURATION := 0.2
const _MOVEMENT_RESTORE_DURATION := 0.1

var _entity: Entity
var _movement_tween: Tween = null

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

	_entity.moved.connect(_move_to_entity_tile)
	_move_to_entity_tile()


func _refresh_position() -> void:
	position = _ground_position
	position.y -= _elevation


func _move_to_entity_tile(movement: Entity.Movement = null) -> void:
	var tile_position := _entity.current_tile.position

	var target_ground_position := Hexagon.get_tile_world_position(tile_position, 0)
	var target_elevation := _entity.get_elevation() * Hexagon.HEIGHT_OFFSET
	var target_z_index := Hexagon.get_tile_z_index(tile_position) + 2

	if _movement_tween != null and _movement_tween.is_valid():
		_movement_tween.kill()

	if movement == null:
		_ground_position = target_ground_position
		_elevation = target_elevation
		z_index = target_z_index
		return

	var movement_duration := _MOVEMENT_RESTORE_DURATION if movement.kind == Entity.Movement.Kind.RESTORED else _MOVEMENT_DURATION
	var movement_delay := movement_duration * movement.get_delay_factor()

	_movement_tween = create_tween()
	_movement_tween.set_parallel()

	var ground_position_tweener := _movement_tween.tween_property(self, ^":_ground_position", target_ground_position, movement_duration)
	ground_position_tweener.set_delay(movement_delay)

	match movement.kind:
		Entity.Movement.Kind.WALKING:
			ground_position_tweener.set_trans(Tween.TRANS_CUBIC)
			ground_position_tweener.set_ease(Tween.EASE_IN_OUT)
		Entity.Movement.Kind.INITIATOR:
			ground_position_tweener.set_trans(Tween.TRANS_QUAD)
			ground_position_tweener.set_ease(Tween.EASE_OUT)
		Entity.Movement.Kind.CARRIED:
			ground_position_tweener.set_trans(Tween.TRANS_QUAD)
			ground_position_tweener.set_ease(Tween.EASE_IN)
		# RESTORED movements will have linear transitions

	if _elevation != target_elevation:
		var elevation_tweener := _movement_tween.tween_property(self, ^":_elevation", target_elevation, movement_duration)
		elevation_tweener.set_delay(movement_delay)
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
		var movement_ended := _movement_tween.chain()
		movement_ended.tween_callback(func() -> void:
			z_index = target_z_index
		)
