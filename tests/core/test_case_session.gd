extends RefCounted

const CASE_PATH := "res://content/construction/cases/c01_bamboo_scaffold.json"

var t


func _new_session() -> CaseSession:
	return CaseSession.new(CaseLoader.load_case(CASE_PATH))


func _rect_center(session: CaseSession, hazard_index: int) -> Vector2:
	var rect: Array = session.case_data["hazards"][hazard_index]["rect"]
	return Vector2(rect[0] + rect[2] / 2.0, rect[1] + rect[3] / 2.0)


func _find_all_hazards(session: CaseSession) -> void:
	for index in session.case_data["hazards"].size():
		session.tap(_rect_center(session, index))


func _correct_answer(question: Dictionary) -> Variant:
	match question["type"]:
		"single_choice", "multi_select", "drag_ppe":
			return question["correct"]
		"ordering":
			return question["correct_order"]
		"dialogue":
			for choice in question["choices"]:
				if choice["quality"] == "best":
					return choice["id"]
	return null


func _session_at_questions() -> CaseSession:
	var session := _new_session()
	session.begin_hazard_hunt()
	_find_all_hazards(session)
	session.finish_hazard_hunt()
	return session


func _advance_to_question(session: CaseSession, question_id: String) -> void:
	while session.current_question()["id"] != question_id:
		session.submit_answer(_correct_answer(session.current_question()))
		session.next_question()


func test_starts_in_intro() -> void:
	t.assert_eq(_new_session().phase, CaseSession.Phase.INTRO)


func test_phase_changed_signal_fires() -> void:
	var session := _new_session()
	var seen: Array = []
	session.phase_changed.connect(func(phase): seen.append(phase))
	session.begin_hazard_hunt()
	t.assert_eq(seen, [CaseSession.Phase.HAZARD_HUNT])


func test_tap_on_hazard_hits() -> void:
	var session := _new_session()
	session.begin_hazard_hunt()
	var result := session.tap(_rect_center(session, 0))
	t.assert_true(result["hit"])
	t.assert_eq(result["hazard_id"], "no_harness")
	t.assert_false(result["already_found"])
	t.assert_eq(session.found_hazard_ids(), ["no_harness"] as Array[String])


func test_tap_inside_padding_hits() -> void:
	var session := _new_session()
	session.begin_hazard_hunt()
	var rect: Array = session.case_data["hazards"][0]["rect"]
	var result := session.tap(Vector2(rect[0] - 10, rect[1] + 5))
	t.assert_true(result["hit"])


func test_second_tap_reports_already_found() -> void:
	var session := _new_session()
	session.begin_hazard_hunt()
	session.tap(_rect_center(session, 0))
	var result := session.tap(_rect_center(session, 0))
	t.assert_true(result["hit"])
	t.assert_true(result["already_found"])
	t.assert_eq(session.found_hazard_ids().size(), 1)


func test_every_third_miss_shows_hint_and_counts_mistake() -> void:
	var session := _new_session()
	session.begin_hazard_hunt()
	var far_away := Vector2(1270, 10)
	t.assert_false(session.tap(far_away)["show_hint"])
	t.assert_false(session.tap(far_away)["show_hint"])
	var third := session.tap(far_away)
	t.assert_false(third["hit"])
	t.assert_true(third["show_hint"])
	t.assert_eq(session.mistakes(), 1)
	t.assert_eq(session.hint_hazard_id(), "no_harness")


func test_cannot_finish_hunt_early() -> void:
	var session := _new_session()
	session.begin_hazard_hunt()
	session.tap(_rect_center(session, 0))
	t.assert_false(session.finish_hazard_hunt())
	t.assert_eq(session.phase, CaseSession.Phase.HAZARD_HUNT)


func test_all_found_moves_to_questions() -> void:
	var session := _new_session()
	session.begin_hazard_hunt()
	var last_result := {}
	for index in session.case_data["hazards"].size():
		last_result = session.tap(_rect_center(session, index))
	t.assert_true(last_result["all_found"])
	t.assert_true(session.finish_hazard_hunt())
	t.assert_eq(session.phase, CaseSession.Phase.QUESTIONS)
	t.assert_eq(session.current_question()["id"], "main_risk")
	t.assert_eq(session.question_count(), 5)


