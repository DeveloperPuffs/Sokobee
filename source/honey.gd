class_name Honey
extends Node2D


var block: Block

func _process(_delta: float) -> void:
	position = Hexagon.get_world_position(block.tile_position)

func initialize(_block: Block) -> void:
	block = _block