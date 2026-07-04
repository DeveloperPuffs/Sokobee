class_name Cell
extends Sprite2D


const GOAL_TEXTURE = preload("res://assets/sprites/cell_goal.svg")
const NORMAL_TEXTURE = preload("res://assets/sprites/cell_normal.svg")

var _tile: Tile

func initialize(tile: Tile) -> void:
	_tile = tile

	var bounds := get_bounds()
	position = bounds.get_center()

	z_index = Hexagon.get_tile_z_index(tile.position)
	texture = GOAL_TEXTURE if tile.goal else NORMAL_TEXTURE

func get_bounds() -> Rect2:
	const TEXTURE_SIZE = Vector2(Hexagon.TILE_WIDTH, Hexagon.TILE_SIZE * 3.0)
	var top_left := Hexagon.get_tile_world_position(_tile.position, _tile.height)
	top_left.x -= Hexagon.TILE_WIDTH / 2.0
	top_left.y -= Hexagon.TILE_HEIGHT / 2.0
	return Rect2(top_left, TEXTURE_SIZE)