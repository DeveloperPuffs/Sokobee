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

Link Tool:
Left Click to Select/Link Entities
Right Click to Select/Unlink Entities
	[T] Toggle Link 'type' Property

"""

signal exited_editor

enum Tool {
	TILE,
	CHARACTER,
	BLOCK,
	LINK,
}

@export var _selectable_tile_indicator: Cell
@export var _selected_tile_indicator: Cell
@export var _selected_entity_indicator: Sprite2D
@export var _selectable_entity_indicator: Sprite2D
@export var _selected_link_indicator: Sprite2D

@export var _honeycomb: Honeycomb
@export var _tools_dropdown: OptionButton

var _state: State
var _selected_tool: Tool
var _selected_tile: Tile
var _selected_entity: Entity
var _selected_link: Link

var _place_tile_drag_button: MouseButton = MOUSE_BUTTON_NONE

func _ready() -> void:
	_state = Loader.load_level_state("res://assets/levels/default.json")
	if _state == null:
		exited_editor.emit()
		return

	_honeycomb.load(_state)

	_tools_dropdown.add_item("Tile", Tool.TILE)
	_tools_dropdown.add_item("Character", Tool.CHARACTER)
	_tools_dropdown.add_item("Block", Tool.BLOCK)
	_tools_dropdown.add_item("Link", Tool.LINK)

	_tools_dropdown.item_selected.connect(_on_tool_option_item_selected)
	_tools_dropdown.select(Tool.TILE)

	_on_tool_option_item_selected(Tool.TILE as int)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var world_position := get_global_mouse_position()

		if _place_tile_drag_button == MOUSE_BUTTON_LEFT:
			_place_tile(world_position)
		elif _place_tile_drag_button == MOUSE_BUTTON_RIGHT:
			_remove_tile(world_position)

		_refresh_selectable_indicator()
		return

	if event is InputEventMouseButton and not event.is_pressed():
		if event.button_index == _place_tile_drag_button:
			_place_tile_drag_button = MOUSE_BUTTON_NONE
		return

	if not event.is_pressed():
		return

	if event is InputEventMouseButton:
		var world_position := get_global_mouse_position()
		var input_event := event as InputEventMouseButton
		var mouse_button := input_event.button_index

		match _selected_tool:
			Tool.TILE:
				if mouse_button == MOUSE_BUTTON_LEFT:
					_place_tile_drag_button = mouse_button
					_place_tile(world_position)
				elif mouse_button == MOUSE_BUTTON_RIGHT:
					_place_tile_drag_button = mouse_button
					_remove_tile(world_position)

			Tool.CHARACTER:
				if mouse_button == MOUSE_BUTTON_LEFT:
					_place_character(world_position)
				elif mouse_button == MOUSE_BUTTON_RIGHT:
					_remove_character(world_position)

			Tool.BLOCK:
				if mouse_button == MOUSE_BUTTON_LEFT:
					_place_block(world_position)
				elif mouse_button == MOUSE_BUTTON_RIGHT:
					_remove_block(world_position)

			Tool.LINK:
				_on_link_tool_use(world_position, mouse_button)

	elif event is InputEventKey and not event.is_echo():
		var input_key_event := event as InputEventKey
		var key := input_key_event.keycode

		if _selected_tile != null:
			_handle_tile_keybinds(_selected_tile, key)

		elif _selected_entity is Character:
			var selected_character := _selected_entity as Character
			_handle_character_keybinds(selected_character, key)

		elif _selected_entity is Block:
			var selected_block := _selected_entity as Block
			_handle_block_keybinds(selected_block, key)

		elif _selected_link != null:
			_handle_link_keybinds(_selected_link, key)

func _handle_tile_keybinds(tile: Tile, key: Key) -> void:
	match key:
		KEY_G:
			tile.goal = not tile.goal
			_honeycomb.load(_state)

		KEY_PLUS, KEY_EQUAL:
			tile.height = min(max(tile.height + 1, -1), 1)
			_honeycomb.load(_state)
			_set_selected_tile(tile)
			_refresh_selectable_indicator()

		KEY_MINUS, KEY_UNDERSCORE:
			tile.height = min(max(tile.height - 1, -1), 1)
			_honeycomb.load(_state)
			_set_selected_tile(tile)
			_refresh_selectable_indicator()

		KEY_DELETE, KEY_BACKSPACE:
			var world_position := Hexagon.get_tile_world_position(tile.position, tile.height)
			_remove_tile(world_position)

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

		KEY_DELETE, KEY_BACKSPACE:
			var tile := character.current_tile
			var world_position := Hexagon.get_tile_world_position(tile.position, tile.height)
			_remove_character(world_position)

func _handle_block_keybinds(block: Block, key: Key) -> void:
	match key:
		KEY_DELETE, KEY_BACKSPACE:
			var tile := block.current_tile
			var world_position := Hexagon.get_tile_world_position(tile.position, tile.height)
			_remove_block(world_position)

func _handle_link_keybinds(link: Link, key: Key) -> void:
	match key:
		KEY_T:
			if link.entity_a is Character or link.entity_b is Character:
				return

			match link.type:
				Link.Type.SOLID:
					link.type = Link.Type.STICKY
				Link.Type.STICKY:
					link.type = Link.Type.SOLID

			_state.assign_block_clusters()
			_honeycomb.load(_state)

		KEY_DELETE, KEY_BACKSPACE:
			if link == _selected_link:
				_set_selected_link(null)

			_state.links.erase(link)
			link.entity_a.links.erase(link)
			link.entity_b.links.erase(link)

			if link.type == Link.Type.SOLID:
				_state.assign_block_clusters()

			_honeycomb.load(_state)

func _refresh_selectable_indicator() -> void:
	var world_position := get_global_mouse_position()
	var tile_position := _get_tile_position_at(world_position)

	match _selected_tool:
		Tool.TILE:
			_selectable_entity_indicator.visible = false
			_selectable_tile_indicator.visible = true

			var tile: Tile = _state.tiles.get(tile_position)
			if tile == null:
				_selectable_tile_indicator.display(Cell.Type.SELECTABLE, tile_position, 0)
				return

			_selectable_tile_indicator.display(Cell.Type.SELECTABLE, tile.position, tile.height)

		Tool.CHARACTER, Tool.BLOCK, Tool.LINK:
			_selectable_tile_indicator.visible = false

			var entity := _get_entity_at(tile_position)
			if (
				entity == null or
				(_selected_tool == Tool.CHARACTER and entity is Block) or
				(_selected_tool == Tool.BLOCK and entity is Character)
			):
				_selectable_entity_indicator.visible = false
				return

			_selectable_entity_indicator.visible = true

			var elevation := entity.get_elevation()
			var character_position := Hexagon.get_tile_world_position(tile_position, elevation)
			_selectable_entity_indicator.position = character_position

			_selectable_entity_indicator.z_index = Hexagon.get_tile_z_index(tile_position) + 4

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
	_set_selected_link(null)
	_refresh_selectable_indicator()

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
	if entity is Character:
		_remove_character(world_position)
	elif entity is Block:
		_remove_block(world_position)

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

	if character == _state.active_character:
		_state.active_character = null

	for link in character.links:
		_state.links.erase(link)

		var other_entity := link.other(character)
		other_entity.links.erase(link)

		if link.type == Link.Type.SOLID:
			_state.assign_block_clusters()

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

	for link in block.links:
		_state.links.erase(link)

		var other_entity := link.other(block)
		other_entity.links.erase(link)

		if link.type == Link.Type.SOLID:
			_state.assign_block_clusters()

	_state.entities.erase(block)
	_honeycomb.load(_state)

func _get_entity_at(tile_position: Vector2i) -> Entity:
	for entity in _state.entities:
		if entity.current_tile.position == tile_position:
			return entity
	return null

func _on_link_tool_use(world_position: Vector2, mouse_button: MouseButton) -> void:
	var tile_position := _get_tile_position_at(world_position)
	var entity := _get_entity_at(tile_position)

	if entity == null or entity == _selected_entity:
		_set_selected_entity(null)
		_set_selected_link(null)
		return

	if _selected_entity == null:
		_set_selected_entity(entity)
		_set_selected_link(null)
		return

	var tile_position_a := _selected_entity.current_tile.position
	var tile_position_b := entity.current_tile.position
	if not Hexagon.is_direction_vector(tile_position_b - tile_position_a):
		_set_selected_entity(entity)
		_set_selected_link(null)
		return

	var existing_link: Link = null
	for link in _state.links:
		if (link.entity_a == _selected_entity and link.entity_b == entity) \
		or (link.entity_b == _selected_entity and link.entity_a == entity):
			existing_link = link
			break

	if mouse_button == MOUSE_BUTTON_LEFT:
		if existing_link == null:
			existing_link = Link.new(Link.Type.STICKY, _selected_entity, entity)
			_state.links.append(existing_link)
			_selected_entity.links.append(existing_link)
			entity.links.append(existing_link)
			_honeycomb.load(_state)

		_set_selected_entity(null)
		_set_selected_link(existing_link)

	elif mouse_button == MOUSE_BUTTON_RIGHT and existing_link != null:
		if existing_link == _selected_link:
			_set_selected_link(null)

		_state.links.erase(existing_link)
		existing_link.entity_a.links.erase(existing_link)
		existing_link.entity_b.links.erase(existing_link)

		if existing_link.type == Link.Type.SOLID:
			_state.assign_block_clusters()

		_honeycomb.load(_state)

	_set_selected_entity(null)

func _set_selected_link(selected_link: Link) -> void:
	_selected_link = selected_link

	if _selected_link == null:
		_selected_link_indicator.visible = false
		return

	_selected_link_indicator.visible = true

	var entity_a := _selected_link.entity_a
	var entity_b := _selected_link.entity_b

	var tile_position_a := entity_a.current_tile.position
	var tile_position_b := entity_b.current_tile.position

	var elevation_a := entity_a.get_elevation()
	var elevation_b := entity_b.get_elevation()

	var world_position_a := Hexagon.get_tile_world_position(tile_position_a, elevation_a)
	var world_position_b := Hexagon.get_tile_world_position(tile_position_b, elevation_b)

	_selected_link_indicator.position = (world_position_a + world_position_b) / 2.0
	_selected_link_indicator.rotation = (world_position_b - world_position_a).angle()

	var z_index_a := Hexagon.get_tile_z_index(tile_position_a)
	var z_index_b := Hexagon.get_tile_z_index(tile_position_b)

	_selected_link_indicator.z_index = max(z_index_a, z_index_b) + 4
