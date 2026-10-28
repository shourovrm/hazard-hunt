extends RefCounted

const PAPER_CASE := "res://content/construction/cases/c07_mixer_rebar.json"
const SMOOTH_CASE := "res://content/construction/cases/c01_bamboo_scaffold.json"
const CasePlayerScene := preload("res://game/case_player.tscn")

var t


func _new_player(path: String) -> Node:
	var player: Node = CasePlayerScene.instantiate()
	player.animations_enabled = false
	t.root.add_child(player)
	player.start_case(path)
	return player


func _count_named(node: Node, node_name: String) -> int:
	var count := 1 if node.name == node_name else 0
	for child in node.get_children():
		count += _count_named(child, node_name)
	return count


func test_paper_case_reports_paper_style() -> void:
	t.assert_eq(_new_player(PAPER_CASE).motion_style(), "paper")


func test_smooth_case_reports_smooth_style() -> void:
	t.assert_eq(_new_player(SMOOTH_CASE).motion_style(), "smooth")


func test_paper_case_gives_every_actor_paper_motion() -> void:
	var player := _new_player(PAPER_CASE)
	var actor_count: int = player.get_session().case_data["scene"]["actors"].size()
	t.assert_true(_count_named(player, "PaperMotion") >= actor_count, "each actor needs a PaperMotion node")


func test_smooth_case_has_no_paper_motion() -> void:
	t.assert_eq(_count_named(_new_player(SMOOTH_CASE), "PaperMotion"), 0)


func test_paper_case_reaches_safe_reveal() -> void:
	var player := _new_player(PAPER_CASE)
	player.skip_intro()
	var session: CaseSession = player.get_session()
	for hazard in session.case_data["hazards"]:
		var rect: Array = hazard["rect"]
		player.handle_scene_tap(Vector2(rect[0] + rect[2] / 2.0, rect[1] + rect[3] / 2.0))
	player.advance()
	var guard := 0
	while session.phase == CaseSession.Phase.QUESTIONS and guard < 20:
		guard += 1
		var view: QuestionView = player.get_active_question_view()
		view.set_answer(CaseSession.correct_answer(view.question))
		view.submit()
		player.advance()
	t.assert_eq(player.background_state(), "safe")
