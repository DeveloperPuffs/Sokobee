class_name Honeycomb
extends Node2D


@export var _camera: Camera2D
@export var _cell_scene: PackedScene
@export var _bee_scene: PackedScene
@export var _honey_scene: PackedScene
@export var _wax_scene: PackedScene
@export var _character_indicator: Sprite2D

var _state: State = null
var _cells: Array[Cell] = []
var _entity_nodes: Array[Node2D] = []
var _waxes: Array[Wax] = []


func _ready() -> void:
	get_tree().root.size_changed.connect(_update_camera)


func _process(_delta: float) -> void:
	_update_character_indicator()


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


func _update_character_indicator() -> void:
	if _state.active_character == null:
		_character_indicator.visible = false
		return
	
	var tile := _state.active_character.current_tile
	_character_indicator.position = Hexagon.get_tile_world_position(tile.position, tile.height)
	_character_indicator.z_index = Hexagon.get_tile_z_index(tile.position) + 1
	_character_indicator.visible = true


func _update_camera() -> void:
	if _cells.is_empty():
		return

	var first_cell := _cells[0]
	var grid_bounds := first_cell.get_bounds()

	for cell in _cells:
		var cell_bounds := cell.get_bounds()
		grid_bounds = grid_bounds.merge(cell_bounds)

	var screen_size := get_viewport_rect().size
	var zoom_x := screen_size.x / grid_bounds.size.x
	var zoom_y := screen_size.y / grid_bounds.size.y
	var zoom_value := (min(zoom_x, zoom_y) as float) / 1.25 # 1.25 camera padding

	_camera.zoom = Vector2(zoom_value, zoom_value)
	_camera.position = grid_bounds.position + grid_bounds.size / 2.0
