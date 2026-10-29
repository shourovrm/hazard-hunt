extends RefCounted

const CASE_PATH := "res://content/construction/cases/c01_bamboo_scaffold.json"
const SAFE_PICTURE := "res://assets/construction/c01/bg_safe.png"
const INTRO_CLIP := "user://videos/construction/c01/intro.ogv"
const OUTRO_CLIP := "user://videos/construction/c01/outro.ogv"
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
	for path in [INTRO_CLIP, OUTRO_CLIP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _clips_in(player: Node) -> Array[Node]:
	return player.find_children("Clip_*", "VideoStreamPlayer", true, false)


func _is_fading(clip: Node) -> bool:
	return clip.has_meta("fading")


func test_clip_path_uses_the_case_folder_under_user_videos() -> void:
	t.assert_eq(SceneVideo.clip_path(SAFE_PICTURE, "outro"), OUTRO_CLIP)


func test_case_keeps_still_pictures_without_downloaded_clips() -> void:
	_remove_clips()
	var player := _new_player(true)
	t.assert_eq(_clips_in(player).size(), 0)
	player.queue_free()


func test_intro_clip_plays_over_the_scene_and_fades_when_the_hunt_starts() -> void:
	_remove_clips()
	_install_clip(INTRO_CLIP)
	var player := _new_player(true)
	var clips := _clips_in(player)
	t.assert_eq(clips.size(), 1, "intro clip shown at case start")
	if clips.size() == 1:
		var clip: VideoStreamPlayer = clips[0]
		t.assert_eq(String(clip.name), "Clip_intro")
		t.assert_eq(clip.size, Vector2(1280, 720), "clip covers the scene exactly")
		t.assert_false(_is_fading(clip), "clip still playing during the intro talk")
		player.skip_intro()
		t.assert_true(_is_fading(clip), "clip gives way to the still scene for the hunt")
	player.queue_free()
	_remove_clips()


func test_intro_clip_is_skipped_when_animations_are_off() -> void:
	_install_clip(INTRO_CLIP)
	var player := _new_player(false)
	t.assert_eq(_clips_in(player).size(), 0)
	player.queue_free()
	_remove_clips()


func test_outro_clip_plays_during_the_safe_reveal() -> void:
	_remove_clips()
	_install_clip(OUTRO_CLIP)
	var player := _new_player(true)
	player._play_reveal_animation()
	var clips := _clips_in(player)
	t.assert_eq(clips.size(), 1, "outro clip shown at the reveal")
	if clips.size() == 1:
		t.assert_eq(String(clips[0].name), "Clip_outro")
	player.queue_free()
	_remove_clips()
