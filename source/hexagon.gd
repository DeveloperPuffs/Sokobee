class_name Hexagon


enum Direction {
	BOTTOM_RIGHT,
	BOTTOM_CENTER,
	BOTTOM_LEFT,
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
}

const TILE_SIZE := 32.0

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

static func get_world_position(tile_position: Vector2i) -> Vector2:
	var x := 1.5 * tile_position.x * TILE_SIZE
	var y := (sqrt(3.0) / 2.0 * tile_position.x + sqrt(3.0) * tile_position.y) * TILE_SIZE
	return Vector2(x, y)

static func get_direction_rotation(direction: Direction) -> float:
	return PI / 3.0 * (direction as int) + PI / 6.0