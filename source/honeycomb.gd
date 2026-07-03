class_name Honeycomb
extends Node2D


@export var _camera: Camera
@export var _bee_scene: PackedScene
@export var _honey_scene: PackedScene

var _state: State
var _entity_nodes: Array[Node2D]

func _ready() -> void:
	_entity_nodes = []
	get_tree().root.size_changed.connect(_update_camera)

func _draw() -> void:
	for tile_position in _state.tiles.keys():
		var tile_type := _state.tiles[tile_position]
		var center := Hexagon.get_world_position(tile_position)
		_draw_hexagon(center, Hexagon.TILE_SIZE, Color.BLACK)

		var fill_color: Color
		match tile_type:
			State.TileType.TILE_FLOOR:
				fill_color = Color.WHITE
			State.TileType.TILE_GOAL:
				fill_color = Color.GREEN

		_draw_hexagon(center, Hexagon.TILE_SIZE * 0.9, fill_color)

func load(state: State) -> void:
	for entity_node in _entity_nodes:
		entity_node.queue_free()
	_entity_nodes = []

	_state = state

	for entity in state.entities:
		if entity is Character:
			var bee = _bee_scene.instantiate()
			bee.initialize(entity as Character)
			_entity_nodes.append(bee)
			add_child(bee)

		elif entity is Block:
			var honey = _honey_scene.instantiate()
			honey.initialize(entity as Block)
			_entity_nodes.append(honey)
			add_child(honey)

	_update_camera()

func _update_camera() -> void:
	var minimum_position := Vector2(INF, INF)
	var maximum_position := Vector2(-INF, -INF)

	for tile_position in _state.tiles.keys():
		var world_position := Hexagon.get_world_position(tile_position)

		minimum_position.x = min(minimum_position.x, world_position.x)
		minimum_position.y = min(minimum_position.y, world_position.y)

		maximum_position.x = max(maximum_position.x, world_position.x)
		maximum_position.y = max(maximum_position.y, world_position.y)

	var grid_bounds := Rect2(minimum_position, maximum_position - minimum_position)

	# Add some padding to take in account the size of the tiles
	var padding := Vector2(Hexagon.TILE_SIZE, sqrt(3.0) / 2.0 * Hexagon.TILE_SIZE)
	grid_bounds.position -= padding
	grid_bounds.size += padding * 2.0

	_camera.frame(grid_bounds, 1.25)

# Temporary function to draw the hexagon tiles
func _draw_hexagon(center: Vector2, size: float, color: Color) -> void:
	var vertices: Array[Vector2] = []
	for index in range(6):
		var angle := PI / 3.0 * index
		var x := center.x + size * cos(angle)
		var y := center.y + size * sin(angle)
		vertices.append(Vector2(x, y))
	draw_colored_polygon(vertices, color)