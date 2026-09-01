class_name Bee
extends Piece


@export var _sleeping_indicator: Sprite2D

var _character: Character


func _process(_delta: float) -> void:
	_refresh()


func initialize(character: Character) -> void:
	_character = character
	_sleeping_indicator.visible = _character.asleep
	_bind_entity(_character)
	_refresh()


func _refresh() -> void:
	rotation = Hexagon.get_direction_rotation(_character.facing_direction)
	_sleeping_indicator.rotation = -rotation
