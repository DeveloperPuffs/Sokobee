@tool
class_name RebuildSVGScenes
extends EditorScript


const _SCENE_SVG_PATHS: Dictionary[String, String] = {
	"res://scenes/cells/CellNormal.tscn": "res://assets/sprites/tiles/cell_normal.svg",
	"res://scenes/cells/CellGoal.tscn": "res://assets/sprites/tiles/cell_goal.svg",
	"res://scenes/cells/CellSelectable.tscn": "res://assets/sprites/editor/cell_selectable.svg",
	"res://scenes/cells/CellSelected.tscn": "res://assets/sprites/editor/cell_selected.svg",
	"res://scenes/icons/UndoIcon.tscn": "res://assets/sprites/buttons/icons/undo_icon.svg",
	"res://scenes/icons/RedoIcon.tscn": "res://assets/sprites/buttons/icons/redo_icon.svg",
	"res://scenes/icons/RestartIcon.tscn": "res://assets/sprites/buttons/icons/restart_icon.svg",
	"res://scenes/icons/QuitIcon.tscn": "res://assets/sprites/buttons/icons/quit_icon.svg",
}

# If the import settings changed, this should be set to true to force rebuild every scene
const _FORCE_REBUILD_ALL_SCENES := false

const _SVG_SOURCE_METADATA_NAME := "svg_source"
const _SVG_MODIFIED_TIME_METADATA_NAME := "svg_modified_time"


func _run() -> void:
	var scenes_rebuilt := 0
	var scenes_failed := 0

	for scene_path in _SCENE_SVG_PATHS:
		var svg_path := _SCENE_SVG_PATHS[scene_path]

		if not FileAccess.file_exists(svg_path):
			printerr("SVG source does not exist: %s" % svg_path)
			scenes_failed += 1
			continue

		var svg_modified_time := FileAccess.get_modified_time(svg_path)
		if not _FORCE_REBUILD_ALL_SCENES:
			if svg_modified_time <= _get_scene_metadata_svg_modified_time(scene_path):
				continue

		if await _rebuild_svg_scene(svg_path, scene_path, svg_modified_time) != OK:
			scenes_failed += 1
			continue

		print("Rebuilt %s from %s" % [scene_path, svg_path])
		scenes_rebuilt += 1

	print("Rebuilt %d of %d scenes, %d failed." % [scenes_rebuilt, _SCENE_SVG_PATHS.size(), scenes_failed])


func _rebuild_svg_scene(svg_path: String, scene_path: String, modified_time: int) -> Error:
	var svg_importer := SVGImporter.new(
		true, # is_svs - Import as SVS
		true, # is_lock - Lock Shape Nodes
		false, # is_aa - Antialiased Shapes
		true, # is_line_2d - Stroke as Line2Ds
		ScalableVectorShape2D.CollisionObjectType.NONE,
		CurvedLines2D._is_setting_update_curve_at_runtime(),
		CurvedLines2D._is_making_curve_resources_local_to_scene(),
		CurvedLines2D._get_default_tolerance_degrees(),
		CurvedLines2D._get_default_max_stages(),
		CurvedLines2D._use_antialiased_line_2d(),
		SVGImporter.get_runtime_handler(),
		func(message: String, log_level: SVGImporter.LogLevel) -> void:
			if log_level == SVGImporter.LogLevel.ERROR:
				printerr(message)
			elif log_level == SVGImporter.LogLevel.WARN:
				print("Warning: %s" % message)
	)

	var root := Node2D.new()
	root.name = scene_path.get_file().get_basename()

	# load_svg awaits when import_as_svs is set to false
	await svg_importer.load_svg(svg_path, root)
	svg_importer.free()

	_bake_scalable_vector_shape_nodes(root)

	root.set_meta(_SVG_SOURCE_METADATA_NAME, svg_path)
	root.set_meta(_SVG_MODIFIED_TIME_METADATA_NAME, modified_time)

	var scene := PackedScene.new()
	var error := scene.pack(root)
	root.free()

	if error != OK:
		printerr("Failed to pack %s: %s" % [scene_path, error_string(error)])
		return error

	var previous_uid := ResourceLoader.get_resource_uid(scene_path)

	error = ResourceSaver.save(scene, scene_path)
	if error != OK:
		printerr("Failed to save %s: %s" % [scene_path, error_string(error)])
		return error

	if previous_uid != ResourceUID.INVALID_ID and ResourceLoader.get_resource_uid(scene_path) != previous_uid:
		printerr("The UID of %s changed, so references to it may need to be repaired." % scene_path)

	return OK


func _bake_scalable_vector_shape_nodes(node: Node) -> void:
	if node is ScalableVectorShape2D:
		node._on_dimensions_changed()
		node._on_assigned_node_changed()
		node._update_curve()

	for child in node.get_children():
		_bake_scalable_vector_shape_nodes(child)


func _get_scene_metadata_svg_modified_time(scene_path: String) -> int:
	var scene := ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if scene == null:
		return 0

	var scene_state := scene.get_state()
	if scene_state.get_node_count() == 0:
		return 0

	var svg_modified_time_node_property_name := "metadata/" + _SVG_MODIFIED_TIME_METADATA_NAME
	for index in scene_state.get_node_property_count(0):
		var node_property_name := scene_state.get_node_property_name(0, index)
		if node_property_name == svg_modified_time_node_property_name:
			return scene_state.get_node_property_value(0, index)

	return 0
