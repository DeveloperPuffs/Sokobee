class_name Serializer


const _LEVEL_KEYS: Array[String] = ["tiles", "entities", "links", "active"]
const _TILE_KEYS: Array[String] = ["q", "r", "goal", "height"]
const _CHARACTER_KEYS: Array[String] = ["type", "q", "r", "facing", "asleep", "identifier"]
const _BLOCK_KEYS: Array[String] = ["type", "q", "r", "identifier"]
const _LINK_KEYS: Array[String] = ["type", "identifier_a", "identifier_b"]


static func load_level_state(level_data: Variant, result: Level.LoadResult) -> void:
	var context := _LoadContext.new(result)

	if level_data is not Dictionary:
		context.add_fatal("The level data is not an object")
		return

	_check_keys(level_data, _LEVEL_KEYS, "The level", context)

	var tiles_value: Variant = level_data.get("tiles")
	if tiles_value is Array:
		_load_tiles(tiles_value as Array, context)
		context.tiles_are_loaded = true
	else:
		context.add_fatal("Missing or invalid \"tiles\" array")

	var entities_value: Variant = level_data.get("entities")
	if entities_value is Array:
		_load_entities(entities_value as Array, context)
		context.entities_are_loaded = true
	else:
		context.add_fatal("Missing or invalid \"entities\" array")

	var links_value: Variant = level_data.get("links")
	if links_value is Array:
		_load_links(links_value as Array, context)
		context.links_are_loaded = true
	else:
		context.add_fatal("Missing or invalid \"links\" array")

	_load_active_character(level_data, context)
	_check_unreferenced_identifiers(context)

	if context.entities_are_loaded and context.links_are_loaded:
		context.state.assign_block_clusters()


static func save_level_state(state: State) -> Dictionary:
	var identifiers: Dictionary[Entity, int] = {}
	var next_identifier := 0

	for entity in state.entities:
		if entity.links.is_empty() and entity != state.active_character:
			continue

		identifiers[entity] = next_identifier
		next_identifier += 1

	var tiles_data: Array[Dictionary] = []
	for tile: Tile in state.tiles.values():
		var tile_data := {
			"q": tile.position.x,
			"r": tile.position.y
		}

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
		links_data.append({
			"type": _link_type_to_string(link.type),
			"identifier_a": identifiers[link.entity_a],
			"identifier_b": identifiers[link.entity_b]
		})

	var level_data := {
		"tiles": tiles_data,
		"entities": entities_data,
		"links": links_data
	}

	if state.active_character != null:
		level_data["active"] = identifiers[state.active_character as Entity]

	return level_data


static func _load_tiles(tiles_data: Array, context: _LoadContext) -> void:
	var tile_indices: Dictionary[Vector2i, int] = {}

	for tile_index in tiles_data.size():
		var tile_value: Variant = tiles_data[tile_index]
		if tile_value is not Dictionary:
			context.add_error("Tile {index} is not an object".format({
				"index": tile_index
			}))

			continue

		var tile := _load_tile(tile_value as Dictionary, tile_index, context)
		if tile == null:
			continue

		if tile_indices.has(tile.position):
			context.add_error("Tile {index} is at {position}, which tile {first_index} already occupies".format({
				"index": tile_index,
				"position": _describe_position(tile.position),
				"first_index": tile_indices[tile.position]
			}))

			continue

		tile_indices[tile.position] = tile_index
		context.state.tiles[tile.position] = tile


