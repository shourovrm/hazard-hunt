class_name CaseLoader
extends RefCounted
## Reads case and sector files from disk and checks that a case is complete
## enough to play, so the UI never meets missing data.

const REQUIRED_CASE_KEYS: Array[String] = ["id", "title", "scene", "intro", "hazards", "questions", "outcome"]
const QUESTION_TYPES: Array[String] = [
	"single_choice",
	"multi_select",
	"ordering",
	"dialogue",
	"drag_ppe",
	"gate_check",
	"permit_check",
	"evidence_board",
	"cause_chain",
	"matching",
]
const DIALOGUE_QUALITIES: Array[String] = ["best", "ok", "fail"]
const REQUIRED_LANGUAGES: Array[String] = ["en", "bn"]
const GATE_WORKER_KEYS: Array[String] = ["id", "name", "image", "image_safe", "missing", "feedback"]
const PERMIT_STATUSES: Array[String] = ["ok", "not_ok"]
const PERMIT_DECISIONS: Array[String] = ["approve", "refuse"]
# A chain with fewer slots would not show a "why" step between what happened and the root cause.
const CAUSE_CHAIN_MIN_SLOTS := 3


static func load_case(path: String) -> Dictionary:
	var parsed := _read_json_dictionary(path)
	if parsed.is_empty():
		return {}
	var problems := validate(parsed)
	if not problems.is_empty():
		push_error("CaseLoader: case '%s' is invalid:\n- %s" % [path, "\n- ".join(problems)])
		return {}
	return parsed


static func load_sector(path: String) -> Dictionary:
	return _read_json_dictionary(path)


## Reads the list of sectors shown on the sector selection page.
static func load_sector_index(path: String = "res://content/sectors.json") -> Dictionary:
	return _read_json_dictionary(path)


