class_name DialogueView
extends QuestionView
## An NPC speaks and the trainee taps one reply; tapping submits the choice id at once.

const PORTRAIT_SIZE := Vector2(112, 112)
const BUBBLE_FILL_COLOR := Color(0.93, 0.93, 0.90)
const BUBBLE_TEXT_COLOR := Color(0.1, 0.1, 0.1)

var _selected_choice_id := ""


func get_answer() -> Variant:
	return _selected_choice_id


func set_answer(answer: Variant) -> void:
	if answer is not String:
		push_error("DialogueView: answer must be a String choice id, got %s" % [answer])
		return
	_selected_choice_id = answer
	_rebuild()


func _reset_state() -> void:
	_selected_choice_id = ""


func _uses_submit_button() -> bool:
	return false


func _build_body() -> void:
	_body.add_child(_make_speaker_row())
	for choice: Dictionary in question["choices"]:
		var choice_id: String = choice["id"]
		var is_selected := choice_id == _selected_choice_id
		var button := _make_choice_button(Loc.text(choice["text"]), is_selected, _selected_color_for_result())
		button.disabled = _locked
		button.pressed.connect(_on_choice_pressed.bind(choice_id))
		_body.add_child(button)


func _make_speaker_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var speaker_column := VBoxContainer.new()
	speaker_column.add_child(_make_portrait(question["npc_portrait"]))
	var name_label := Label.new()
	name_label.text = Loc.text(question["npc_name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_column.add_child(name_label)
	row.add_child(speaker_column)

	row.add_child(_make_speech_bubble(Loc.text(question["npc_line"])))
	return row


func _make_portrait(texture_path: String) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = _load_texture(texture_path)
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return portrait


func _make_speech_bubble(bubble_text: String) -> PanelContainer:
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = BUBBLE_FILL_COLOR
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	bubble.add_theme_stylebox_override("panel", style)
	var label := _make_wrapping_label(bubble_text)
	label.add_theme_color_override("font_color", BUBBLE_TEXT_COLOR)
	bubble.add_child(label)
	return bubble


func _build_result_extras(result: Dictionary) -> void:
	var reply: Dictionary = result.get("reply", {})
	if not reply.is_empty():
		_result_area.add_child(_make_speech_bubble(Loc.text(reply)))
	var feedback: Dictionary = result.get("feedback", {})
	if not feedback.is_empty():
		_result_area.add_child(_make_wrapping_label(Loc.text(feedback)))


func _on_choice_pressed(choice_id: String) -> void:
	_selected_choice_id = choice_id
	_rebuild()
	submit()
