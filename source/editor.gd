class_name Editor
extends Node2D


"""

Editor Controls

Selected Tile:
	[G] Toggle 'goal' Property
	[+] Increase Height
	[-] Decrease Height

Place Cell Tool:
Left Click to Place Cell
Right Click to Remove Cell

"""

signal exited_editor

enum Tool {
	VIEW,
	SELECT,
	PLACE_CELL,
	PLACE_BEE,
	PLACE_HONEY,
}

@export var _preview_cell: Cell
@export var _selected_cell: Cell
@export var _honeycomb: Honeycomb
@export var _tools_dropdown: OptionButton

var _state: State
var _selected_tool: Tool
var _selected_tile: Tile

func _ready() -> void:
	_state = Loader.load_level_state("res://assets/levels/default.json")
	if _state == null:
		exited_editor.emit()
		return

	_honeycomb.load(_state)

	_tools_dropdown.add_item("View", Tool.VIEW)
	_tools_dropdown.add_item("Select", Tool.SELECT)
	_tools_dropdown.add_item("Place Cell", Tool.PLACE_CELL)
	_tools_dropdown.add_item("Place Bee", Tool.PLACE_BEE)
	_tools_dropdown.add_item("Place Honey", Tool.PLACE_HONEY)

	_tools_dropdown.item_selected.connect(_on_tool_option_item_selected)
	_tools_dropdown.select(Tool.VIEW)

	_display_selected_tile(null)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var world_position := get_global_mouse_position()

		var tile := _honeycomb.get_tile_at(world_position)
		if tile == null:
			var tile_position := Hexagon.get_world_tile_position(world_position)

			tile = _state.tiles.get(tile_position)
			if tile == null:
				_preview_cell.display(Cell.Type.PREVIEW, tile_position, 0)
				return

		_preview_cell.display(Cell.Type.PREVIEW, tile.position, tile.height)
		return
		
	if not event.is_pressed():
		return

	if event is InputEventMouseButton:
		var world_position := get_global_mouse_position()

		match _selected_tool:
			Tool.SELECT:
				_on_select_tool_use(world_position, event.button_index)
			Tool.PLACE_CELL:
				_on_place_cell_tool_use(world_position, event.button_index)
			Tool.PLACE_BEE:
				pass
			Tool.PLACE_HONEY:
				pass

	elif event is InputEventKey and not event.is_echo():
		if _selected_tile == null:
			return

		match event.keycode:
			KEY_G:
				_selected_tile.goal = not _selected_tile.goal
				_honeycomb.load(_state)

			KEY_PLUS, KEY_EQUAL:
				_selected_tile.height = min(max(_selected_tile.height + 1, -1), 1)
				_honeycomb.load(_state)
				_display_selected_tile(_selected_tile)

			KEY_MINUS, KEY_UNDERSCORE:
				_selected_tile.height = min(max(_selected_tile.height - 1, -1), 1)
				_honeycomb.load(_state)
				_display_selected_tile(_selected_tile)

func _display_selected_tile(selected_tile: Tile) -> void:
	_selected_tile = selected_tile

	if _selected_tile == null:
		_selected_cell.visible = false
		return

	_selected_cell.visible = true
	_selected_cell.display(Cell.Type.SELECTED, _selected_tile.position, _selected_tile.height)

func _on_tool_option_item_selected(index: int) -> void:
	_selected_tool = _tools_dropdown.get_item_id(index) as Tool
	_display_selected_tile(null)

func _on_select_tool_use(world_position: Vector2i, mouse_button: MouseButton) -> void:
	if mouse_button != MouseButton.MOUSE_BUTTON_LEFT:
		return

	var tile_position := Hexagon.get_world_tile_position(world_position)
	var tile: Tile = _state.tiles.get(tile_position)
	_display_selected_tile(tile)

func _on_place_cell_tool_use(world_position: Vector2i, mouse_button: MouseButton) -> void:
	var tile_position := Hexagon.get_world_tile_position(world_position)
	var tile: Tile = _state.tiles.get(tile_position)

	if mouse_button == MouseButton.MOUSE_BUTTON_LEFT:
		if tile == null:
			tile = Tile.new(tile_position, false, 0)
			_state.tiles[tile_position] = tile
			_honeycomb.load(_state)
		_display_selected_tile(tile)
	elif mouse_button == MouseButton.MOUSE_BUTTON_RIGHT:
		if tile != null:
			if tile == _selected_tile:
				_display_selected_tile(null)
			_state.tiles.erase(tile_position)
			_honeycomb.load(_state)