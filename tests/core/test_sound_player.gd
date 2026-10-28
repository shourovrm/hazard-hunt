extends RefCounted

const TEST_SAVE_PATH := "user://test_progress_sound.json"

var t


func test_every_named_sound_exists() -> void:
	for sound_name in Sfx.SOUND_NAMES:
		t.assert_true(Sfx.has_sound(sound_name), "missing sound '%s'" % sound_name)
		t.assert_true(ResourceLoader.exists("res://assets/audio/%s.ogg" % sound_name), "no file for '%s'" % sound_name)


func test_play_does_not_error() -> void:
	Sfx.set_muted(false)
	for sound_name in Sfx.SOUND_NAMES:
		Sfx.play(sound_name)


func test_ambience_starts_and_stops() -> void:
	Sfx.play_ambience("res://assets/audio/ambience_site.ogg")
	t.assert_eq(Sfx.current_ambience(), "res://assets/audio/ambience_site.ogg")
	Sfx.stop_ambience()
	t.assert_eq(Sfx.current_ambience(), "")


func test_mute_is_saved() -> void:
	Progress.save_path = TEST_SAVE_PATH
	Progress.reset()
	t.assert_true(Progress.get_sound_enabled(), "sound should be on by default")
	Sfx.set_muted(true)
	t.assert_true(Sfx.is_muted())
	t.assert_false(Progress.get_sound_enabled())
	Sfx.set_muted(false)
	t.assert_true(Progress.get_sound_enabled())
