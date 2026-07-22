class_name Main
extends Node2D


const MENU_SCENE := preload("res://scenes/Menu.tscn")
const EDIT_SCENE := preload("res://scenes/Editor.tscn")
const GAME_SCENE := preload("res://scenes/Game.tscn")

var active_scene: Node = null


func _ready() -> void:
	_set_menu_scene()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func _set_menu_scene() -> void:
	_set_scene(MENU_SCENE)


func _set_edit_scene() -> void:
	_set_scene(EDIT_SCENE)


func _set_game_scene() -> void:
	_set_scene(GAME_SCENE)


func _set_scene(scene: PackedScene) -> void:
	if active_scene != null:
		active_scene.queue_free()

	active_scene = scene.instantiate()

	if active_scene is Menu:
		active_scene.play_button_pressed.connect(_set_game_scene)
		active_scene.edit_button_pressed.connect(_set_edit_scene)
		active_scene.quit_button_pressed.connect(_on_quit)
	elif active_scene is Game:
		active_scene.exited_game.connect(_set_menu_scene)
	elif active_scene is Editor:
		active_scene.exited_editor.connect(_set_menu_scene)

	add_child(active_scene)


func _on_quit() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
