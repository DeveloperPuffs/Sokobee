class_name Honey
extends Piece


var _block: Block


func bind_block(block: Block) -> void:
	_block = block
	_bind_entity(block)
