class_name Serializer


static func load_level(level_data: Dictionary) -> State:
	var state := State.new()

	for tile: Dictionary in level_data["tiles"]:
		var tile_position := Vector2i(tile["q"], tile["r"])
		var goal: bool = tile.get("goal", false)
		var height: int = tile.get("height", 0)
		state.tiles[tile_position] = Tile.new(tile_position, goal, height)

	var identifiable_entities: Dictionary[int, Entity] = {}

	for entity_data: Dictionary in level_data["entities"]:
		var tile_position = Vector2i(entity_data["q"], entity_data["r"])
		var tile := state.tiles[tile_position]

		var entity: Entity

		match entity_data["type"]:
			"character":
				var direction_string: String = entity_data["facing"]
				var facing_direction: Hexagon.Direction = _direction_from_string(direction_string)
				var asleep: bool = entity_data.get("asleep", false)

				var character := Character.new(tile, facing_direction, asleep)
				state.characters.append(character)
				entity = character

			"block":
				var block := Block.new(tile)
				entity = block

		state.entities.append(entity)

		var identifier: int = entity_data.get("identifier", -1)
		if identifier != -1:
			identifiable_entities[identifier] = entity

	for link_data: Dictionary in level_data["links"]:
		var link_type: Link.Type = _link_type_from_string(link_data["type"])

		var identifier_a: int = link_data["identifier_a"]
		var identifier_b: int = link_data["identifier_b"]

		var entity_a := identifiable_entities[identifier_a]
		var entity_b := identifiable_entities[identifier_b]

		var link := Link.new(link_type, entity_a, entity_b)
		state.links.append(link)

		entity_a.links.append(link)
		entity_b.links.append(link)

	state.assign_block_clusters()

	var active_character_identifier: int = level_data.get("active", -1)
	if active_character_identifier != -1:
		state.active_character = identifiable_entities[active_character_identifier]

	return state


static func _save_level(state: State) -> Dictionary:
	var identifiers: Dictionary[Entity, int] = {}
	var next_identifier := 0

	for entity in state.entities:
		if entity.links.is_empty() and entity != state.active_character:
			continue

		identifiers[entity] = next_identifier
		next_identifier += 1

	var tiles_data: Array[Dictionary] = []
	for tile: Tile in state.tiles.values():
		var tile_data := {}

		tile_data["q"] = tile.position.x
		tile_data["r"] = tile.position.y

		if tile.goal:
			tile_data["goal"] = true

		if tile.height != 0:
			tile_data["height"] = tile.height

		tiles_data.append(tile_data)

	var entities_data: Array[Dictionary] = []
	for entity in state.entities:
		var entity_data := {}

		if entity is Character:
			var character := entity as Character
			entity_data["type"] = "character"
			entity_data["q"] = character.current_tile.position.x
			entity_data["r"] = character.current_tile.position.y
			entity_data["facing"] = _direction_to_string(character.facing_direction)

			if character.asleep:
				entity_data["asleep"] = true

		elif entity is Block:
			var block := entity as Block
			entity_data["type"] = "block"
			entity_data["q"] = block.current_tile.position.x
			entity_data["r"] = block.current_tile.position.y

		if identifiers.has(entity):
			entity_data["identifier"] = identifiers[entity]

		entities_data.append(entity_data)

	var links_data: Array[Dictionary] = []
	for link in state.links:
		var link_data := {}

		link_data["type"] = _link_type_to_string(link.type)
		link_data["identifier_a"] = identifiers[link.entity_a]
		link_data["identifier_b"] = identifiers[link.entity_b]

		links_data.append(link_data)

	var level_data := {}

	level_data["tiles"] = tiles_data
	level_data["entities"] = entities_data
	level_data["links"] = links_data

	if state.active_character != null:
		level_data["active"] = identifiers[state.active_character]

	return level_data


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


static func _direction_to_string(direction: Hexagon.Direction) -> String:
	match direction:
		Hexagon.Direction.BOTTOM_RIGHT:
			return "BOTTOM_RIGHT"
		Hexagon.Direction.BOTTOM_CENTER:
			return "BOTTOM_CENTER"
		Hexagon.Direction.BOTTOM_LEFT:
			return "BOTTOM_LEFT"
		Hexagon.Direction.TOP_LEFT:
			return "TOP_LEFT"
		Hexagon.Direction.TOP_CENTER:
			return "TOP_CENTER"
		Hexagon.Direction.TOP_RIGHT:
			return "TOP_RIGHT"
		_:
			return ""


static func _link_type_from_string(link_type_string: String) -> Variant:
	match link_type_string:
		"SOLID":
			return Link.Type.SOLID
		"STICKY":
			return Link.Type.STICKY
		_:
			return null


static func _link_type_to_string(link_type: Link.Type) -> String:
	match link_type:
		Link.Type.SOLID:
			return "SOLID"
		Link.Type.STICKY:
			return "STICKY"
		_:
			return ""
