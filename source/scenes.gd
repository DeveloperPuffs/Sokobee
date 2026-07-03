class_name Scenes
extends Node


signal exited_application

@export var scene_container: Node

const MENU_SCENE := preload("res://scenes/Menu.tscn")
const GAME_SCENE := preload("res://scenes/Game.tscn")

var active_scene: Node

func _ready() -> void:
	_set_menu_scene()

func _set_menu_scene() -> void:
	_set_scene(MENU_SCENE)

func _set_game_scene() -> void:
	_set_scene(GAME_SCENE)

func _set_scene(scene: PackedScene) -> void:
	if active_scene != null:
		active_scene.queue_free()

	active_scene = scene.instantiate()
	scene_container.add_child(active_scene)

	if active_scene is Menu:
		active_scene.play_button_pressed.connect(_set_game_scene)
		active_scene.quit_button_pressed.connect(_on_quit)
	elif active_scene is Game:
		active_scene.exited_game.connect(_set_menu_scene)

func _on_quit() -> void:
	exited_application.emit()