static func _load_tile(tile_data: Dictionary, tile_index: int, context: _LoadContext) -> Tile:
	_check_keys(tile_data, _TILE_KEYS, "Tile " + str(tile_index), context)

	var position_value: Variant = _read_position(tile_data)
	if position_value is not Vector2i:
		context.add_error("Tile {index} is missing integers \"q\" and/or \"r\"".format({
			"index": tile_index
		}))

		return null

	var position: Vector2i = position_value

	var goal := false
	if tile_data.has("goal"):
		var goal_value: Variant = tile_data["goal"]
		if goal_value is bool:
			goal = goal_value
		else:
			context.add_error("The tile at {position} has a non-boolean \"goal\"".format({
				"position": _describe_position(position)
			}))

	var height := 0
	if tile_data.has("height"):
		var height_value: Variant = _read_integer(tile_data, "height")
		if height_value is not int:
			context.add_error("The tile at {position} has a non-integer \"height\"".format({
				"position": _describe_position(position)
			}))
		else:
			height = height_value

			if height < Tile.MINIMUM_HEIGHT or height > Tile.MAXIMUM_HEIGHT:
				context.add_error("The tile at {position} has a \"height\" of {height}, outside the supported range of {minimum} to {maximum}".format({
					"position": _describe_position(position),
					"height": height,
					"minimum": Tile.MINIMUM_HEIGHT,
					"maximum": Tile.MAXIMUM_HEIGHT
				}))

	return Tile.new(position, goal, height)


static func _load_entities(entities_data: Array, context: _LoadContext) -> void:
	for entity_index in entities_data.size():
		var entity_value: Variant = entities_data[entity_index]
		if entity_value is not Dictionary:
			context.add_error("Entity {index} is not an object".format({
				"index": entity_index
			}))

			continue

		var entity := _load_entity(entity_value as Dictionary, entity_index, context)
		if entity == null:
			continue

		if entity.current_tile != null:
			context.state.entities.append(entity)

			if entity is Character:
				context.state.characters.append(entity as Character)


static func _load_entity(entity_data: Dictionary, entity_index: int, context: _LoadContext) -> Entity:
	var type_value: Variant = entity_data.get("type")
	if type_value is not String:
		context.add_error("Entity {index} has a missing or invalid \"type\"".format({
			"index": entity_index
		}))

		return null

	var entity_type: String = type_value
	if entity_type != "character" and entity_type != "block":
		context.add_error("Entity {index} has an unknown \"type\": \"{type}\"".format({
			"index": entity_index,
			"type": entity_type
		}))

		return null

	# The allowed keys depend on the type, so this cannot be checked any earlier
	var known_keys := _CHARACTER_KEYS if entity_type == "character" else _BLOCK_KEYS
	_check_keys(entity_data, known_keys, "Entity " + str(entity_index), context)

	var position_value: Variant = _read_position(entity_data)
	if position_value is not Vector2i:
		context.add_error("Entity {index} is missing integers \"q\" and/or \"r\"".format({
			"index": entity_index
		}))

		return null

	var position: Vector2i = position_value
	var description := "\"{type}\" at {position}".format({
		"type": entity_type,
		"position": _describe_position(position)
	})

	var facing_direction := Hexagon.Direction.TOP_CENTER
	var asleep := false

	if entity_type == "character":
		var facing_value: Variant = entity_data.get("facing")
		if facing_value is not String:
			context.add_error(description + " has a missing or invalid \"facing\"")
			return null

		var direction_value: Variant = _direction_from_string(facing_value)
		if direction_value == null:
			context.add_error(description + " has an unknown \"facing\": \"{facing}\"".format({
				"facing": facing_value
			}))

			return null

		facing_direction = direction_value

		if entity_data.has("asleep"):
			var asleep_value: Variant = entity_data["asleep"]
			if asleep_value is bool:
				asleep = asleep_value
			else:
				context.add_error(description + " has a non-boolean \"asleep\"")

	if context.occupied_positions.has(position):
		context.add_error(description + " shares a tile with entity \"{first_index}\"".format({
			"first_index": context.occupied_positions[position]
		}))

	context.occupied_positions[position] = entity_index

	var tile: Tile = context.state.tiles.get(position)
	if tile == null and context.tiles_are_loaded:
		context.add_error(description + " is not standing on a tile")

	var entity: Entity
	if entity_type == "character":
		entity = Character.new(tile, facing_direction, asleep)
	else:
		entity = Block.new(tile)

	if entity_data.has("identifier"):
		var identifier_value: Variant = _read_integer(entity_data, "identifier")
		if identifier_value is not int:
			context.add_error(description + " has a non-integer \"identifier\"")
			return entity

		var identifier: int = identifier_value
		if context.entity_identifiers.has(identifier):
			context.add_error(description + " shares the \"identifier\" {identifier} with entity \"{first_index}\"".format({
				"identifier": identifier,
				"first_index": context.entity_identifiers[identifier]
			}))

			return entity

		context.entity_identifiers[identifier] = entity_index
		context.identifiable_entities[identifier] = entity

	return entity


