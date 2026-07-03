class_name Loader


static func load_level_state(level_data_file_path: String) -> Variant:
	var level_data_string := FileAccess.get_file_as_string(level_data_file_path)

	var json := JSON.new()
	if json.parse(level_data_string) != OK:
		return null

	var state := State.new()

	for tile in json.data["tiles"]:
		var tile_position := Vector2i(tile["q"], tile["r"])
		var tile_type: State.TileType = _tile_type_from_string(tile["type"])
		state.tiles[tile_position] = tile_type

	for entity in json.data["entities"]:
		var tile_position = Vector2i(entity["q"], entity["r"])
		match entity["type"]:
			"character":
				var facing_direction: Hexagon.Direction = _direction_from_string(entity["facing"])
				var character := Character.new(tile_position, facing_direction)
				state.entities.append(character)
				state.characters.append(character)
			"block":
				var block := Block.new(tile_position)
				state.entities.append(block)

	state.active_character = state.characters[0]

	return state

static func _tile_type_from_string(tile_type_string: String) -> Variant:
	match tile_type_string:
		"TILE_FLOOR":
			return State.TileType.TILE_FLOOR
		"TILE_GOAL":
			return State.TileType.TILE_GOAL
		_:
			return null

static func _direction_from_string(direction_string: String) -> Variant:
	match direction_string:
		"BOTTOM_RIGHT":
			return Hexagon.Direction.BOTTOM_RIGHT
		"BOTTOM_CENTER":
			return Hexagon.Direction.BOTTOM_CENTER
		"BOTTOM_LEFT":
			return Hexagon.Direction.BOTTOM_LEFT
		"TOP_LEFT":
			return Hexagon.Direction.TOP_LEFT
		"TOP_CENTER":
			return Hexagon.Direction.TOP_CENTER
		"TOP_RIGHT":
			return Hexagon.Direction.TOP_RIGHT
		_:
			return null