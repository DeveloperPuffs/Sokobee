class_name Level


var filepath: String
var title: String


func _init(_filepath: String, _title: String) -> void:
	filepath = _filepath
	title = _title


func load_state() -> State:
	var level_data_file_path := "res://assets/levels/" + filepath
	var level_data_string := FileAccess.get_file_as_string(level_data_file_path)
	if level_data_string == "":
		return null

	var json_parser := JSON.new()
	var json_parsing_result := json_parser.parse(level_data_string)
	if json_parsing_result != OK:
		print("JSON Parsing Error {error} at {path}:{line} - {message}".format({
			"error": json_parsing_result,
			"filepath": level_data_file_path,
			"line": json_parser.get_error_line(),
			"message": json_parser.get_error_message()
		}))

		return null

	var level_data := json_parser.data as Dictionary
	var state := Serializer.load_level_state(level_data)
	if state == null:
		return null

	return state
