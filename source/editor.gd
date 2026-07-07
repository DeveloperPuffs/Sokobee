class_name Editor
extends Node2D


signal exited_editor

enum Tool {
	VIEW,
	CELL,
	BEE,
	HONEY,
	HEIGHT,
}

@export var _preview_cell: Cell
@export var _honeycomb: Honeycomb
@export var _tools_dropdown: OptionButton

var _state: State
var _selected_tool: Tool

func _ready() -> void:
	_state = Loader.load_level_state("res://assets/levels/default.json")
	if _state == null:
		exited_editor.emit()
		return

	_honeycomb.load(_state)

	_tools_dropdown.add_item("View", Tool.VIEW)
	_tools_dropdown.add_item("Cell", Tool.CELL)
	_tools_dropdown.add_item("Bee", Tool.BEE)
	_tools_dropdown.add_item("Honey", Tool.HONEY)
	_tools_dropdown.add_item("Height", Tool.HEIGHT)

	_tools_dropdown.item_selected.connect(_on_tool_option_item_selected)

func _process(_delta: float) -> void:
	var world_position := get_global_mouse_position()
	var tile_position := Hexagon.get_world_tile_position(world_position)

	var tile: Tile = _state.tiles.get(tile_position)
	var tile_height := 0 if tile == null else tile.height
	_preview_cell.display(Cell.Type.PREVIEW, tile_position, tile_height)

func _on_tool_option_item_selected(index: int):
	_selected_tool = _tools_dropdown.get_item_id(index) as Tool
