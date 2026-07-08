class_name Editor
extends Node2D


"""

Editor Controls

Tile Tool:
Left Click (and Drag) to Place Tiles
Right Click (and Drag) to Remove Tiles
	[G] Toggle Tile 'goal' Property
	[+] Increase Tile Height
	[-] Decrease Tile Height

Character Tool:
Left Click to Place Character
Right Click to Remove Character
	[C] Set Selected Character as Active Character
	[S] Toggle Character 'asleep' property
	[A] Rotate Character Left
	[D] Rotate Character Right

"""

signal exited_editor

enum Tool {
	VIEW,
	TILE,
	CHARACTER,
	BLOCK,
}

@export var _tile_preview: Cell
@export var _selected_tile_indicator: Cell
@export var _selected_entity_indicator: Sprite2D

@export var _honeycomb: Honeycomb
@export var _tools_dropdown: OptionButton

var _state: State
var _selected_tool: Tool
var _selected_tile: Tile
var _selected_entity: Entity

var _place_tile_drag_button: MouseButton = MOUSE_BUTTON_NONE

func _ready() -> void:
	_state = Loader.load_level_state("res://assets/levels/default.json")
	if _state == null:
		exited_editor.emit()
		return

	_honeycomb.load(_state)

	_tools_dropdown.add_item("View", Tool.VIEW)
	_tools_dropdown.add_item("Tile", Tool.TILE)
	_tools_dropdown.add_item("Character", Tool.CHARACTER)
	_tools_dropdown.add_item("Block", Tool.BLOCK)

	_tools_dropdown.item_selected.connect(_on_tool_option_item_selected)
	_tools_dropdown.select(Tool.VIEW)

	_set_selected_tile(null)
	_set_selected_entity(null)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var world_position := get_global_mouse_position()

		if _place_tile_drag_button == MOUSE_BUTTON_LEFT:
			_place_tile(world_position)
		elif _place_tile_drag_button == MOUSE_BUTTON_RIGHT:
			_remove_tile(world_position)

		_refresh_tile_preview()
		return

	if event is InputEventMouseButton and not event.is_pressed():
		if event.button_index == _place_tile_drag_button:
			_place_tile_drag_button = MOUSE_BUTTON_NONE
		return

	if not event.is_pressed():
		return

	if event is InputEventMouseButton:
		var world_position := get_global_mouse_position()

		match _selected_tool:
			Tool.TILE:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_place_tile_drag_button = event.button_index
					_place_tile(world_position)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_place_tile_drag_button = event.button_index
					_remove_tile(world_position)

			Tool.CHARACTER:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_place_character(world_position)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_remove_character(world_position)

			Tool.BLOCK:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_place_block(world_position)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_remove_block(world_position)

	elif event is InputEventKey and not event.is_echo():
		var input_key_event := event as InputEventKey

		if _selected_tile != null:
			_handle_tile_keybinds(_selected_tile, input_key_event.keycode)
		elif _selected_entity is Character:
			var selected_character := _selected_entity as Character
			_handle_character_keybinds(selected_character, input_key_event.keycode)

func _handle_tile_keybinds(tile: Tile, key: Key) -> void:
	match key:
		KEY_G:
			tile.goal = not tile.goal
			_honeycomb.load(_state)

		KEY_PLUS, KEY_EQUAL:
			tile.height = min(max(tile.height + 1, -1), 1)
			_honeycomb.load(_state)
			_set_selected_tile(tile)
			_refresh_tile_preview()

		KEY_MINUS, KEY_UNDERSCORE:
			tile.height = min(max(tile.height - 1, -1), 1)
			_honeycomb.load(_state)
			_set_selected_tile(tile)
			_refresh_tile_preview()

func _handle_character_keybinds(character: Character, key: Key) -> void:
	match key:
		KEY_C:
			_state.active_character = character

		KEY_A, KEY_LEFT:
			var new_direction := Hexagon.get_direction_turned_left(character.facing_direction)
			character.facing_direction = new_direction

		KEY_D, KEY_RIGHT:
			var new_direction := Hexagon.get_direction_turned_right(character.facing_direction)
			character.facing_direction = new_direction

		KEY_S:
			character.asleep = not character.asleep
			_honeycomb.load(_state)

func _refresh_tile_preview() -> void:
	var world_position := get_global_mouse_position()
	var tile_position := _get_tile_position_at(world_position)
	var tile: Tile = _state.tiles.get(tile_position)

	if tile != null:
		var entity := _get_entity_at(tile_position)
		if _selected_tool == Tool.CHARACTER and entity is Block \
			or _selected_tool == Tool.BLOCK and entity is Character:
			_tile_preview.visible = false
			return

		_tile_preview.visible = true
		_tile_preview.display(Cell.Type.PREVIEW, tile.position, tile.height)
		return

	if _selected_tool == Tool.TILE:
		_tile_preview.visible = true
		_tile_preview.display(Cell.Type.PREVIEW, tile_position, 0)
		return

	_tile_preview.visible = false

