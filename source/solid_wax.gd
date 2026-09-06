class_name SolidWax
extends Wax


@export var _direction_shapes: Dictionary[Hexagon.Direction, Node2D]


func bind_link(link: Link, piece_a: Piece, piece_b: Piece) -> void:
	var position_offset := link.entity_b.current_tile.position - link.entity_a.current_tile.position
	var direction := Hexagon.get_vector_direction(position_offset)

	for shape_direction in _direction_shapes:
		if shape_direction != direction:
			_direction_shapes[shape_direction].free()
	_direction_shapes.clear()

	piece_a.position_changed.connect(_refresh_sprite)
	piece_b.position_changed.connect(_refresh_sprite)

	super(link, piece_a, piece_b)

func _refresh_sprite() -> void:
	super()
	position = _piece_a.position


func _refresh_z_index() -> void:
	super()
	z_index = maxi(_piece_a.z_index, _piece_b.z_index) + 1
