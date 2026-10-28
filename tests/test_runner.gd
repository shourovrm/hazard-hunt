extends Node
## Runs every tests/<dir>/test_*.gd file and quits with exit code 1 on failure.
## Usage: godot --headless --path . res://tests/test_runner.tscn -- --dir=core
## Without --dir it runs every test directory.

const TestContext := preload("res://tests/test_context.gd")
const ScriptErrorLogger := preload("res://tests/script_error_logger.gd")
const TEST_ROOT := "res://tests"

var _error_logger := ScriptErrorLogger.new()


func _ready() -> void:
	OS.add_logger(_error_logger)
	var directories := _directories_to_run()
	var context := TestContext.new()
	context.root = self
	var test_count := 0
	for directory in directories:
		for script_path in _test_scripts_in(directory):
			test_count += await _run_script(script_path, context)
	for failure in context.failures:
		print("FAIL ", failure)
	print("%d tests, %d failures" % [test_count, context.failures.size()])
	get_tree().quit(1 if not context.failures.is_empty() or test_count == 0 else 0)


func _directories_to_run() -> Array[String]:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--dir="):
			return [TEST_ROOT + "/" + argument.trim_prefix("--dir=")]
	var all_directories: Array[String] = []
	for name in DirAccess.get_directories_at(TEST_ROOT):
		all_directories.append(TEST_ROOT + "/" + name)
	return all_directories


func _test_scripts_in(directory: String) -> Array[String]:
	var paths: Array[String] = []
	for file_name in DirAccess.get_files_at(directory):
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			paths.append(directory + "/" + file_name)
	paths.sort()
	return paths


func _run_script(script_path: String, context: TestContext) -> int:
	var script: GDScript = load(script_path)
	if script == null or not script.can_instantiate():
		context.current_test = script_path
		context.fail("script failed to load or compile")
		return 1
	var count := 0
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		count += 1
		context.current_test = "%s::%s" % [script_path.get_file(), method_name]
		var test_instance: Object = script.new()
		test_instance.set("t", context)
		_error_logger.take_errors()
		await test_instance.call(method_name)
		for script_error in _error_logger.take_errors():
			context.fail("script error: " + script_error)
		for child in get_children():
			child.queue_free()
		await get_tree().process_frame
	return count
