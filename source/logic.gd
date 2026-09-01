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
	if character.asleep:
		return false

	var direction_vector := Hexagon.get_direction_vector(direction)

	var queued_entities: Array[Entity] = []

	var entity_target_tiles: Dictionary[Entity, Tile] = {}
	var entity_movements: Dictionary[Entity, Entity.Movement] = {}

	queued_entities.append(character)

	var character_movement := Entity.Movement.new(Entity.Movement.Kind.WALKING)
	entity_movements[character] = character_movement

	while not queued_entities.is_empty():
		var entity: Entity = queued_entities.pop_front()
		if entity_target_tiles.has(entity):
			continue

		var movement := entity_movements[entity]
		var elevation := entity.get_elevation()

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

			entity_target_tiles[connected_entity] = target_tile
			if not entity_movements.has(connected_entity):
				entity_movements[connected_entity] = movement

			for link in connected_entity.links:
				if link.type != Link.Type.STICKY:
					continue

				var other_entity := link.other(connected_entity)
				if entity_target_tiles.has(other_entity):
					continue

				var new_offset := target_position - other_entity.current_tile.position
				if Hexagon.is_direction_vector(new_offset):
					continue

				queued_entities.append(other_entity)

				if not entity_movements.has(other_entity):
					var offset := other_entity.current_tile.position - connected_entity.current_tile.position
					var world_offset := Hexagon.get_tile_world_position(offset, 0)
					var world_direction := Hexagon.get_tile_world_position(direction_vector, 0)
					var blocking := world_offset.dot(world_direction) > 0.0

					entity_movements[other_entity] = Entity.Movement.new(
						Entity.Movement.Kind.CARRIED,
						movement.dragging_delay_count + (0 if blocking else 1),
						movement.blocking_delay_count + (1 if blocking else 0),
					)

			# Search for a potential blocker that occupying the target position
			for other_entity in state.entities:
				if other_entity == connected_entity or entity_target_tiles.has(other_entity):
					continue

				if other_entity.current_tile == target_tile:
					queued_entities.append(other_entity)

					if not entity_movements.has(other_entity):
						entity_movements[other_entity] = Entity.Movement.new(
							Entity.Movement.Kind.CARRIED,
							movement.dragging_delay_count,
							movement.blocking_delay_count + 1,
						)

					break

	if entity_target_tiles.size() > 1:
		character_movement.kind = Entity.Movement.Kind.INITIATOR

	var previous_tiles: Dictionary[Entity, Tile] = {}
	for entity in entity_target_tiles:
		previous_tiles[entity] = entity.current_tile
		entity.current_tile = entity_target_tiles[entity]

	for entity in entity_target_tiles:
		entity.moved.emit(previous_tiles[entity], entity.current_tile, entity_movements[entity])

	return true


static func rotate_character_left(character: Character) -> void:
	if character.asleep:
		return

	character.facing_direction = Hexagon.get_direction_turned_left(character.facing_direction)


static func rotate_character_right(character: Character) -> void:
	if character.asleep:
		return

	character.facing_direction = Hexagon.get_direction_turned_right(character.facing_direction)


static func select_character(state: State, character: Character) -> bool:
	if character == state.active_character:
		return false

	if character.asleep:
		return false

	state.active_character = character
	return true
