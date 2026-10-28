class_name CaseSession
extends RefCounted
## One play-through of one case: hazard hunt, questions, reveal, result.
## Pure logic with no scene nodes; the UI reads state and calls the methods.

signal phase_changed(phase: Phase)

enum Phase { INTRO, HAZARD_HUNT, QUESTIONS, SAFE_REVEAL, RESULT }

const TAP_PADDING := 16.0
const MISSES_PER_MISTAKE := 3

var case_data: Dictionary
var phase: Phase = Phase.INTRO

var _found_hazard_ids: Array[String] = []
var _miss_count := 0
var _mistake_count := 0
var _question_index := 0
var _current_question_answered := false
var _last_correct_result: Dictionary = {}


func _init(new_case_data: Dictionary) -> void:
	case_data = new_case_data


func begin_hazard_hunt() -> void:
	if not _require_phase(Phase.INTRO, "begin_hazard_hunt"):
		return
	_change_phase(Phase.HAZARD_HUNT)


func tap(point: Vector2) -> Dictionary:
	if not _require_phase(Phase.HAZARD_HUNT, "tap"):
		return {}
	var hazard_id := _hazard_id_at(point)
	if hazard_id != "":
		return _register_hazard_tap(hazard_id)
	return _register_miss()


func found_hazard_ids() -> Array[String]:
	return _found_hazard_ids.duplicate()


func hint_hazard_id() -> String:
	for hazard in case_data["hazards"]:
		if hazard["id"] not in _found_hazard_ids:
			return hazard["id"]
	return ""


func all_hazards_found() -> bool:
	return _found_hazard_ids.size() == case_data["hazards"].size()


func finish_hazard_hunt() -> bool:
	if not _require_phase(Phase.HAZARD_HUNT, "finish_hazard_hunt"):
		return false
	if not all_hazards_found():
		return false
	_change_phase(Phase.QUESTIONS)
	return true


func question_index() -> int:
	return _question_index


func question_count() -> int:
	return case_data["questions"].size()


func current_question() -> Dictionary:
	if not _require_phase(Phase.QUESTIONS, "current_question"):
		return {}
	return case_data["questions"][_question_index]


func submit_answer(answer: Variant) -> Dictionary:
	if not _require_phase(Phase.QUESTIONS, "submit_answer"):
		return {}
	if _current_question_answered:
		return _last_correct_result
	var question: Dictionary = case_data["questions"][_question_index]
	var result_data := _evaluate_answer(question, answer)
	_mistake_count += _mistakes_for_result(result_data)
	if result_data["correct"]:
		_current_question_answered = true
		_last_correct_result = result_data
	return result_data


func next_question() -> bool:
	if not _require_phase(Phase.QUESTIONS, "next_question"):
		return false
	if not _current_question_answered:
		push_error(
			"CaseSession: next_question called before question '%s' was answered correctly" % current_question()["id"]
		)
		return false
	if _question_index + 1 >= question_count():
		_change_phase(Phase.SAFE_REVEAL)
		return false
	_question_index += 1
	_current_question_answered = false
	_last_correct_result = {}
	return true


func finish_reveal() -> void:
	if not _require_phase(Phase.SAFE_REVEAL, "finish_reveal"):
		return
	_change_phase(Phase.RESULT)


func mistakes() -> int:
	return _mistake_count


func stars() -> int:
	if _mistake_count == 0:
		return 3
	if _mistake_count <= 2:
		return 2
	return 1


func result() -> Dictionary:
	return {
		"case_id": case_data["id"],
		"stars": stars(),
		"mistakes": _mistake_count,
		"hazards_found": _found_hazard_ids.size(),
	}


func _require_phase(expected_phase: Phase, method_name: String) -> bool:
	if phase == expected_phase:
		return true
	push_error(
		(
			"CaseSession: %s needs phase %s but phase is %s"
			% [method_name, Phase.keys()[expected_phase], Phase.keys()[phase]]
		)
	)
	return false


func _change_phase(new_phase: Phase) -> void:
	phase = new_phase
	phase_changed.emit(new_phase)


func _hazard_id_at(point: Vector2) -> String:
	for hazard in case_data["hazards"]:
		var rect_values: Array = hazard["rect"]
		var rect := Rect2(rect_values[0], rect_values[1], rect_values[2], rect_values[3])
		if rect.grow(TAP_PADDING).has_point(point):
			return hazard["id"]
	return ""


func _register_hazard_tap(hazard_id: String) -> Dictionary:
	var already_found := hazard_id in _found_hazard_ids
	if not already_found:
		_found_hazard_ids.append(hazard_id)
	return _tap_result(true, hazard_id, already_found, false)


func _register_miss() -> Dictionary:
	_miss_count += 1
	var show_hint := _miss_count % MISSES_PER_MISTAKE == 0
	if show_hint:
		_mistake_count += 1
	return _tap_result(false, "", false, show_hint)


func _tap_result(hit: bool, hazard_id: String, already_found: bool, show_hint: bool) -> Dictionary:
	return {
		"hit": hit,
		"hazard_id": hazard_id,
		"already_found": already_found,
		"show_hint": show_hint,
		"all_found": all_hazards_found(),
	}


func _evaluate_answer(question: Dictionary, answer: Variant) -> Dictionary:
	var quality := "fail"
	var chosen_choice: Dictionary = {}
	if question["type"] == "dialogue":
		chosen_choice = _find_choice(question, answer)
		quality = chosen_choice.get("quality", "fail")
	elif _is_correct_non_dialogue(question, answer):
		quality = "best"
	var correct := quality != "fail"
	return {
		"correct": correct,
		"quality": quality,
		"hint": {} if correct else question.get("hint", {}),
		"explanation": question.get("explanation", {}) if correct else {},
		"reply": chosen_choice.get("reply", {}),
		"feedback": chosen_choice.get("feedback", {}),
	}


func _mistakes_for_result(result_data: Dictionary) -> int:
	# A wrong answer and a merely acceptable ("ok") dialogue choice each cost one mistake.
	if not result_data["correct"] or result_data["quality"] == "ok":
		return 1
	return 0


func _find_choice(question: Dictionary, choice_id: Variant) -> Dictionary:
	for choice in question["choices"]:
		if choice["id"] == choice_id:
			return choice
	push_error("CaseSession: question '%s' has no choice '%s'" % [question["id"], str(choice_id)])
	return {}


func _is_correct_non_dialogue(question: Dictionary, answer: Variant) -> bool:
	match question["type"]:
		"single_choice":
			return answer == question["correct"]
		"multi_select", "drag_ppe":
			return answer is Array and _as_sorted_strings(answer) == _as_sorted_strings(question["correct"])
		"ordering":
			return answer is Array and _as_strings(answer) == _as_strings(question["correct_order"])
	push_error("CaseSession: unknown question type '%s'" % str(question["type"]))
	return false


# Answers may arrive as untyped Arrays, so compare as plain string arrays.
func _as_strings(values: Array) -> Array[String]:
	var strings: Array[String] = []
	for value in values:
		strings.append(str(value))
	return strings


func _as_sorted_strings(values: Array) -> Array[String]:
	var strings := _as_strings(values)
	strings.sort()
	return strings
