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

static func try_move_entity(state: State, entity: Entity, direction: Hexagon.Direction) -> bool:
	var current_tile := entity.current_tile

	var target_position := current_tile.position + Hexagon.get_direction_vector(direction)
	var target_tile: Tile = state.tiles.get(target_position)
	if target_tile == null:
		return false

	if entity is Block:
		# Blocks cannot be pushed upwards
		if target_tile.height > current_tile.height:
			return false

	for other_entity in state.entities:
		if other_entity == entity:
			continue

		if other_entity.current_tile == target_tile:
			if try_move_entity(state, other_entity, direction):
				entity.current_tile = target_tile
				return true
			else:
				return false

	entity.current_tile = target_tile
	return true

static func rotate_character_left(character: Character) -> void:
	character.facing_direction = Hexagon.get_direction_turned_left(character.facing_direction)

static func rotate_character_right(character: Character) -> void:
	character.facing_direction = Hexagon.get_direction_turned_right(character.facing_direction)

static func select_character(state: State, character: Character) -> bool:
	if character == state.active_character:
		return false

	state.active_character = character
	return true