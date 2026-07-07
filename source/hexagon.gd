class_name Hexagon


enum Direction {
	BOTTOM_RIGHT,
	BOTTOM_CENTER,
	BOTTOM_LEFT,
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
}

const _DIRECTION_VECTORS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, -1),
]

# Hexagon tiles with the flat-top orientation
const TILE_SIZE := 128.0
const TILE_WIDTH := 2.0 * TILE_SIZE
const TILE_HEIGHT := sqrt(3.0) * TILE_SIZE
const HEIGHT_OFFSET := TILE_SIZE / 2.0

# This leaves 10 z-indices for each tile
const Z_INDEX_SCALE := 10

static func get_opposite_direction(direction: Direction) -> Direction:
	return ((direction as int + 3) % 6) as Direction

static func get_direction_turned_left(direction: Direction) -> Direction:
	return ((direction as int) + 5) % 6 as Direction

static func get_direction_turned_right(direction: Direction) -> Direction:
	return ((direction as int) + 1) % 6 as Direction

static func get_direction_vector(direction: Direction) -> Vector2i:
	return _DIRECTION_VECTORS[direction as int]

static func is_direction_vector(vector: Vector2i) -> bool:
	return _DIRECTION_VECTORS.has(vector)

static func get_direction_rotation(direction: Direction) -> float:
	return PI / 3.0 * (direction as int) + PI / 6.0

static func get_tile_world_position(tile_position: Vector2i, tile_height: int) -> Vector2:
	var x := 1.5 * tile_position.x * TILE_SIZE
	var y := (sqrt(3.0) / 2.0 * tile_position.x + sqrt(3.0) * tile_position.y) * TILE_SIZE
	y -= tile_height * HEIGHT_OFFSET
	return Vector2(x, y)

static func get_world_tile_position(world_position: Vector2) -> Vector2i:
	var q := world_position.x / (1.5 * TILE_SIZE)
	var r := world_position.y / (sqrt(3.0) * TILE_SIZE) - q / 2.0

	var s := -q - r
	var q_rounded := roundi(q)
	var r_rounded := roundi(r)
	var s_rounded := roundi(s)

	var q_difference := absf(q_rounded - q)
	var r_difference := absf(r_rounded - r)
	var s_difference := absf(s_rounded - s)

	if q_difference > r_difference and q_difference > s_difference:
		q_rounded = -r_rounded - s_rounded
	elif r_difference > s_difference:
		r_rounded = -q_rounded - s_rounded

	return Vector2i(q_rounded, r_rounded)

static func get_tile_z_index(tile_position: Vector2i) -> int:
	return (tile_position.x + 2 * tile_position.y) * Z_INDEX_SCALE

static func check_point_tile_interesection(point: Vector2, tile_position: Vector2i, tile_height: int) -> bool:
	var tile_center := get_tile_world_position(tile_position, tile_height)
	var offset := (point - tile_center).abs()
	if offset.y > TILE_HEIGHT / 2.0:
		return false

	return sqrt(3.0) * offset.x + offset.y <= TILE_HEIGHT