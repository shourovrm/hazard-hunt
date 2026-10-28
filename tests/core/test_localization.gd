extends RefCounted

var t


func test_text_returns_current_language() -> void:
	Loc.set_language("en")
	t.assert_eq(Loc.text({"en": "Helmet", "bn": "হেলমেট"}), "Helmet")
	Loc.set_language("bn")
	t.assert_eq(Loc.text({"en": "Helmet", "bn": "হেলমেট"}), "হেলমেট")


func test_text_falls_back_to_english() -> void:
	Loc.set_language("bn")
	t.assert_eq(Loc.text({"en": "Helmet"}), "Helmet")


func test_ui_formats_numbers_with_bengali_digits() -> void:
	Loc.set_language("bn")
	t.assert_eq(Loc.ui("question_counter", {"number": 2, "total": 5}), "প্রশ্ন ২ / ৫")
	Loc.set_language("en")
	t.assert_eq(Loc.ui("question_counter", {"number": 2, "total": 5}), "Question 2 of 5")


func test_every_ui_string_has_both_languages() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Loc.UI_STRINGS_PATH))
	for key in parsed:
		t.assert_true(parsed[key].has("en") and parsed[key].has("bn"), "ui string '%s' needs en and bn" % key)
