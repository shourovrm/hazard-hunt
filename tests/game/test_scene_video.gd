extends RefCounted

const CASE_PATH := "res://content/construction/cases/c01_bamboo_scaffold.json"
const PICTURE_PATH := "res://assets/construction/c01/bg_unsafe.png"
const VIDEO_PATH := "user://videos/construction/c01/bg_unsafe.ogv"
const SAMPLE_VIDEO := "res://tests/fixtures/one_frame.ogv"
const CasePlayerScene := preload("res://game/case_player.tscn")

var t


func _new_player() -> Node:
	var player: Node = CasePlayerScene.instantiate()
	player.animations_enabled = false
	t.root.add_child(player)
	player.start_case(CASE_PATH)
	return player


func _remove_downloaded_video() -> void:
	if FileAccess.file_exists(VIDEO_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(VIDEO_PATH))


func test_video_path_mirrors_picture_path_under_user_videos() -> void:
	t.assert_eq(SceneVideo.video_path_for(PICTURE_PATH), VIDEO_PATH)


func test_background_stays_a_still_picture_without_downloaded_video() -> void:
	_remove_downloaded_video()
	var player := _new_player()
	t.assert_eq(player.find_children("*", "VideoStreamPlayer", true, false).size(), 0)
	player.queue_free()


func test_background_plays_downloaded_video_over_the_picture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VIDEO_PATH.get_base_dir()))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(SAMPLE_VIDEO), ProjectSettings.globalize_path(VIDEO_PATH))
	var player := _new_player()
	var videos := player.find_children("*", "VideoStreamPlayer", true, false)
	t.assert_eq(videos.size(), 1, "only the unsafe picture has a video")
	if videos.size() == 1:
		var video: VideoStreamPlayer = videos[0]
		t.assert_true(video.loop, "background video loops")
		t.assert_eq(video.size, Vector2(1280, 720), "video covers the picture exactly")
		t.assert_true(video.get_parent() is Sprite2D, "video follows the picture's fades and slides")
	player.queue_free()
	_remove_downloaded_video()
