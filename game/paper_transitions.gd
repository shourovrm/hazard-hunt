class_name PaperTransitions
extends RefCounted
## Scene changes for paper-style cases. A background sheet slides in like a new sheet of paper
## laid on the desk, and an actor turns over like a card when its picture changes.

const SHEET_SLIDE_SECONDS := 0.6
const SHEET_START_ROTATION := 0.0524  # about 3 degrees, in radians
const SHEET_SHADOW_OFFSET := Vector2(10.0, 12.0)
const SHEET_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.35)
const SHADOW_NODE_NAME := "DropShadow"
const CARD_FLIP_SECONDS := 0.5


## Slides `sheet` from `offscreen_x` on the x axis to its rest pose at the origin, turning it from
## SHEET_START_ROTATION to 0 on the way. `tween` must be a parallel tween, because the two property
## tweeners have to run at the same time.
static func slide_sheet_in(tween: Tween, sheet: Sprite2D, offscreen_x: float) -> void:
	var start_position := Vector2(offscreen_x, 0.0)
	sheet.modulate.a = 1.0
	sheet.position = start_position
	sheet.rotation = SHEET_START_ROTATION
	add_drop_shadow(sheet)
	(
		tween
		. tween_property(sheet, "position", Vector2.ZERO, SHEET_SLIDE_SECONDS)
		. from(start_position)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. tween_property(sheet, "rotation", 0.0, SHEET_SLIDE_SECONDS)
		. from(SHEET_START_ROTATION)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


## A dark copy of the sheet, drawn behind it and offset down and right, so the sheet's edge casts a
## shadow on the desk. Being a child, the copy follows the sheet through the slide.
static func add_drop_shadow(sheet: Sprite2D) -> void:
	var shadow := Sprite2D.new()
	shadow.name = SHADOW_NODE_NAME
	shadow.texture = sheet.texture
	shadow.centered = sheet.centered
	shadow.position = SHEET_SHADOW_OFFSET
	shadow.modulate = SHEET_SHADOW_COLOR
	# show_behind_parent keeps the shadow above the sheets drawn before this one, which a negative
	# z_index would not do: that would draw it under the unsafe background.
	shadow.show_behind_parent = true
	sheet.add_child(shadow)


## Puts a sheet back at its rest pose. Needed when finishing the reveal early cuts its slide short.
static func settle_sheet(sheet: Sprite2D) -> void:
	sheet.position = Vector2.ZERO
	sheet.rotation = 0.0


## Adds a card flip to the parallel `tween`. The actor turns edge-on, the picture swaps at the edge
## and the card turns back. The actor must have a PaperMotion child, which does the scaling.
static func add_card_flip(tween: Tween, actor: Sprite2D, safe_sprite: Sprite2D) -> void:
	var motion := actor.get_node("PaperMotion") as PaperMotion
	tween.tween_method(_show_card_frame.bind(motion, actor, safe_sprite), 0.0, 1.0, CARD_FLIP_SECONDS)


## Returns an actor to its face-up scale when a flip was cut short. Actors without PaperMotion
## (smooth cases) have nothing to reset.
static func finish_card_flip(actor: Sprite2D) -> void:
	var motion := actor.get_node_or_null("PaperMotion") as PaperMotion
	if motion != null:
		motion.reset_card_flip()


## One frame of the flip. The safe picture is shown from the halfway point, when the card is edge-on
## and nothing is visible to swap. Both pictures are set every frame, so the result depends only on
## `progress`, not on which frames the tween happened to run.
static func _show_card_frame(progress: float, motion: PaperMotion, actor: Sprite2D, safe_sprite: Sprite2D) -> void:
	motion.set_card_flip_progress(progress)
	if progress >= 0.5:
		actor.self_modulate.a = 0.0
		safe_sprite.modulate.a = 1.0
	else:
		actor.self_modulate.a = 1.0
		safe_sprite.modulate.a = 0.0
