extends Logger
## Captures runtime script errors (for example calling a method on null). Godot aborts the
## failing test function and carries on, so without this a crashing test would count as passed.

var script_errors: Array[String] = []
var _mutex := Mutex.new()


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	_script_backtraces: Array[ScriptBacktrace]
) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	var message := rationale if not rationale.is_empty() else code
	_mutex.lock()
	script_errors.append("%s (%s:%d in %s)" % [message, file, line, function])
	_mutex.unlock()


func take_errors() -> Array[String]:
	_mutex.lock()
	var taken := script_errors.duplicate()
	script_errors.clear()
	_mutex.unlock()
	return taken
