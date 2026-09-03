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
var _piece_a: Piece
var _piece_b: Piece


func _process(_delta: float) -> void:
	_refresh_z_index()


func initialize(link: Link, piece_a: Piece, piece_b: Piece) -> void:
	_link = link
	_piece_a = piece_a
	_piece_b = piece_b

	centered = false
	offset = -_CENTER_TILE_POSITION

	match _link.type:
		Link.Type.SOLID:
			var position_offset := _link.entity_b.current_tile.position - _link.entity_a.current_tile.position
			texture = _SOLID_TEXTURES[Hexagon.get_vector_direction(position_offset) as int]
		Link.Type.STICKY:
			texture = _STICKY_TEXTURE

	piece_a.position_changed.connect(_refresh_position)
	piece_b.position_changed.connect(_refresh_position)

	_refresh_position()
	_refresh_z_index()


func _refresh_position() -> void:
	var world_position_a := _piece_a.position
	var world_position_b := _piece_b.position

	match _link.type:
		Link.Type.SOLID:
			position = world_position_a
			rotation = 0.0
			scale = Vector2.ONE

		Link.Type.STICKY:
			var delta := world_position_b - world_position_a
			position = world_position_a
			rotation = delta.angle() + PI / 2.0
			scale = Vector2(1.0, delta.length() / _CANVAS_TILE_DISTANCE)


func _refresh_z_index() -> void:
	z_index = max(_piece_a.z_index, _piece_b.z_index) + 1
