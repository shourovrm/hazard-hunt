extends Control
## Site map: one card per case of the sector, then one disabled card per coming-soon entry.

const SECTOR_PATH := "res://content/construction/sector.json"
const MAIN_MENU_SCENE := "res://game/main_menu.tscn"
const CASE_PLAYER_SCENE := "res://game/case_player.tscn"
const HOME_ICON_PATH := "res://assets/icons/home.svg"
# Two rows of four cards fit a 720 px tall screen without scrolling; more cases scroll vertically.
const CARD_COLUMNS := 4
const CARD_SIZE := Vector2(272, 272)
const THUMBNAIL_SIZE := Vector2(240, 88)

var _sector: Dictionary = {}
var _case_entries: Array[Dictionary] = []
var _title_label: Label
var _home_button: NavigationButton
var _card_row: GridContainer


func _ready() -> void:
	_sector = CaseLoader.load_sector(SECTOR_PATH)
	if _sector.is_empty():
		push_error("SectorMap: cannot show the map without '%s'" % SECTOR_PATH)
		return
	_load_case_entries()
	ScreenBackground.add_to(self, 0.72)
	_build_layout()
	Loc.language_changed.connect(_on_language_changed)
	_refresh()


func _load_case_entries() -> void:
	for case_path: String in _sector["cases"]:
		var case_data := CaseLoader.load_case(case_path)
		if case_data.is_empty():
			continue
		_case_entries.append({"path": case_path, "data": case_data})


func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	column.add_child(header)
	_home_button = NavigationButton.new(HOME_ICON_PATH, Vector2(160, 64))
	_home_button.pressed.connect(_on_home_pressed)
	header.add_child(_home_button)
	_title_label = Label.new()
	_title_label.theme_type_variation = "TitleLabel"
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_title_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_card_row = GridContainer.new()
	_card_row.columns = CARD_COLUMNS
	_card_row.add_theme_constant_override("h_separation", 20)
	_card_row.add_theme_constant_override("v_separation", 16)
	center.add_child(_card_row)


## Rebuilds every card so text and star counts match the current language and saved progress.
func _refresh() -> void:
	_title_label.text = Loc.text(_sector["title"])
	_home_button.text = Loc.ui("home")
	for existing_card in _card_row.get_children():
		_card_row.remove_child(existing_card)
		existing_card.queue_free()
	var case_ids: Array = []
	for entry in _case_entries:
		case_ids.append(entry["data"]["id"])
	for entry in _case_entries:
		_card_row.add_child(_make_case_card(entry, case_ids))
	for coming_soon_title: Dictionary in _sector.get("coming_soon", []):
		_card_row.add_child(_make_coming_soon_card(coming_soon_title))


func _make_case_card(entry: Dictionary, case_ids: Array) -> PanelContainer:
	var case_data: Dictionary = entry["data"]
	var case_id: String = case_data["id"]
	var is_unlocked := Progress.is_unlocked(case_ids, case_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var column := VBoxContainer.new()
	card.add_child(column)

	var thumbnail := TextureRect.new()
	thumbnail.texture = load(case_data["scene"]["background"]["unsafe"]) as Texture2D
	thumbnail.custom_minimum_size = THUMBNAIL_SIZE
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	column.add_child(thumbnail)

	var title := _make_card_title(Loc.text(case_data["title"]))
	column.add_child(title)

	var stars := StarRating.new()
	stars.star_size = 28.0
	stars.filled_count = Progress.get_stars(case_id)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(stars)

	var play_button := Button.new()
	play_button.theme_type_variation = "PrimaryButton"
	play_button.text = Loc.ui("play") if is_unlocked else Loc.ui("locked")
	play_button.custom_minimum_size = Vector2(0, 56)
	play_button.disabled = not is_unlocked
	play_button.size_flags_vertical = Control.SIZE_SHRINK_END
	play_button.pressed.connect(_on_play_pressed.bind(entry["path"]))
	column.add_child(play_button)
	if not is_unlocked:
		card.theme_type_variation = "MutedCard"
	return card


func _make_coming_soon_card(title_text: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "MutedCard"
	card.custom_minimum_size = CARD_SIZE
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(column)
	column.add_child(_make_card_title(Loc.text(title_text)))
	var notice := Label.new()
	notice.theme_type_variation = "SmallLabel"
	notice.text = Loc.ui("coming_soon")
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(notice)
	return card


func _make_card_title(title_text: String) -> Label:
	var title := Label.new()
	title.theme_type_variation = "HeadingLabel"
	title.add_theme_font_size_override("font_size", 21)
	title.text = title_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return title


func _on_play_pressed(case_path: String) -> void:
	Sfx.play("tap")
	GameState.selected_case_path = case_path
	get_tree().change_scene_to_file(CASE_PLAYER_SCENE)


func _on_home_pressed() -> void:
	Sfx.play("tap")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Android back goes home directly; the map has no unsaved state to protect.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_home_pressed()


func _on_language_changed(_language: String) -> void:
	_refresh()
