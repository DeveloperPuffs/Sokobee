class_name Piece
extends Node2D


const _MOVEMENT_DURATION := 0.2
const _MOVEMENT_RESTORE_DURATION := 0.1

signal position_changed()

signal _movement_started(movement: Entity.Movement)
signal _movement_landed()

signal _wall_hit(direction: Hexagon.Direction)

@export var link_attachment_marker: LinkAttachmentMarker

var _entity: Entity

var _movement_delay := 0.0
var _movement_tween: Tween = null

var _ground_position := Vector2.ZERO:
	set(ground_position):
		_ground_position = ground_position
		_refresh_position()

var _elevation := 0.0:
	set(elevation_offset):
		_elevation = elevation_offset
		_refresh_position()

var _bump_tween: Tween = null
var _bump_vector := Vector2.ZERO

var _bump_offset := 0.0:
	set(bump_effect):
		_bump_offset = bump_effect
		_refresh_position()

var _shake_tween: Tween = null

var _shake_offset := Vector2.ZERO:
	set(shake_offset):
		_shake_offset = shake_offset
		_refresh_position()


func _init() -> void:
	_wall_hit.connect(func(_direction: Hexagon.Direction) -> void:
		if _shake_tween != null and _shake_tween.is_valid():
			_shake_tween.kill()

		_shake_offset = Vector2.ZERO
		_shake_tween = create_tween()

		var bump_magnitude := _bump_vector.length()
		var forward_vector := _bump_vector.normalized()
		var lateral_vector := Vector2(-forward_vector.y, forward_vector.x)

		var shake_method := func(progress: float) -> void:
			_shake_offset = (1.0 - progress) * (
				forward_vector * sin(progress * TAU * 2.0) * bump_magnitude * 0.3 +
				lateral_vector * sin(progress * TAU * 4.0) * bump_magnitude * 0.1
			)

		var shake_tweener := _shake_tween.tween_method(shake_method, 0.0, 1.0, 0.4)
		shake_tweener.set_delay(0.05)
	)


func _bind_entity(entity: Entity) -> void:
	_entity = entity

	_entity.moved.connect(_move_to_entity_tile)
	_entity.move_failed.connect(_perform_bump_effect)

	_move_to_entity_tile()


func _refresh_position() -> void:
	position = _ground_position + _bump_offset * _bump_vector + _shake_offset
	position.y -= _elevation
	position_changed.emit()


func _move_to_entity_tile(movement: Entity.Movement = null) -> void:
	var tile_position := _entity.current_tile.position

	var target_ground_position := Hexagon.get_tile_world_position(tile_position)
	var target_elevation := _entity.cluster.get_elevation() * Hexagon.HEIGHT_OFFSET
	var target_z_index := Hexagon.get_tile_z_index(tile_position) + 2

	var interrupted := false
	var remaining_delay := 0.0

	if _movement_tween != null and _movement_tween.is_valid():
		interrupted = true
		remaining_delay = maxf(_movement_delay - _movement_tween.get_total_elapsed_time(), 0.0)
		_movement_tween.kill()

	if movement == null:
		_movement_delay = 0.0
		_ground_position = target_ground_position
		_elevation = target_elevation
		z_index = target_z_index
		return

	var movement_duration := _MOVEMENT_RESTORE_DURATION if movement.kind == Entity.Movement.Kind.RESTORED else _MOVEMENT_DURATION
	var movement_delay = remaining_delay if interrupted else movement_duration * movement.get_delay_factor()

	_movement_tween = create_tween()
	_movement_tween.set_parallel()

	var movement_started_callback := _movement_tween.tween_callback(_movement_started.emit.bind(movement))
	movement_started_callback.set_delay(movement_delay)

	var ground_position_tweener := _movement_tween.tween_property(self, ^":_ground_position", target_ground_position, movement_duration)
	ground_position_tweener.set_delay(movement_delay)

	if not interrupted:
		match movement.kind:
			Entity.Movement.Kind.WALKING:
				ground_position_tweener.set_trans(Tween.TRANS_BACK)
				ground_position_tweener.set_ease(Tween.EASE_OUT)
			Entity.Movement.Kind.INITIATOR:
				ground_position_tweener.set_trans(Tween.TRANS_QUAD)
				ground_position_tweener.set_ease(Tween.EASE_OUT)
			Entity.Movement.Kind.CARRIED:
				ground_position_tweener.set_trans(Tween.TRANS_BACK)
				ground_position_tweener.set_ease(Tween.EASE_OUT)
			# RESTORED movements will have linear transitions

	if _elevation != target_elevation:
		# Fall off the tile late when descending, but rise early when ascending
		var elevation_tweener := _movement_tween.tween_property(self, ^":_elevation", target_elevation, movement_duration)
		elevation_tweener.set_delay(movement_delay)
		elevation_tweener.set_trans(Tween.TRANS_EXPO)

		if _elevation > target_elevation:
			elevation_tweener.set_ease(Tween.EASE_IN)
			if movement.kind != Entity.Movement.Kind.RESTORED:
				var movement_landed := _movement_tween.chain()
				movement_landed.tween_callback(_movement_landed.emit)

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


func _perform_bump_effect(direction: Hexagon.Direction, cause: Entity.MoveFailCause) -> void:
	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()

	var direction_vector := Hexagon.get_direction_vector(direction)
	var world_direction := Hexagon.get_tile_world_position(direction_vector)

	_bump_tween = create_tween()

	match cause:
		Entity.MoveFailCause.NONE:
			_bump_vector = world_direction * 0.1

			var out_tweener := _bump_tween.tween_property(self, ^":_bump_offset", 1.0, 0.1)
			out_tweener.set_trans(Tween.TRANS_QUAD)
			out_tweener.set_ease(Tween.EASE_OUT)

			var back_tweener := _bump_tween.tween_property(self, ^":_bump_offset", 0.0, 0.1)
			back_tweener.set_trans(Tween.TRANS_CUBIC)
			back_tweener.set_ease(Tween.EASE_IN_OUT)

		Entity.MoveFailCause.NO_GROUND_AHEAD:
			_bump_vector = world_direction * 0.25

			var out_tweener := _bump_tween.tween_property(self, ^":_bump_offset", 1.0, 0.15)
			out_tweener.set_trans(Tween.TRANS_SINE)
			out_tweener.set_ease(Tween.EASE_OUT)

			var back_tweener := _bump_tween.tween_property(self, ^":_bump_offset", 0.0, 0.05)
			back_tweener.set_trans(Tween.TRANS_SINE)
			back_tweener.set_ease(Tween.EASE_IN_OUT)

		Entity.MoveFailCause.WALL_AHEAD:
			var wall_hit_callback := _bump_tween.tween_callback(_wall_hit.emit.bind(direction))
			wall_hit_callback.set_delay(0.05)

			_bump_vector = world_direction * 0.2

			var out_tweener := _bump_tween.tween_property(self, ^":_bump_offset", 1.0, 0.05)
			out_tweener.set_trans(Tween.TRANS_QUAD)
			out_tweener.set_ease(Tween.EASE_OUT)

			var back_tweener := _bump_tween.tween_property(self, ^":_bump_offset", 0.0, 0.15)
			back_tweener.set_trans(Tween.TRANS_BACK)
			back_tweener.set_ease(Tween.EASE_OUT)
