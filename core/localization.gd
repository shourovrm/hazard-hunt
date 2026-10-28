extends Node
## Autoload "Loc": holds the current language and turns localized
## dictionaries such as {"en": "...", "bn": "..."} into display text.

signal language_changed(language: String)

const SUPPORTED_LANGUAGES: Array[String] = ["bn", "en"]
const FALLBACK_LANGUAGE := "en"
const UI_STRINGS_PATH := "res://content/ui_strings.json"
const BENGALI_DIGITS := "০১২৩৪৫৬৭৮৯"

var language := "bn"
var _ui_strings: Dictionary = {}


func _ready() -> void:
	_ui_strings = _load_ui_strings()


func set_language(code: String) -> void:
	if code not in SUPPORTED_LANGUAGES:
		push_error("Loc: unsupported language '%s'" % code)
		return
	if code == language:
		return
	language = code
	language_changed.emit(code)


func text(localized: Dictionary) -> String:
	if localized.has(language):
		return localized[language]
	if localized.has(FALLBACK_LANGUAGE):
		push_warning("Loc: no '%s' text, using '%s': %s" % [language, FALLBACK_LANGUAGE, localized])
		return localized[FALLBACK_LANGUAGE]
	push_error("Loc: localized text has neither '%s' nor '%s': %s" % [language, FALLBACK_LANGUAGE, localized])
	return ""


## Returns a UI string from content/ui_strings.json. Numbers in `values`
## are shown with Bengali digits when the language is Bangla.
func ui(key: String, values: Dictionary = {}) -> String:
	if _ui_strings.is_empty():
		_ui_strings = _load_ui_strings()
	if not _ui_strings.has(key):
		push_error("Loc: missing UI string key '%s'" % key)
		return key
	var display_values := {}
	for value_key in values:
		display_values[value_key] = number(values[value_key]) if values[value_key] is int else str(values[value_key])
	return text(_ui_strings[key]).format(display_values)


## Formats an integer with the digits of the current language.
func number(value: int) -> String:
	var digits := str(value)
	if language != "bn":
		return digits
	var converted := ""
	for character in digits:
		if character >= "0" and character <= "9":
			converted += BENGALI_DIGITS[int(character)]
		else:
			converted += character
	return converted


func _load_ui_strings() -> Dictionary:
	var file_text := FileAccess.get_file_as_string(UI_STRINGS_PATH)
	if file_text.is_empty():
		push_error("Loc: cannot read %s (error %s)" % [UI_STRINGS_PATH, FileAccess.get_open_error()])
		return {}
	var parsed: Variant = JSON.parse_string(file_text)
	if parsed is not Dictionary:
		push_error("Loc: %s is not a JSON object" % UI_STRINGS_PATH)
		return {}
	return parsed
