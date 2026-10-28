class_name CauseChainView
extends QuestionView
## The "5 Whys" chain. Left: slots from "What happened" down to "Root cause", each filled by tapping
## a card in the pool on the right. Tapping a filled slot sends its card back to the pool. The answer
## is the array of card ids in slot order, top first.

const LABEL_FONT_SIZE := 16
const CARD_TEXT_FONT_SIZE := 20
const SLOT_COLUMN_WIDTH := 330.0
const COLUMN_SEPARATION := 16
const SLOT_FILL_COLOR := Color(0.97, 0.95, 0.88)
const SLOT_BORDER_COLOR := Color(0.35, 0.30, 0.25)
const SLOT_TEXT_COLOR := Color(0.1, 0.1, 0.1)
const LINK_COLOR := Color(0.95, 0.55, 0.15)
const LINK_WIDTH := 4.0
const LINK_HEIGHT := 14.0
const EMPTY_SLOT := ""

var _slot_card_ids: Array = []


func get_answer() -> Variant:
	return _slot_card_ids.duplicate()


## Test and show-answer hook: fills the slots in the order given. Slots after the end of the
## array stay empty, so a partial answer leaves Submit disabled.
func set_answer(answer: Variant) -> void:
	if answer is not Array or answer.size() > _slot_count():
		push_error("CauseChainView: answer must list at most %d card ids, got %s" % [_slot_count(), answer])
		return
	_clear_slots()
	for slot_index in answer.size():
		_slot_card_ids[slot_index] = answer[slot_index]
	_rebuild()


func submit() -> void:
	if not _is_answer_valid():
		push_error("CauseChainView: cannot submit while a slot is empty")
		return
	super.submit()


func _reset_state() -> void:
	_clear_slots()


func _is_answer_valid() -> bool:
	return not _slot_card_ids.has(EMPTY_SLOT)


func _build_body() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", COLUMN_SEPARATION)
	_body.add_child(columns)
	columns.add_child(_make_chain_column())
	columns.add_child(_make_pool_column())


func _make_chain_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(SLOT_COLUMN_WIDTH, 0)
	column.add_theme_constant_override("separation", 4)
	for slot_index in _slot_count():
		if slot_index > 0:
			column.add_child(_make_link())
		column.add_child(_make_slot_label(slot_index))
		column.add_child(_make_slot_button(slot_index))
	column.add_child(_make_clear_button())
	return column


func _make_link() -> ColorRect:
	var link := ColorRect.new()
	link.color = LINK_COLOR
	link.custom_minimum_size = Vector2(LINK_WIDTH, LINK_HEIGHT)
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return link


func _make_slot_label(slot_index: int) -> Label:
	var label := _make_wrapping_label(_slot_label_text(slot_index))
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	return label


## The first slot is the event, the last is the root cause, and the slots between are numbered
## "Why? (n)" starting at 1.
func _slot_label_text(slot_index: int) -> String:
	if slot_index == 0:
		return Loc.ui("what_happened")
	if slot_index == _slot_count() - 1:
		return Loc.ui("root_cause")
	return Loc.ui("why_slot", {"number": slot_index})


## A filled slot is enabled so tapping it returns its card. An empty slot is disabled and looks like
## a blank paper panel. Once the chain is locked every slot turns green.
func _make_slot_button(slot_index: int) -> Button:
	var card_id: String = _slot_card_ids[slot_index]
	var button := Button.new()
	if card_id != EMPTY_SLOT:
		button.text = _card_text(card_id)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, MINIMUM_TOUCH_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", CARD_TEXT_FONT_SIZE)
	button.disabled = _locked or card_id == EMPTY_SLOT
	if _locked:
		_apply_selected_look(button, CORRECT_COLOR)
	else:
		_apply_paper_look(button)
	button.pressed.connect(_on_slot_pressed.bind(slot_index))
	return button


func _apply_paper_look(button: Button) -> void:
	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = SLOT_FILL_COLOR
	paper_style.border_color = SLOT_BORDER_COLOR
	paper_style.set_border_width_all(2)
	paper_style.set_corner_radius_all(6)
	paper_style.content_margin_left = 12
	paper_style.content_margin_right = 12
	paper_style.content_margin_top = 8
	paper_style.content_margin_bottom = 8
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, paper_style)
	for color_name in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"
	]:
		button.add_theme_color_override(color_name, SLOT_TEXT_COLOR)


func _make_clear_button() -> Button:
	var button := Button.new()
	button.text = Loc.ui("clear_chain")
	button.custom_minimum_size = Vector2(0, MINIMUM_TOUCH_HEIGHT)
	button.disabled = _locked
	button.pressed.connect(_on_clear_pressed)
	return button


func _make_pool_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	for card: Dictionary in question["cards"]:
		if not _slot_card_ids.has(card["id"]):
			column.add_child(_make_pool_button(card["id"]))
	return column


func _make_pool_button(card_id: String) -> Button:
	var button := _make_choice_button(_card_text(card_id), false)
	button.add_theme_font_size_override("font_size", CARD_TEXT_FONT_SIZE)
	button.disabled = _locked
	button.pressed.connect(_on_pool_card_pressed.bind(card_id))
	return button


## Puts the card into the first empty slot. When every slot is full the tap does nothing, so the
## trainee must free a slot first.
func _on_pool_card_pressed(card_id: String) -> void:
	var empty_slot_index := _slot_card_ids.find(EMPTY_SLOT)
	if empty_slot_index == -1:
		return
	Sfx.play("select")
	_slot_card_ids[empty_slot_index] = card_id
	_rebuild()


func _on_slot_pressed(slot_index: int) -> void:
	Sfx.play("select")
	_slot_card_ids[slot_index] = EMPTY_SLOT
	_rebuild()


func _on_clear_pressed() -> void:
	Sfx.play("tap")
	_clear_slots()
	_rebuild()


func _clear_slots() -> void:
	_slot_card_ids = []
	for _index in _slot_count():
		_slot_card_ids.append(EMPTY_SLOT)


func _slot_count() -> int:
	return question["correct_chain"].size()


func _card_text(card_id: String) -> String:
	for card: Dictionary in question["cards"]:
		if card["id"] == card_id:
			return Loc.text(card["text"])
	push_error("CauseChainView: unknown card id '%s'" % card_id)
	return ""
