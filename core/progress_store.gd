class_name ProgressStore
extends Node
## Autoload "Progress": best stars per case and the chosen language,
## saved as JSON so they survive restarts.

const DEFAULT_LANGUAGE := "bn"

var save_path := "user://progress.json"

var _best_stars: Dictionary = {}
var _language := DEFAULT_LANGUAGE


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	_clear_memory()
	if not FileAccess.file_exists(save_path):
		return
	var parser := JSON.new()
	var parse_error := parser.parse(FileAccess.get_file_as_string(save_path))
	if parse_error != OK or not parser.data is Dictionary:
		push_error(
			(
				"ProgressStore: corrupt save file '%s', starting empty (line %d: %s)"
				% [save_path, parser.get_error_line(), parser.get_error_message()]
			)
		)
		return
	_apply_saved_data(parser.data)


func save_progress() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("ProgressStore: cannot write '%s' (error %d)" % [save_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify({"stars": _best_stars, "language": _language}))
	file.close()


func record_result(case_id: String, stars: int) -> void:
	if stars > get_stars(case_id):
		_best_stars[case_id] = stars
	save_progress()


func get_stars(case_id: String) -> int:
	return _best_stars.get(case_id, 0)


func is_completed(case_id: String) -> bool:
	return get_stars(case_id) > 0


func is_unlocked(case_ids: Array, case_id: String) -> bool:
	var position := case_ids.find(case_id)
	if position < 0:
		push_error("ProgressStore: case '%s' is not in case list %s" % [case_id, str(case_ids)])
		return false
	if position == 0:
		return true
	return is_completed(case_ids[position - 1])


func get_language() -> String:
	return _language


func set_language(code: String) -> void:
	_language = code
	save_progress()


func reset() -> void:
	_clear_memory()
	if FileAccess.file_exists(save_path):
		var remove_error := DirAccess.remove_absolute(save_path)
		if remove_error != OK:
			push_error("ProgressStore: cannot delete '%s' (error %d)" % [save_path, remove_error])


func _clear_memory() -> void:
	_best_stars = {}
	_language = DEFAULT_LANGUAGE


func _apply_saved_data(saved: Dictionary) -> void:
	var saved_stars: Variant = saved.get("stars", {})
	if saved_stars is Dictionary:
		for case_id in saved_stars:
			# JSON numbers load as float; stars are whole numbers.
			_best_stars[str(case_id)] = int(saved_stars[case_id])
	_language = str(saved.get("language", DEFAULT_LANGUAGE))
