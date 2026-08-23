class_name Wax
extends Sprite2D


const _SOLID_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/links/solid_bottom_right_link.svg"),
	preload("res://assets/sprites/links/solid_bottom_link.svg"),
	preload("res://assets/sprites/links/solid_bottom_left_link.svg"),
	preload("res://assets/sprites/links/solid_top_left_link.svg"),
	preload("res://assets/sprites/links/solid_top_link.svg"),
	preload("res://assets/sprites/links/solid_top_right_link.svg"),
]

const _STICKY_TEXTURE := preload("res://assets/sprites/links/sticky_link.svg")

# The approximate position of the center tile in the link tile grid
# (from the top left of the link textures)
const _CENTER_TILE_POSITION := Vector2(319.5023, 315.3215)

# The approximate distance between two neighbouring tiles in the link tile grid
const _CANVAS_TILE_DISTANCE := 222.5685

var _link: Link


func _process(_delta: float) -> void:
	_refresh()


func initialize(link: Link) -> void:
	_link = link

	centered = false
	offset = -_CENTER_TILE_POSITION

	_refresh()


func _refresh() -> void:
	var entity_a := _link.entity_a
	var entity_b := _link.entity_b

	var tile_position_a := entity_a.current_tile.position
	var tile_position_b := entity_b.current_tile.position

	position = Hexagon.get_tile_world_position(tile_position_a, entity_a.get_elevation())

	match _link.type:
		Link.Type.SOLID:
			var direction := Hexagon.get_vector_direction(tile_position_b - tile_position_a)
			texture = _SOLID_TEXTURES[direction as int]

		Link.Type.STICKY:
			var world_position_b := Hexagon.get_tile_world_position(tile_position_b, entity_b.get_elevation())
			var delta := world_position_b - position

			texture = _STICKY_TEXTURE
			rotation = delta.angle() + PI / 2.0
			scale = Vector2(1.0, delta.length() / _CANVAS_TILE_DISTANCE)

	var z_index_a := Hexagon.get_tile_z_index(tile_position_a)
	var z_index_b := Hexagon.get_tile_z_index(tile_position_b)
	z_index = max(z_index_a, z_index_b) + 3
