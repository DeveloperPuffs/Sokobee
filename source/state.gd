class_name State


var tiles: Dictionary[Vector2i, Tile]
var entities: Array[Entity]

var characters: Array[Character]
var active_character: Character

func _init() -> void:
	tiles = {}
	entities = []
	characters = []
	active_character = null