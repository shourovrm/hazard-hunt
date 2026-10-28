class_name GateCheckView
extends QuestionView
## Workers arrive one at a time. The player taps the PPE each worker is missing, then presses one
## action button: "Let in" when nothing is marked, "Send back for gear" otherwise. The answer is a
## Dictionary of worker id to the ppe ids marked on the FIRST decision for that worker.

enum DecisionState { UNDECIDED, CORRECT, WRONG }

const WORKER_IMAGE_HEIGHT := 300.0
const COLUMN_SEPARATION := 16
const ICON_MAX_WIDTH := 48

var _current_index := 0
var _marked_ppe_ids: Array[String] = []
var _decision_state := DecisionState.UNDECIDED
var _first_decisions: Dictionary = {}


func get_answer() -> Variant:
	return _first_decisions.duplicate(true)


## Test hook and replay hook: records the first decisions for every worker and moves to the
## last worker, so that submit() emits the given answer.
func set_answer(answer: Variant) -> void:
	if answer is not Dictionary:
		push_error("GateCheckView: answer must be a Dictionary of worker id to ppe ids, got %s" % [answer])
		return
	_first_decisions = answer.duplicate(true)
	_current_index = _worker_count() - 1
	_marked_ppe_ids.clear()
	_decision_state = DecisionState.UNDECIDED
	_rebuild()


func current_worker_index() -> int:
	return _current_index


func set_marked(ppe_id: String, marked: bool) -> void:
	if _locked or _decision_state == DecisionState.CORRECT:
		return
	if marked and not _marked_ppe_ids.has(ppe_id):
		_marked_ppe_ids.append(ppe_id)
	elif not marked:
		_marked_ppe_ids.erase(ppe_id)
	_decision_state = DecisionState.UNDECIDED
	_rebuild()


## Compares the marks with the worker's missing gear. Only the first decision per worker is
## recorded, so correcting a wrong decision does not change the answer. Returns whether it was right.
func decide() -> bool:
	var worker := _current_worker()
	if not _first_decisions.has(worker["id"]):
		_first_decisions[worker["id"]] = _marked_ppe_ids.duplicate()
	var is_right := _marks_match(_marked_ppe_ids, worker["missing"])
	if is_right:
		_decision_state = DecisionState.CORRECT
		Sfx.play("correct")
	else:
		_decision_state = DecisionState.WRONG
		Sfx.play("wrong")
	_rebuild()
	if is_right and _is_last_worker():
		submit()
	return is_right


## Advances only after a right decision: the player must not skip a worker who is still wrong.
func next_worker() -> void:
	if _decision_state != DecisionState.CORRECT or _is_last_worker():
		return
	_current_index += 1
	_marked_ppe_ids.clear()
	_decision_state = DecisionState.UNDECIDED
	_hint_is_shown = false
	_solution_is_shown = false
	_rebuild()


func _reset_state() -> void:
	_current_index = 0
	_marked_ppe_ids.clear()
	_decision_state = DecisionState.UNDECIDED
	_first_decisions = {}


func _uses_submit_button() -> bool:
	return false


## Only the current worker's decision is wrong at this point; earlier workers were already right.
func _can_show_answer() -> bool:
	return _decision_state == DecisionState.WRONG and not _locked


## Marks only the current worker's missing gear. The base version would call set_answer(), which
## records every worker and jumps to the last one, so it does not fit a per-worker decision.
## The wrong first decision is already recorded, so this changes no score.
func show_solution() -> void:
	if not _can_show_answer():
		return
	Sfx.play("select")
	_solution_is_shown = true
	_marked_ppe_ids.assign(_current_worker()["missing"])
	_decision_state = DecisionState.UNDECIDED
	_rebuild()


## The per-worker feedback lives in the right column, so the shared result area shows only the
## result from the case player (status and explanation).
func _build_result_area() -> void:
	if _last_result.is_empty():
		return
	super._build_result_area()


func _build_body() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", COLUMN_SEPARATION)
	columns.add_child(_make_worker_image())
	columns.add_child(_make_decision_column())
	_body.add_child(columns)


func _make_worker_image() -> TextureRect:
	var texture := _load_texture(_worker_image_path())
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(_image_width_for(texture), WORKER_IMAGE_HEIGHT)
	return image


