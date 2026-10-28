extends RefCounted
## Every case listed in a sector must load, validate, reference existing files and be winnable.

const SECTOR_PATHS := ["res://content/construction/sector.json"]

var t


func _case_paths() -> Array:
	var paths: Array = []
	for sector_path in SECTOR_PATHS:
		paths.append_array(CaseLoader.load_sector(sector_path)["cases"])
	return paths


func _collect_resource_paths(value: Variant, found: Array[String]) -> void:
	if value is String and value.begins_with("res://"):
		found.append(value)
	elif value is Dictionary:
		for key in value:
			_collect_resource_paths(value[key], found)
	elif value is Array:
		for item in value:
			_collect_resource_paths(item, found)


func _perfect_answer(question: Dictionary) -> Variant:
	match question["type"]:
		"single_choice", "multi_select", "drag_ppe":
			return question["correct"]
		"ordering":
			return question["correct_order"]
		"dialogue":
			for choice in question["choices"]:
				if choice["quality"] == "best":
					return choice["id"]
		"gate_check":
			var answer := {}
			for worker in question["workers"]:
				answer[worker["id"]] = worker["missing"]
			return answer
	return null


func test_every_case_is_valid() -> void:
	for path in _case_paths():
		var case_data := CaseLoader.load_case(path)
		t.assert_false(case_data.is_empty(), "case failed to load: %s" % path)


func test_every_referenced_file_exists() -> void:
	for path in _case_paths():
		var found: Array[String] = []
		_collect_resource_paths(CaseLoader.load_case(path), found)
		for resource_path in found:
			t.assert_true(ResourceLoader.exists(resource_path), "%s references missing %s" % [path, resource_path])


func test_every_case_can_be_won_with_three_stars() -> void:
	for path in _case_paths():
		var session := CaseSession.new(CaseLoader.load_case(path))
		session.begin_hazard_hunt()
		for hazard in session.case_data["hazards"]:
			var rect: Array = hazard["rect"]
			session.tap(Vector2(rect[0] + rect[2] / 2.0, rect[1] + rect[3] / 2.0))
		if session.phase == CaseSession.Phase.HAZARD_HUNT:
			t.assert_true(session.finish_hazard_hunt(), "hazards not all findable by centre tap in %s" % path)
		var moved := true
		while moved:
			session.submit_answer(_perfect_answer(session.current_question()))
			moved = session.next_question()
		session.finish_reveal()
		t.assert_eq(session.stars(), 3, path)