func test_single_choice_wrong_then_right() -> void:
	var session := _session_at_questions()
	var wrong := session.submit_answer("noise")
	t.assert_false(wrong["correct"])
	t.assert_false(wrong["hint"].is_empty())
	t.assert_eq(session.mistakes(), 1)
	var right := session.submit_answer("falls")
	t.assert_true(right["correct"])
	t.assert_false(right["explanation"].is_empty())
	t.assert_eq(session.mistakes(), 1)


func test_cannot_skip_unanswered_question() -> void:
	var session := _session_at_questions()
	t.assert_false(session.next_question())
	t.assert_eq(session.question_index(), 0)
	t.assert_eq(session.phase, CaseSession.Phase.QUESTIONS)


func test_multi_select_ignores_order_and_rejects_partial() -> void:
	var session := _session_at_questions()
	_advance_to_question(session, "make_mason_safe")
	t.assert_false(session.submit_answer(["harness", "helmet"])["correct"])
	t.assert_true(session.submit_answer(["guardrail", "harness", "helmet"])["correct"])


func test_ordering_needs_exact_order() -> void:
	var session := _session_at_questions()
	_advance_to_question(session, "control_order")
	t.assert_false(session.submit_answer(["guardrail", "replace_pole", "barricade", "ppe"])["correct"])
	t.assert_true(session.submit_answer(["replace_pole", "guardrail", "barricade", "ppe"])["correct"])


func test_dialogue_qualities() -> void:
	var session := _session_at_questions()
	_advance_to_question(session, "persuade_karim")
	var mistakes_before := session.mistakes()
	var fail := session.submit_answer("ignore")
	t.assert_false(fail["correct"])
	t.assert_eq(fail["quality"], "fail")
	t.assert_false(fail["reply"].is_empty())
	t.assert_false(fail["feedback"].is_empty())
	var ok := session.submit_answer("threaten")
	t.assert_true(ok["correct"])
	t.assert_eq(ok["quality"], "ok")
	t.assert_eq(session.mistakes(), mistakes_before + 2)


func test_dialogue_best_has_no_mistake() -> void:
	var session := _session_at_questions()
	_advance_to_question(session, "persuade_karim")
	var best := session.submit_answer("explain")
	t.assert_true(best["correct"])
	t.assert_eq(best["quality"], "best")
	t.assert_eq(session.mistakes(), 0)


func test_drag_ppe_set_equality() -> void:
	var session := _session_at_questions()
	_advance_to_question(session, "equip_rahim")
	t.assert_false(session.submit_answer(["helmet", "boots", "gloves", "earmuffs"])["correct"])
	t.assert_true(session.submit_answer(["gloves", "helmet", "boots"])["correct"])


func test_full_perfect_run_gives_three_stars() -> void:
	var session := _session_at_questions()
	var moved := true
	while moved:
		session.submit_answer(_correct_answer(session.current_question()))
		moved = session.next_question()
	t.assert_eq(session.phase, CaseSession.Phase.SAFE_REVEAL)
	session.finish_reveal()
	t.assert_eq(session.phase, CaseSession.Phase.RESULT)
	var result := session.result()
	t.assert_eq(result["case_id"], "c01_bamboo_scaffold")
	t.assert_eq(result["stars"], 3)
	t.assert_eq(result["mistakes"], 0)
	t.assert_eq(result["hazards_found"], 4)


func test_stars_drop_with_mistakes() -> void:
	var session := _session_at_questions()
	session.submit_answer("noise")
	t.assert_eq(session.stars(), 2)
	session.submit_answer("dust")
	t.assert_eq(session.stars(), 2)
	session.submit_answer("heat")
	t.assert_eq(session.stars(), 1)


func test_wrong_phase_calls_are_rejected() -> void:
	var session := _new_session()
	t.assert_eq(session.submit_answer("falls"), {})
	t.assert_eq(session.current_question(), {})
	t.assert_false(session.finish_hazard_hunt())
