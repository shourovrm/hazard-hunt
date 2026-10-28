class_name DragPpeView
extends QuestionView
## PPE items are dragged onto the worker, or tapped, to equip them. Tapping an equipped item
## removes it. The answer is the array of equipped item ids.

const WORKER_SIZE := Vector2(240, 250)
const ICON_MAX_WIDTH := 48
const TRAY_SINGLE_COLUMN_LIMIT := 4

var _equipped_item_ids: Array[String] = []


func get_answer() -> Variant:
	return _equipped_item_ids.duplicate()


func set_answer(answer: Variant) -> void:
	if answer is not Array:
		push_error("DragPpeView: answer must be an Array of item ids, got %s" % [answer])
		return
	_equipped_item_ids.clear()
	for item_id in answer:
		if item_id is String and not _find_item(item_id).is_empty() and not _equipped_item_ids.has(item_id):
			_equipped_item_ids.append(item_id)
		else:
			push_error("DragPpeView: ignoring invalid item id %s" % [item_id])
	_rebuild()


func _reset_state() -> void:
	_equipped_item_ids.clear()


func _is_answer_valid() -> bool:
	return not _equipped_item_ids.is_empty()


func _build_body() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.add_child(_make_worker_column())
	columns.add_child(_make_tray_column())
	_body.add_child(columns)


func _make_worker_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(WORKER_SIZE.x, 0)

	var worker_target := PpeDropTarget.new()
	worker_target.is_accepting = not _locked
	worker_target.item_dropped.connect(_equip_item)
	var worker_stack := VBoxContainer.new()
	worker_target.add_child(worker_stack)

	var worker_image := TextureRect.new()
	worker_image.texture = _load_texture(_worker_image_path())
	worker_image.custom_minimum_size = WORKER_SIZE
	worker_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	worker_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	worker_stack.add_child(worker_image)
	var drop_hint_label := _make_wrapping_label(Loc.ui("drop_gear_here"))
	drop_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop_hint_label.visible = not _locked
	worker_stack.add_child(drop_hint_label)
	column.add_child(worker_target)
	# Equipped items are shown in the tray itself (green), so no separate icon row is needed.
	return column


## The worker shows the safe version once the answer is correct, when the question provides one.
func _worker_image_path() -> String:
	if _locked and question.has("target_image_safe"):
		return question["target_image_safe"]
	return question["target_image"]


func _make_tray_column() -> GridContainer:
	# Two columns once there are more than four items, so the whole question fits the panel
	# and the worker picture never scrolls out of view.
	var column := GridContainer.new()
	column.columns = 2 if question["items"].size() > TRAY_SINGLE_COLUMN_LIMIT else 1
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("h_separation", 8)
	column.add_theme_constant_override("v_separation", 8)
	for item: Dictionary in question["items"]:
		var button := _make_tray_button(item)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(button)
	return column


func _make_tray_button(item: Dictionary) -> PpeItemButton:
	var button := PpeItemButton.new()
	button.item_id = item["id"]
	button.preview_texture = _load_texture(item["icon"])
	button.icon = button.preview_texture
	button.add_theme_constant_override("icon_max_width", ICON_MAX_WIDTH)
	button.text = Loc.text(item["text"])
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, MINIMUM_TOUCH_HEIGHT)
	button.disabled = _locked
	if _equipped_item_ids.has(item["id"]):
		_apply_selected_look(button, _selected_color_for_result())
	button.pressed.connect(_toggle_item.bind(item["id"]))
	return button


## Tray buttons never leave the tray, so a tap on an equipped item must unequip it.
func _toggle_item(item_id: String) -> void:
	if _equipped_item_ids.has(item_id):
		_unequip_item(item_id)
	else:
		_equip_item(item_id)


func _equip_item(item_id: String) -> void:
	if _locked or _find_item(item_id).is_empty() or _equipped_item_ids.has(item_id):
		return
	_equipped_item_ids.append(item_id)
	Sfx.play("select")
	_rebuild()


func _unequip_item(item_id: String) -> void:
	if _locked:
		return
	_equipped_item_ids.erase(item_id)
	Sfx.play("select")
	_rebuild()


func _find_item(item_id: String) -> Dictionary:
	for item: Dictionary in question["items"]:
		if item["id"] == item_id:
			return item
	return {}
