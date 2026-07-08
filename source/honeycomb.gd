class_name Honeycomb
extends Node2D


@export var _camera: Camera
@export var _cell_scene: PackedScene
@export var _bee_scene: PackedScene
@export var _honey_scene: PackedScene
@export var _wax_scene: PackedScene

var _state: State
var _cells: Array[Cell]
var _entity_nodes: Array[Node2D]
var _waxes: Array[Wax]

func _ready() -> void:
	_state = null
	_cells = []
	_entity_nodes = []
	_waxes = []
	get_tree().root.size_changed.connect(_update_camera)

func load(state: State) -> void:
	for cell in _cells:
		cell.queue_free()
	_cells = []

	for entity_node in _entity_nodes:
		entity_node.queue_free()
	_entity_nodes = []

	for wax in _waxes:
		wax.queue_free()
	_waxes = []

	for tile: Tile in state.tiles.values():
		var cell := _cell_scene.instantiate()
		var cell_type := Cell.Type.GOAL if tile.goal else Cell.Type.NORMAL
		cell.display(cell_type, tile.position, tile.height)
		_cells.append(cell)
		add_child(cell)

	for entity in state.entities:
		if entity is Character:
			var bee: Bee = _bee_scene.instantiate()
			bee.initialize(entity as Character)
			_entity_nodes.append(bee)
			add_child(bee)

		elif entity is Block:
			var honey: Honey = _honey_scene.instantiate()
			honey.initialize(entity as Block)
			_entity_nodes.append(honey)
			add_child(honey)
	
	for link in state.links:
		var wax: Wax = _wax_scene.instantiate()
		wax.initialize(link)
		_waxes.append(wax)
		add_child(wax)

	_state = state

	_update_camera()

func get_tile_at(world_position: Vector2) -> Tile:
	var frontmost_tile: Tile = null
	var frontmost_z_index := 0

	for tile: Tile in _state.tiles.values():
		if not Hexagon.check_point_tile_interesection(world_position, tile.position, tile.height):
			continue

		var tile_z_index := Hexagon.get_tile_z_index(tile.position)
		if frontmost_tile == null or tile_z_index > frontmost_z_index:
			frontmost_z_index = tile_z_index
			frontmost_tile = tile

	return frontmost_tile

func _update_camera() -> void:
	if _cells.is_empty():
		return

	var first_cell := _cells[0]
	var grid_bounds := first_cell.get_bounds()

	for cell in _cells:
		var cell_bounds := cell.get_bounds()
		grid_bounds = grid_bounds.merge(cell_bounds)

	_camera.frame(grid_bounds, 1.25)