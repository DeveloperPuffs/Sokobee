class_name Honey
extends Sprite2D


var _block: Block


func initialize(block: Block) -> void:
	_block = block

	_block.tile_changed.connect(func(_previous_tile: Tile, current_tile: Tile) -> void:
		_set_current_tile(current_tile)
	)

	_set_current_tile(_block.current_tile, false)


func _set_current_tile(tile: Tile, animate: bool = true) -> void:
	var tile_position := tile.position
	z_index = Hexagon.get_tile_z_index(tile_position) + 2

	var target_position := Hexagon.get_tile_world_position(tile_position, _block.get_elevation())

	if not animate:
		position = target_position
		return

	var movement_tween := create_tween()
	movement_tween.tween_property(self, ^":position", target_position, 0.2)
