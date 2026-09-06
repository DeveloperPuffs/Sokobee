@tool
class_name GameButton
extends Button


const _ART_SCALE := 8.0

const _HOVER_LIFT := 16.0 * _ART_SCALE
const _PRESS_LIFT := -48.0 * _ART_SCALE

const _HOVER_DURATION := 0.15
const _PRESS_DURATION := 0.08
const _REST_DURATION := 0.5

@export var _icon_scene: PackedScene:
	set(icon_scene):
		_icon_scene = icon_scene
		_refresh_icon()

@export var _surface: Node2D
@export var _wall: ScalableVectorShape2D
@export var _icon_container: Node2D

var _surface_rest_y: float
var _wall_rest_y: float
var _wall_rest_height: float

var _hovering := false:
	set(hovering):
		if not _hovering == hovering:
			_hovering = hovering
			_animate_lift()

var _pressing := false:
	set(pressing):
		if not _pressing == pressing:
			_pressing = pressing
			_animate_lift()

var _lift := 0.0:
	set(lift):
		_lift = lift

		if not is_node_ready() or _surface == null or _wall == null:
			return

		_surface.position.y = _surface_rest_y - lift

		var height := maxf(_wall_rest_height + lift, 0.0)
		_wall.scale.y = height / _wall_rest_height
		_wall.position.y = _wall_rest_y - (height - _wall_rest_height) / 2.0

var lift_tween: Tween = null


func _ready() -> void:
	_surface_rest_y = _surface.position.y
	_wall_rest_y = _wall.position.y
	_wall_rest_height = _wall.size.y

	_refresh_icon()

	if Engine.is_editor_hint():
		return

	mouse_entered.connect(func() -> void: _hovering = true)
	mouse_exited.connect(func() -> void: _hovering = false)
	button_down.connect(func() -> void: _pressing = true)
	button_up.connect(func() -> void: _pressing = false)


func _has_point(point: Vector2) -> bool:
	return Hexagon.check_point_hexagon_intersection(point)


func _refresh_icon() -> void:
	if not is_node_ready() or _icon_container == null:
		return

	for child in _icon_container.get_children():
		child.free()

	if _icon_scene == null:
		return

	var icon_shape := _icon_scene.instantiate()
	_icon_container.add_child(icon_shape)


func _animate_lift() -> void:
	if lift_tween != null and lift_tween.is_valid():
		lift_tween.kill()

	lift_tween = create_tween()

	if _pressing:
		lift_tween.tween_property(self, ^":_lift", _PRESS_LIFT, _PRESS_DURATION)
	elif _hovering:
		lift_tween.tween_property(self, ^":_lift", _HOVER_LIFT, _HOVER_DURATION)
	else:
		lift_tween.tween_property(self, ^":_lift", 0.0, _REST_DURATION)
