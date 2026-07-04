class_name Snapshot


var _active_character: Character
var _active_character_direction: Hexagon.Direction
var _entity_tiles: Dictionary[Entity, Tile]

func _init(state: State) -> void:
	_active_character = state.active_character
	_active_character_direction = state.active_character.facing_direction

	for entity in state.entities:
		_entity_tiles[entity] = entity.current_tile

func apply(state: State) -> void:
	state.active_character = _active_character
	state.active_character.facing_direction = _active_character_direction

	for entity in state.entities:
		entity.current_tile = _entity_tiles[entity]