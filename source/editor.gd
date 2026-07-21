class_name Editor
extends Node2D


"""

Editor Controls

Tile Tool:
Left Click to Place Tile
Right Click to Remove Tile
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

@export var _controller: Controller
@export var _honeycomb: Honeycomb
@export var _playtest_button: Button
@export var _tool_selector_dropdown: OptionButton
@export var _edit_button: Button
@export var _keep_layout_button: Button

var _state: State
var _selected_tool: Tool
var _selected_element: Variant = null # Tile, Entity, Link, or null
var _clusters_are_dirty: bool = false
var _honeycomb_is_dirty: bool = false
var _playtesting: bool = false
var _snapshot: Snapshot = null


func _ready() -> void:
	_state = Loader.load_level_state("res://assets/levels/default.json")
	if _state == null:
		exited_editor.emit()
		return

	_honeycomb.load(_state)

	_controller.restart_requested.connect(_on_restart_requested)

	_tool_selector_dropdown.add_item("Tile", Tool.TILE)
	_tool_selector_dropdown.add_item("Character", Tool.CHARACTER)
	_tool_selector_dropdown.add_item("Block", Tool.BLOCK)
	_tool_selector_dropdown.add_item("Link", Tool.LINK)

	_tool_selector_dropdown.item_selected.connect(_on_tool_option_item_selected)

	_playtest_button.pressed.connect(_toggle_playtesting)
	_edit_button.pressed.connect(_toggle_playtesting)
	_keep_layout_button.pressed.connect(_on_keep_layout)

	_toggle_playtesting(false)
	_tool_selector_dropdown.select(Tool.TILE)
	_on_tool_option_item_selected(Tool.TILE as int)


func _process(_delta: float) -> void:
	if _clusters_are_dirty:
		_state.assign_block_clusters()
		_clusters_are_dirty = false

	if _honeycomb_is_dirty:
		_honeycomb.load(_state)
		_honeycomb_is_dirty = false


func _unhandled_input(event: InputEvent) -> void:
	if _playtesting:
		return

	if event is InputEventMouseMotion:
		_refresh_selectable_indicator()

	if event is InputEventMouseButton and event.is_pressed():
		var input_event := event as InputEventMouseButton
		_handle_mouse_click(input_event.button_index)

	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var input_key_event := event as InputEventKey
		_handle_key_press(input_key_event.keycode)


func _toggle_playtesting(playtesting: bool = not _playtesting) -> void:
	_playtesting = playtesting

	_playtest_button.visible = not playtesting
	_tool_selector_dropdown.visible = not playtesting
	_edit_button.visible = playtesting
	_keep_layout_button.visible = playtesting

	if playtesting:
		_refresh_selectable_indicator()
		_set_selected_element(null)

		_snapshot = Snapshot.new(_state)
		_controller.load(_state)

	else:
		if _snapshot != null:
			_snapshot.apply(_state)
			_snapshot = null

		_refresh_selectable_indicator()

	_controller.set_active(playtesting)


func _on_restart_requested() -> void:
	_snapshot.apply(_state)
	_controller.load(_state)


func _on_keep_layout() -> void:
	_snapshot = null
	_toggle_playtesting(false)


func _handle_mouse_click(mouse_button: MouseButton) -> void:
	var world_position := get_global_mouse_position()
	var tile_position := _get_tile_position_at(world_position)
	var tile: Tile = _state.tiles.get(tile_position)

	if _selected_tool == Tool.TILE:
		if mouse_button == MOUSE_BUTTON_LEFT:
			if tile == null:
				tile = Tile.new(tile_position, false, 0)
				_state.tiles[tile_position] = tile
				_honeycomb_is_dirty = true

			_set_selected_element(tile)

		elif mouse_button == MOUSE_BUTTON_RIGHT and tile != null:
			_remove_tile(tile)

		return

	var entity := _get_entity_at(tile_position)

	if _selected_tool == Tool.LINK:
		if entity == null or entity == _selected_element:
			_set_selected_element(null)
			return

		if _selected_element is not Entity:
			_set_selected_element(entity)
			return

		var selected_entity := _selected_element as Entity

		var tile_position_a := selected_entity.current_tile.position
		var tile_position_b := entity.current_tile.position
		if not Hexagon.is_direction_vector(tile_position_b - tile_position_a):
			_set_selected_element(entity)
			return

		var existing_link: Link = null
		for link in _state.links:
			if (link.entity_a == selected_entity and link.entity_b == entity) \
			or (link.entity_b == selected_entity and link.entity_a == entity):
				existing_link = link
				break

		if mouse_button == MOUSE_BUTTON_LEFT:
			if existing_link == null:
				existing_link = Link.new(Link.Type.STICKY, selected_entity, entity)
				_state.links.append(existing_link)
				selected_entity.links.append(existing_link)
				entity.links.append(existing_link)
				_honeycomb_is_dirty = true

			_set_selected_element(existing_link)
			return

		elif mouse_button == MOUSE_BUTTON_RIGHT and existing_link != null:
			_remove_link(existing_link)

		_set_selected_element(null)
		return

	if tile == null:
		return

	if _selected_tool == Tool.CHARACTER:
		if entity is Block:
			return

		var character := entity as Character

		if mouse_button == MOUSE_BUTTON_LEFT:
			if character == null:
				character = Character.new(tile, Hexagon.Direction.TOP_CENTER, false)
				_state.entities.append(character)
				_state.characters.append(character)
				_honeycomb_is_dirty = true

			_set_selected_element(character)

		elif mouse_button == MOUSE_BUTTON_RIGHT and character != null:
			_remove_character(character)
	
		return

	if _selected_tool == Tool.BLOCK:
		if entity is Character:
			return

		var block := entity as Block

		if mouse_button == MOUSE_BUTTON_LEFT:
			if block == null:
				block = Block.new(tile)
				_state.entities.append(block)
				_honeycomb_is_dirty = true

			_set_selected_element(block)

		elif mouse_button == MOUSE_BUTTON_RIGHT and block != null:
			_remove_block(block)

		return


func _handle_key_press(key: Key) -> void:
	if _selected_element is Tile:
		var selected_tile := _selected_element as Tile

		match key:
			KEY_G:
				selected_tile.goal = not selected_tile.goal
				_honeycomb_is_dirty = true

			KEY_PLUS, KEY_EQUAL:
				selected_tile.height = min(max(selected_tile.height + 1, -1), 1)
				_honeycomb_is_dirty = true
				_set_selected_element(selected_tile)
				_refresh_selectable_indicator()

			KEY_MINUS, KEY_UNDERSCORE:
				selected_tile.height = min(max(selected_tile.height - 1, -1), 1)
				_honeycomb_is_dirty = true
				_set_selected_element(selected_tile)
				_refresh_selectable_indicator()

			KEY_DELETE, KEY_BACKSPACE:
				_remove_tile(selected_tile)

	elif _selected_element is Character:
		var selected_character := _selected_element as Character
		match key:
			KEY_C:
				_state.active_character = selected_character

			KEY_A, KEY_LEFT:
				var new_direction := Hexagon.get_direction_turned_left(selected_character.facing_direction)
				selected_character.facing_direction = new_direction

			KEY_D, KEY_RIGHT:
				var new_direction := Hexagon.get_direction_turned_right(selected_character.facing_direction)
				selected_character.facing_direction = new_direction

			KEY_S:
				selected_character.asleep = not selected_character.asleep
				_honeycomb_is_dirty = true

			KEY_DELETE, KEY_BACKSPACE:
				_remove_character(selected_character)

	elif _selected_element is Block:
		var selected_block := _selected_element as Block
		match key:
			KEY_DELETE, KEY_BACKSPACE:
				_remove_block(selected_block)

	elif _selected_element is Link:
		var selected_link := _selected_element as Link
		match key:
			KEY_T:
				if selected_link.entity_a is Character or selected_link.entity_b is Character:
					return

				match selected_link.type:
					Link.Type.SOLID:
						selected_link.type = Link.Type.STICKY
					Link.Type.STICKY:
						selected_link.type = Link.Type.SOLID

				_clusters_are_dirty = true
				_honeycomb_is_dirty = true

			KEY_DELETE, KEY_BACKSPACE:
				_set_selected_element(null)
				_remove_link(selected_link)


func _refresh_selectable_indicator() -> void:
	if _playtesting:
		_selectable_tile_indicator.visible = false
		_selectable_entity_indicator.visible = false
		return

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
	var tile := _state.get_tile_at(world_position)
	if tile != null:
		return tile.position
	return Hexagon.get_world_tile_position(world_position)


func _set_selected_element(selected_element: Variant) -> void:
	_selected_element = selected_element

	_selected_tile_indicator.visible = selected_element is Tile
	_selected_entity_indicator.visible = selected_element is Entity
	_selected_link_indicator.visible = selected_element is Link

	if selected_element is Tile:
		var selected_tile := selected_element as Tile
		var cell_position := selected_tile.position
		var cell_height := selected_tile.height
		_selected_tile_indicator.display(Cell.Type.SELECTED, cell_position, cell_height)

	elif selected_element is Entity:
		var selected_entity := selected_element as Entity
		var tile_position := selected_entity.current_tile.position
		var elevation := selected_entity.get_elevation()
		_selected_entity_indicator.position = Hexagon.get_tile_world_position(tile_position, elevation)
		_selected_entity_indicator.z_index = Hexagon.get_tile_z_index(tile_position) + 3

	elif selected_element is Link:
		var selected_link := selected_element as Link

		var tile_position_a := selected_link.entity_a.current_tile.position
		var tile_position_b := selected_link.entity_b.current_tile.position

		var elevation_a := selected_link.entity_a.get_elevation()
		var elevation_b := selected_link.entity_b.get_elevation()

		var world_position_a := Hexagon.get_tile_world_position(tile_position_a, elevation_a)
		var world_position_b := Hexagon.get_tile_world_position(tile_position_b, elevation_b)

		var z_index_a := Hexagon.get_tile_z_index(tile_position_a)
		var z_index_b := Hexagon.get_tile_z_index(tile_position_b)

		_selected_link_indicator.position = (world_position_a + world_position_b) / 2.0
		_selected_link_indicator.rotation = (world_position_b - world_position_a).angle()
		_selected_link_indicator.z_index = max(z_index_a, z_index_b) + 4


func _on_tool_option_item_selected(index: int) -> void:
	_selected_tool = _tool_selector_dropdown.get_item_id(index) as Tool
	_set_selected_element(null)
	_refresh_selectable_indicator()


func _remove_tile(tile: Tile) -> void:
	if tile == _selected_element:
		_set_selected_element(null)

	var entity := _get_entity_at(tile.position)
	if entity is Character:
		_remove_character(entity as Character)
	elif entity is Block:
		_remove_block(entity as Block)

	_state.tiles.erase(tile.position)
	_honeycomb_is_dirty = true


func _remove_character(character: Character) -> void:
	if character == _selected_element:
		_set_selected_element(null)

	if character == _state.active_character:
		_state.active_character = null

	for link in character.links.duplicate():
		_remove_link(link)

	_state.entities.erase(character)
	_state.characters.erase(character)
	_honeycomb_is_dirty = true


func _remove_block(block: Block) -> void:
	if block == _selected_element:
		_set_selected_element(null)

	for link in block.links.duplicate():
		_remove_link(link)

	_state.entities.erase(block)
	_honeycomb_is_dirty = true


func _remove_link(link: Link) -> void:
	_state.links.erase(link)
	link.entity_a.links.erase(link)
	link.entity_b.links.erase(link)

	if link.type == Link.Type.SOLID:
		_clusters_are_dirty = true

	_honeycomb_is_dirty = true


func _get_entity_at(tile_position: Vector2i) -> Entity:
	for entity in _state.entities:
		if entity.current_tile.position == tile_position:
			return entity
	return null
