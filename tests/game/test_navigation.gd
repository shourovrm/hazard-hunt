extends RefCounted

const CASE_PATH := "res://content/construction/cases/c01_bamboo_scaffold.json"
const MainMenuScene := preload("res://game/main_menu.tscn")
const SectorMapScene := preload("res://game/sector_map.tscn")
const CasePlayerScene := preload("res://game/case_player.tscn")

var t


func _visible_button_with_text(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _visible_button_with_text(child, text)
		if found != null:
			return found
	return null


func _new_player() -> Node:
	var player: Node = CasePlayerScene.instantiate()
	player.animations_enabled = false
	t.root.add_child(player)
	player.start_case(CASE_PATH)
	return player


func test_main_menu_has_exit_button_with_confirm() -> void:
	Loc.set_language("en")
	var menu: Node = MainMenuScene.instantiate()
	t.root.add_child(menu)
	t.assert_not_null(_visible_button_with_text(menu, Loc.ui("exit_game")), "no Exit button")
	t.assert_false(menu.is_quit_confirm_visible())
	menu.request_quit()
	t.assert_true(menu.is_quit_confirm_visible(), "quit confirm not shown")


func test_sector_map_has_home_button() -> void:
	Loc.set_language("en")
	var sector_map: Node = SectorMapScene.instantiate()
	t.root.add_child(sector_map)
	t.assert_not_null(_visible_button_with_text(sector_map, Loc.ui("home")), "no Home button")


func test_case_player_home_button_in_every_phase() -> void:
	var player := _new_player()
	var home_button: Node = player.find_child("HomeButton", true, false)
	t.assert_not_null(home_button, "no HomeButton")
	if home_button == null:
		return
	t.assert_true(home_button.is_visible_in_tree(), "HomeButton hidden in intro")
	player.skip_intro()
	t.assert_true(home_button.is_visible_in_tree(), "HomeButton hidden in hunt")
	for hazard in player.get_session().case_data["hazards"]:
		var rect: Array = hazard["rect"]
		player.handle_scene_tap(Vector2(rect[0] + rect[2] / 2.0, rect[1] + rect[3] / 2.0))
	player.advance()
	t.assert_true(home_button.is_visible_in_tree(), "HomeButton hidden in questions")


func test_leave_case_asks_first() -> void:
	var player := _new_player()
	t.assert_false(player.is_leave_confirm_visible())
	player.request_home()
	t.assert_true(player.is_leave_confirm_visible(), "leave confirm not shown")
	player.cancel_leave()
	t.assert_false(player.is_leave_confirm_visible(), "leave confirm still shown after Stay")
	t.assert_eq(player.get_session().phase, CaseSession.Phase.INTRO, "cancel must keep the case running")
