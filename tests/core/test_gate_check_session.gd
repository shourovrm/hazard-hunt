extends RefCounted

const CASE_PATH := "res://content/construction/cases/c02_gate_check.json"

var t


func _case_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CASE_PATH))


func _perfect_answer(question: Dictionary) -> Dictionary:
	var answer := {}
	for worker in question["workers"]:
		answer[worker["id"]] = worker["missing"].duplicate()
	return answer


func _session_at_gate() -> CaseSession:
	var session := CaseSession.new(CaseLoader.load_case(CASE_PATH))
	session.begin_hazard_hunt()
	return session


func test_gate_case_is_valid() -> void:
	t.assert_eq(CaseLoader.validate(_case_data()), [] as Array[String])


func test_case_without_hazards_skips_hunt() -> void:
	var session := CaseSession.new(CaseLoader.load_case(CASE_PATH))
	var seen: Array = []
	session.phase_changed.connect(func(phase): seen.append(phase))
	session.begin_hazard_hunt()
	t.assert_eq(session.phase, CaseSession.Phase.QUESTIONS)
	t.assert_eq(seen, [CaseSession.Phase.QUESTIONS])
	t.assert_eq(session.current_question()["id"], "gate_line")


func test_perfect_gate_check_is_best() -> void:
	var session := _session_at_gate()
	var result := session.submit_answer(_perfect_answer(session.current_question()))
	t.assert_true(result["correct"])
	t.assert_eq(result["quality"], "best")
	t.assert_eq(session.mistakes(), 0)
	t.assert_false(result["explanation"].is_empty())


func test_wrong_first_decisions_count_as_mistakes() -> void:
	var session := _session_at_gate()
	var answer := _perfect_answer(session.current_question())
	answer["rina"] = []
	answer["foreman"] = ["helmet"]
	var result := session.submit_answer(answer)
	t.assert_true(result["correct"])
	t.assert_eq(result["quality"], "ok")
	t.assert_eq(session.mistakes(), 2)


func test_missing_worker_is_rejected() -> void:
	var session := _session_at_gate()
	var answer := _perfect_answer(session.current_question())
	answer.erase("sumon")
	var result := session.submit_answer(answer)
	t.assert_false(result["correct"])
	t.assert_eq(session.mistakes(), 1)


func test_unknown_missing_item_is_reported() -> void:
	var case_data := _case_data()
	case_data["questions"][0]["workers"][1]["missing"] = ["parachute"]
	t.assert_false(CaseLoader.validate(case_data).is_empty())


func test_empty_worker_list_is_reported() -> void:
	var case_data := _case_data()
	case_data["questions"][0]["workers"] = []
	t.assert_false(CaseLoader.validate(case_data).is_empty())