func _get_tile_position_at(world_position: Vector2) -> Vector2i:
	# Prefer the cell the mouse is visually over
	var tile := _honeycomb.get_tile_at(world_position)
	if tile != null:
		return tile.position
	return Hexagon.get_world_tile_position(world_position)

func _set_selected_tile(selected_tile: Tile) -> void:
	_selected_tile = selected_tile

	if _selected_tile == null:
		_selected_tile_indicator.visible = false
		return

	var cell_position := _selected_tile.position
	var cell_height := _selected_tile.height
	_selected_tile_indicator.display(Cell.Type.SELECTED, cell_position, cell_height)
	_selected_tile_indicator.visible = true

func _set_selected_entity(selected_entity: Entity) -> void:
	_selected_entity = selected_entity

	if _selected_entity == null:
		_selected_entity_indicator.visible = false
		return

	var tile_position := _selected_entity.current_tile.position
	var elevation := _selected_entity.get_elevation()

	_selected_entity_indicator.position = Hexagon.get_tile_world_position(tile_position, elevation)
	_selected_entity_indicator.z_index = Hexagon.get_tile_z_index(tile_position) + 3
	_selected_entity_indicator.visible = true

func _on_tool_option_item_selected(index: int) -> void:
	_selected_tool = _tools_dropdown.get_item_id(index) as Tool
	_place_tile_drag_button = MOUSE_BUTTON_NONE
	_set_selected_tile(null)
	_set_selected_entity(null)
	_refresh_tile_preview()

func _place_tile(world_position: Vector2) -> void:
	var tile_position := _get_tile_position_at(world_position)
	var tile: Tile = _state.tiles.get(tile_position)

	if tile == null:
		tile = Tile.new(tile_position, false, 0)
		_state.tiles[tile_position] = tile
		_honeycomb.load(_state)

	_set_selected_tile(tile)

func _remove_tile(world_position: Vector2) -> void:
	var tile_position := _get_tile_position_at(world_position)
	var tile: Tile = _state.tiles.get(tile_position)

	if tile == null:
		return
	
	if tile == _selected_tile:
		_set_selected_tile(null)

	var entity := _get_entity_at(tile_position)
	if entity != null:
		_state.entities.erase(entity)
		if entity is Character:
			_state.characters.erase(entity)

	_state.tiles.erase(tile_position)
	_honeycomb.load(_state)

func _place_character(world_position: Vector2) -> void:
	var tile_position := _get_tile_position_at(world_position)
	var tile: Tile = _state.tiles.get(tile_position)
	if tile == null:
		return

	var entity := _get_entity_at(tile_position)
	if entity is Block:
		return

	var character := entity as Character
	if character == null:
		character = Character.new(tile, Hexagon.Direction.TOP_CENTER, false)
		_state.entities.append(character)
		_state.characters.append(character)
		_honeycomb.load(_state)

	_set_selected_entity(character)

func _remove_character(world_position: Vector2) -> void:
	var tile_position := _get_tile_position_at(world_position)
	var tile: Tile = _state.tiles.get(tile_position)
	if tile == null:
		return

	var entity := _get_entity_at(tile_position)
	if entity is Block:
		return

	var character := entity as Character
	if character == _selected_entity:
		_set_selected_entity(null)

	_state.entities.erase(character)
	_state.characters.erase(character)
	_honeycomb.load(_state)

func _place_block(world_position: Vector2) -> void:
	var tile_position := _get_tile_position_at(world_position)
	var tile: Tile = _state.tiles.get(tile_position)
	if tile == null:
		return

	var entity := _get_entity_at(tile_position)
	if entity is Character:
		return

	var block := entity as Block
	if block == null:
		block = Block.new(tile)
		_state.entities.append(block)
		_honeycomb.load(_state)

	_set_selected_entity(block)

func _remove_block(world_position: Vector2) -> void:
	var tile_position := _get_tile_position_at(world_position)
	var tile: Tile = _state.tiles.get(tile_position)
	if tile == null:
		return

	var entity := _get_entity_at(tile_position)
	if entity is Character:
		return

	var block := entity as Block
	if block == _selected_entity:
		_set_selected_entity(null)

	_state.entities.erase(block)
	_honeycomb.load(_state)

func _get_entity_at(tile_position: Vector2i) -> Entity:
	for entity in _state.entities:
		if entity.current_tile.position == tile_position:
			return entity
	return null