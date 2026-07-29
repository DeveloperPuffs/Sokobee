class_name Manifest


var _filepath: String
var _data: Dictionary

var levels: Array[Level] = []
var editor_level: Level = null


func _init(filepath: String) -> void:
	_filepath = filepath

	var level_data_string := FileAccess.get_file_as_string(filepath)
	if level_data_string == "":
		return

	var json_parser := JSON.new()
	var json_parsing_result := json_parser.parse(level_data_string)
	if json_parsing_result != OK:
		print("JSON Parsing Error {error} at {path}:{line} - {message}".format({
			"error": json_parsing_result,
			"filepath": filepath,
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


func save_level(level: Level) -> void:
	levels.append(level)

	var levels_metadata: Array = _data["levels"]
	levels_metadata.append({
		"filepath": level.filepath,
		"title": level.title
	})

	var data_string := JSON.stringify(_data, "\t")
	var file := FileAccess.open(_filepath, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(data_string)
	file.close()
