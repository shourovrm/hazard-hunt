class_name LeaveConfirmDialog
extends Control
## In-game confirm card: dims the screen, blocks taps underneath, and asks before leaving a screen.

signal confirm_pressed

const DIM_COLOR := Color(0.07, 0.063, 0.2, 0.7)
const CARD_WIDTH := 560.0
const BUTTON_MINIMUM_SIZE := Vector2(220, 72)
const TITLE_FONT_SIZE := 32

var _title_key: String
var _body_key: String
var _confirm_key: String
var _title_label: Label
var _body_label: Label
var _stay_button: Button
var _confirm_button: Button


## The three arguments are Loc.ui keys. An empty `body_key` hides the sentence under the title.
func _init(title_key: String, body_key: String, confirm_key: String) -> void:
	_title_key = title_key
	_body_key = body_key
	_confirm_key = confirm_key
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Stopping the mouse here is what keeps taps from reaching the screen underneath the card.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_layout()
	Loc.language_changed.connect(_on_language_changed)
	_refresh_texts()


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func _build_layout() -> void:
	var dimmer := ColorRect.new()
	dimmer.color = DIM_COLOR
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card := PanelContainer.new()
	card.theme_type_variation = "PillPanel"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	center.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)

	_title_label = Label.new()
	_title_label.theme_type_variation = "PillLabel"
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title_label)

	_body_label = Label.new()
	_body_label.theme_type_variation = "PillLabel"
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_body_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	column.add_child(button_row)

	_stay_button = Button.new()
	_stay_button.custom_minimum_size = BUTTON_MINIMUM_SIZE
	_stay_button.pressed.connect(_on_stay_pressed)
	button_row.add_child(_stay_button)

	_confirm_button = Button.new()
	_confirm_button.theme_type_variation = "PrimaryButton"
	_confirm_button.custom_minimum_size = BUTTON_MINIMUM_SIZE
	_confirm_button.pressed.connect(_on_confirm_pressed)
	button_row.add_child(_confirm_button)


func _refresh_texts() -> void:
	_title_label.text = Loc.ui(_title_key)
	_body_label.visible = not _body_key.is_empty()
	if _body_label.visible:
		_body_label.text = Loc.ui(_body_key)
	_stay_button.text = Loc.ui("stay")
	_confirm_button.text = Loc.ui(_confirm_key)


func _on_stay_pressed() -> void:
	Sfx.play("tap")
	close()


func _on_confirm_pressed() -> void:
	Sfx.play("tap")
	confirm_pressed.emit()


func _on_language_changed(_language: String) -> void:
	_refresh_texts()
