class_name State


enum TileType {
	TILE_FLOOR,
	TILE_GOAL,
}

var tiles: Dictionary[Vector2i, TileType]
var entities: Array[Entity]

var characters: Array[Character]
var active_character: Character

func _init() -> void:
	tiles = {}
	entities = []
	characters = []
	active_character = null