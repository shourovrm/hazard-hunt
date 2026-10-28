extends RefCounted

const CASE_PATHS := [
	"res://content/construction/cases/c01_bamboo_scaffold.json",
	"res://content/construction/cases/c02_gate_check.json",
	"res://content/construction/cases/c03_electrical.json",
]

var t


func _all_questions() -> Array:
	var questions: Array = []
	for path in CASE_PATHS:
		var case_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		questions.append_array(case_data["questions"])
	return questions


func _visible_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.visible:
		return node
	for child in node.get_children():
		var found := _visible_button(child, text)
		if found != null:
			return found
	return null


func test_every_question_has_a_hint_button() -> void:
	Loc.set_language("en")
	for question in _all_questions():
		var view := QuestionFactory.create(question)
		t.root.add_child(view)
		t.assert_not_null(_visible_button(view, Loc.ui("hint_button")), "no hint button for %s" % question["id"])


func test_show_hint_displays_hint_text() -> void:
	Loc.set_language("en")
	for question in _all_questions():
		var view := QuestionFactory.create(question)
		t.root.add_child(view)
		view.show_hint()
		t.assert_true(question["hint"]["en"] in t.collect_text(view), "hint text not shown for %s" % question["id"])


func test_hint_button_hidden_after_correct_result() -> void:
	Loc.set_language("en")
	var question: Dictionary = _all_questions()[0]
	var view := QuestionFactory.create(question)
	t.root.add_child(view)
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
	t.assert_eq(_visible_button(view, Loc.ui("hint_button")), null, "hint button still visible after correct answer")
