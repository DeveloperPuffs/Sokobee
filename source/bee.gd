class_name Bee
extends Piece


const _ROTATION_DURATION := 0.2
const _ROTATION_RESTORE_DURATION := 0.1

const _PUSHING_SQUASH := 0.2
const _PUSHED_SQUASH := 0.1
const _LANDING_SQUASH := 0.25
const _WALL_HIT_SQUASH := 0.25
const _SQUASH_BULGE_RATIO := 0.6

@export var _sleeping_indicator: Sprite2D
@export var _squash_pivot: Node2D
@export var _rotator: Node2D
@export var _animation_player: AnimationPlayer

var _character: Character
var _rotation_tween: Tween = null
var _squash_tween: Tween = null
var _landing_tween: Tween = null

var _squash_axis := 0.0

var _squash := 0.0:
	set(squash):
		_squash = squash
		_refresh_squash()


func _init() -> void:
	super()

	_movement_started.connect(func(movement: Entity.Movement) -> void:
		if not movement.has_direction():
			return

		match movement.kind:
			Entity.Movement.Kind.WALKING:
				_animation_player.play("flutter")
			Entity.Movement.Kind.INITIATOR:
				_animation_player.play("flap")
				_squash_along(movement.get_direction(), _PUSHING_SQUASH)
			Entity.Movement.Kind.CARRIED:
				_animation_player.play("flutter")
				_squash_along(movement.get_direction(), _PUSHED_SQUASH)
	)

	_movement_landed.connect(func() -> void:
		if _landing_tween != null and _landing_tween.is_valid():
			_landing_tween.kill()

		_landing_tween = create_tween()

		var landed_scale := Vector2(1.0 + _LANDING_SQUASH * _SQUASH_BULGE_RATIO, 1.0 - _LANDING_SQUASH)
		_landing_tween.tween_property(self, ^":scale", landed_scale, 0.05)

		var recover_tweener := _landing_tween.tween_property(self, ^":scale", Vector2.ONE, 0.15)
		recover_tweener.set_trans(Tween.TRANS_BACK)
		recover_tweener.set_ease(Tween.EASE_OUT)
	)

	_wall_hit.connect(func(direction: Hexagon.Direction) -> void:
		_squash_along(direction, _WALL_HIT_SQUASH)
	)


func bind_character(character: Character) -> void:
	_character = character
	_bind_entity(character)

	_sleeping_indicator.visible = _character.asleep
	_character.turned.connect(_face_character_direction)

	_face_character_direction()


func _refresh_squash() -> void:
	var axis := Transform2D(_squash_axis, Vector2.ZERO)
	var inverse_axis := Transform2D(-_squash_axis, Vector2.ZERO)

	var scaling := Transform2D(
		Vector2(1.0 - _squash, 0.0),
		Vector2(0.0, 1.0 + _squash * _SQUASH_BULGE_RATIO),
		Vector2.ZERO
	)

	# Rotate into the squash axis, scale along it, rotate back — otherwise the
	# art turns with the axis instead of deforming along it
	_squash_pivot.transform = axis * scaling * inverse_axis


func _face_character_direction(_rotation: Character.Rotation = null) -> void:
	var direction_rotation := Hexagon.get_direction_rotation(_character.facing_direction)
	var target_rotation := _rotator.rotation + wrapf(direction_rotation - _rotator.rotation, -PI, PI)

	if _rotation_tween != null and _rotation_tween.is_valid():
		_rotation_tween.kill()

	if _rotation == null:
		_rotator.rotation = target_rotation
		return

	var rotation_duration := _ROTATION_RESTORE_DURATION if _rotation.restoring else _ROTATION_DURATION

	_rotation_tween = create_tween()
	_rotation_tween.set_parallel()

	var rotation_tweener := _rotation_tween.tween_property(_rotator, ^":rotation", target_rotation, rotation_duration)
	if not _rotation.restoring:
		rotation_tweener.set_trans(Tween.TRANS_BACK)
		rotation_tweener.set_ease(Tween.EASE_OUT)
		_animation_player.play("flutter")


func _squash_along(direction: Hexagon.Direction, squash: float) -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()

	_squash_tween = create_tween()

	_squash_axis = Hexagon.get_direction_rotation(direction)

	var compress_tweener := _squash_tween.tween_property(self, ^":_squash", squash, _MOVEMENT_DURATION * 0.3)
	compress_tweener.set_trans(Tween.TRANS_QUAD)
	compress_tweener.set_ease(Tween.EASE_OUT)

	var release_tweener := _squash_tween.tween_property(self, ^":_squash", 0.0, _MOVEMENT_DURATION * 0.7)
	release_tweener.set_trans(Tween.TRANS_BACK)
	release_tweener.set_ease(Tween.EASE_OUT)
