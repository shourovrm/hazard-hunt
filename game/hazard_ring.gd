class_name HazardRing
extends Node2D
## An elliptical ring that encloses a hazard rectangle. The node origin is the rectangle
## centre, so scale tweens grow the ring around the hazard.

const SEGMENT_COUNT := 36
const RING_WIDTH := 6.0
const OUTLINE_WIDTH := 10.0
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.5)
## The ellipse through the rectangle corners has radius half-size * sqrt(2); the extra pixels
## keep the stroke clear of the hazard artwork.
const CLEARANCE := 8.0

var ring_color := Color(0.99, 0.78, 0.18)

var _outline_points := PackedVector2Array()


func configure(hazard_rect: Rect2, new_ring_color: Color) -> void:
	ring_color = new_ring_color
	position = hazard_rect.get_center()
	var radii := hazard_rect.size * 0.5 * sqrt(2.0) + Vector2.ONE * CLEARANCE
	_outline_points = PackedVector2Array()
	for segment_index in SEGMENT_COUNT + 1:
		var angle := TAU * segment_index / SEGMENT_COUNT
		_outline_points.append(Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	queue_redraw()


func _draw() -> void:
	if _outline_points.is_empty():
		return
	draw_polyline(_outline_points, OUTLINE_COLOR, OUTLINE_WIDTH, true)
	draw_polyline(_outline_points, ring_color, RING_WIDTH, true)