static func _load_links(links_data: Array, context: _LoadContext) -> void:
	for link_index in links_data.size():
		var link_value: Variant = links_data[link_index]
		if link_value is not Dictionary:
			context.add_error("Link {index} is not an object".format({
				"index": link_index
			}))

			continue

		var link := _load_link(link_value as Dictionary, link_index, context)
		if link == null:
			continue

		if link.entity_a.current_tile != null and link.entity_b.current_tile != null:
			context.state.links.append(link)
			link.entity_a.links.append(link)
			link.entity_b.links.append(link)


static func _load_link(link_data: Dictionary, link_index: int, context: _LoadContext) -> Link:
	_check_keys(link_data, _LINK_KEYS, "Link " + str(link_index), context)

	var type_value: Variant = link_data.get("type")
	if type_value is not String:
		context.add_error("Link {index} has a missing or invalid \"type\"".format({
			"index": link_index
		}))

		return null

	var link_type_value: Variant = _link_type_from_string(type_value)
	if link_type_value == null:
		context.add_error("Link {index} has an unknown \"type\": \"{type}\"".format({
			"index": link_index,
			"type": type_value
		}))

		return null

	var link_type: Link.Type = link_type_value

	var value_a: Variant = _read_integer(link_data, "identifier_a")
	if value_a is not int:
		context.add_error("Link {index} is missing an integer \"identifier_a\"".format({
			"index": link_index
		}))

	var value_b: Variant = _read_integer(link_data, "identifier_b")
	if value_b is not int:
		context.add_error("Link {index} is missing an integer \"identifier_b\"".format({
			"index": link_index
		}))

	if value_a is not int or value_b is not int:
		return null

	var identifier_a: int = value_a
	var identifier_b: int = value_b

	context.referenced_identifiers[identifier_a] = true
	context.referenced_identifiers[identifier_b] = true

	if identifier_a == identifier_b:
		context.add_error("Link {index} joins an entity to itself".format({
			"index": link_index
		}))

		return null

	var identifier_pair := Vector2i(mini(identifier_a, identifier_b), maxi(identifier_a, identifier_b))
	if context.linked_pairs.has(identifier_pair):
		context.add_error("Link {index} joins the same two entities as link {first_index}".format({
			"index": link_index,
			"first_index": context.linked_pairs[identifier_pair]
		}))

		return null

	context.linked_pairs[identifier_pair] = link_index

	if not context.entities_are_loaded:
		return null

	var entity_a := _find_linked_entity(identifier_a, link_index, context)
	var entity_b := _find_linked_entity(identifier_b, link_index, context)
	if entity_a == null or entity_b == null:
		return null

	if link_type == Link.Type.SOLID and (entity_a is not Block or entity_b is not Block):
		context.add_error("Link {index} is solid but does not join two blocks".format({
			"index": link_index
		}))

		return null

	if entity_a.current_tile != null and entity_b.current_tile != null:
		var offset := entity_b.current_tile.position - entity_a.current_tile.position
		if not Hexagon.is_direction_vector(offset):
			context.add_error("Link {index} joins two entities that are not on adjacent tiles".format({
				"index": link_index
			}))

			return null

	return Link.new(link_type, entity_a, entity_b)


