class_name OrderingView
extends QuestionView
## Items are moved with up/down buttons; the answer is the array of item ids, top first.

var _item_ids_in_order: Array[String] = []


func get_answer() -> Variant:
	return _item_ids_in_order.duplicate()


func set_answer(answer: Variant) -> void:
	if answer is not Array or answer.size() != question["items"].size():
		push_error("OrderingView: answer must list every item id once, got %s" % [answer])
		return
	_item_ids_in_order.clear()
	for item_id in answer:
		_item_ids_in_order.append(item_id)
	_rebuild()


func _reset_state() -> void:
	_item_ids_in_order.clear()
	for item: Dictionary in question["items"]:
		_item_ids_in_order.append(item["id"])
	_shuffle_until_not_solved()


## A start state equal to the solution would let a trainee submit without doing anything.
## The items are listed in file order, which may itself be the solution, so always shuffle first.
func _shuffle_until_not_solved() -> void:
	if _item_ids_in_order.size() < 2:
		push_error("OrderingView: question '%s' needs at least two items" % question.get("id", "?"))
		return
	var correct_order: Array = question["correct_order"]
	_item_ids_in_order.shuffle()
	while _item_ids_in_order == correct_order:
		_item_ids_in_order.shuffle()


func _build_body() -> void:
	_body.add_child(_make_wrapping_label(Loc.ui("most_effective")))
	for position_index in _item_ids_in_order.size():
		_body.add_child(_make_item_row(position_index))
	_body.add_child(_make_wrapping_label(Loc.ui("least_effective")))


func _make_item_row(position_index: int) -> HBoxContainer:
	var item := _find_item(_item_ids_in_order[position_index])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var rank_label := Label.new()
	rank_label.text = Loc.number(position_index + 1)
	rank_label.custom_minimum_size = Vector2(32, 0)
	row.add_child(rank_label)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_child(_make_wrapping_label(Loc.text(item["text"])))
	if _locked and item.has("tag"):
		var tag_label := _make_wrapping_label(Loc.text(item["tag"]))
		tag_label.add_theme_color_override("font_color", CORRECT_COLOR)
		text_column.add_child(tag_label)
	row.add_child(text_column)

	var is_first := position_index == 0
	var is_last := position_index == _item_ids_in_order.size() - 1
	row.add_child(_make_move_button("↑", position_index, -1, is_first))
	row.add_child(_make_move_button("↓", position_index, 1, is_last))
	return row


func _make_move_button(symbol: String, position_index: int, direction: int, at_edge: bool) -> Button:
	var button := Button.new()
	button.text = symbol
	button.custom_minimum_size = Vector2(MINIMUM_TOUCH_HEIGHT, MINIMUM_TOUCH_HEIGHT)
	button.disabled = _locked or at_edge
	button.pressed.connect(_move_item.bind(position_index, direction))
	return button


func _move_item(position_index: int, direction: int) -> void:
	var target_index := position_index + direction
	if target_index < 0 or target_index >= _item_ids_in_order.size():
		push_error("OrderingView: cannot move item %d by %d" % [position_index, direction])
		return
	var moved_item_id := _item_ids_in_order[position_index]
	_item_ids_in_order[position_index] = _item_ids_in_order[target_index]
	_item_ids_in_order[target_index] = moved_item_id
	Sfx.play("select")
	_rebuild()


func _find_item(item_id: String) -> Dictionary:
	for item: Dictionary in question["items"]:
		if item["id"] == item_id:
			return item
	push_error("OrderingView: unknown item id '%s'" % item_id)
	return {}
