class_name ResultCard
extends PanelContainer
## The card shown when a case ends: the stars, the mistake count, the references and the two
## buttons that play the case again or return to the sector map. The owner connects to the
## signals and decides what each button does.

signal play_again_requested
signal back_to_map_requested

const CARD_WIDTH := 760.0


func setup(result: Dictionary, case_data: Dictionary) -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	_add_summary(column, result)
	if str(case_data.get("review_status", "")).begins_with("draft"):
		_add_draft_notice(column)
	var references: Array = case_data["outcome"].get("references", [])
	_add_references(column, references)
	column.add_child(_make_result_buttons())


func _add_summary(column: VBoxContainer, result: Dictionary) -> void:
	var title := Label.new()
	title.theme_type_variation = "HeadingLabel"
	title.add_theme_font_size_override("font_size", 40)
	title.text = Loc.ui("case_complete")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var stars := StarRating.new()
	stars.star_size = 72.0
	stars.filled_count = result["stars"]
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(stars)

	var mistakes := Label.new()
	mistakes.text = Loc.ui("mistakes_count", {"count": result["mistakes"]})
	mistakes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(mistakes)


func _add_draft_notice(column: VBoxContainer) -> void:
	var draft_notice := Label.new()
	draft_notice.theme_type_variation = "SmallLabel"
	draft_notice.text = Loc.ui("draft_notice")
	draft_notice.add_theme_color_override("font_color", Color(0.7, 0.3, 0.05))
	draft_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(draft_notice)


func _add_references(column: VBoxContainer, references: Array) -> void:
	if references.is_empty():
		return
	column.add_child(HSeparator.new())
	var heading := Label.new()
	heading.theme_type_variation = "SmallLabel"
	heading.text = Loc.ui("references")
	column.add_child(heading)
	for reference: String in references:
		var reference_label := Label.new()
		reference_label.theme_type_variation = "SmallLabel"
		reference_label.text = "• " + reference
		reference_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(reference_label)


func _make_result_buttons() -> HBoxContainer:
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	var play_again_button := Button.new()
	play_again_button.theme_type_variation = "PrimaryButton"
	play_again_button.text = Loc.ui("play_again")
	play_again_button.custom_minimum_size = Vector2(260, 72)
	play_again_button.pressed.connect(play_again_requested.emit)
	buttons.add_child(play_again_button)
	var back_button := Button.new()
	back_button.text = Loc.ui("back_to_map")
	back_button.custom_minimum_size = Vector2(300, 72)
	back_button.pressed.connect(back_to_map_requested.emit)
	buttons.add_child(back_button)
	return buttons
