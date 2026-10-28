extends RefCounted

const CASE_PATHS := [
	"res://content/construction/cases/c01_bamboo_scaffold.json",
	"res://content/construction/cases/c03_electrical.json",
	"res://content/construction/cases/c04_trench.json",
	"res://content/construction/cases/c12_near_miss_investigation.json",
]
const GATE_CASE_PATH := "res://content/construction/cases/c02_gate_check.json"

var t


func _questions(path: String) -> Array:
	var case_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	return case_data["questions"]


func _visible_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.visible:
		return node
	for child in node.get_children():
		var found := _visible_button(child, text)
		if found != null:
			return found
	return null


func _wrong_result(question: Dictionary) -> Dictionary:
	return {
		"correct": false, "quality": "fail", "hint": question["hint"], "explanation": {}, "reply": {}, "feedback": {}
	}


func _same_answer(actual: Variant, expected: Variant) -> bool:
	if expected is Array:
		var sorted_actual: Array = actual.duplicate()
		var sorted_expected: Array = expected.duplicate()
		if actual is Array and expected.size() > 0 and not (actual == expected):
			sorted_actual.sort()
			sorted_expected.sort()
		return sorted_actual == sorted_expected
	return str(actual) == str(expected)


func test_correct_answer_helper_wins_every_question() -> void:
	for path in CASE_PATHS + [GATE_CASE_PATH]:
		var session := CaseSession.new(CaseLoader.load_case(path))
		session.begin_hazard_hunt()
		for hazard in session.case_data["hazards"]:
			var rect: Array = hazard["rect"]
			session.tap(Vector2(rect[0] + rect[2] / 2.0, rect[1] + rect[3] / 2.0))
		if session.phase == CaseSession.Phase.HAZARD_HUNT:
			session.finish_hazard_hunt()
		var moved := true
		while moved:
			var result := session.submit_answer(CaseSession.correct_answer(session.current_question()))
			t.assert_true(result["correct"], "%s %s" % [path, session.current_question()["id"]])
			moved = session.next_question()
		t.assert_eq(session.mistakes(), 0, path)


func test_show_answer_appears_only_after_wrong_result() -> void:
	Loc.set_language("en")
	for path in CASE_PATHS:
		for question in _questions(path):
			var view := QuestionFactory.create(question)
			t.root.add_child(view)
			t.assert_eq(
				_visible_button(view, Loc.ui("show_answer")), null, "show answer too early: %s" % question["id"]
			)
			view.show_result(_wrong_result(question))
			t.assert_not_null(_visible_button(view, Loc.ui("show_answer")), "no show answer: %s" % question["id"])


func test_show_solution_selects_correct_answer() -> void:
	Loc.set_language("en")
	for path in CASE_PATHS:
		for question in _questions(path):
			var view := QuestionFactory.create(question)
			t.root.add_child(view)
			view.show_result(_wrong_result(question))
			view.show_solution()
			var expected: Variant = CaseSession.correct_answer(question)
			if question["type"] == "permit_check":
				t.assert_eq(view.get_answer()["marks"], expected["marks"], question["id"])
			elif question["type"] in ["multi_select", "drag_ppe"]:
				t.assert_same_items(view.get_answer(), expected, question["id"])
			else:
				t.assert_true(_same_answer(view.get_answer(), expected), "wrong solution shown for %s" % question["id"])
			t.assert_true(
				Loc.ui("solution_shown") in t.collect_text(view), "solution note missing: %s" % question["id"]
			)


func test_gate_show_answer_marks_current_worker() -> void:
	Loc.set_language("en")
	var view := QuestionFactory.create(_questions(GATE_CASE_PATH)[0])
	t.root.add_child(view)
	view.decide()
	view.next_worker()
	t.assert_false(view.decide(), "Rina without boots should be wrong")
	t.assert_not_null(_visible_button(view, Loc.ui("show_answer")), "no show answer after wrong gate decision")
	view.show_solution()
	t.assert_true(view.decide(), "after show answer, the decision should be right")
