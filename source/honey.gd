class_name Honey
extends Sprite2D


var _block: Block

func _process(_delta: float) -> void:
	var current_tile := _block.current_tile
	position = Hexagon.get_tile_world_position(current_tile.position, _block.get_elevation())
	z_index = Hexagon.get_tile_z_index(current_tile.position) + 2

func initialize(block: Block) -> void:
	_block = block