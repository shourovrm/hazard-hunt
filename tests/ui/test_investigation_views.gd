extends RefCounted

const CASE_PATH := "res://content/construction/cases/c12_near_miss_investigation.json"

var t


func _question(question_id: String) -> Dictionary:
	var case_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE_PATH))
	for question in case_data["questions"]:
		if question["id"] == question_id:
			return question
	return {}


func _mounted(question_id: String) -> QuestionView:
	var view := QuestionFactory.create(_question(question_id))
	t.root.add_child(view)
	return view


func _visible_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _visible_button(child, text)
		if found != null:
			return found
	return null


func test_factory_creates_all_three_views() -> void:
	for question_id in ["study_evidence", "five_whys", "action_plan"]:
		var view := QuestionFactory.create(_question(question_id))
		t.assert_not_null(view, "no view for %s" % question_id)
		if view != null:
			view.free()


func test_evidence_board_flip_and_done_button() -> void:
	Loc.set_language("en")
	var view := _mounted("study_evidence")
	var done := _visible_button(view, Loc.ui("done_studying"))
	t.assert_not_null(done, "no done button")
	if done != null:
		t.assert_true(done.disabled, "done should wait until every photo is turned")
	var question := _question("study_evidence")
	view.flip_card("rods_loose")
	t.assert_true(view.is_card_flipped("rods_loose"))
	t.assert_true(question["cards"][0]["caption"]["en"] in t.collect_text(view), "caption not shown after flip")
	for card in question["cards"]:
		if not view.is_card_flipped(card["id"]):
			view.flip_card(card["id"])
	done = _visible_button(view, Loc.ui("done_studying"))
	if done != null:
		t.assert_false(done.disabled, "done should be enabled after every photo is turned")
	var emitted: Array = []
	view.answer_submitted.connect(func(answer): emitted.append(answer))
	view.submit()
	t.assert_eq(emitted.size(), 1)
	if emitted.size() == 1:
		t.assert_same_items(emitted[0], CaseSession.correct_answer(question))


func test_cause_chain_set_answer_and_submit() -> void:
	Loc.set_language("en")
	var view := _mounted("five_whys")
	var question := _question("five_whys")
	t.assert_true(Loc.ui("root_cause") in t.collect_text(view), "root cause slot label missing")
	t.assert_true(question["cards"][1]["text"]["en"] in t.collect_text(view), "distractor card missing from pool")
	var emitted: Array = []
	view.answer_submitted.connect(func(answer): emitted.append(answer))
	view.set_answer(question["correct_chain"])
	view.submit()
	t.assert_eq(emitted.size(), 1)
	if emitted.size() == 1:
		t.assert_eq(emitted[0], question["correct_chain"])


func test_matching_rows_and_submit() -> void:
	Loc.set_language("en")
	var view := _mounted("action_plan")
	var question := _question("action_plan")
	t.assert_true(question["targets"][1]["text"]["en"] in t.collect_text(view), "target buttons missing")
	var emitted: Array = []
	view.answer_submitted.connect(func(answer): emitted.append(answer))
	for item_id in question["correct"]:
		view.set_match(item_id, question["correct"][item_id])
	view.submit()
	t.assert_eq(emitted.size(), 1)
	if emitted.size() == 1:
		t.assert_eq(emitted[0], question["correct"])


func test_language_switch_rebuilds_new_views() -> void:
	Loc.set_language("en")
	var view := _mounted("five_whys")
	Loc.set_language("bn")
	t.assert_true(Loc.ui("root_cause") in t.collect_text(view), "bangla label missing after switch")
	Loc.set_language("en")
