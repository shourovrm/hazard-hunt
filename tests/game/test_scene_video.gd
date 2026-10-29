extends RefCounted

const CASE_PATH := "res://content/construction/cases/c01_bamboo_scaffold.json"
const SAFE_PICTURE := "res://assets/construction/c01/bg_safe.png"
const ACCIDENT_CLIP := "user://videos/construction/c01/accident.ogv"
const SAFE_WORK_CLIP := "user://videos/construction/c01/safe_work.ogv"
const SAMPLE_CLIP := "res://tests/fixtures/one_frame.ogv"
const CasePlayerScene := preload("res://game/case_player.tscn")

var t


func _new_player(animations_enabled: bool) -> Node:
	var player: Node = CasePlayerScene.instantiate()
	player.animations_enabled = animations_enabled
	t.root.add_child(player)
	player.start_case(CASE_PATH)
	return player


func _install_clip(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(SAMPLE_CLIP), ProjectSettings.globalize_path(path))


func _remove_clips() -> void:
	for path in [ACCIDENT_CLIP, SAFE_WORK_CLIP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _clips_in(player: Node) -> Array[Node]:
	return player.find_children("Clip_*", "VideoStreamPlayer", true, false)


func _find_all_hazards(player: Node) -> void:
	player.skip_intro()
	for hazard in player.get_session().case_data["hazards"]:
		var rect: Array = hazard["rect"]
		player.handle_scene_tap(Vector2(rect[0] + rect[2] / 2.0, rect[1] + rect[3] / 2.0))


func test_clip_path_uses_the_case_folder_under_user_videos() -> void:
	t.assert_eq(SceneVideo.clip_path(SAFE_PICTURE, "safe_work"), SAFE_WORK_CLIP)


func test_fade_out_accepts_a_clip_that_already_freed_itself() -> void:
	var video := VideoStreamPlayer.new()
	video.free()
	SceneVideo.fade_out(video)
	t.assert_true(true, "no script error for a freed clip")


func test_hunt_shows_the_counter_with_clips_downloaded() -> void:
	_install_clip(ACCIDENT_CLIP)
	_install_clip(SAFE_WORK_CLIP)
	var player := _new_player(true)
	t.assert_eq(_clips_in(player).size(), 0, "no clip before the hunt")
	player.skip_intro()
	t.assert_true(player._counter_pill.visible, "hazard counter shown in the hunt")
	player.queue_free()
	_remove_clips()


func test_without_clips_the_hunt_goes_straight_to_questions() -> void:
	_remove_clips()
	var player := _new_player(true)
	_find_all_hazards(player)
	player.advance()
	t.assert_eq(player.get_session().phase, CaseSession.Phase.QUESTIONS)
	player.queue_free()


func test_accident_clip_plays_between_the_hunt_and_the_questions() -> void:
	_remove_clips()
	_install_clip(ACCIDENT_CLIP)
	var player := _new_player(true)
	_find_all_hazards(player)
	player.advance()
	t.assert_eq(player.get_session().phase, CaseSession.Phase.HAZARD_HUNT, "questions wait for the clip")
	var clips := _clips_in(player)
	t.assert_eq(clips.size(), 1, "accident clip shown")
	t.assert_false(player._counter_pill.visible, "counter hidden while the clip plays")
	if clips.size() == 1:
		t.assert_eq(String(clips[0].name), "Clip_accident")
		clips[0].finished.emit()
		t.assert_ne(clips[0].modulate, Color.WHITE, "last frame freezes with a tint")
	player.advance()
	t.assert_eq(player.get_session().phase, CaseSession.Phase.QUESTIONS, "a second press skips the hold")
	player.queue_free()
	_remove_clips()


func test_safe_work_clip_plays_at_the_reveal_and_holds_its_last_frame() -> void:
	_remove_clips()
	_install_clip(SAFE_WORK_CLIP)
	var player := _new_player(true)
	player._play_reveal_animation()
	var clips := _clips_in(player)
	t.assert_eq(clips.size(), 1, "safe-work clip shown at the reveal")
	if clips.size() == 1:
		t.assert_eq(String(clips[0].name), "Clip_safe_work")
		clips[0].finished.emit()
		t.assert_false(clips[0].has_meta("fading"), "last frame stays instead of swapping back to the still")
	player.queue_free()
	_remove_clips()
