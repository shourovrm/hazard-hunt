extends RefCounted

const CASE_PATH := "res://content/construction/cases/c01_bamboo_scaffold.json"

var t


func _questions() -> Array:
	var case_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE_PATH))
	return case_data["questions"]


func _question(question_id: String) -> Dictionary:
	for question in _questions():
		if question["id"] == question_id:
			return question
	return {}


func _correct_answer(question: Dictionary) -> Variant:
	match question["type"]:
		"single_choice", "multi_select", "drag_ppe":
			return question["correct"]
		"ordering":
			return question["correct_order"]
		"dialogue":
			return "explain"
	return null


func _mounted_view(question: Dictionary) -> QuestionView:
	var view := QuestionFactory.create(question)
	t.root.add_child(view)
	return view


func test_factory_creates_a_view_for_every_type() -> void:
	for question in _questions():
		var view := QuestionFactory.create(question)
		t.assert_not_null(view, "no view for type %s" % question["type"])
		if view != null:
			t.assert_eq(view.question["id"], question["id"])
			view.free()


func test_factory_rejects_unknown_type() -> void:
	t.assert_eq(QuestionFactory.create({"id": "x", "type": "essay"}), null)


func test_set_answer_then_submit_emits_answer() -> void:
	for question in _questions():
		var view := _mounted_view(question)
		var emitted: Array = []
		view.answer_submitted.connect(func(answer): emitted.append(answer))
		var answer: Variant = _correct_answer(question)
		view.set_answer(answer)
		view.submit()
		t.assert_eq(emitted.size(), 1, "%s should emit once" % question["id"])
		if emitted.size() == 1:
			if question["type"] in ["multi_select", "drag_ppe"]:
				t.assert_same_items(emitted[0], answer, question["id"])
			else:
				t.assert_eq(emitted[0], answer, question["id"])


func test_ordering_never_starts_solved() -> void:
	var question := _question("control_order")
	for attempt in 10:
		var view := _mounted_view(question)
		t.assert_ne(view.get_answer(), question["correct_order"], "ordering started solved")
		t.assert_same_items(view.get_answer(), question["correct_order"])
		view.free()


func test_wrong_result_keeps_view_unlocked_and_shows_hint() -> void:
	Loc.set_language("en")
	var question := _question("main_risk")
	var view := _mounted_view(question)
	view.show_result(
		{"correct": false, "quality": "fail", "hint": question["hint"], "explanation": {}, "reply": {}, "feedback": {}}
	)
	t.assert_false(view.is_locked())
	t.assert_true(question["hint"]["en"] in t.collect_text(view), "hint not shown")


func test_correct_result_locks_view_and_shows_explanation() -> void:
	Loc.set_language("en")
	var question := _question("main_risk")
	var view := _mounted_view(question)
	view.show_result(
		{
			"correct": true,
			"quality": "best",
			"hint": {},
			"explanation": question["explanation"],
			"reply": {},
			"feedback": {}
		}
	)
	t.assert_true(view.is_locked())
	t.assert_true(question["explanation"]["en"] in t.collect_text(view), "explanation not shown")


func test_dialogue_shows_npc_line_and_reply() -> void:
	Loc.set_language("en")
	var question := _question("persuade_karim")
	var view := _mounted_view(question)
	t.assert_true(question["npc_line"]["en"] in t.collect_text(view), "npc line not shown")
	var choice: Dictionary = question["choices"][2]
	view.show_result(
		{
			"correct": false,
			"quality": "fail",
			"hint": question["hint"],
			"explanation": {},
			"reply": choice["reply"],
			"feedback": choice["feedback"]
		}
	)
	t.assert_true(choice["reply"]["en"] in t.collect_text(view), "npc reply not shown")


func test_language_switch_rebuilds_text() -> void:
	Loc.set_language("en")
	var question := _question("make_mason_safe")
	var view := _mounted_view(question)
	t.assert_true(question["prompt"]["en"] in t.collect_text(view), "english prompt missing")
	Loc.set_language("bn")
	t.assert_true(question["prompt"]["bn"] in t.collect_text(view), "bangla prompt missing after switch")
	Loc.set_language("en")
