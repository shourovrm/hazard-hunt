class_name PpeItemButton
extends Button
## A PPE item in the tray. It can be tapped (handled by the owner through `pressed`) or
## dragged onto a PpeDropTarget.

const DRAG_KEY := "ppe_item_id"
const DRAG_PREVIEW_SIZE := Vector2(72, 72)

var item_id := ""
var preview_texture: Texture2D


func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled or preview_texture == null:
		return null
	var preview := TextureRect.new()
	preview.texture = preview_texture
	preview.custom_minimum_size = DRAG_PREVIEW_SIZE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {DRAG_KEY: item_id}
