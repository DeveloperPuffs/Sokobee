class_name Bee
extends Piece


const _ROTATION_DURATION := 0.2
const _ROTATION_RESTORE_DURATION := 0.1

@export var _sleeping_indicator: Sprite2D

var _character: Character
var _rotation_tween: Tween = null


func _process(_delta: float) -> void:
	_sleeping_indicator.rotation = -rotation


func initialize(character: Character) -> void:
	_character = character
	_bind_entity(_character)

	_sleeping_indicator.visible = _character.asleep
	_character.turned.connect(_face_character_direction)

	_face_character_direction()


func _face_character_direction(_rotation: Character.Rotation = null) -> void:
	var direction_rotation := Hexagon.get_direction_rotation(_character.facing_direction)
	var target_rotation := rotation + wrapf(direction_rotation - rotation, -PI, PI)

	if _rotation_tween != null and _rotation_tween.is_valid():
		_rotation_tween.kill()

	if _rotation == null:
		rotation = target_rotation
		_sleeping_indicator.rotation = -rotation
		return

	var rotation_duration := _ROTATION_RESTORE_DURATION if _rotation.restoring else _ROTATION_DURATION

	_rotation_tween = create_tween()
	_rotation_tween.set_parallel()

	var rotation_tweener := _rotation_tween.tween_property(self, ^":rotation", target_rotation, rotation_duration)
	if not _rotation.restoring:
		rotation_tweener.set_trans(Tween.TRANS_BACK)
		rotation_tweener.set_ease(Tween.EASE_OUT)
