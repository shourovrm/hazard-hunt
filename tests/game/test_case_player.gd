extends RefCounted

const CASE_PATH := "res://content/construction/cases/c01_bamboo_scaffold.json"
const TEST_SAVE_PATH := "user://test_progress_game.json"

var t


func _correct_answer(question: Dictionary) -> Variant:
	match question["type"]:
		"single_choice", "multi_select", "drag_ppe":
			return question["correct"]
		"ordering":
			return question["correct_order"]
		"dialogue":
			return "explain"
	return null


func _use_test_progress() -> void:
	Progress.save_path = TEST_SAVE_PATH
	Progress.reset()


func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := _find_button_with_text(child, text)
		if found != null:
			return found
	return null


func _new_player() -> Node:
	var player: Node = load("res://game/case_player.tscn").instantiate()
	player.animations_enabled = false
	t.root.add_child(player)
	player.start_case(CASE_PATH)
	return player


func test_main_menu_has_start_button() -> void:
	Loc.set_language("en")
	var menu: Node = load("res://game/main_menu.tscn").instantiate()
	t.root.add_child(menu)
	t.assert_not_null(_find_button_with_text(menu, Loc.ui("start")), "no Start button")


func test_sector_map_lists_first_case() -> void:
	Loc.set_language("en")
	_use_test_progress()
	var sector_map: Node = load("res://game/sector_map.tscn").instantiate()
	t.root.add_child(sector_map)
	t.assert_true("Bamboo Scaffold: Work at Height" in t.collect_text(sector_map), "case title missing")
	t.assert_true(Loc.ui("coming_soon") in t.collect_text(sector_map), "coming soon cards missing")


func test_player_starts_unsafe_in_intro() -> void:
	var player := _new_player()
	t.assert_eq(player.get_session().phase, CaseSession.Phase.INTRO)
	t.assert_eq(player.background_state(), "unsafe")


func test_full_case_flow_reaches_result_and_saves_stars() -> void:
	_use_test_progress()
	var player := _new_player()
	player.skip_intro()
	var session: CaseSession = player.get_session()
	t.assert_eq(session.phase, CaseSession.Phase.HAZARD_HUNT)
	for hazard in session.case_data["hazards"]:
		var rect: Array = hazard["rect"]
		player.handle_scene_tap(Vector2(rect[0] + rect[2] / 2.0, rect[1] + rect[3] / 2.0))
	t.assert_true(session.all_hazards_found())
	player.advance()
	t.assert_eq(session.phase, CaseSession.Phase.QUESTIONS)
	var guard := 0
	while session.phase == CaseSession.Phase.QUESTIONS and guard < 20:
		guard += 1
		var view: QuestionView = player.get_active_question_view()
		t.assert_not_null(view, "no question view shown")
		if view == null:
			return
		view.set_answer(_correct_answer(view.question))
		view.submit()
		t.assert_true(view.is_locked(), "view not locked after correct answer")
		player.advance()
	t.assert_eq(session.phase, CaseSession.Phase.SAFE_REVEAL)
	t.assert_eq(player.background_state(), "safe")
	player.advance()
	t.assert_eq(session.phase, CaseSession.Phase.RESULT)
	t.assert_true(player.is_result_visible())
	t.assert_eq(Progress.get_stars("c01_bamboo_scaffold"), 3)


func test_miss_tap_does_not_find_hazard() -> void:
	var player := _new_player()
	player.skip_intro()
	player.handle_scene_tap(Vector2(1270, 10))
	t.assert_eq(player.get_session().found_hazard_ids().size(), 0)


func test_wide_screen_backdrop_exists() -> void:
	var player := _new_player()
	var backdrop: Node = player.find_child("Backdrop", true, false)
	t.assert_not_null(backdrop, "no Backdrop node")
	if backdrop != null:
		t.assert_not_null(backdrop.get("texture"), "Backdrop has no texture")


func test_case_starts_site_ambience() -> void:
	var player := _new_player()
	t.assert_eq(Sfx.current_ambience(), "res://assets/audio/ambience_site.ogg")
	player.queue_free()


func test_main_menu_has_sound_toggle() -> void:
	Loc.set_language("en")
	var menu: Node = load("res://game/main_menu.tscn").instantiate()
	t.root.add_child(menu)
	var label := Loc.ui("sound_off") if Sfx.is_muted() else Loc.ui("sound_on")
	t.assert_not_null(_find_button_with_text(menu, label), "no sound toggle button")
