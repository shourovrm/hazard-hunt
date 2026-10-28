extends RefCounted

const SectorSelectScene := preload("res://game/sector_select.tscn")
const SectorMapScene := preload("res://game/sector_map.tscn")
const CONSTRUCTION := "res://content/construction/sector.json"

var t


func _button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null


func test_sector_index_loads() -> void:
	var index := CaseLoader.load_sector_index()
	t.assert_true(CONSTRUCTION in index["sectors"], "construction missing from sector index")
	t.assert_false(index["coming_soon"].is_empty())


func test_sector_select_lists_sectors_and_coming_soon() -> void:
	Loc.set_language("en")
	var page: Node = SectorSelectScene.instantiate()
	t.root.add_child(page)
	var text: String = t.collect_text(page)
	t.assert_true(Loc.ui("choose_sector") in text, "page title missing")
	t.assert_true("Construction Site" in text, "construction card missing")
	t.assert_true("Garments (RMG) Factory" in text, "coming soon sector missing")
	t.assert_not_null(_button(page, Loc.ui("open_sector")), "no Open button")
	t.assert_not_null(_button(page, Loc.ui("home")), "no Home button")


func test_opening_a_sector_selects_it() -> void:
	GameState.selected_sector_path = ""
	var page: Node = SectorSelectScene.instantiate()
	t.root.add_child(page)
	page.select_sector(CONSTRUCTION)
	t.assert_eq(GameState.selected_sector_path, CONSTRUCTION)


func test_sector_map_has_sectors_button() -> void:
	Loc.set_language("en")
	GameState.selected_sector_path = CONSTRUCTION
	var sector_map: Node = SectorMapScene.instantiate()
	t.root.add_child(sector_map)
	t.assert_not_null(_button(sector_map, Loc.ui("sectors")), "no Sectors button on the map")
