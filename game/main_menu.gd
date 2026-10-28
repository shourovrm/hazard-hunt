extends Control
## Title screen: Start button and the language switch.

const SECTOR_SELECT_SCENE := "res://game/sector_select.tscn"
const EXIT_ICON_PATH := "res://assets/icons/exit.svg"
const BUTTON_SIZE := Vector2(360, 80)

var _title_label: Label
var _subtitle_label: Label
var _start_button: Button
var _language_button: Button
var _sound_button: Button
var _exit_button: NavigationButton
var _quit_confirm: LeaveConfirmDialog


func _ready() -> void:
	# Apply the saved language before any text is built, so the first frame is already correct.
	Loc.set_language(Progress.get_language())
	ScreenBackground.add_to(self, 0.6)
	_build_layout()
	Loc.language_changed.connect(_on_language_changed)
	_refresh_texts()


func _build_layout() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	_title_label = _make_centered_label("TitleLabel")
	column.add_child(_title_label)
	_subtitle_label = _make_centered_label("SubtitleLabel")
	column.add_child(_subtitle_label)
	column.add_child(_make_spacer(36))

	_start_button = Button.new()
	_start_button.theme_type_variation = "PrimaryButton"
	_start_button.custom_minimum_size = BUTTON_SIZE
	_start_button.add_theme_font_size_override("font_size", 32)
	_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start_button.pressed.connect(_on_start_pressed)
	column.add_child(_start_button)

	_language_button = Button.new()
	_language_button.custom_minimum_size = Vector2(240, 64)
	_language_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_language_button.pressed.connect(_on_language_switch_pressed)
	column.add_child(_language_button)

	_sound_button = Button.new()
	_sound_button.custom_minimum_size = Vector2(240, 64)
	_sound_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sound_button.pressed.connect(_on_sound_toggle_pressed)
	column.add_child(_sound_button)

	_exit_button = NavigationButton.new(EXIT_ICON_PATH, Vector2(240, 64))
	_exit_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_exit_button.pressed.connect(_on_exit_pressed)
	column.add_child(_exit_button)

	_quit_confirm = LeaveConfirmDialog.new("quit_title", "", "exit_game")
	_quit_confirm.confirm_pressed.connect(_on_quit_confirmed)
	add_child(_quit_confirm)


func _make_centered_label(type_variation: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = type_variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _refresh_texts() -> void:
	_title_label.text = Loc.ui("app_title")
	_subtitle_label.text = Loc.ui("app_subtitle")
	_subtitle_label.visible = not _subtitle_label.text.is_empty()
	_start_button.text = Loc.ui("start")
	_language_button.text = Loc.ui("language_switch")
	_sound_button.text = Loc.ui("sound_off") if Sfx.is_muted() else Loc.ui("sound_on")
	_exit_button.text = Loc.ui("exit_game")


## Android back asks the same question as the Exit button, so the game never closes by accident.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		request_quit()


func request_quit() -> void:
	_quit_confirm.open()


func is_quit_confirm_visible() -> bool:
	return _quit_confirm.visible


func _on_exit_pressed() -> void:
	Sfx.play("tap")
	request_quit()


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _on_start_pressed() -> void:
	Sfx.play("tap")
	get_tree().change_scene_to_file(SECTOR_SELECT_SCENE)


func _on_language_switch_pressed() -> void:
	Sfx.play("tap")
	var other_language := "en" if Loc.language == "bn" else "bn"
	Loc.set_language(other_language)
	Progress.set_language(other_language)


## Toggles after the mute change, so the confirming tap is heard only when sound comes back on.
func _on_sound_toggle_pressed() -> void:
	Sfx.set_muted(not Sfx.is_muted())
	Sfx.play("tap")
	_refresh_texts()


func _on_language_changed(_language: String) -> void:
	_refresh_texts()
