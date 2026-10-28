class_name PpeDropTarget
extends PanelContainer
## The worker figure. Accepts a dragged PpeItemButton and reports which item was dropped.

signal item_dropped(item_id: String)

var is_accepting := true


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return is_accepting and data is Dictionary and data.has(PpeItemButton.DRAG_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	item_dropped.emit(data[PpeItemButton.DRAG_KEY])
