class_name PermitCheckView
extends QuestionView
## A paper permit form: one row per condition, each marked OK or Not OK, then the trainee approves
## or refuses the permit. The answer is {"marks": {check_id: status}, "decision": decision}.

const STATUS_OK := "ok"
const STATUS_NOT_OK := "not_ok"
const DECISION_APPROVE := "approve"
const DECISION_REFUSE := "refuse"
const PAPER_FILL_COLOR := Color(0.97, 0.95, 0.88)
const PAPER_BORDER_COLOR := Color(0.35, 0.30, 0.25)
const PAPER_TEXT_COLOR := Color(0.1, 0.1, 0.1)
const PAPER_TITLE_FONT_SIZE := 26
const PAPER_PADDING := 16

var _marks: Dictionary = {}
var _chosen_decision := ""


func get_answer() -> Variant:
	return {"marks": _marks.duplicate(), "decision": _chosen_decision}


## Test hook and show-answer hook: sets every mark and highlights the decision. The trainee
## still presses the decision button to submit.
func set_answer(answer: Variant) -> void:
	if answer is not Dictionary:
		push_error("PermitCheckView: answer must be a Dictionary with marks and decision, got %s" % [answer])
		return
	var marks: Dictionary = answer["marks"]
	_marks = marks.duplicate()
	_chosen_decision = answer["decision"]
	_rebuild()


func set_mark(check_id: String, status: String) -> void:
	if _locked:
		return
	_marks[check_id] = status
	# A changed mark makes an earlier decision stale, so the trainee must decide again.
	_chosen_decision = ""
	_rebuild()


## Sets the decision and submits it. Does nothing until every row is marked, the same rule
## that keeps the decision buttons disabled.
func choose_decision(decision: String) -> void:
	if _locked or not _all_checks_marked():
		return
	_chosen_decision = decision
	_rebuild()
	submit()


func _reset_state() -> void:
	_marks = {}
	_chosen_decision = ""


func _uses_submit_button() -> bool:
	return false


func _build_body() -> void:
	_body.add_child(_make_paper_form())
	_body.add_child(_make_decision_row())


func _make_paper_form() -> PanelContainer:
	var form := PanelContainer.new()
	form.add_theme_stylebox_override("panel", _make_paper_style())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	form.add_child(rows)
	var title_label := _make_paper_label(Loc.text(question["permit_title"]))
	title_label.add_theme_font_size_override("font_size", PAPER_TITLE_FONT_SIZE)
	rows.add_child(title_label)
	for check: Dictionary in question["checks"]:
		rows.add_child(HSeparator.new())
		rows.add_child(_make_check_row(check))
	return form


func _make_paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_FILL_COLOR
	style.border_color = PAPER_BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(PAPER_PADDING)
	return style


func _make_paper_label(label_text: String) -> Label:
	var label := _make_wrapping_label(label_text)
	label.add_theme_color_override("font_color", PAPER_TEXT_COLOR)
	return label


func _make_check_row(check: Dictionary) -> VBoxContainer:
	var check_id: String = check["id"]
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_paper_label(Loc.text(check["text"])))
	var status_buttons := HBoxContainer.new()
	status_buttons.add_theme_constant_override("separation", 12)
	status_buttons.add_child(_make_status_button(check_id, STATUS_OK, Loc.ui("check_ok")))
	status_buttons.add_child(_make_status_button(check_id, STATUS_NOT_OK, Loc.ui("check_not_ok")))
	row.add_child(status_buttons)
	return row


func _make_status_button(check_id: String, status: String, button_text: String) -> Button:
	var is_selected: bool = _marks.get(check_id, "") == status
	var button := _make_choice_button(button_text, is_selected, _status_color(status))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = _locked
	button.pressed.connect(_on_status_pressed.bind(check_id, status))
	return button


## Before the lock a mark is just a choice. After the lock every row is correct, so OK rows
## turn green and Not OK rows turn red, which shows the correct status of each condition.
func _status_color(status: String) -> Color:
	if not _locked:
		return SELECTED_FILL_COLOR
	if status == STATUS_OK:
		return CORRECT_COLOR
	return WRONG_COLOR


func _on_status_pressed(check_id: String, status: String) -> void:
	Sfx.play("select")
	set_mark(check_id, status)


func _make_decision_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_make_decision_button(DECISION_APPROVE, Loc.ui("approve_permit"), false))
	row.add_child(_make_decision_button(DECISION_REFUSE, Loc.ui("refuse_permit"), true))
	return row


## Refuse is the primary action on the form, so it takes the PrimaryButton look.
func _make_decision_button(decision: String, button_text: String, is_primary: bool) -> Button:
	var button := Button.new()
	button.text = button_text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, MINIMUM_TOUCH_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_primary:
		button.theme_type_variation = "PrimaryButton"
	button.disabled = _locked or not _all_checks_marked()
	if _chosen_decision == decision:
		_apply_selected_look(button, _selected_color_for_result())
	button.pressed.connect(_on_decision_pressed.bind(decision))
	return button


func _on_decision_pressed(decision: String) -> void:
	Sfx.play("tap")
	choose_decision(decision)


func _all_checks_marked() -> bool:
	for check: Dictionary in question["checks"]:
		if not _marks.has(check["id"]):
			return false
	return true
