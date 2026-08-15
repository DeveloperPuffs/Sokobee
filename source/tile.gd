class_name Tile


const MINIMUM_HEIGHT := -1
const MAXIMUM_HEIGHT := 1

var position: Vector2i
var goal: bool
var height: int


func _init(_position: Vector2i, _goal: bool, _height: int) -> void:
	position = _position
	goal = _goal
	height = _height
