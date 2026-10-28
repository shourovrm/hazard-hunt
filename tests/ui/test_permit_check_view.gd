extends RefCounted

const CASE_PATH := "res://content/construction/cases/c04_trench.json"

var t


func _permit_question() -> Dictionary:
	var case_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE_PATH))
	return case_data["questions"][0]


func _mounted_view() -> QuestionView:
	var view := QuestionFactory.create(_permit_question())
	t.root.add_child(view)
	return view


func _button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.visible:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null


func _mark_all_correctly(view: QuestionView) -> void:
	for check in _permit_question()["checks"]:
		view.set_mark(check["id"], check["status"])


func test_factory_creates_permit_view() -> void:
	var view := QuestionFactory.create(_permit_question())
	t.assert_not_null(view)
	if view != null:
		t.assert_eq(view.question["id"], "dig_permit")
		view.free()


func test_decision_buttons_wait_for_all_marks() -> void:
	Loc.set_language("en")
	var view := _mounted_view()
	var refuse := _button(view, Loc.ui("refuse_permit"))
	t.assert_not_null(refuse, "no refuse button")
	if refuse != null:
		t.assert_true(refuse.disabled, "refuse should be disabled before all rows are marked")
	_mark_all_correctly(view)
	refuse = _button(view, Loc.ui("refuse_permit"))
	if refuse != null:
		t.assert_false(refuse.disabled, "refuse should be enabled after all rows are marked")


func test_choose_decision_submits_marks_and_decision() -> void:
	var view := _mounted_view()
	var emitted: Array = []
	view.answer_submitted.connect(func(answer): emitted.append(answer))
	_mark_all_correctly(view)
	view.choose_decision("refuse")
	t.assert_eq(emitted.size(), 1)
	if emitted.size() == 1:
		t.assert_eq(emitted[0]["decision"], "refuse")
		t.assert_eq(emitted[0]["marks"]["utilities"], "ok")
		t.assert_eq(emitted[0]["marks"]["shoring"], "not_ok")


func test_shows_permit_title_and_checks() -> void:
	Loc.set_language("en")
	var view := _mounted_view()
	var text: String = t.collect_text(view)
	t.assert_true(_permit_question()["permit_title"]["en"] in text, "permit title missing")
	t.assert_true(_permit_question()["checks"][0]["text"]["en"] in text, "first check missing")
	Loc.set_language("bn")
	t.assert_true(_permit_question()["permit_title"]["bn"] in t.collect_text(view), "bangla title missing")
	Loc.set_language("en")
