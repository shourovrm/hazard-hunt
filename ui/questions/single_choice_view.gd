class_name SingleChoiceView
extends QuestionView
## One option out of several; the answer is the option id.

var _selected_option_id := ""


func get_answer() -> Variant:
	return _selected_option_id


func set_answer(answer: Variant) -> void:
	if answer is not String:
		push_error("SingleChoiceView: answer must be a String option id, got %s" % [answer])
		return
	_selected_option_id = answer
	_rebuild()


func _reset_state() -> void:
	_selected_option_id = ""


func _is_answer_valid() -> bool:
	return _selected_option_id != ""


func _build_body() -> void:
	for option: Dictionary in question["options"]:
		var option_id: String = option["id"]
		var is_selected := option_id == _selected_option_id
		var button := _make_choice_button(Loc.text(option["text"]), is_selected, _selected_color_for_result())
		button.disabled = _locked
		button.pressed.connect(_on_option_pressed.bind(option_id))
		_body.add_child(button)


func _on_option_pressed(option_id: String) -> void:
	_selected_option_id = option_id
	_rebuild()
