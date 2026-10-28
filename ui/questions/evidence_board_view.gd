class_name EvidenceBoardView
extends QuestionView
## A cork board of photo cards. Tapping a card turns it over to show its caption on a paper back.
## The trainee must turn every card at least once before Submit, labelled "I have studied the
## evidence", is enabled. The answer is an Array of the card ids turned at least once.

const CORK_FILL_COLOR := Color(0.74, 0.56, 0.36)
const CORK_PADDING := 12
const CORK_CORNER_RADIUS := 8
const PAPER_FILL_COLOR := Color(0.97, 0.95, 0.88)
const NAVY_TEXT_COLOR := Color(0.11, 0.18, 0.33)
const CARD_SIZE := Vector2(230, 150)
const CARD_COLUMN_COUNT := 3
const CARD_SEPARATION := 16
const CARD_CORNER_RADIUS := 6
const CARD_BORDER_WIDTH := 2
const CAPTION_FONT_SIZE := 19
const PAPER_PADDING := 10
## Half of the flip: the card squashes to zero width, swaps its face, then opens again.
const FLIP_HALF_SECONDS := 0.15
const FRONT_NODE_NAME := "Front"
const BACK_NODE_NAME := "Back"

var _turned_card_ids: Array[String] = []
var _flipped_card_ids: Array[String] = []
var _card_buttons: Dictionary = {}
var _flip_tweens: Dictionary = {}
var _seen_label: Label


func get_answer() -> Variant:
	return _turned_card_ids.duplicate()


## Test hook and show-answer hook: marks the given cards as turned and showing their backs.
## The trainee still presses Submit to go on.
func set_answer(answer: Variant) -> void:
	if answer is not Array:
		push_error("EvidenceBoardView: answer must be an Array of card ids, got %s" % [answer])
		return
	_turned_card_ids.assign(answer)
	_flipped_card_ids.assign(answer)
	_rebuild()


## Turns the card over (or back). The state changes at once; the squash animation only changes
## the look of the face, so tests and the submit rule never wait for it.
func flip_card(card_id: String) -> void:
	if _locked:
		return
	if not _card_buttons.has(card_id):
		push_error("EvidenceBoardView: no card '%s' in question '%s'" % [card_id, question.get("id", "?")])
		return
	Sfx.play("select")
	if _flipped_card_ids.has(card_id):
		_flipped_card_ids.erase(card_id)
	else:
		_flipped_card_ids.append(card_id)
	if not _turned_card_ids.has(card_id):
		_turned_card_ids.append(card_id)
	_refresh_progress()
	_play_flip_animation(card_id)


func is_card_flipped(card_id: String) -> bool:
	return _flipped_card_ids.has(card_id)


func _reset_state() -> void:
	_turned_card_ids = []
	_flipped_card_ids = []
	_card_buttons = {}
	_flip_tweens = {}


func _is_answer_valid() -> bool:
	for card_id in _all_card_ids():
		if not _turned_card_ids.has(card_id):
			return false
	return true


## Submit is relabelled for this view, so the base class's Submit label is replaced after it runs.
func _rebuild() -> void:
	if _locked:
		_flipped_card_ids.assign(_all_card_ids())
	super._rebuild()
	if _submit_button != null:
		_submit_button.text = Loc.ui("done_studying")


func _build_body() -> void:
	_card_buttons = {}
	_flip_tweens = {}
	_seen_label = _make_wrapping_label("")
	_body.add_child(_seen_label)
	_body.add_child(_make_wrapping_label(Loc.ui("tap_to_flip")))
	_body.add_child(_make_cork_board())
	_refresh_progress()


func _make_cork_board() -> PanelContainer:
	var board := PanelContainer.new()
	board.add_theme_stylebox_override("panel", _make_cork_style())
	var grid := GridContainer.new()
	grid.columns = CARD_COLUMN_COUNT
	grid.add_theme_constant_override("h_separation", CARD_SEPARATION)
	grid.add_theme_constant_override("v_separation", CARD_SEPARATION)
	board.add_child(grid)
	for card: Dictionary in question["cards"]:
		grid.add_child(_make_card(card))
	return board


func _make_cork_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CORK_FILL_COLOR
	style.set_corner_radius_all(CORK_CORNER_RADIUS)
	style.set_content_margin_all(CORK_PADDING)
	return style


func _make_card(card: Dictionary) -> Button:
	var card_id: String = card["id"]
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = CARD_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pivot_offset = CARD_SIZE / 2.0
	for style_name in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(style_name, _make_card_frame_style())
	button.add_child(_make_card_front(card))
	button.add_child(_make_card_back(card))
	button.pressed.connect(flip_card.bind(card_id))
	_card_buttons[card_id] = button
	_show_card_face(card_id)
	return button


func _make_card_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_FILL_COLOR
	style.border_color = NAVY_TEXT_COLOR
	style.set_border_width_all(CARD_BORDER_WIDTH)
	style.set_corner_radius_all(CARD_CORNER_RADIUS)
	return style


func _make_card_front(card: Dictionary) -> TextureRect:
	var photo := TextureRect.new()
	photo.name = FRONT_NODE_NAME
	photo.texture = _load_texture(card["image"])
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return photo


## The caption is always in the tree, so its text can be read whether or not the back is shown.
func _make_card_back(card: Dictionary) -> PanelContainer:
	var back := PanelContainer.new()
	back.name = BACK_NODE_NAME
	back.add_theme_stylebox_override("panel", _make_paper_style())
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var caption := _make_wrapping_label(Loc.text(card["caption"]))
	caption.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	caption.add_theme_color_override("font_color", NAVY_TEXT_COLOR)
	back.add_child(caption)
	return back


func _make_paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_FILL_COLOR
	style.set_content_margin_all(PAPER_PADDING)
	return style


## The face swap happens at the middle of the squash. Outside the tree there is no frame to
## animate, so the face swaps at once.
func _play_flip_animation(card_id: String) -> void:
	var button: Button = _card_buttons[card_id]
	if not button.is_inside_tree():
		_show_card_face(card_id)
		return
	if _flip_tweens.has(card_id) and _flip_tweens[card_id].is_valid():
		_flip_tweens[card_id].kill()
	var tween := button.create_tween()
	tween.tween_property(button, "scale:x", 0.0, FLIP_HALF_SECONDS)
	tween.tween_callback(_show_card_face.bind(card_id))
	tween.tween_property(button, "scale:x", 1.0, FLIP_HALF_SECONDS)
	_flip_tweens[card_id] = tween


func _show_card_face(card_id: String) -> void:
	var button: Button = _card_buttons[card_id]
	var shows_back := _flipped_card_ids.has(card_id)
	button.get_node(FRONT_NODE_NAME).visible = not shows_back
	button.get_node(BACK_NODE_NAME).visible = shows_back


func _refresh_progress() -> void:
	_seen_label.text = Loc.ui("cards_seen", {"seen": _turned_card_ids.size(), "total": _all_card_ids().size()})
	_submit_button.disabled = _locked or not _is_answer_valid()


func _all_card_ids() -> Array[String]:
	var card_ids: Array[String] = []
	for card: Dictionary in question["cards"]:
		card_ids.append(card["id"])
	return card_ids
