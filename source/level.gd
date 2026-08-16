class_name Level


var filepath: String
var title: String


func _init(_filepath: String, _title: String) -> void:
	filepath = _filepath
	title = _title


func get_absolute_filepath() -> String:
	return "res://assets/levels/" + filepath


func load_state() -> LoadResult:
	var result := LoadResult.new()

	var level_data_filepath := get_absolute_filepath()
	var level_data_string := FileAccess.get_file_as_string(level_data_filepath)
	if level_data_string == "":
		result.add_fatal("Failed to read " + filepath)
		return result

	var json_parser := JSON.new()
	var json_parsing_result := json_parser.parse(level_data_string)
	if json_parsing_result != OK:
		result.add_fatal("JSON Parsing Error {error} at {filepath}:{line} - {message}".format({
			"error": json_parsing_result,
			"filepath": level_data_filepath,
			"line": json_parser.get_error_line(),
			"message": json_parser.get_error_message()
		}))

		return result

	Serializer.load_level_state(json_parser.data, result)
	return result


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


class LoadResult:
	var state: State = State.new()
	var issues: Array[Issue] = []


	func add_warning(message: String) -> void:
		issues.append(Issue.warning(message))


	func add_error(message: String) -> void:
		issues.append(Issue.error(message))


	func add_fatal(message: String) -> void:
		issues.append(Issue.fatal(message))


	func has_errors() -> bool:
		return _has_issue_severity(Issue.Severity.ERROR)


	func has_fatal_errors() -> bool:
		return _has_issue_severity(Issue.Severity.FATAL)


	func _has_issue_severity(minimum_severity: Issue.Severity) -> bool:
		for issue in issues:
			if issue.severity >= minimum_severity:
				return true

		return false
