class_name Logic


static func win_check(state: State) -> bool:
	var block_positions: Array[Vector2i] = []
	for entity in state.entities:
		if is_instance_of(entity, Block):
			block_positions.append(entity.current_tile.position)

	for tile: Tile in state.tiles.values():
		if not tile.goal:
			continue

		if not block_positions.has(tile.position):
			return false	

	return true


static func try_move_character(state: State, character: Character, direction: Hexagon.Direction) -> bool:
	var direction_vector := Hexagon.get_direction_vector(direction)

	var moving_entities: Dictionary[Entity, Tile] = {}
	var queued_entities: Array[Entity] = []

	queued_entities.append(character)
	while not queued_entities.is_empty():
		var entity = queued_entities.pop_back()
		if moving_entities.has(entity):
			continue

		var elevation = entity.get_elevation()

		var cluster: Array[Entity] = []
		if entity is Block:
			var block := entity as Block
			cluster.append_array(block.cluster)
		elif entity is Character:
			cluster.append(entity)

		for connected_entity in cluster:
			var target_position := connected_entity.current_tile.position + direction_vector
			var target_tile: Tile = state.tiles.get(target_position)
			if target_tile == null:
				return false

			if connected_entity is Block:
				# Blocks cannot be pushed upwards
				if target_tile.height > elevation:
					return false

			if connected_entity is Character:
				var connected_character := connected_entity as Character
				if connected_character.asleep:
					# Sleeping characters cannot be pushed upwards
					if target_tile.height > elevation:
						return false

			moving_entities[connected_entity] = target_tile

			for link in connected_entity.links:
				if link.type != Link.Type.STICKY:
					continue

				var other_entity := link.other(connected_entity)
				if moving_entities.has(other_entity):
					continue

				var new_offset := target_position - other_entity.current_tile.position
				if not Hexagon.is_direction_vector(new_offset):
					queued_entities.append(other_entity)

			# Search for a potential blocker that occupying the target position
			for other_entity in state.entities:
				if other_entity == connected_entity or moving_entities.has(other_entity):
					continue

				if other_entity.current_tile == target_tile:
					queued_entities.append(other_entity)
					break

	for moving_entity in moving_entities:
		moving_entity.current_tile = moving_entities[moving_entity]

	return true


static func rotate_character_left(character: Character) -> void:
	character.facing_direction = Hexagon.get_direction_turned_left(character.facing_direction)


static func rotate_character_right(character: Character) -> void:
	character.facing_direction = Hexagon.get_direction_turned_right(character.facing_direction)


static func select_character(state: State, character: Character) -> bool:
	if character == state.active_character:
		return false

	if character.asleep:
		return false

	state.active_character = character
	return true
