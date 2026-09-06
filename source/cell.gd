class_name Cell
extends Node2D


enum Type {
	NORMAL,
	GOAL,
	SELECTABLE,
	SELECTED,
}

@export var _type_scenes: Dictionary[Type, PackedScene]

var _type: Type
var _tile_position: Vector2i
var _tile_height: int

var _shape: Node2D


func display(type: Type, tile_position: Vector2i, tile_height: int = 0) -> void:
	_tile_position = tile_position
	_tile_height = tile_height

	position = Hexagon.get_tile_world_position(_tile_position, _tile_height)

	z_index = Hexagon.get_tile_z_index(_tile_position)
	if type == Type.SELECTABLE:
		z_index += 2 * Hexagon.Z_INDEX_SCALE + 2
	elif type == Type.SELECTED:
		z_index += 2 * Hexagon.Z_INDEX_SCALE + 1

	if _shape != null and type == _type:
		return

	_type = type

	if _shape != null:
		_shape.queue_free()

	_shape = _type_scenes[type].instantiate()
	add_child(_shape)


func get_bounds() -> Rect2:
	const TEXTURE_SIZE = Vector2(Hexagon.TILE_WIDTH, Hexagon.TILE_SIZE * 3.0)

	var center := Hexagon.get_tile_world_position(_tile_position, _tile_height)
	var x := center.x - Hexagon.TILE_WIDTH / 2.0
	var y := center.y - Hexagon.TILE_HEIGHT / 2.0
	return Rect2(Vector2(x, y), TEXTURE_SIZE)
