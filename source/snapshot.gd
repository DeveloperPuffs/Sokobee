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

	var entity_offsets: Dictionary[Entity, Vector2i] = {}
	for entity in state.entities:
		var target_tile := _entity_tiles[entity]
		var offset := target_tile.position - entity.current_tile.position
		entity_offsets[entity] = offset
		entity.current_tile = target_tile

	for entity in state.entities:
		entity.moved.emit(Entity.Movement.new(Entity.Movement.Kind.RESTORED, entity_offsets[entity]))

	for character in state.characters:
		character.set_facing_direction(_facing_directions[character], true)
