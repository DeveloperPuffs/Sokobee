class_name Logic


static func win_check(state: State) -> bool:
	var block_positions: Array[Vector2i] = []
	for entity in state.entities:
		if is_instance_of(entity, Block):
			block_positions.append(entity.tile_position)

	for tile_position: Vector2i in state.tiles.keys():
		var tile_type := state.tiles[tile_position]
		if tile_type == State.TileType.TILE_GOAL:
			if not block_positions.has(tile_position):
				return false	

	return true

static func try_move_entity(state: State, entity: Entity, direction: Hexagon.Direction) -> bool:
	var target_position := entity.tile_position + Hexagon.get_direction_vector(direction)
	if not state.tiles.has(target_position):
		return false

	for other_entity in state.entities:
		if other_entity == entity:
			continue

		if other_entity.tile_position == target_position:
			if try_move_entity(state, other_entity, direction):
				entity.tile_position = target_position
				return true
			else:
				return false

	entity.tile_position = target_position
	return true

static func rotate_character_left(character: Character) -> void:
	character.facing_direction = Hexagon.get_direction_turned_left(character.facing_direction)

static func rotate_character_right(character: Character) -> void:
	character.facing_direction = Hexagon.get_direction_turned_right(character.facing_direction)