class_name Main
extends Node2D


@export var _menu_scene: PackedScene
@export var _editor_scene: PackedScene
@export var _game_scene: PackedScene

var active_scene: Node = null


func _ready() -> void:
	_set_scene(_menu_scene)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func _set_scene(scene: PackedScene) -> void:
	if active_scene != null:
		active_scene.queue_free()

	active_scene = scene.instantiate()

	if active_scene is Menu:
		var menu_scene: Menu = active_scene
		menu_scene.play_button_pressed.connect(_set_scene.bind(_game_scene))
		menu_scene.edit_button_pressed.connect(_set_scene.bind(_editor_scene))
		menu_scene.quit_button_pressed.connect(func() -> void:
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		)

	elif active_scene is Game:
		var game_scene: Game = active_scene
		game_scene.exited_game.connect(_set_scene.bind(_menu_scene))

	elif active_scene is Editor:
		var editor_scene: Editor = active_scene
		editor_scene.exited_editor.connect(_set_scene.bind(_menu_scene))

	add_child(active_scene)
