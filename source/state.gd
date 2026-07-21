class_name State


var tiles: Dictionary[Vector2i, Tile] = {}
var entities: Array[Entity] = []
var links: Array[Link] = []

var characters: Array[Character] = []
var active_character: Character = null


func assign_block_clusters() -> void:
	for entity in entities:
		if entity is Block:
			var block := entity as Block
			block.cluster = []

	for entity in entities:
		if not (entity is Block):
			continue

		var block := entity as Block
		if not block.cluster.is_empty():
			continue

		var cluster: Array[Block] = []
		var queue: Array[Block] = [block]

		while not queue.is_empty():
			var current: Block = queue.pop_back()
			if cluster.has(current):
				continue

			cluster.append(current)

			for link in current.links:
				if link.type == Link.Type.SOLID:
					queue.push_back(link.other(current) as Block)

		for member in cluster:
			member.cluster = cluster


func get_tile_at(world_position: Vector2) -> Tile:
	var frontmost_tile: Tile = null
	var frontmost_z_index := 0

	for tile: Tile in tiles.values():
		if not Hexagon.check_point_tile_interesection(world_position, tile.position, tile.height):
			continue

		var tile_z_index := Hexagon.get_tile_z_index(tile.position)
		if frontmost_tile == null or tile_z_index > frontmost_z_index:
			frontmost_z_index = tile_z_index
			frontmost_tile = tile

	return frontmost_tile