## Returns one readable message per problem; an empty array means the case is valid.
static func validate(case_data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key in REQUIRED_CASE_KEYS:
		if not case_data.has(key):
			problems.append("missing required key '%s'" % key)
	_check_localized(case_data.get("title"), "title", problems)
	_check_localized(case_data.get("intro"), "intro", problems)
	_check_hazards(case_data.get("hazards"), problems)
	_check_questions(case_data.get("questions"), problems)
	return problems


static func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("CaseLoader: file does not exist: '%s'" % path)
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK:
		push_error(
			"CaseLoader: JSON error in '%s' line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()]
		)
		return {}
	if not parser.data is Dictionary:
		push_error("CaseLoader: top level of '%s' is not an object" % path)
		return {}
	return parser.data


static func _check_localized(value: Variant, where: String, problems: Array[String]) -> void:
	if value == null:
		return  # a missing key is reported by the caller
	if not value is Dictionary:
		problems.append("%s: expected an object with 'en' and 'bn' text" % where)
		return
	for language in REQUIRED_LANGUAGES:
		if not value.has(language) or not value[language] is String or value[language] == "":
			problems.append("%s: missing '%s' text" % [where, language])


static func _check_hazards(hazards: Variant, problems: Array[String]) -> void:
	if hazards == null:
		return
	# An empty list is valid: a case such as the morning gate check has no hunt.
	if not hazards is Array:
		problems.append("hazards: expected an array")
		return
	for hazard in hazards:
		if not hazard is Dictionary:
			problems.append("hazards: every entry must be an object")
			continue
		var where := "hazard '%s'" % str(hazard.get("id", "?"))
		if not hazard.has("id"):
			problems.append("%s: missing 'id'" % where)
		_check_localized(hazard.get("label"), where + " label", problems)
		_check_localized(hazard.get("explain"), where + " explain", problems)
		_check_rect(hazard.get("rect"), where, problems)


static func _check_rect(rect: Variant, where: String, problems: Array[String]) -> void:
	if not rect is Array or rect.size() != 4:
		problems.append("%s: rect must be 4 numbers [x, y, width, height]" % where)
		return
	for number in rect:
		if not (number is float or number is int):
			problems.append("%s: rect must contain only numbers, got %s" % [where, str(rect)])
			return
	if rect[2] <= 0 or rect[3] <= 0:
		problems.append("%s: rect width and height must be positive, got %s" % [where, str(rect)])


static func _check_questions(questions: Variant, problems: Array[String]) -> void:
	if questions == null:
		return
	if not questions is Array or questions.is_empty():
		problems.append("questions: expected a non-empty array")
		return
	var seen_ids: Array[String] = []
	for question in questions:
		if not question is Dictionary:
			problems.append("questions: every entry must be an object")
			continue
		var question_id := str(question.get("id", ""))
		var where := "question '%s'" % question_id
		if question_id == "":
			problems.append("%s: missing 'id'" % where)
		elif question_id in seen_ids:
			problems.append("%s: duplicate question id" % where)
		seen_ids.append(question_id)
		_check_question(question, where, problems)


static func _check_question(question: Dictionary, where: String, problems: Array[String]) -> void:
	var question_type := str(question.get("type", ""))
	if question_type not in QUESTION_TYPES:
		problems.append("%s: unknown type '%s'" % [where, question_type])
		return
	if not question.has("prompt"):
		problems.append("%s: missing 'prompt'" % where)
	_check_localized(question.get("prompt"), where + " prompt", problems)
	# Hint and explanation are shown to the player, so they must be bilingual when present.
	for optional_key in ["hint", "explanation"]:
		if question.has(optional_key):
			_check_localized(question[optional_key], "%s %s" % [where, optional_key], problems)
	match question_type:
		"single_choice":
			_check_single_choice(question, where, problems)
		"multi_select":
			_check_id_set_answer(question, "options", where, problems)
		"drag_ppe":
			_check_id_set_answer(question, "items", where, problems)
		"ordering":
			_check_ordering(question, where, problems)
		"dialogue":
			_check_dialogue(question, where, problems)
		"gate_check":
			_check_gate_check(question, where, problems)
		"permit_check":
			_check_permit_check(question, where, problems)
		"evidence_board":
			_check_evidence_board(question, where, problems)
		"cause_chain":
			_check_cause_chain(question, where, problems)
		"matching":
			_check_matching(question, where, problems)


## Validates the entries of `list_key` (options, items, cards or targets) and returns their ids.
## `text_key` names the localized field of each entry; evidence cards use "caption".
static func _check_entries(
	question: Dictionary, list_key: String, where: String, problems: Array[String], text_key: String = "text"
) -> Array:
	var entry_ids: Array = []
	var entries: Variant = question.get(list_key)
	if not entries is Array or entries.is_empty():
		problems.append("%s: '%s' must be a non-empty array" % [where, list_key])
		return entry_ids
	for entry in entries:
		if not entry is Dictionary or not entry.has("id"):
			problems.append("%s: every entry in '%s' needs an 'id'" % [where, list_key])
			continue
		entry_ids.append(entry["id"])
		_check_localized(entry.get(text_key), "%s %s '%s' %s" % [where, list_key, entry["id"], text_key], problems)
	return entry_ids


static func _check_unique_ids(ids: Array, where: String, problems: Array[String]) -> void:
	var seen_ids: Array = []
	for entry_id in ids:
		if entry_id in seen_ids:
			problems.append("%s: duplicate id '%s'" % [where, str(entry_id)])
		seen_ids.append(entry_id)


static func _check_single_choice(question: Dictionary, where: String, problems: Array[String]) -> void:
	var option_ids := _check_entries(question, "options", where, problems)
	if not question.get("correct") in option_ids:
		problems.append("%s: correct '%s' is not an option id" % [where, str(question.get("correct"))])


static func _check_id_set_answer(
	question: Dictionary, list_key: String, where: String, problems: Array[String]
) -> void:
	var known_ids := _check_entries(question, list_key, where, problems)
	var correct: Variant = question.get("correct")
	if not correct is Array or correct.is_empty():
		problems.append("%s: 'correct' must be a non-empty array" % where)
		return
	for correct_id in correct:
		if correct_id not in known_ids:
			problems.append("%s: correct id '%s' is not in '%s'" % [where, str(correct_id), list_key])


static func _check_ordering(question: Dictionary, where: String, problems: Array[String]) -> void:
	var item_ids := _check_entries(question, "items", where, problems)
	var correct_order: Variant = question.get("correct_order")
	if not correct_order is Array:
		problems.append("%s: 'correct_order' must be an array" % where)
		return
	var sorted_expected := item_ids.duplicate()
	var sorted_actual: Array = correct_order.duplicate()
	sorted_expected.sort()
	sorted_actual.sort()
	if sorted_expected != sorted_actual:
		problems.append(
			"%s: correct_order %s is not a permutation of item ids %s" % [where, str(correct_order), str(item_ids)]
		)


static func _check_dialogue(question: Dictionary, where: String, problems: Array[String]) -> void:
	_check_localized(question.get("npc_line"), where + " npc_line", problems)
	var choices: Variant = question.get("choices")
	if not choices is Array or choices.is_empty():
		problems.append("%s: 'choices' must be a non-empty array" % where)
		return
	var best_count := 0
	for choice in choices:
		if not choice is Dictionary:
			problems.append("%s: every choice must be an object" % where)
			continue
		var choice_where := "%s choice '%s'" % [where, str(choice.get("id", "?"))]
		for key in ["text", "reply", "feedback"]:
			_check_localized(choice.get(key), "%s %s" % [choice_where, key], problems)
		var quality := str(choice.get("quality", ""))
		if quality not in DIALOGUE_QUALITIES:
			problems.append("%s: quality must be best, ok or fail, got '%s'" % [choice_where, quality])
		elif quality == "best":
			best_count += 1
	if best_count == 0:
		problems.append("%s: needs at least one choice with quality 'best'" % where)


static func _check_gate_check(question: Dictionary, where: String, problems: Array[String]) -> void:
	var ppe_ids := _check_entries(question, "ppe_items", where, problems)
	_check_ppe_icons(question.get("ppe_items"), where, problems)
	_check_gate_workers(question.get("workers"), ppe_ids, where, problems)


static func _check_ppe_icons(ppe_items: Variant, where: String, problems: Array[String]) -> void:
	if not ppe_items is Array:
		return  # _check_entries already reported the missing array
	for item in ppe_items:
		if not item is Dictionary:
			continue  # _check_entries already reported the bad entry
		var icon: Variant = item.get("icon")
		if not icon is String or icon == "":
			problems.append("%s: ppe item '%s' needs an 'icon' path" % [where, str(item.get("id", "?"))])


static func _check_gate_workers(workers: Variant, ppe_ids: Array, where: String, problems: Array[String]) -> void:
	if not workers is Array or workers.is_empty():
		problems.append("%s: 'workers' must be a non-empty array" % where)
		return
	var seen_worker_ids: Array = []
	for worker in workers:
		if not worker is Dictionary:
			problems.append("%s: every worker must be an object" % where)
			continue
		var worker_where := "%s worker '%s'" % [where, str(worker.get("id", "?"))]
		for key in GATE_WORKER_KEYS:
			if not worker.has(key):
				problems.append("%s: missing '%s'" % [worker_where, key])
		if worker.has("id"):
			if worker["id"] in seen_worker_ids:
				problems.append("%s: duplicate worker id" % worker_where)
			seen_worker_ids.append(worker["id"])
		_check_localized(worker.get("name"), worker_where + " name", problems)
		_check_localized(worker.get("feedback"), worker_where + " feedback", problems)
		_check_missing_items(worker.get("missing"), ppe_ids, worker_where, problems)


static func _check_missing_items(missing: Variant, ppe_ids: Array, where: String, problems: Array[String]) -> void:
	if missing == null:
		return  # a missing key is reported by the caller
	if not missing is Array:
		problems.append("%s: 'missing' must be an array of ppe ids" % where)
		return
	for ppe_id in missing:
		if ppe_id not in ppe_ids:
			problems.append("%s: missing '%s' is not a ppe_items id" % [where, str(ppe_id)])


static func _check_permit_check(question: Dictionary, where: String, problems: Array[String]) -> void:
	if not question.has("permit_title"):
		problems.append("%s: missing 'permit_title'" % where)
	_check_localized(question.get("permit_title"), where + " permit_title", problems)
	var statuses := _check_permit_checks(question.get("checks"), where, problems)
	_check_permit_decision(question.get("correct_decision"), statuses, where, problems)


## Returns the status of every valid check, so the decision can be checked against them.
static func _check_permit_checks(checks: Variant, where: String, problems: Array[String]) -> Array[String]:
	var statuses: Array[String] = []
	if not checks is Array or checks.is_empty():
		problems.append("%s: 'checks' must be a non-empty array" % where)
		return statuses
	var seen_check_ids: Array = []
	for check in checks:
		if not check is Dictionary or not check.has("id"):
			problems.append("%s: every check needs an 'id'" % where)
			continue
		var check_where := "%s check '%s'" % [where, str(check["id"])]
		if check["id"] in seen_check_ids:
			problems.append("%s: duplicate check id" % check_where)
		seen_check_ids.append(check["id"])
		_check_localized(check.get("text"), check_where + " text", problems)
		var status := str(check.get("status", ""))
		if status not in PERMIT_STATUSES:
			problems.append("%s: status must be ok or not_ok, got '%s'" % [check_where, status])
		else:
			statuses.append(status)
	return statuses


# The permit must be refused when any check failed and approved only when every check passed.
static func _check_permit_decision(
	decision: Variant, statuses: Array[String], where: String, problems: Array[String]
) -> void:
	if str(decision) not in PERMIT_DECISIONS:
		problems.append("%s: correct_decision must be approve or refuse, got '%s'" % [where, str(decision)])
		return
	if statuses.is_empty():
		return  # the check problems above already explain why there is nothing to compare
	var expected_decision := "refuse" if "not_ok" in statuses else "approve"
	if str(decision) != expected_decision:
		problems.append(
			"%s: correct_decision is '%s' but the checks require '%s'" % [where, str(decision), expected_decision]
		)


static func _check_evidence_board(question: Dictionary, where: String, problems: Array[String]) -> void:
	var card_ids := _check_entries(question, "cards", where, problems, "caption")
	_check_unique_ids(card_ids, where + " cards", problems)
	_check_card_images(question.get("cards"), where, problems)


static func _check_card_images(cards: Variant, where: String, problems: Array[String]) -> void:
	if not cards is Array:
		return  # _check_entries already reported the missing array
	for card in cards:
		if not card is Dictionary:
			continue  # _check_entries already reported the bad entry
		var image: Variant = card.get("image")
		if not image is String or image == "":
			problems.append("%s: card '%s' needs an 'image' path" % [where, str(card.get("id", "?"))])


static func _check_cause_chain(question: Dictionary, where: String, problems: Array[String]) -> void:
	var card_ids := _check_entries(question, "cards", where, problems)
	_check_unique_ids(card_ids, where + " cards", problems)
	var correct_chain: Variant = question.get("correct_chain")
	if not correct_chain is Array or correct_chain.size() < CAUSE_CHAIN_MIN_SLOTS:
		problems.append("%s: 'correct_chain' must be an array of at least %d card ids" % [where, CAUSE_CHAIN_MIN_SLOTS])
		return
	for card_id in correct_chain:
		if card_id not in card_ids:
			problems.append("%s: correct_chain id '%s' is not in 'cards'" % [where, str(card_id)])
	_check_unique_ids(correct_chain, where + " correct_chain", problems)


static func _check_matching(question: Dictionary, where: String, problems: Array[String]) -> void:
	var item_ids := _check_entries(question, "items", where, problems)
	var target_ids := _check_entries(question, "targets", where, problems)
	_check_matching_correct(question.get("correct"), item_ids, target_ids, where, problems)


## Every item must map to a known target, and the map must not name unknown items.
static func _check_matching_correct(
	correct: Variant, item_ids: Array, target_ids: Array, where: String, problems: Array[String]
) -> void:
	if not correct is Dictionary:
		problems.append("%s: 'correct' must be an object mapping item ids to target ids" % where)
		return
	for item_id in item_ids:
		if not correct.has(item_id):
			problems.append("%s: no correct target for item '%s'" % [where, str(item_id)])
		elif correct[item_id] not in target_ids:
			problems.append(
				(
					"%s: correct target '%s' for item '%s' is not in 'targets'"
					% [where, str(correct[item_id]), str(item_id)]
				)
			)
	for mapped_item_id in correct:
		if mapped_item_id not in item_ids:
			problems.append("%s: correct maps '%s', which is not in 'items'" % [where, str(mapped_item_id)])
