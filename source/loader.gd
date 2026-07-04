class_name Loader


static func load_level_state(level_data_file_path: String) -> Variant:
	var level_data_string := FileAccess.get_file_as_string(level_data_file_path)

	var json := JSON.new()
	if json.parse(level_data_string) != OK:
		return null

	var state := State.new()

	for tile: Dictionary in json.data["tiles"]:
		var tile_position := Vector2i(tile["q"], tile["r"])
		var goal: bool = tile.get("goal", false)
		var height: int = tile.get("height", 0)
		state.tiles[tile_position] = Tile.new(tile_position, goal, height)

	for entity in json.data["entities"]:
		var tile_position = Vector2i(entity["q"], entity["r"])
		var tile := state.tiles[tile_position]
		match entity["type"]:
			"character":
				var facing_direction: Hexagon.Direction = _direction_from_string(entity["facing"])
				var character := Character.new(tile, facing_direction)
				state.entities.append(character)
				state.characters.append(character)
			"block":
				var block := Block.new(tile)
				state.entities.append(block)

	state.active_character = state.characters[0]

	return state

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