class_name Wax
extends Node2D


const SOLID_TEXTURE = preload("res://assets/sprites/link_solid_placeholder.svg")
const STICKY_TEXTURE = preload("res://assets/sprites/link_sticky_placeholder.svg")

@export var _sprite: Sprite2D

var _link: Link

func _process(_delta: float) -> void:
	var entity_a := _link.entity_a
	var entity_b := _link.entity_b

	var tile_position_a := entity_a.current_tile.position
	var tile_position_b := entity_b.current_tile.position

	var elevation_a := entity_a.get_elevation()
	var elevation_b := entity_b.get_elevation()

	var world_position_a := Hexagon.get_tile_world_position(tile_position_a, elevation_a)
	var world_position_b := Hexagon.get_tile_world_position(tile_position_b, elevation_b)

	var delta := world_position_b - world_position_a
	scale = Vector2(delta.length() / _sprite.texture.get_width(), 1.0)
	position = (world_position_a + world_position_b) / 2.0
	rotation = delta.angle()

	var z_index_a = Hexagon.get_tile_z_index(tile_position_a)
	var z_index_b = Hexagon.get_tile_z_index(tile_position_b)
	z_index = max(z_index_a, z_index_b) + 3

func initialize(link: Link) -> void:
	_link = link

	match link.type:
		Link.Type.SOLID:
			_sprite.texture = SOLID_TEXTURE
		Link.Type.STICKY:
			_sprite.texture = STICKY_TEXTURE