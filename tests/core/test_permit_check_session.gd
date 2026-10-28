extends RefCounted

const CASE_PATH := "res://content/construction/cases/c04_trench.json"

var t


func _case_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CASE_PATH))


func _permit_question(case_data: Dictionary) -> Dictionary:
	return case_data["questions"][0]


func _correct_answer(question: Dictionary) -> Dictionary:
	var marks := {}
	for check in question["checks"]:
		marks[check["id"]] = check["status"]
	return {"marks": marks, "decision": question["correct_decision"]}


func _session_at_permit() -> CaseSession:
	var session := CaseSession.new(CaseLoader.load_case(CASE_PATH))
	session.begin_hazard_hunt()
	for hazard in session.case_data["hazards"]:
		var rect: Array = hazard["rect"]
		session.tap(Vector2(rect[0] + rect[2] / 2.0, rect[1] + rect[3] / 2.0))
	session.finish_hazard_hunt()
	return session


func test_trench_case_is_valid() -> void:
	t.assert_eq(CaseLoader.validate(_case_data()), [] as Array[String])


func test_correct_marks_and_decision() -> void:
	var session := _session_at_permit()
	var result := session.submit_answer(_correct_answer(session.current_question()))
	t.assert_true(result["correct"])
	t.assert_eq(session.mistakes(), 0)


func test_one_wrong_mark_is_wrong() -> void:
	var session := _session_at_permit()
	var answer := _correct_answer(session.current_question())
	answer["marks"]["utilities"] = "not_ok"
	var result := session.submit_answer(answer)
	t.assert_false(result["correct"])
	t.assert_false(result["hint"].is_empty())
	t.assert_eq(session.mistakes(), 1)


func test_right_marks_wrong_decision_is_wrong() -> void:
	var session := _session_at_permit()
	var answer := _correct_answer(session.current_question())
	answer["decision"] = "approve"
	t.assert_false(session.submit_answer(answer)["correct"])


func test_decision_must_match_checks() -> void:
	var case_data := _case_data()
	_permit_question(case_data)["correct_decision"] = "approve"
	t.assert_false(CaseLoader.validate(case_data).is_empty())


func test_unknown_status_is_reported() -> void:
	var case_data := _case_data()
	_permit_question(case_data)["checks"][0]["status"] = "maybe"
	t.assert_false(CaseLoader.validate(case_data).is_empty())
