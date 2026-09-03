class_name State


var tiles: Dictionary[Vector2i, Tile] = {}
var entities: Array[Entity] = []
var links: Array[Link] = []

var characters: Array[Character] = []
var active_character: Character = null


func assign_clusters() -> void:
	for entity in entities:
		entity.cluster = Cluster.new()

	for entity in entities:
		if entity is Character:
			entity.cluster.entities.append(entity)
			continue

		if entity is Block:
			var block: Block = entity
			if not block.cluster.entities.is_empty():
				continue

			var queue: Array[Block] = [block]

			while not queue.is_empty():
				var current_block: Block = queue.pop_back()
				if block.cluster.entities.has(current_block):
					continue

				block.cluster.entities.append(current_block)

				for link in current_block.links:
					if link.type == Link.Type.SOLID:
						var connected_block: Block = link.other(current_block)
						queue.push_back(connected_block)

			for connected_block in block.cluster.entities:
				connected_block.cluster = block.cluster

			continue


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
