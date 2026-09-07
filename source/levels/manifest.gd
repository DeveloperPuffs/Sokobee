class_name Manifest


var _filepath: String
var _data: Dictionary

var levels: Array[Level] = []
var editor_level: Level = null


func _init(filepath: String) -> void:
	_filepath = filepath
	_load_data()


func create_level(title: String) -> Level:
	var filename := title.strip_edges().to_lower().replace(" ", "_")
	if filename == "":
		filename = "unnamed_level"

	var filepath := filename + ".json"
	var suffix := 2
	while FileAccess.file_exists("res://assets/levels/" + filepath):
		filepath = "{filename}_{suffix}.json".format({
			"filename": filename,
			"suffix": suffix
		})

		suffix += 1

	return Level.new(filepath, title)


func register_level(level: Level) -> void:
	if not levels.has(level):
		levels.append(level)

	_save_data()


func _load_data() -> void:
	var level_data_string := FileAccess.get_file_as_string(_filepath)
	if level_data_string == "":
		return

	var json_parser := JSON.new()
	var json_parsing_result := json_parser.parse(level_data_string)
	if json_parsing_result != OK:
		print("JSON Parsing Error {error} at {path}:{line} - {message}".format({
			"error": json_parsing_result,
			"filepath": _filepath,
			"line": json_parser.get_error_line(),
			"message": json_parser.get_error_message()
		}))

		return

	_data = json_parser.data
	var levels_metadata: Array = _data["levels"]
	for level_metadata: Dictionary in levels_metadata:
		var level_filepath: String = level_metadata["filepath"]
		var level_title: String = level_metadata["title"]
		levels.append(Level.new(level_filepath, level_title))

	var editor_level_metadata: Dictionary = _data["editor_level"]
	var editor_level_filepath: String = editor_level_metadata["filepath"]
	var editor_level_title: String = editor_level_metadata["title"]
	editor_level = Level.new(editor_level_filepath, editor_level_title)


func _save_data() -> void:
	if _data.is_empty():
		return

	var levels_metadata: Array = []
	for level in levels:
		levels_metadata.append({
			"filepath": level.filepath,
			"title": level.title
		})

	_data["levels"] = levels_metadata

	var data_string := JSON.stringify(_data, "\t")
	var file := FileAccess.open(_filepath, FileAccess.WRITE)
	if file == null:
		print("Failed to Write to {path} - {error}".format({
			"path": _filepath,
			"error": FileAccess.get_open_error()
		}))

		return

	file.store_string(data_string)
	file.close()
