class_name Honeycomb
extends Node2D


@export var _camera: Camera2D
@export var _cell_scene: PackedScene
@export var _bee_scene: PackedScene
@export var _honey_scene: PackedScene
@export var _character_indicator: Sprite2D

var _state: State = null
var _tile_cells: Dictionary[Tile, Cell] = {}
var _entity_pieces: Dictionary[Entity, Piece] = {}
var _link_waxes: Dictionary[Link, Wax] = {}

var _fitted_camera_position := Vector2.ZERO

var _camera_kick_requested := false
var _camera_kick_maximum := Vector2.ZERO
var _camera_kick_tween: Tween = null
var _camera_kick := Vector2.ZERO:
	set(camera_kick):
		_camera_kick = camera_kick
		_refresh_camera_position()


func _ready() -> void:
	get_tree().root.size_changed.connect(_update_camera)


func _process(_delta: float) -> void:
	if _state == null:
		return

	if _camera_kick_requested:
		_camera_kick_requested = false

		if _camera_kick_tween != null and _camera_kick_tween.is_valid():
			_camera_kick_tween.kill()

		_camera_kick_tween = create_tween()

		var camera_kick_tweener := _camera_kick_tween.tween_property(self, ^":_camera_kick", _camera_kick_maximum, 0.05)
		camera_kick_tweener.set_trans(Tween.TRANS_QUAD)
		camera_kick_tweener.set_ease(Tween.EASE_OUT)

		var camera_recover_tweener := _camera_kick_tween.tween_property(self, ^":_camera_kick", Vector2.ZERO, 0.18)
		camera_recover_tweener.set_trans(Tween.TRANS_BACK)
		camera_recover_tweener.set_ease(Tween.EASE_OUT)

	if _state.active_character == null:
		_character_indicator.visible = false
	else:
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
		var piece: Piece

		if entity is Character:
			var character: Character = entity
			var bee: Bee = _bee_scene.instantiate()
			bee.bind_character(character)
			piece = bee

		elif entity is Block:
			var block: Block = entity
			var honey: Honey = _honey_scene.instantiate()
			honey.bind_block(block)
			piece = honey

		piece._wall_hit.connect(_request_camera_kick)

		_entity_pieces[entity] = piece
		add_child(piece)
	
	for link in state.links:
		var wax: Wax
		match link.type:
			Link.Type.SOLID:
				wax = SolidWax.new(link, _entity_pieces[link.entity_a], _entity_pieces[link.entity_b])
			Link.Type.STICKY:
				wax = StickyWax.new(link, _entity_pieces[link.entity_a], _entity_pieces[link.entity_b])

		_link_waxes[link] = wax
		add_child(wax)

	_state = state

	_update_camera()


func _refresh_camera_position() -> void:
	_camera.position = _fitted_camera_position + _camera_kick


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
	_fitted_camera_position = grid_bounds.position + grid_bounds.size / 2.0
	_refresh_camera_position()


func _request_camera_kick(direction: Hexagon.Direction) -> void:
	if _camera_kick_requested:
		return

	_camera_kick_requested = true

	var direction_vector := Hexagon.get_direction_vector(direction)
	var world_direction := Hexagon.get_tile_world_position(direction_vector)
	_camera_kick_maximum = world_direction * 0.05
