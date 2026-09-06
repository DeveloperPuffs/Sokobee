class_name StickyWax
extends Wax


const _THICKNESS := 64.0
const _TEXTURE_SIZE := 256.0

# This offset makes the sticky wax appear in front of solid links where they overlap
const _Z_INDEX_OFFSET := 2 * Hexagon.Z_INDEX_SCALE + 2


func _process(_delta: float) -> void:
	super(_delta)

	var marker_a := _piece_a.link_attachment_marker
	var marker_b := _piece_b.link_attachment_marker

	var delta := marker_b.global_position - marker_a.global_position
	var distance := delta.length()
	if is_zero_approx(distance):
			return

	var unit := delta / distance
	var length := maxf(distance - (marker_a.radius + marker_b.radius), 0.0) + _THICKNESS

	global_position = marker_a.global_position + unit * (marker_a.radius + (length - _THICKNESS) / 2.0)
	global_rotation = unit.angle()

	scale = Vector2(length / _TEXTURE_SIZE, _THICKNESS / _TEXTURE_SIZE)
	material.set_shader_parameter("length", length)


func _refresh_z_index() -> void:
	super()
	z_index = maxi(_piece_a.z_index, _piece_b.z_index) + _Z_INDEX_OFFSET
