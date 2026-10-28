extends RefCounted

const CASE_PATH := "res://content/construction/cases/c12_near_miss_investigation.json"

var t


func _case_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CASE_PATH))


func _question(case_data: Dictionary, question_id: String) -> Dictionary:
	for question in case_data["questions"]:
		if question["id"] == question_id:
			return question
	return {}


func _session_at(question_id: String) -> CaseSession:
	var session := CaseSession.new(CaseLoader.load_case(CASE_PATH))
	session.begin_hazard_hunt()
	while session.current_question()["id"] != question_id:
		session.submit_answer(CaseSession.correct_answer(session.current_question()))
		session.next_question()
	return session


func test_investigation_case_is_valid() -> void:
	t.assert_eq(CaseLoader.validate(_case_data()), [] as Array[String])


func test_evidence_board_needs_every_card() -> void:
	var session := _session_at("study_evidence")
	t.assert_false(session.submit_answer(["rods_loose", "open_edge"])["correct"])
	var all_ids := ["deadline", "rods_loose", "open_edge", "passer_by", "hand_rope", "empty_store"]
	t.assert_true(session.submit_answer(all_ids)["correct"])


func test_cause_chain_needs_exact_order() -> void:
	var session := _session_at("five_whys")
	var wrong := ["event", "careless", "no_edge_protection", "store_empty", "no_owner"]
	t.assert_false(session.submit_answer(wrong)["correct"])
	var swapped := ["event", "no_edge_protection", "loose_rods", "store_empty", "no_owner"]
	t.assert_false(session.submit_answer(swapped)["correct"])
	var right := ["event", "loose_rods", "no_edge_protection", "store_empty", "no_owner"]
	t.assert_true(session.submit_answer(right)["correct"])


func test_matching_needs_every_row_right() -> void:
	var session := _session_at("action_plan")
	var answer := {
		"tie_rods": "supervisor", "stock": "store_officer", "walkway": "site_manager", "hoist_rule": "supervisor"
	}
	t.assert_false(session.submit_answer(answer)["correct"])
	answer["hoist_rule"] = "site_manager"
	t.assert_true(session.submit_answer(answer)["correct"])


func test_correct_answer_helper_for_new_types() -> void:
	var case_data := _case_data()
	t.assert_same_items(
		CaseSession.correct_answer(_question(case_data, "study_evidence")),
		["rods_loose", "open_edge", "passer_by", "hand_rope", "empty_store", "deadline"]
	)
	t.assert_eq(
		CaseSession.correct_answer(_question(case_data, "five_whys")),
		_question(case_data, "five_whys")["correct_chain"]
	)
	t.assert_eq(
		CaseSession.correct_answer(_question(case_data, "action_plan")), _question(case_data, "action_plan")["correct"]
	)


func test_chain_with_unknown_card_is_reported() -> void:
	var case_data := _case_data()
	_question(case_data, "five_whys")["correct_chain"][1] = "aliens"
	t.assert_false(CaseLoader.validate(case_data).is_empty())


func test_matching_with_unknown_target_is_reported() -> void:
	var case_data := _case_data()
	_question(case_data, "action_plan")["correct"]["stock"] = "president"
	t.assert_false(CaseLoader.validate(case_data).is_empty())


func test_evidence_card_needs_both_languages() -> void:
	var case_data := _case_data()
	_question(case_data, "study_evidence")["cards"][0]["caption"].erase("bn")
	t.assert_false(CaseLoader.validate(case_data).is_empty())
