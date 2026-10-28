class_name NavigationButton
extends Button
## Navy rounded button with a white icon and optional text: the Home and Exit buttons on every screen.

const BACKGROUND_COLOR := Color(0.118, 0.106, 0.31, 1.0)
const PRESSED_BACKGROUND_COLOR := Color(0.07, 0.063, 0.2, 1.0)
const CORNER_RADIUS := 16
const CONTENT_MARGIN := 8.0
const ICON_MAX_WIDTH := 36
# The theme draws text dark for white buttons; on navy every state needs white text to stay readable.
const TEXT_COLOR := Color(1, 1, 1, 1)


func _init(icon_path: String, minimum_size: Vector2) -> void:
	icon = load(icon_path) as Texture2D
	if icon == null:
		push_error("NavigationButton: cannot load icon '%s'" % icon_path)
	custom_minimum_size = minimum_size
	add_theme_constant_override("icon_max_width", ICON_MAX_WIDTH)
	add_theme_stylebox_override("normal", _make_background(BACKGROUND_COLOR))
	add_theme_stylebox_override("hover", _make_background(BACKGROUND_COLOR))
	add_theme_stylebox_override("pressed", _make_background(PRESSED_BACKGROUND_COLOR))
	add_theme_color_override("font_color", TEXT_COLOR)
	add_theme_color_override("font_hover_color", TEXT_COLOR)
	add_theme_color_override("font_pressed_color", TEXT_COLOR)
	add_theme_color_override("font_focus_color", TEXT_COLOR)


func _make_background(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_content_margin_all(CONTENT_MARGIN)
	return style
