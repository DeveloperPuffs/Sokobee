class_name Tile


var position: Vector2i
var goal: bool
var height: int


func _init(_position: Vector2i, _goal: bool, _height: int) -> void:
	position = _position
	goal = _goal
	height = _height
