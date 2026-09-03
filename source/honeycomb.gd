class_name Honeycomb
extends Node2D


@export var _camera: Camera2D
@export var _cell_scene: PackedScene
@export var _bee_scene: PackedScene
@export var _honey_scene: PackedScene
@export var _wax_scene: PackedScene
@export var _character_indicator: Sprite2D

var _state: State = null
var _tile_cells: Dictionary[Tile, Cell] = {}
var _entity_pieces: Dictionary[Entity, Piece] = {}
var _link_waxes: Dictionary[Link, Wax] = {}


func _ready() -> void:
	get_tree().root.size_changed.connect(_update_camera)


func _process(_delta: float) -> void:
	if _state == null:
		return

	if _state.active_character == null:
		_character_indicator.visible = false
		return
	
	var tile := _state.active_character.current_tile
	_character_indicator.position = Hexagon.get_tile_world_position(tile.position, tile.height)
	_character_indicator.z_index = Hexagon.get_tile_z_index(tile.position) + 1
	_character_indicator.visible = true


func load(state: State) -> void:
	for tile in _tile_cells:
		_tile_cells[tile].queue_free()
	_tile_cells = {}

	for entity in _entity_pieces:
		_entity_pieces[entity].queue_free()
	_entity_pieces = {}

	for link in _link_waxes:
		_link_waxes[link].queue_free()
	_link_waxes = {}

	for tile: Tile in state.tiles.values():
		var cell: Cell = _cell_scene.instantiate()
		var cell_type := Cell.Type.GOAL if tile.goal else Cell.Type.NORMAL
		cell.display(cell_type, tile.position, tile.height)
		_tile_cells[tile] = cell
		add_child(cell)

	for entity in state.entities:
		if entity is Character:
			var character: Character = entity
			var bee: Bee = _bee_scene.instantiate()
			bee.initialize(character)
			_entity_pieces[character] = bee
			add_child(bee)

		elif entity is Block:
			var block: Block = entity
			var honey: Honey = _honey_scene.instantiate()
			honey.initialize(block)
			_entity_pieces[block] = honey
			add_child(honey)
	
	for link in state.links:
		var wax: Wax = _wax_scene.instantiate()
		wax.initialize(link, _entity_pieces[link.entity_a], _entity_pieces[link.entity_b])
		_link_waxes[link] = wax
		add_child(wax)

	_state = state

	_update_camera()


func _update_camera() -> void:
	if _tile_cells.is_empty():
		return

	var grid_bounds: Rect2

	var first_tile := true
	for tile in _tile_cells:
		var cell := _tile_cells[tile]
		var cell_bounds := cell.get_bounds()

		if first_tile:
			grid_bounds = cell_bounds
			first_tile = false
			continue

		grid_bounds = grid_bounds.merge(cell_bounds)

	var screen_size := get_viewport_rect().size
	var zoom_x := screen_size.x / grid_bounds.size.x
	var zoom_y := screen_size.y / grid_bounds.size.y
	var zoom_value := minf(zoom_x, zoom_y) / 1.25 # 1.25 camera padding

	_camera.zoom = Vector2(zoom_value, zoom_value)
	_camera.position = grid_bounds.position + grid_bounds.size / 2.0
