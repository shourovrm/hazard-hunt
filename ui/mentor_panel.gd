class_name MentorPanel
extends PanelContainer
## Bottom strip with the mentor portrait, name and a line of text that types on.
## A tap finishes the typing; a tap on finished text emits `tapped` so the owner can continue.

signal tapped

const PORTRAIT_PATH := "res://assets/characters/mentor_portrait.png"
const PORTRAIT_SIZE := Vector2(100, 136)
const TYPING_CHARACTERS_PER_SECOND := 80.0
const MINIMUM_TYPING_SECONDS := 0.25
const BODY_FONT_SIZE := 22

## False makes the text appear at once (used by tests and reduced-motion).
var animations_enabled := true

var _current_text: Dictionary = {}
var _current_headline: Dictionary = {}
var _name_label: Label
var _headline_label: Label
var _body_label: Label
var _typing_tween: Tween


func _ready() -> void:
	theme_type_variation = "MentorStrip"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	Loc.language_changed.connect(_on_language_changed)
	gui_input.connect(_on_gui_input)
	_refresh_texts()


## Shows `localized` in the body. An optional `headline` is shown in bold above it.
func say(localized: Dictionary, headline: Dictionary = {}) -> void:
	_current_text = localized
	_current_headline = headline
	_refresh_texts()
	_start_typing()


func clear() -> void:
	_current_text = {}
	_current_headline = {}
	_finish_typing()
	_refresh_texts()


func is_typing() -> bool:
	return _typing_tween != null and _typing_tween.is_valid()


## Shows the whole text at once.
func finish_typing() -> void:
	_finish_typing()


func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var portrait := TextureRect.new()
	portrait.texture = load(PORTRAIT_PATH) as Texture2D
	if portrait.texture == null:
		push_error("MentorPanel: cannot load portrait '%s'" % PORTRAIT_PATH)
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)

	_name_label = _make_label("NameLabel")
	column.add_child(_name_label)
	_headline_label = _make_label("HeadingLabel")
	_headline_label.add_theme_font_size_override("font_size", 24)
	column.add_child(_headline_label)
	_body_label = _make_label("")
	_body_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	column.add_child(_body_label)


func _make_label(type_variation: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = type_variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh_texts() -> void:
	if _body_label == null:
		return
	_name_label.text = Loc.ui("mentor_name")
	_headline_label.text = Loc.text(_current_headline) if not _current_headline.is_empty() else ""
	_headline_label.visible = not _current_headline.is_empty()
	_body_label.text = Loc.text(_current_text) if not _current_text.is_empty() else ""


func _start_typing() -> void:
	_finish_typing()
	if not animations_enabled or _body_label == null or not is_inside_tree():
		return
	_body_label.visible_ratio = 0.0
	var typing_seconds := maxf(MINIMUM_TYPING_SECONDS, _body_label.text.length() / TYPING_CHARACTERS_PER_SECOND)
	_typing_tween = create_tween()
	_typing_tween.tween_property(_body_label, "visible_ratio", 1.0, typing_seconds)
	_typing_tween.finished.connect(_finish_typing)


func _finish_typing() -> void:
	if _typing_tween != null:
		_typing_tween.kill()
		_typing_tween = null
	if _body_label != null:
		_body_label.visible_ratio = 1.0


func _on_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if is_typing():
		_finish_typing()
	else:
		tapped.emit()


func _on_language_changed(_language: String) -> void:
	_refresh_texts()
	_finish_typing()
