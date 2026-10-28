class_name QuestionView
extends Control
## Base class of every question widget. It owns the shared layout (prompt, scrolling body,
## result area, Submit button), the lock state and the result display. Subclasses fill the
## body and define the answer shape from the table in docs/CONTRACT.md (Area A).

signal answer_submitted(answer: Variant)

const PANEL_SIZE := Vector2(760, 560)
const MINIMUM_TOUCH_HEIGHT := 64.0
const SELECTED_FILL_COLOR := Color(0.16, 0.36, 0.62)
const CORRECT_COLOR := Color(0.18, 0.62, 0.30)
const WRONG_COLOR := Color(0.85, 0.25, 0.22)
const HINT_BUTTON_WIDTH := 160.0
const SHOW_ANSWER_BUTTON_WIDTH := HINT_BUTTON_WIDTH

var question: Dictionary = {}

var _locked := false
var _hint_is_shown := false
var _has_wrong_result := false
var _solution_is_shown := false
var _last_result: Dictionary = {}
var _prompt_label: Label
var _body: VBoxContainer
var _result_area: VBoxContainer
var _submit_button: Button
var _hint_button: Button
var _show_answer_button: Button
var _scroll: ScrollContainer


func setup(new_question: Dictionary) -> void:
	if not new_question.has("prompt"):
		push_error("QuestionView: question '%s' has no prompt" % new_question.get("id", "?"))
		return
	question = new_question
	_locked = false
	_hint_is_shown = false
	_has_wrong_result = false
	_solution_is_shown = false
	_last_result = {}
	size = PANEL_SIZE
	_reset_state()
	_build_skeleton()
	if not Loc.language_changed.is_connected(_on_language_changed):
		# Bound to this node, so Godot drops the connection when the view is freed.
		Loc.language_changed.connect(_on_language_changed)
	_rebuild()


func get_answer() -> Variant:
	push_error("QuestionView.get_answer must be overridden")
	return null


func set_answer(_answer: Variant) -> void:
	push_error("QuestionView.set_answer must be overridden")


func submit() -> void:
	answer_submitted.emit(get_answer())


func show_result(result: Dictionary) -> void:
	if result.get("correct", false):
		Sfx.play("correct")
	else:
		Sfx.play("wrong")
	_last_result = result
	if result.get("correct", false):
		_locked = true
	else:
		_has_wrong_result = true
	_rebuild()
	_scroll_to_bottom_after_layout()


func is_locked() -> bool:
	return _locked


## Free help: shows the question's hint in the feedback area. It never changes the score,
## so it does not go through submit() or show_result().
func show_hint() -> void:
	if _locked or not question.has("hint"):
		return
	Sfx.play("select")
	_hint_is_shown = true
	_rebuild()
	_scroll_to_bottom_after_layout()


## Show answer after a wrong try: selects the correct answer in the UI so the trainee is never
## stuck. It never calls submit(), so the trainee still presses Submit, the decision or the
## dialogue choice to go on. The wrong try already counted, so this changes no score.
func show_solution() -> void:
	if not _can_show_answer():
		return
	Sfx.play("select")
	_solution_is_shown = true
	# Looked up by name: a direct CaseSession.correct_answer() call is a parse error until that
	# helper exists, and a parse error here would stop every question view from compiling.
	set_answer(Callable(CaseSession, "correct_answer").call(question))
	_rebuild()


## Called once from setup() so subclasses can initialise their selection state.
func _reset_state() -> void:
	pass


## Subclasses add their input widgets to `_body`. Called on every rebuild.
func _build_body() -> void:
	pass


func _is_answer_valid() -> bool:
	return true


## The show answer button needs a wrong try first. Once locked, the answer is already right.
func _can_show_answer() -> bool:
	return _has_wrong_result and not _locked


## Dialogue submits by tapping a choice and has no Submit button.
func _uses_submit_button() -> bool:
	return true


## Lets a subclass show extra result content (such as an NPC reply) above the status line.
func _build_result_extras(_result: Dictionary) -> void:
	pass


