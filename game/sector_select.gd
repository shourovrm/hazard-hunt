extends Control
## Sector page: one card per sector in content/sectors.json, then one muted card per coming-soon
## sector. Opening a card shows that sector's site map.

const MAIN_MENU_SCENE := "res://game/main_menu.tscn"
const SECTOR_MAP_SCENE := "res://game/sector_map.tscn"
const HOME_ICON_PATH := "res://assets/icons/home.svg"
const CARD_COLUMNS := 3
const CARD_SIZE := Vector2(340, 380)
const THUMBNAIL_SIZE := Vector2(308, 170)
const STARS_PER_CASE := 3

var _sector_entries: Array[Dictionary] = []
var _coming_soon: Array = []
var _title_label: Label
var _home_button: NavigationButton
var _card_grid: GridContainer


func _ready() -> void:
	var index := CaseLoader.load_sector_index()
	if index.is_empty():
		push_error("SectorSelect: cannot show sectors without content/sectors.json")
		return
	_load_sector_entries(index)
	_coming_soon = index.get("coming_soon", [])
	ScreenBackground.add_to(self, 0.72)
	_build_layout()
	Loc.language_changed.connect(_on_language_changed)
	_refresh()


func _load_sector_entries(index: Dictionary) -> void:
	for sector_path: String in index.get("sectors", []):
		var sector := CaseLoader.load_sector(sector_path)
		if sector.is_empty():
			continue
		_sector_entries.append({"path": sector_path, "data": sector})


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
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_card_grid = GridContainer.new()
	_card_grid.columns = CARD_COLUMNS
	_card_grid.add_theme_constant_override("h_separation", 24)
	_card_grid.add_theme_constant_override("v_separation", 20)
	center.add_child(_card_grid)


## Rebuilds every card so text and star totals match the current language and saved progress.
func _refresh() -> void:
	_title_label.text = Loc.ui("choose_sector")
	_home_button.text = Loc.ui("home")
	for existing_card in _card_grid.get_children():
		_card_grid.remove_child(existing_card)
		existing_card.queue_free()
	for entry in _sector_entries:
		_card_grid.add_child(_make_sector_card(entry))
	for coming_soon_entry: Dictionary in _coming_soon:
		_card_grid.add_child(_make_coming_soon_card(coming_soon_entry["title"]))


func _make_sector_card(entry: Dictionary) -> PanelContainer:
	var sector: Dictionary = entry["data"]
	var case_paths: Array = sector.get("cases", [])
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	if sector.has("thumbnail"):
		var thumbnail := TextureRect.new()
		thumbnail.texture = load(sector["thumbnail"]) as Texture2D
		thumbnail.custom_minimum_size = THUMBNAIL_SIZE
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		column.add_child(thumbnail)

	column.add_child(_make_card_title(Loc.text(sector["title"])))
	var details := Label.new()
	details.theme_type_variation = "SmallLabel"
	details.text = Loc.ui("case_count", {"count": case_paths.size()})
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(details)

	var stars := StarRating.new()
	stars.star_size = 24.0
	stars.total_count = STARS_PER_CASE
	stars.filled_count = _average_stars(case_paths)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(stars)

	var open_button := Button.new()
	open_button.theme_type_variation = "PrimaryButton"
	open_button.text = Loc.ui("open_sector")
	open_button.custom_minimum_size = Vector2(0, 60)
	open_button.size_flags_vertical = Control.SIZE_SHRINK_END
	open_button.pressed.connect(select_sector.bind(entry["path"]))
	column.add_child(open_button)
	return card


## Rounded average of the best stars across the sector's cases (0 when none played).
func _average_stars(case_paths: Array) -> int:
	if case_paths.is_empty():
		return 0
	var total := 0
	for case_path: String in case_paths:
		var case_data := CaseLoader.load_case(case_path)
		if not case_data.is_empty():
			total += Progress.get_stars(case_data["id"])
	return roundi(float(total) / case_paths.size())


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
	title.add_theme_font_size_override("font_size", 26)
	title.text = title_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return title


func select_sector(sector_path: String) -> void:
	GameState.selected_sector_path = sector_path
	if not is_inside_tree() or get_tree().current_scene != self:
		return
	Sfx.play("tap")
	get_tree().change_scene_to_file(SECTOR_MAP_SCENE)


func _on_home_pressed() -> void:
	Sfx.play("tap")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Android back returns to the main menu.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_home_pressed()


func _on_language_changed(_language: String) -> void:
	_refresh()
