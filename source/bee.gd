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
@export var _scaler: Node2D
@export var _rotator: Node2D
@export var _animation_player: AnimationPlayer

var _character: Character
var _rotation_tween: Tween = null

var _pulse_tween: Tween = null
var _pulse := 1.0:
	set(pulse):
		_pulse = pulse
		_refresh_transformation()

var _squash_tween: Tween = null
var _squash_axis_angle := 0.0
var _squash := 0.0:
	set(squash):
		_squash = squash
		_refresh_transformation()


func _init() -> void:
	super()

	_movement_started.connect(func(movement: Entity.Movement) -> void:
		if not movement.has_direction():
			return

		var direction := movement.get_direction()
		var direction_angle := Hexagon.get_direction_rotation(direction)
		match movement.kind:
			Entity.Movement.Kind.WALKING:
				_animation_player.play("flutter")
			Entity.Movement.Kind.INITIATOR:
				_animation_player.play("flap")
				_squash_along(direction_angle, _PUSHING_SQUASH)
			Entity.Movement.Kind.CARRIED:
				_animation_player.play("flutter")
				_squash_along(direction_angle, _PUSHED_SQUASH)
	)

	_movement_landed.connect(func() -> void:
		_squash_along(PI / 2.0, _LANDING_SQUASH)
	)

	_wall_hit.connect(func(direction: Hexagon.Direction) -> void:
		_squash_along(Hexagon.get_direction_rotation(direction), _WALL_HIT_SQUASH)
	)


func bind_character(character: Character) -> void:
	_character = character
	_bind_entity(character)

	_sleeping_indicator.visible = _character.asleep
	_character.turned.connect(_face_character_direction)

	_character.clicked.connect(func() -> void:
		if _pulse_tween != null and _pulse_tween.is_valid():
			_pulse_tween.kill()

		_pulse_tween = create_tween()

		var pulsed_value := 0.9 if _character.asleep else 1.2
		var pulsed_tweener := _pulse_tween.tween_property(self, ^":_pulse", pulsed_value, 0.1)
		pulsed_tweener.set_trans(Tween.TRANS_QUAD)
		pulsed_tweener.set_ease(Tween.EASE_OUT)

		var settle_tweener := _pulse_tween.tween_property(self, ^":_pulse", 1.0, 0.2)
		settle_tweener.set_trans(Tween.TRANS_BACK)
		settle_tweener.set_ease(Tween.EASE_OUT)
	)

	_face_character_direction()


func _refresh_transformation() -> void:
	_scaler.transform = (
		# Pulse Transform
		Transform2D(Vector2(_pulse, 0.0), Vector2(0.0, _pulse), Vector2.ZERO) *

		# Squash Transform
		Transform2D(_squash_axis_angle, Vector2.ZERO) *
		Transform2D(
			Vector2(1.0 - _squash, 0.0),
			Vector2(0.0, 1.0 + _squash * _SQUASH_BULGE_RATIO),
			Vector2.ZERO
		) *
		Transform2D(-_squash_axis_angle, Vector2.ZERO)
	)


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


func _squash_along(axis_angle: float, squash: float) -> void:
	_squash_axis_angle = axis_angle

	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()

	_squash_tween = create_tween()

	var compress_tweener := _squash_tween.tween_property(self, ^":_squash", squash, 0.05)
	compress_tweener.set_trans(Tween.TRANS_QUAD)
	compress_tweener.set_ease(Tween.EASE_OUT)

	var release_tweener := _squash_tween.tween_property(self, ^":_squash", 0.0, 0.15)
	release_tweener.set_trans(Tween.TRANS_BACK)
	release_tweener.set_ease(Tween.EASE_OUT)