static func _check_unreferenced_identifiers(context: _LoadContext) -> void:
	if not context.links_are_loaded:
		return

	for identifier: int in context.entity_identifiers:
		if context.referenced_identifiers.has(identifier):
			continue

		context.add_warning("Entity {index} declares the identifier {identifier}, which nothing refers to".format({
			"index": context.entity_identifiers[identifier],
			"identifier": identifier
		}))


static func _find_linked_entity(identifier: int, link_index: int, context: _LoadContext) -> Entity:
	if not context.identifiable_entities.has(identifier):
		context.add_error("Link {index} refers to the identifier {identifier}, which no entity declares".format({
			"index": link_index,
			"identifier": identifier
		}))

		return null

	return context.identifiable_entities[identifier]


static func _load_active_character(level_data: Dictionary, context: _LoadContext) -> void:
	if not level_data.has("active"):
		return

	var active_value: Variant = _read_integer(level_data, "active")
	if active_value is not int:
		context.add_error("\"active\" is not an integer")
		return

	var active: int = active_value
	context.referenced_identifiers[active] = true

	if not context.entities_are_loaded:
		return

	if not context.identifiable_entities.has(active):
		context.add_error("\"active\" refers to the identifier {identifier}, which no entity declares".format({
			"identifier": active
		}))

		return

	var entity := context.identifiable_entities[active]
	if entity is not Character:
		context.add_error("\"active\" refers to the identifier {identifier}, which is not a character".format({
			"identifier": active
		}))

		return

	var character: Character = entity
	if character.asleep:
		context.add_error("\"active\" refers to the identifier {identifier}, which is a character that is asleep".format({
			"identifier": active
		}))

		return

	context.state.active_character = character


static func _check_keys(data: Dictionary, known_keys: Array[String], description: String, context: _LoadContext) -> void:
	for key: Variant in data:
		if key is String and known_keys.has(key):
			continue

		context.add_warning("{description} has an unrecognised key \"{key}\"".format({
			"description": description,
			"key": str(key)
		}))


static func _read_integer(data: Dictionary, key: String) -> Variant:
	var value: Variant = data.get(key)

	if value is int:
		return value

	if value is float:
		var number: float = value
		if number != floorf(number):
			return null

		return int(number)

	return null


static func _read_position(data: Dictionary) -> Variant:
	var q_value: Variant = _read_integer(data, "q")
	var r_value: Variant = _read_integer(data, "r")
	if q_value is not int or r_value is not int:
		return null

	return Vector2i(q_value as int, r_value as int)


static func _describe_position(tile_position: Vector2i) -> String:
	return "(q: {q}, r: {r})".format({"q": tile_position.x, "r": tile_position.y})


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


static func _direction_to_string(direction: Hexagon.Direction) -> Variant:
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
			return null


static func _link_type_from_string(link_type_string: String) -> Variant:
	match link_type_string:
		"SOLID":
			return Link.Type.SOLID
		"STICKY":
			return Link.Type.STICKY
		_:
			return null


static func _link_type_to_string(link_type: Link.Type) -> Variant:
	match link_type:
		Link.Type.SOLID:
			return "SOLID"
		Link.Type.STICKY:
			return "STICKY"
		_:
			return null


class _LoadContext:
	var state: State
	var _result: Level.LoadResult

	var identifiable_entities: Dictionary[int, Entity] = {}
	var entity_identifiers: Dictionary[int, int] = {} # Maps identifier to entity index
	var referenced_identifiers: Dictionary[int, bool] = {} # Identifiers that a link or "active" names
	var linked_pairs: Dictionary[Vector2i, int] = {} # Maps a sorted identifier pair to link index
	var occupied_positions: Dictionary[Vector2i, int] = {}
	var tiles_are_loaded := false
	var entities_are_loaded := false
	var links_are_loaded := false


	func _init(result: Level.LoadResult) -> void:
		_result = result
		state = result.state


	func add_warning(message: String) -> void:
		_result.add_warning(message)


	func add_error(message: String) -> void:
		_result.add_error(message)


	func add_fatal(message: String) -> void:
		_result.add_fatal(message)
