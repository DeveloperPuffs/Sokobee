class_name Honeycomb
extends Node2D


@export var _camera: Camera
@export var _cell_scene: PackedScene
@export var _bee_scene: PackedScene
@export var _honey_scene: PackedScene

var _state: State
var _cells: Array[Cell]
var _entity_nodes: Array[Node2D]

func _ready() -> void:
	_state = null
	_cells = []
	_entity_nodes = []
	get_tree().root.size_changed.connect(_update_camera)

func load(state: State) -> void:
	for cell in _cells:
		cell.queue_free()
	_cells = []

	for entity_node in _entity_nodes:
		entity_node.queue_free()
	_entity_nodes = []

	_state = state

	for tile: Tile in _state.tiles.values():
		var cell := _cell_scene.instantiate()
		cell.initialize(tile)
		_cells.append(cell)
		add_child(cell)

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
	if _cells.is_empty():
		return

	var first_cell := _cells[0]
	var grid_bounds := first_cell.get_bounds()

	for cell in _cells:
		var cell_bounds := cell.get_bounds()
		grid_bounds = grid_bounds.merge(cell_bounds)

	_camera.frame(grid_bounds, 1.25)