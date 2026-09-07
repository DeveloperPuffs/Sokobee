class_name Wax
extends Node2D


var _link: Link
var _piece_a: Piece
var _piece_b: Piece


func bind_link(link: Link, piece_a: Piece, piece_b: Piece) -> void:
	_link = link
	_piece_a = piece_a
	_piece_b = piece_b

	_refresh_sprite()
	_refresh_z_index()


func _process(_delta: float) -> void:
	_refresh_z_index()


func _refresh_sprite() -> void:
	pass


func _refresh_z_index() -> void:
	pass
