class_name Loader


static func load_level_state(level_data_file_path: String) -> Variant:
	var level_data_string := FileAccess.get_file_as_string(level_data_file_path)

	var json := JSON.new()
	if json.parse(level_data_string) != OK:
		return null

	var level_data: Dictionary = json.data
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

	_assign_block_clusters(state)

	state.active_character = state.characters[0]

	return state

static func _assign_block_clusters(state: State) -> void:
	for entity in state.entities:
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

static func _link_type_from_string(link_type_string: String) -> Variant:
	match link_type_string:
		"SOLID":
			return Link.Type.SOLID
		"STICKY":
			return Link.Type.STICKY
		_:
			return null
