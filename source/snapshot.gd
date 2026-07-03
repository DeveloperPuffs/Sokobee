class_name Snapshot


var _active_character: Character
var _active_character_direction: Hexagon.Direction
var _entity_positions: Dictionary[Entity, Vector2i]

func _init(state: State) -> void:
	_active_character = state.active_character
	_active_character_direction = state.active_character.facing_direction

	for entity in state.entities:
		_entity_positions[entity] = entity.tile_position

func apply(state: State) -> void:
	state.active_character = _active_character
	state.active_character.facing_direction = _active_character_direction

	for entity in state.entities:
		entity.tile_position = _entity_positions[entity]