## Keeps the source aspect ratio at the fixed height, so a tall or wide sprite is not squashed.
func _image_width_for(texture: Texture2D) -> float:
	if texture == null or texture.get_height() == 0:
		return WORKER_IMAGE_HEIGHT
	return WORKER_IMAGE_HEIGHT * texture.get_width() / float(texture.get_height())


func _make_decision_column() -> VBoxContainer:
	var worker := _current_worker()
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	column.add_child(_make_wrapping_label(Loc.text(worker["name"])))
	column.add_child(_make_wrapping_label(_counter_text()))
	column.add_child(_make_wrapping_label(Loc.ui("mark_missing")))
	for ppe_item: Dictionary in question["ppe_items"]:
		column.add_child(_make_toggle_button(ppe_item))
	column.add_child(_make_action_button())
	column.add_child(_make_feedback_box(worker))
	return column


func _counter_text() -> String:
	return Loc.ui("worker_counter", {"number": _current_index + 1, "total": _worker_count()})


func _make_toggle_button(ppe_item: Dictionary) -> Button:
	var is_marked := _marked_ppe_ids.has(ppe_item["id"])
	var button := _make_choice_button(Loc.text(ppe_item["text"]), is_marked, _selected_color_for_result())
	button.icon = _load_texture(ppe_item["icon"])
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", ICON_MAX_WIDTH)
	button.disabled = _locked or _decision_state == DecisionState.CORRECT
	button.pressed.connect(_on_toggle_pressed.bind(ppe_item["id"]))
	return button


func _on_toggle_pressed(ppe_id: String) -> void:
	Sfx.play("select")
	set_marked(ppe_id, not _marked_ppe_ids.has(ppe_id))


## One button does both jobs: it decides the worker, or moves on after a right decision.
func _make_action_button() -> Button:
	var button := Button.new()
	button.theme_type_variation = "PrimaryButton"
	button.custom_minimum_size = Vector2(0, MINIMUM_TOUCH_HEIGHT)
	button.disabled = _locked
	if _decision_state == DecisionState.CORRECT and not _is_last_worker():
		button.text = Loc.ui("next_worker")
	elif _marked_ppe_ids.is_empty():
		button.text = Loc.ui("let_in")
	else:
		button.text = Loc.ui("send_back")
	button.pressed.connect(_on_action_pressed)
	return button


func _on_action_pressed() -> void:
	Sfx.play("tap")
	if _decision_state == DecisionState.CORRECT:
		next_worker()
	else:
		decide()


func _make_feedback_box(worker: Dictionary) -> VBoxContainer:
	var feedback_box := VBoxContainer.new()
	feedback_box.add_theme_constant_override("separation", 8)
	match _decision_state:
		DecisionState.CORRECT:
			var correct_label := _make_wrapping_label(Loc.ui("correct"))
			correct_label.add_theme_color_override("font_color", CORRECT_COLOR)
			feedback_box.add_child(correct_label)
			feedback_box.add_child(_make_wrapping_label(Loc.text(worker["feedback"])))
		DecisionState.WRONG:
			var try_again_label := _make_wrapping_label(Loc.ui("try_again"))
			try_again_label.add_theme_color_override("font_color", WRONG_COLOR)
			feedback_box.add_child(try_again_label)
			feedback_box.add_child(_make_wrapping_label(Loc.text(question["hint"])))
		_:
			if _hint_is_shown:
				feedback_box.add_child(_make_wrapping_label(Loc.text(question["hint"])))
	return feedback_box


## Shows the safe photo of a sent-back worker once the line is solved, so the outcome is visible.
func _worker_image_path() -> String:
	var worker := _current_worker()
	var was_sent_back: bool = not worker["missing"].is_empty()
	if was_sent_back and (_decision_state == DecisionState.CORRECT or _locked):
		return worker["image_safe"]
	return worker["image"]


## Once the last worker is right, the view submits; there is no further button.
func _is_last_worker() -> bool:
	return _current_index == _worker_count() - 1


func _worker_count() -> int:
	return question["workers"].size()


func _current_worker() -> Dictionary:
	return question["workers"][_current_index]


func _marks_match(marked: Array[String], missing: Array) -> bool:
	if marked.size() != missing.size():
		return false
	for ppe_id in marked:
		if not missing.has(ppe_id):
			return false
	return true
