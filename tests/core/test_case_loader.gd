extends RefCounted

const CASE_PATH := "res://content/construction/cases/c01_bamboo_scaffold.json"
const SECTOR_PATH := "res://content/construction/sector.json"

var t


func _real_case() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CASE_PATH))


func _has_message_containing(messages: Array[String], fragment: String) -> bool:
	for message in messages:
		if fragment in message:
			return true
	return false


func test_load_real_case() -> void:
	var case_data := CaseLoader.load_case(CASE_PATH)
	t.assert_eq(case_data.get("id"), "c01_bamboo_scaffold")
	t.assert_eq(case_data["questions"].size(), 5)


func test_real_case_is_valid() -> void:
	t.assert_eq(CaseLoader.validate(_real_case()), [] as Array[String])


func test_missing_file_returns_empty() -> void:
	t.assert_eq(CaseLoader.load_case("res://content/does_not_exist.json"), {})


func test_missing_id_is_reported() -> void:
	var case_data := _real_case()
	case_data.erase("id")
	t.assert_true(_has_message_containing(CaseLoader.validate(case_data), "id"))


func test_missing_bangla_text_is_reported() -> void:
	var case_data := _real_case()
	case_data["questions"][0]["prompt"].erase("bn")
	t.assert_false(CaseLoader.validate(case_data).is_empty())


func test_unknown_question_type_is_reported() -> void:
	var case_data := _real_case()
	case_data["questions"][0]["type"] = "essay"
	t.assert_true(_has_message_containing(CaseLoader.validate(case_data), "essay"))


func test_single_choice_correct_must_be_an_option() -> void:
	var case_data := _real_case()
	case_data["questions"][0]["correct"] = "nonsense"
	t.assert_false(CaseLoader.validate(case_data).is_empty())


func test_multi_select_unknown_correct_id_is_reported() -> void:
	var case_data := _real_case()
	case_data["questions"][1]["correct"] = ["harness", "parachute"]
	t.assert_false(CaseLoader.validate(case_data).is_empty())


func test_ordering_must_be_permutation() -> void:
	var case_data := _real_case()
	case_data["questions"][2]["correct_order"] = ["replace_pole", "guardrail", "ppe"]
	t.assert_false(CaseLoader.validate(case_data).is_empty())


func test_dialogue_needs_a_best_choice() -> void:
	var case_data := _real_case()
	for choice in case_data["questions"][3]["choices"]:
		if choice["quality"] == "best":
			choice["quality"] = "ok"
	t.assert_false(CaseLoader.validate(case_data).is_empty())


func test_bad_hazard_rect_is_reported() -> void:
	var case_data := _real_case()
	case_data["hazards"][0]["rect"] = [10, 10, -5]
	t.assert_false(CaseLoader.validate(case_data).is_empty())


func test_duplicate_question_ids_are_reported() -> void:
	var case_data := _real_case()
	case_data["questions"][1]["id"] = case_data["questions"][0]["id"]
	t.assert_false(CaseLoader.validate(case_data).is_empty())


func test_load_sector() -> void:
	var sector := CaseLoader.load_sector(SECTOR_PATH)
	t.assert_eq(sector.get("id"), "construction")
	t.assert_eq(sector["cases"].size(), 2)
