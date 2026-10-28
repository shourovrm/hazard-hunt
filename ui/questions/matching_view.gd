class_name MatchingView
extends QuestionView
## One row per action: the action text sits above one toggle button per responsible person, and a
## row holds exactly one chosen person. The answer is a Dictionary of item id to target id.

const ROW_SEPARATION := 6
const TARGET_BUTTON_SEPARATION := 12

var _matches: Dictionary = {}


func get_answer() -> Variant:
	return _matches.duplicate()


## Test hook and show-answer hook: sets every row to the given target. The trainee still presses
## Submit to go on.
func set_answer(answer: Variant) -> void:
	if answer is not Dictionary:
		push_error("MatchingView: answer must be a Dictionary of item id to target id, got %s" % [answer])
		return
	_matches = answer.duplicate()
	_rebuild()


## Chooses one target for one row. Choosing another target in the same row replaces the first.
func set_match(item_id: String, target_id: String) -> void:
	if _locked:
		return
	if not _item_ids().has(item_id) or not _target_ids().has(target_id):
		push_error(
			(
				"MatchingView: unknown item '%s' or target '%s' in question '%s'"
				% [item_id, target_id, question.get("id", "?")]
			)
		)
		return
	_matches[item_id] = target_id
	_rebuild()


func _reset_state() -> void:
	_matches = {}


func _is_answer_valid() -> bool:
	for item_id in _item_ids():
		if not _matches.has(item_id):
			return false
	return true


func _build_body() -> void:
	for item: Dictionary in question["items"]:
		_body.add_child(_make_item_row(item))


func _make_item_row(item: Dictionary) -> VBoxContainer:
	var item_id: String = item["id"]
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	row.add_child(_make_wrapping_label(Loc.text(item["text"])))
	var target_buttons := HBoxContainer.new()
	target_buttons.add_theme_constant_override("separation", TARGET_BUTTON_SEPARATION)
	for target: Dictionary in question["targets"]:
		target_buttons.add_child(_make_target_button(item_id, target))
	row.add_child(target_buttons)
	return row


func _make_target_button(item_id: String, target: Dictionary) -> Button:
	var target_id: String = target["id"]
	var is_chosen: bool = _matches.get(item_id, "") == target_id
	var button := _make_choice_button(Loc.text(target["text"]), is_chosen, _selected_color_for_result())
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.disabled = _locked
	button.pressed.connect(_on_target_pressed.bind(item_id, target_id))
	return button


func _on_target_pressed(item_id: String, target_id: String) -> void:
	Sfx.play("select")
	set_match(item_id, target_id)


func _item_ids() -> Array[String]:
	var item_ids: Array[String] = []
	for item: Dictionary in question["items"]:
		item_ids.append(item["id"])
	return item_ids


func _target_ids() -> Array[String]:
	var target_ids: Array[String] = []
	for target: Dictionary in question["targets"]:
		target_ids.append(target["id"])
	return target_ids