func _rebuild() -> void:
	if _prompt_label == null:
		return
	_prompt_label.text = Loc.text(question["prompt"])
	_clear_children(_body)
	_build_body()
	_clear_children(_result_area)
	_build_result_area()
	if _solution_is_shown:
		_result_area.add_child(_make_wrapping_label(Loc.ui("solution_shown")))
	_submit_button.visible = _uses_submit_button() and not _locked
	_submit_button.text = Loc.ui("submit")
	_submit_button.disabled = _locked or not _is_answer_valid()
	_hint_button.text = Loc.ui("hint_button")
	_hint_button.visible = not _locked and question.has("hint")
	_show_answer_button.text = Loc.ui("show_answer")
	_show_answer_button.visible = _can_show_answer()


func _build_skeleton() -> void:
	for existing_child in get_children():
		remove_child(existing_child)
		existing_child.queue_free()
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(_scroll)

	var scrolled_content := VBoxContainer.new()
	scrolled_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrolled_content.add_theme_constant_override("separation", 12)
	_scroll.add_child(scrolled_content)

	_prompt_label = _make_wrapping_label("")
	scrolled_content.add_child(_prompt_label)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	scrolled_content.add_child(_body)
	_result_area = VBoxContainer.new()
	_result_area.add_theme_constant_override("separation", 8)
	scrolled_content.add_child(_result_area)

	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 12)
	layout.add_child(footer_row)

	_hint_button = Button.new()
	_hint_button.custom_minimum_size = Vector2(HINT_BUTTON_WIDTH, MINIMUM_TOUCH_HEIGHT)
	_hint_button.pressed.connect(show_hint)
	footer_row.add_child(_hint_button)

	_submit_button = Button.new()
	_submit_button.theme_type_variation = "PrimaryButton"
	_submit_button.custom_minimum_size = Vector2(0, MINIMUM_TOUCH_HEIGHT)
	_submit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_submit_button.pressed.connect(_on_submit_pressed)
	footer_row.add_child(_submit_button)

	_show_answer_button = Button.new()
	_show_answer_button.custom_minimum_size = Vector2(SHOW_ANSWER_BUTTON_WIDTH, MINIMUM_TOUCH_HEIGHT)
	_show_answer_button.pressed.connect(show_solution)
	footer_row.add_child(_show_answer_button)


func _on_submit_pressed() -> void:
	Sfx.play("tap")
	submit()


## The feedback labels are added in this frame, and the scroll maximum only covers them after
## the layout pass, so the bottom is read one frame later.
func _scroll_to_bottom_after_layout() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_scroll):
		return
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _build_result_area() -> void:
	if _last_result.is_empty():
		if _hint_is_shown:
			_result_area.add_child(_make_wrapping_label(Loc.text(question["hint"])))
		return
	_build_result_extras(_last_result)
	var is_correct: bool = _last_result.get("correct", false)
	var status_label := _make_wrapping_label(Loc.ui("correct") if is_correct else Loc.ui("try_again"))
	status_label.add_theme_color_override("font_color", CORRECT_COLOR if is_correct else WRONG_COLOR)
	_result_area.add_child(status_label)
	var detail: Dictionary = _last_result.get("explanation" if is_correct else "hint", {})
	if not detail.is_empty():
		_result_area.add_child(_make_wrapping_label(Loc.text(detail)))


func _on_language_changed(_language: String) -> void:
	_rebuild()


func _make_wrapping_label(label_text: String) -> Label:
	var label := Label.new()
	label.text = label_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## A full-width, left-aligned, wrapping button. A selected button gets a filled style so the
## state is visible without relying on the theme's toggle look.
func _make_choice_button(button_text: String, is_selected: bool, selected_color: Color = SELECTED_FILL_COLOR) -> Button:
	var button := Button.new()
	button.text = button_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, MINIMUM_TOUCH_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_selected:
		_apply_selected_look(button, selected_color)
	return button


## Fills `button` with `fill_color` in every state and sets white text, so the selected state
## shows without relying on the theme's toggle look.
func _apply_selected_look(button: Button, fill_color: Color) -> void:
	var selected_style := _make_selected_style(fill_color)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, selected_style)
	for color_name in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"
	]:
		button.add_theme_color_override(color_name, Color.WHITE)


func _make_selected_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


## Selected choices turn green once the question is solved and locked.
func _selected_color_for_result() -> Color:
	if _locked:
		return CORRECT_COLOR
	return SELECTED_FILL_COLOR


func _load_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("QuestionView: cannot load texture '%s' for question '%s'" % [path, question.get("id", "?")])
	return texture


## Removes at once (so text queries do not see stale children) and frees safely, because this
## may run inside a signal emitted by one of the children.
func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
