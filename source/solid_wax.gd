class_name SolidWax
extends Wax


const _SOLID_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/links/solid_bottom_right_link.svg"),
	preload("res://assets/sprites/links/solid_bottom_link.svg"),
	preload("res://assets/sprites/links/solid_bottom_left_link.svg"),
	preload("res://assets/sprites/links/solid_top_left_link.svg"),
	preload("res://assets/sprites/links/solid_top_link.svg"),
	preload("res://assets/sprites/links/solid_top_right_link.svg"),
]

# The approximate position of the center tile in the link tile grid
# (from the top left of the link textures)
const _CENTER_TILE_POSITION := Vector2(319.5023, 315.3215)


func _init(link: Link, piece_a: Piece, piece_b: Piece) -> void:
	super(link, piece_a, piece_b)

	piece_a.position_changed.connect(_refresh_sprite)
	piece_b.position_changed.connect(_refresh_sprite)

	centered = false
	offset = -_CENTER_TILE_POSITION

	var position_offset := _link.entity_b.current_tile.position - _link.entity_a.current_tile.position
	texture = _SOLID_TEXTURES[Hexagon.get_vector_direction(position_offset) as int]


func _refresh_sprite() -> void:
	super()
	position = _piece_a.position


func _refresh_z_index() -> void:
	super()
	z_index = maxi(_piece_a.z_index, _piece_b.z_index) + 1
