class_name MultiSelectView
extends QuestionView
## Any number of options; the answer is the array of chosen option ids.

var _selected_option_ids: Array[String] = []


func get_answer() -> Variant:
	return _selected_option_ids.duplicate()


func set_answer(answer: Variant) -> void:
	if answer is not Array:
		push_error("MultiSelectView: answer must be an Array of option ids, got %s" % [answer])
		return
	_selected_option_ids.clear()
	for option_id in answer:
		if option_id is String and not _selected_option_ids.has(option_id):
			_selected_option_ids.append(option_id)
		else:
			push_error("MultiSelectView: ignoring invalid option id %s" % [option_id])
	_rebuild()


func _reset_state() -> void:
	_selected_option_ids.clear()


func _is_answer_valid() -> bool:
	return not _selected_option_ids.is_empty()


func _build_body() -> void:
	_body.add_child(_make_wrapping_label(Loc.ui("choose_all")))
	for option: Dictionary in question["options"]:
		var option_id: String = option["id"]
		var is_selected := _selected_option_ids.has(option_id)
		var button := _make_choice_button(Loc.text(option["text"]), is_selected, _selected_color_for_result())
		button.disabled = _locked
		button.pressed.connect(_on_option_pressed.bind(option_id))
		_body.add_child(button)


func _on_option_pressed(option_id: String) -> void:
	if _selected_option_ids.has(option_id):
		_selected_option_ids.erase(option_id)
	else:
		_selected_option_ids.append(option_id)
	Sfx.play("select")
	_rebuild()
