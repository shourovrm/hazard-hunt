extends RefCounted

const CASE_PATH := "res://content/construction/cases/c02_gate_check.json"

var t


func _gate_question() -> Dictionary:
	var case_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE_PATH))
	return case_data["questions"][0]


func _mounted_view() -> QuestionView:
	var view := QuestionFactory.create(_gate_question())
	t.root.add_child(view)
	return view


func _has_button(node: Node, text: String) -> bool:
	if node is Button and node.text == text and node.visible:
		return true
	for child in node.get_children():
		if _has_button(child, text):
			return true
	return false


func test_factory_creates_gate_view() -> void:
	var view := QuestionFactory.create(_gate_question())
	t.assert_not_null(view)
	if view != null:
		t.assert_eq(view.question["id"], "gate_line")
		view.free()


func test_right_decision_moves_to_next_worker() -> void:
	var view := _mounted_view()
	t.assert_eq(view.current_worker_index(), 0)
	t.assert_true(view.decide(), "letting Sohel in should be right")
	view.next_worker()
	t.assert_eq(view.current_worker_index(), 1)


func test_wrong_decision_stays_and_can_be_corrected() -> void:
	var view := _mounted_view()
	view.decide()
	view.next_worker()
	t.assert_false(view.decide(), "letting Rina in without boots should be wrong")
	t.assert_eq(view.current_worker_index(), 1)
	view.set_marked("boots", true)
	t.assert_true(view.decide())


func test_action_button_label_follows_marks() -> void:
	Loc.set_language("en")
	var view := _mounted_view()
	t.assert_true(_has_button(view, Loc.ui("let_in")), "Let in button missing")
	view.set_marked("helmet", true)
	t.assert_true(_has_button(view, Loc.ui("send_back")), "Send back button missing")


func test_full_line_submits_first_decisions() -> void:
	var view := _mounted_view()
	var emitted: Array = []
	view.answer_submitted.connect(func(answer): emitted.append(answer))
	var question := _gate_question()
	for index in question["workers"].size():
		var worker: Dictionary = question["workers"][index]
		if worker["id"] == "rina":
			view.decide()
		for ppe_id in worker["missing"]:
			view.set_marked(ppe_id, true)
		t.assert_true(view.decide(), "decision for %s" % worker["id"])
		if index < question["workers"].size() - 1:
			view.next_worker()
	t.assert_eq(emitted.size(), 1, "view should submit once after the last worker")
	if emitted.size() == 1:
		t.assert_eq(emitted[0]["rina"], [], "Rina's first decision was 'let in'")
		t.assert_same_items(emitted[0]["foreman"], ["helmet", "vest"])


func test_set_answer_then_submit() -> void:
	var view := _mounted_view()
	var emitted: Array = []
	view.answer_submitted.connect(func(answer): emitted.append(answer))
	var answer := {
		"sohel": [],
		"rina": ["boots"],
		"jamal": ["helmet"],
		"nayeem": ["vest"],
		"sumon": [],
		"foreman": ["helmet", "vest"]
	}
	view.set_answer(answer)
	view.submit()
	t.assert_eq(emitted.size(), 1)
	if emitted.size() == 1:
		t.assert_eq(emitted[0].size(), 6)


func test_language_switch_rebuilds_text() -> void:
	Loc.set_language("en")
	var view := _mounted_view()
	t.assert_true("Sohel" in t.collect_text(view))
	Loc.set_language("bn")
	t.assert_true("সোহেল" in t.collect_text(view))
	Loc.set_language("en")
