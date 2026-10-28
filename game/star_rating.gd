class_name StarRating
extends Control
## Draws a row of five-pointed stars, `filled_count` of `total_count` filled. Drawn as polygons
## because glyph coverage for star characters differs between fonts and devices.

const POINT_COUNT := 5
const INNER_TO_OUTER_RADIUS_RATIO := 0.45
const SPACING_RATIO := 0.15
const FILLED_COLOR := Color(0.99, 0.78, 0.18)
const FILLED_OUTLINE_COLOR := Color(0.72, 0.5, 0.05)
const EMPTY_COLOR := Color(0.84, 0.81, 0.74)
const EMPTY_OUTLINE_COLOR := Color(0.7, 0.66, 0.58)
const OUTLINE_WIDTH := 2.0

var filled_count := 0:
	set(value):
		filled_count = value
		queue_redraw()
var total_count := 3:
	set(value):
		total_count = value
		_update_size()
var star_size := 56.0:
	set(value):
		star_size = value
		_update_size()


func _init() -> void:
	_update_size()


func _draw() -> void:
	var spacing := star_size * SPACING_RATIO
	for star_index in total_count:
		var centre := Vector2(star_size * 0.5 + star_index * (star_size + spacing), size.y * 0.5)
		var is_filled := star_index < filled_count
		var points := _star_points(centre, star_size * 0.5)
		draw_colored_polygon(points, FILLED_COLOR if is_filled else EMPTY_COLOR)
		points.append(points[0])
		draw_polyline(points, FILLED_OUTLINE_COLOR if is_filled else EMPTY_OUTLINE_COLOR, OUTLINE_WIDTH, true)


func _update_size() -> void:
	var spacing := star_size * SPACING_RATIO
	custom_minimum_size = Vector2(total_count * star_size + (total_count - 1) * spacing, star_size)
	queue_redraw()


func _star_points(centre: Vector2, outer_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var inner_radius := outer_radius * INNER_TO_OUTER_RADIUS_RATIO
	for vertex_index in POINT_COUNT * 2:
		var radius := outer_radius if vertex_index % 2 == 0 else inner_radius
		# Start at the top (-PI / 2) so the star stands upright.
		var angle := -PI / 2.0 + vertex_index * PI / POINT_COUNT
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points
