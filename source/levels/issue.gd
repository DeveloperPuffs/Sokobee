class_name Issue


enum Severity {
	WARNING,
	ERROR,
	FATAL,
}

var severity: Severity
var message: String


static func warning(_message: String) -> Issue:
	return Issue.new(Severity.WARNING, _message)


static func error(_message: String) -> Issue:
	return Issue.new(Severity.ERROR, _message)


static func fatal(_message: String) -> Issue:
	return Issue.new(Severity.FATAL, _message)


func _init(_severity: Severity, _message: String) -> void:
	severity = _severity
	message = _message


func _to_string() -> String:
	var severity_string: String
	match severity:
		Severity.WARNING:
			severity_string = "Warning"
		Severity.ERROR:
			severity_string = "Error"
		Severity.FATAL:
			severity_string = "Fatal"

	return severity_string + ": " + message
