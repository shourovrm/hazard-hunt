class_name ScreenBackground
extends RefCounted
## Adds the dimmed construction-site picture shared by the menu and the site map.

const PICTURE_PATH := "res://assets/construction/c01/bg_safe.png"


## Adds a full-screen picture plus a dark overlay of `dim_alpha` as the first children of `parent`.
static func add_to(parent: Control, dim_alpha: float) -> void:
	var picture := TextureRect.new()
	picture.texture = load(PICTURE_PATH) as Texture2D
	if picture.texture == null:
		push_error("ScreenBackground: cannot load '%s'" % PICTURE_PATH)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Covered, not fitted, so wide phone screens show no empty bars.
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.118, 0.106, 0.31, dim_alpha)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(picture)
	parent.move_child(picture, 0)
	parent.add_child(dimmer)
	parent.move_child(dimmer, 1)
