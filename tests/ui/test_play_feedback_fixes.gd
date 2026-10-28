extends RefCounted
## Fixes found during the first phone play-through of case 1.

const CASE_PATH := "res://content/construction/cases/c01_bamboo_scaffold.json"

var t


func _question(question_id: String) -> Dictionary:
	var case_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE_PATH))
	for question in case_data["questions"]:
		if question["id"] == question_id:
			return question
	return {}


func _mounted_view(question: Dictionary) -> QuestionView:
	var view := QuestionFactory.create(question)
	t.root.add_child(view)
	return view


func _buttons_with_text(node: Node, text: String) -> Array[Button]:
	var found: Array[Button] = []
	if node is Button and node.text == text:
		found.append(node)
	for child in node.get_children():
		found.append_array(_buttons_with_text(child, text))
	return found


func _texture_paths(node: Node) -> Array[String]:
	var paths: Array[String] = []
	if node is TextureRect and node.texture != null:
		paths.append(node.texture.resource_path)
	for child in node.get_children():
		paths.append_array(_texture_paths(child))
	return paths


func _correct_result(question: Dictionary) -> Dictionary:
	return {
		"correct": true,
		"quality": "best",
		"hint": {},
		"explanation": question["explanation"],
		"reply": {},
		"feedback": {}
	}


func test_submit_button_hidden_after_correct_result() -> void:
	Loc.set_language("en")
	var question := _question("main_risk")
	var view := _mounted_view(question)
	view.set_answer("falls")
	view.show_result(_correct_result(question))
	for button in _buttons_with_text(view, Loc.ui("submit")):
		t.assert_false(button.visible, "submit button still visible after a correct answer")


func test_equipped_ppe_item_keeps_its_tray_slot() -> void:
	Loc.set_language("en")
	var question := _question("equip_rahim")
	var view := _mounted_view(question)
	view.set_answer(["helmet"])
	var helmet_buttons := _buttons_with_text(view, "Helmet")
	t.assert_eq(helmet_buttons.size(), 1, "helmet should stay in the tray as one labelled button")
	if helmet_buttons.size() == 1:
		t.assert_true(helmet_buttons[0].visible, "equipped helmet slot hidden")


func test_worker_shows_safe_image_after_correct_result() -> void:
	var question := _question("equip_rahim")
	var view := _mounted_view(question)
	view.set_answer(question["correct"])
	view.show_result(_correct_result(question))
	t.assert_true(
		question["target_image_safe"] in _texture_paths(view), "worker image did not switch to the safe version"
	)
