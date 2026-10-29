class_name FixesList
extends RefCounted
## Builds the "site after your fixes" list shown with the safe scene.


## Fills `list` with the safe-scene title and one bullet row per fix.
static func rebuild(list: VBoxContainer, fixes: Array) -> void:
	for existing_child in list.get_children():
		list.remove_child(existing_child)
		existing_child.queue_free()
	var title := Label.new()
	title.theme_type_variation = "HeadingLabel"
	title.text = Loc.ui("safe_scene_title")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(title)
	for fix: Dictionary in fixes:
		list.add_child(_make_fix_row(Loc.text(fix)))


static func _make_fix_row(fix_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bullet := Label.new()
	bullet.text = "•"
	bullet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bullet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bullet)
	var fix_label := Label.new()
	fix_label.text = fix_text
	fix_label.add_theme_font_size_override("font_size", 21)
	fix_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fix_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fix_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fix_label)
	return row
