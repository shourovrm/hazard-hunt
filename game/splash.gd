extends Control
## Opening screen: logo, title and developer credit for a moment, then the main menu.
## A tap skips the wait.

const MAIN_MENU_SCENE := "res://game/main_menu.tscn"
const ICON_PATH := "res://assets/icon.png"
const NAVY := Color("#1E1B4F")
const ORANGE := Color("#F37A2B")
const MUTED_TEXT := Color("#cfd0e6")
const SHOW_SECONDS := 2.0

## Tests switch this off so the splash stays on screen.
var auto_advance := true
var _has_left := false
var _title_label: Label
var _subtitle_label: Label
var _developed_by_label: Label
var _developer_name_label: Label


func _ready() -> void:
	# The splash is the first screen, so it applies the saved language itself.
	Loc.set_language(Progress.get_language())
	_build_layout()
	_refresh_texts()
	Loc.language_changed.connect(_on_language_changed)
	if auto_advance:
		get_tree().create_timer(SHOW_SECONDS).timeout.connect(_go_to_main_menu)


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = NAVY
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)

	var icon := TextureRect.new()
	icon.texture = load(ICON_PATH) as Texture2D
	icon.custom_minimum_size = Vector2(160, 160)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	_title_label = _make_label(52, Color.WHITE)
	column.add_child(_title_label)
	_subtitle_label = _make_label(22, MUTED_TEXT)
	column.add_child(_subtitle_label)

	var credit := VBoxContainer.new()
	credit.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	credit.grow_horizontal = Control.GROW_DIRECTION_BOTH
	credit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	credit.offset_bottom = -40
	add_child(credit)
	_developed_by_label = _make_label(20, MUTED_TEXT)
	credit.add_child(_developed_by_label)
	_developer_name_label = _make_label(30, ORANGE)
	credit.add_child(_developer_name_label)


func _refresh_texts() -> void:
	_title_label.text = Loc.ui("app_title")
	_subtitle_label.text = Loc.ui("app_subtitle")
	_developed_by_label.text = Loc.ui("developed_by")
	_developer_name_label.text = Loc.ui("developer_name")


func _on_language_changed(_language: String) -> void:
	_refresh_texts()


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_go_to_main_menu()


func _go_to_main_menu() -> void:
	if _has_left or not is_inside_tree():
		return
	_has_left = true
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
