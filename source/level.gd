class_name Level


var filepath: String
var title: String


func _init(_filepath: String, _title: String) -> void:
	filepath = _filepath
	title = _title


func get_absolute_filepath() -> String:
	return "res://assets/levels/" + filepath


func load_state() -> State:
	var level_data_filepath := get_absolute_filepath()
	var level_data_string := FileAccess.get_file_as_string(level_data_filepath)
	if level_data_string == "":
		return null

	var json_parser := JSON.new()
	var json_parsing_result := json_parser.parse(level_data_string)
	if json_parsing_result != OK:
		print("JSON Parsing Error {error} at {path}:{line} - {message}".format({
			"error": json_parsing_result,
			"filepath": level_data_filepath,
			"line": json_parser.get_error_line(),
			"message": json_parser.get_error_message()
		}))

		return null

	var level_data := json_parser.data as Dictionary
	var state := Serializer.load_level_state(level_data)
	if state == null:
		return null

	return state


func save_state(state: State) -> bool:
	var level_data := Serializer.save_level_state(state)
	var level_data_string := JSON.stringify(level_data, "\t")

	var level_data_filepath := get_absolute_filepath()
	var file := FileAccess.open(level_data_filepath, FileAccess.WRITE)
	if file == null:
		print("Failed to Write {filepath} - {error}".format({
			"filepath": level_data_filepath,
			"error": FileAccess.get_open_error()
		}))

		return false

	file.store_string(level_data_string)
	file.close()

	return true
