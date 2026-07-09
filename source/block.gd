class_name Block
extends Entity


var cluster: Array[Block]

func _init(_current_tile: Tile) -> void:
	super._init(_current_tile)
	cluster = []

func get_elevation() -> int:
	var maximum_elevation := super.get_elevation()
	for connected_block in cluster:
		if connected_block == self:
			continue

		var connected_block_elevation := connected_block.current_tile.height
		maximum_elevation = max(maximum_elevation, connected_block_elevation)

	return maximum_elevation
