class_name Snapshot


var _active_character: Character
var _entity_tiles: Dictionary[Entity, Tile] = {}
var _facing_directions: Dictionary[Character, Hexagon.Direction] = {}


func _init(state: State) -> void:
	_active_character = state.active_character

	for entity in state.entities:
		_entity_tiles[entity] = entity.current_tile

	for character in state.characters:
		_facing_directions[character] = character.facing_direction


func apply(state: State) -> void:
	state.active_character = _active_character

	for entity in state.entities:
		entity.current_tile = _entity_tiles[entity]

	for entity in state.entities:
		entity.moved.emit(Entity.Movement.new(Entity.Movement.Kind.RESTORED))

	for character in state.characters:
		character.facing_direction = _facing_directions[character]
