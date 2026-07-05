class_name Hexagon


enum Direction {
	BOTTOM_RIGHT,
	BOTTOM_CENTER,
	BOTTOM_LEFT,
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
}

# Hexagon tiles with the flat-top orientation
const TILE_SIZE := 128.0
const TILE_WIDTH := 2.0 * TILE_SIZE
const TILE_HEIGHT := sqrt(3.0) * TILE_SIZE
const HEIGHT_OFFSET := TILE_SIZE / 4.0

# This leaves 10 z-indices for each tile
const Z_INDEX_SCALE := 10

static func get_opposite_direction(direction: Direction) -> Direction:
	return ((direction as int + 3) % 6) as Direction

static func get_direction_turned_left(direction: Direction) -> Direction:
	return ((direction as int) + 5) % 6 as Direction

static func get_direction_turned_right(direction: Direction) -> Direction:
	return ((direction as int) + 1) % 6 as Direction

static func get_direction_vector(direction: Direction) -> Vector2i:
	const DIRECTION_VECTORS := [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 1),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(1, -1),
	]

	return DIRECTION_VECTORS[direction as int]

static func get_direction_rotation(direction: Direction) -> float:
	return PI / 3.0 * (direction as int) + PI / 6.0

static func get_tile_world_position(tile_position: Vector2i, tile_height: int) -> Vector2:
	var x := 1.5 * tile_position.x * TILE_SIZE
	var y := (sqrt(3.0) / 2.0 * tile_position.x + sqrt(3.0) * tile_position.y) * TILE_SIZE
	y -= tile_height * HEIGHT_OFFSET
	return Vector2(x, y)

static func get_tile_z_index(tile_position: Vector2i) -> int:
	return (tile_position.x + 2 * tile_position.y) * Z_INDEX_SCALE

static func check_point_tile_interesection(point: Vector2, tile_position: Vector2i, tile_height: int) -> bool:
	var tile_center := get_tile_world_position(tile_position, tile_height)
	var offset := (point - tile_center).abs()
	if offset.y > TILE_HEIGHT / 2.0:
		return false

	return sqrt(3.0) * offset.x + offset.y <= TILE_HEIGHT