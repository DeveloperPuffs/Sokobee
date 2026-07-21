class_name Cell
extends Sprite2D


enum Type {
	NORMAL,
	GOAL,
	SELECTABLE,
	SELECTED,
}

const NORMAL_TEXTURE := preload("res://assets/sprites/cell_normal.svg")
const GOAL_TEXTURE := preload("res://assets/sprites/cell_goal.svg")
const SELECTABLE_TEXTURE := preload("res://assets/sprites/cell_selectable.svg")
const SELECTED_TEXTURE := preload("res://assets/sprites/cell_selected.svg")

var _type: Type
var _tile_position: Vector2i
var _tile_height: int


func display(type: Type, tile_position: Vector2i, tile_height: int = 0) -> void:
	_type = type
	_tile_position = tile_position
	_tile_height = tile_height

	var bounds := get_bounds()
	position = bounds.get_center()

	z_index = Hexagon.get_tile_z_index(_tile_position)

	match type:
		Type.NORMAL:
			texture = NORMAL_TEXTURE
		Type.GOAL:
			texture = GOAL_TEXTURE
		Type.SELECTABLE:
			texture = SELECTABLE_TEXTURE
			z_index += 2 * Hexagon.Z_INDEX_SCALE + 2
		Type.SELECTED:
			texture = SELECTED_TEXTURE
			z_index += 2 * Hexagon.Z_INDEX_SCALE + 1


func get_bounds() -> Rect2:
	const TEXTURE_SIZE = Vector2(Hexagon.TILE_WIDTH, Hexagon.TILE_SIZE * 3.0)

	var center := Hexagon.get_tile_world_position(_tile_position, _tile_height)
	var x := center.x - Hexagon.TILE_WIDTH / 2.0
	var y := center.y - Hexagon.TILE_HEIGHT / 2.0
	return Rect2(Vector2(x, y), TEXTURE_SIZE)
