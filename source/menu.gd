class_name Menu
extends Node2D


@export var _play_button: Button
@export var _edit_button: Button
@export var _quit_button: Button

signal play_button_pressed
signal edit_button_pressed
signal quit_button_pressed


func _ready() -> void:
	_play_button.pressed.connect(play_button_pressed.emit)
	_edit_button.pressed.connect(edit_button_pressed.emit)
	_quit_button.pressed.connect(quit_button_pressed.emit)
