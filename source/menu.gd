class_name Menu
extends Node2D


@export var _play_button: Button
@export var _edit_button: Button
@export var _quit_button: Button

signal play_button_pressed
signal edit_button_pressed
signal quit_button_pressed

func _ready() -> void:
	_play_button.pressed.connect(_on_play_button_pressed)
	_edit_button.pressed.connect(_on_edit_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)

func _on_play_button_pressed() -> void:
	play_button_pressed.emit()

func _on_edit_button_pressed() -> void:
	edit_button_pressed.emit()

func _on_quit_button_pressed() -> void:
	quit_button_pressed.emit()
