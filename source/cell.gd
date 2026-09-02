class_name Cell
extends Sprite2D


enum Type {
	NORMAL,
	GOAL,
	SELECTABLE,
	SELECTED,
}

const _TEXTURES: Dictionary[Type, Texture] = {
	Type.NORMAL: preload("res://assets/sprites/tiles/cell_normal.svg"),
	Type.GOAL: preload("res://assets/sprites/tiles/cell_goal.svg"),
	Type.SELECTABLE: preload("res://assets/sprites/editor/cell_selectable.svg"),
	Type.SELECTED: preload("res://assets/sprites/editor/cell_selected.svg"),
}

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

	texture = _TEXTURES[type]
	if type == Type.SELECTABLE:
		z_index += 2 * Hexagon.Z_INDEX_SCALE + 2
	elif type == Type.SELECTED:
		z_index += 2 * Hexagon.Z_INDEX_SCALE + 1


func get_bounds() -> Rect2:
	const TEXTURE_SIZE = Vector2(Hexagon.TILE_WIDTH, Hexagon.TILE_SIZE * 3.0)

	var center := Hexagon.get_tile_world_position(_tile_position, _tile_height)
	var x := center.x - Hexagon.TILE_WIDTH / 2.0
	var y := center.y - Hexagon.TILE_HEIGHT / 2.0
	return Rect2(Vector2(x, y), TEXTURE_SIZE)
