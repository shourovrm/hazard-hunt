extends RefCounted

const TEST_SAVE_PATH := "user://test_progress.json"

var t


func _new_store() -> ProgressStore:
	var store := ProgressStore.new()
	store.save_path = TEST_SAVE_PATH
	store.reset()
	return store


func test_unplayed_case_has_zero_stars() -> void:
	var store := _new_store()
	t.assert_eq(store.get_stars("c01"), 0)
	t.assert_false(store.is_completed("c01"))
	store.free()


func test_keeps_best_stars() -> void:
	var store := _new_store()
	store.record_result("c01", 2)
	store.record_result("c01", 1)
	t.assert_eq(store.get_stars("c01"), 2)
	store.record_result("c01", 3)
	t.assert_eq(store.get_stars("c01"), 3)
	t.assert_true(store.is_completed("c01"))
	store.free()


func test_saved_progress_survives_reload() -> void:
	var store := _new_store()
	store.record_result("c01", 3)
	store.set_language("en")
	var reloaded := ProgressStore.new()
	reloaded.save_path = TEST_SAVE_PATH
	reloaded.load_progress()
	t.assert_eq(reloaded.get_stars("c01"), 3)
	t.assert_eq(reloaded.get_language(), "en")
	store.free()
	reloaded.free()


func test_default_language_is_bangla() -> void:
	var store := _new_store()
	t.assert_eq(store.get_language(), "bn")
	store.free()


func test_corrupt_file_starts_empty() -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	var store := ProgressStore.new()
	store.save_path = TEST_SAVE_PATH
	store.load_progress()
	t.assert_eq(store.get_stars("c01"), 0)
	store.free()


func test_every_listed_case_is_unlocked() -> void:
	var store := _new_store()
	var case_ids := ["c01", "c02", "c03"]
	t.assert_true(store.is_unlocked(case_ids, "c01"))
	t.assert_true(store.is_unlocked(case_ids, "c02"))
	t.assert_true(store.is_unlocked(case_ids, "c03"))
	store.free()
