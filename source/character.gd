class_name Character
extends Entity


signal turned(rotation: Rotation)

@warning_ignore("unused_signal")
signal clicked()

var facing_direction: Hexagon.Direction
var asleep: bool


func _init(_current_tile: Tile, _facing_direction: Hexagon.Direction, _asleep: bool) -> void:
	super._init(_current_tile)
	facing_direction = _facing_direction
	asleep = _asleep


func set_facing_direction(_facing_direction: Hexagon.Direction, restoring: bool = false) -> void:
	facing_direction = _facing_direction
	turned.emit(Rotation.new(restoring))


class Rotation:
	var restoring: bool

	func _init(_restoring: bool) -> void:
		restoring = _restoring
