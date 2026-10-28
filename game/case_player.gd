extends Control
## Plays one case: it shows the scene, forwards taps and answers to a CaseSession and reacts to
## the session's phase changes. All game rules live in CaseSession; this node only presents them.

const SCENE_SIZE := Vector2(1280, 720)
const SECTOR_MAP_SCENE := "res://game/sector_map.tscn"

# Layout. The mentor strip covers the bottom of the screen, so during the hunt the camera is
# moved down until the lowest hazard still ends above the strip.
const MENTOR_STRIP_HEIGHT := 172.0
const HUNT_CAMERA_TOP := 108.0
const QUESTION_PANEL_WIDTH := 760.0
const QUESTION_FOCUS_PADDING := 30.0
const INTRO_ZOOM := 1.35
const INTRO_START_FOCUS := Vector2(480, 380)
const SCREEN_MARGIN := 16.0

# Motion.
const INTRO_PAN_SECONDS := 4.0
const CAMERA_MOVE_SECONDS := 0.6
const REVEAL_FADE_SECONDS := 1.6
const REVEAL_MOVE_SECONDS := 2.2
const SPARKLE_DELAY_SECONDS := 0.7
const FOUND_POP_SECONDS := 0.35
const HINT_PULSE_SECONDS := 0.5
const HINT_PULSE_COUNT := 4
const BREATHE_SCALE_AMPLITUDE := 0.02
const BREATHE_HALF_CYCLE_SECONDS := 1.6
const WORK_BOB_RADIANS := 0.035
const WORK_BOB_HALF_CYCLE_SECONDS := 0.55

# Particles.
const DUST_PARTICLE_COUNT := 20
const SPARKLE_PARTICLES_PER_HAZARD := 8
const SOFT_DOT_SIZE := 32

const FOUND_RING_COLOR := Color(0.953, 0.478, 0.169)
const HINT_RING_COLOR := Color(1.0, 0.35, 0.25)

var animations_enabled := true

var _session: CaseSession
var _case_path := ""
var _background_is_safe := false
var _result_visible := false
var _hazard_bounds := Rect2()
var _soft_dot_texture: Texture2D

# World (everything the Camera2D looks at).
var _world: Node2D
var _camera: Camera2D
var _scene_content: Node2D
var _background_unsafe: Sprite2D
var _background_safe: Sprite2D
var _actors: Array[Sprite2D] = []
var _ring_layer: Node2D
var _found_rings: Dictionary = {}
var _hint_ring: HazardRing
var _camera_tween: Tween
var _hint_tween: Tween
var _reveal_tween: Tween

# Screen-space interface.
var _tap_catcher: Control
var _counter_pill: PanelContainer
var _counter_label: Label
var _all_found_label: Label
var _continue_button: Button
var _mentor: MentorPanel
var _question_panel: PanelContainer
var _question_counter_label: Label
var _question_slot: Control
var _question_view: QuestionView
var _next_button: Button
var _fixes_panel: PanelContainer
var _fixes_list: VBoxContainer
var _result_layer: Control
var _result_card_holder: CenterContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_soft_dot_texture = _make_soft_dot_texture()
	_build_world()
	_build_interface()
	Loc.language_changed.connect(_on_language_changed)
	if not GameState.selected_case_path.is_empty():
		start_case(GameState.selected_case_path)


# ---- Test hooks and public API -------------------------------------------------------------


func start_case(path: String) -> void:
	var case_data := CaseLoader.load_case(path)
	if case_data.is_empty():
		push_error("CasePlayer: cannot start case '%s'" % path)
		return
	_reset_for_new_case()
	_case_path = path
	_session = CaseSession.new(case_data)
	_session.phase_changed.connect(_on_phase_changed)
	_populate_world(case_data)
	_enter_intro()


func get_session() -> CaseSession:
	return _session


func skip_intro() -> void:
	if _session == null or _session.phase != CaseSession.Phase.INTRO:
		return
	_session.begin_hazard_hunt()


## Does what the visible Continue or Next button of the current step does.
func advance() -> void:
	if _session == null:
		return
	match _session.phase:
		CaseSession.Phase.INTRO:
			skip_intro()
		CaseSession.Phase.HAZARD_HUNT:
			_session.finish_hazard_hunt()
		CaseSession.Phase.QUESTIONS:
			_advance_question()
		CaseSession.Phase.SAFE_REVEAL:
			_session.finish_reveal()


## `scene_point` is in scene coordinates (1280x720), not screen coordinates.
func handle_scene_tap(scene_point: Vector2) -> void:
	if _session == null or _session.phase != CaseSession.Phase.HAZARD_HUNT:
		return
	_hide_hint_ring()
	var tap_result := _session.tap(scene_point)
	if tap_result["hit"]:
		_show_hazard_hit(tap_result)
	else:
		_mentor.say(_ui_text("not_a_hazard"))
	if tap_result["show_hint"]:
		_show_hint()
	_refresh_hazard_counter()
	_refresh_continue_button()


func get_active_question_view() -> QuestionView:
	return _question_view


func background_state() -> String:
	return "safe" if _background_is_safe else "unsafe"


func is_result_visible() -> bool:
	return _result_visible


# ---- Building the nodes --------------------------------------------------------------------


func _build_world() -> void:
	# A solid layer behind the world fills the bars that appear on screens wider than 16:9.
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -10
	add_child(backdrop_layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.07, 0.1)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_layer.add_child(backdrop)

	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_world.add_child(_camera)
	_camera.position = SCENE_SIZE / 2.0


func _build_interface() -> void:
	var interface_layer := CanvasLayer.new()
	interface_layer.name = "Interface"
	interface_layer.layer = 1
	add_child(interface_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface_layer.add_child(root)

	_tap_catcher = Control.new()
	_tap_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap_catcher.gui_input.connect(_on_tap_catcher_gui_input)
	root.add_child(_tap_catcher)

	_build_counter_pill(root)
	_build_fixes_panel(root)
	_build_question_panel(root)
	_build_continue_button(root)
	_mentor = load("res://ui/mentor_panel.tscn").instantiate()
	_mentor.animations_enabled = animations_enabled
	_mentor.tapped.connect(_on_mentor_tapped)
	root.add_child(_mentor)
	_build_result_layer(root)
	_hide_all_panels()


func _build_counter_pill(parent: Control) -> void:
	_counter_pill = PanelContainer.new()
	_counter_pill.theme_type_variation = "PillPanel"
	_counter_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_top_right(_counter_pill, SCREEN_MARGIN, 12.0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter_pill.add_child(column)
	_counter_label = Label.new()
	_counter_label.theme_type_variation = "PillLabel"
	_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_counter_label)
	_all_found_label = Label.new()
	_all_found_label.theme_type_variation = "PillLabel"
	_all_found_label.add_theme_font_size_override("font_size", 22)
	_all_found_label.add_theme_color_override("font_color", Color(0.99, 0.9, 0.62))
	_all_found_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_all_found_label)
	parent.add_child(_counter_pill)


func _build_continue_button(parent: Control) -> void:
	_continue_button = Button.new()
	_continue_button.theme_type_variation = "PrimaryButton"
	_continue_button.custom_minimum_size = Vector2(260, 72)
	_continue_button.add_theme_font_size_override("font_size", 28)
	_continue_button.anchor_left = 1.0
	_continue_button.anchor_right = 1.0
	_continue_button.anchor_top = 1.0
	_continue_button.anchor_bottom = 1.0
	_continue_button.offset_right = -24.0
	_continue_button.offset_left = -24.0
	_continue_button.offset_bottom = -(MENTOR_STRIP_HEIGHT + SCREEN_MARGIN)
	_continue_button.offset_top = _continue_button.offset_bottom
	_continue_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_continue_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_continue_button.pressed.connect(advance)
	parent.add_child(_continue_button)


func _build_question_panel(parent: Control) -> void:
	_question_panel = PanelContainer.new()
	_question_panel.theme_type_variation = "SidePanel"
	_question_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_question_panel.offset_left = -QUESTION_PANEL_WIDTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_question_panel.add_child(column)
	_question_counter_label = Label.new()
	_question_counter_label.theme_type_variation = "HeadingLabel"
	column.add_child(_question_counter_label)
	_question_slot = Control.new()
	_question_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_question_slot.custom_minimum_size = Vector2(0, 300)
	column.add_child(_question_slot)
	_next_button = Button.new()
	_next_button.theme_type_variation = "PrimaryButton"
	_next_button.custom_minimum_size = Vector2(0, 72)
	_next_button.add_theme_font_size_override("font_size", 28)
	_next_button.pressed.connect(advance)
	column.add_child(_next_button)
	parent.add_child(_question_panel)


func _build_fixes_panel(parent: Control) -> void:
	_fixes_panel = PanelContainer.new()
	_fixes_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_top_right(_fixes_panel, SCREEN_MARGIN, SCREEN_MARGIN)
	_fixes_panel.custom_minimum_size = Vector2(440, 0)
	_fixes_list = VBoxContainer.new()
	_fixes_list.add_theme_constant_override("separation", 8)
	_fixes_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fixes_panel.add_child(_fixes_list)
	parent.add_child(_fixes_panel)


func _build_result_layer(parent: Control) -> void:
	_result_layer = Control.new()
	_result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.07, 0.063, 0.2, 0.7)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(dimmer)
	_result_card_holder = CenterContainer.new()
	_result_card_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_layer.add_child(_result_card_holder)
	parent.add_child(_result_layer)


## Anchors a control to the top-right corner; it grows leftwards and downwards with its content.
func _anchor_top_right(control: Control, margin_right: float, margin_top: float) -> void:
	control.anchor_left = 1.0
	control.anchor_right = 1.0
	control.anchor_top = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = -margin_right
	control.offset_right = -margin_right
	control.offset_top = margin_top
	control.offset_bottom = margin_top
	control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	control.grow_vertical = Control.GROW_DIRECTION_END


func _hide_all_panels() -> void:
	_counter_pill.visible = false
	_continue_button.visible = false
	_mentor.visible = false
	_question_panel.visible = false
	_next_button.visible = false
	_fixes_panel.visible = false
	_result_layer.visible = false


# ---- Building the scene --------------------------------------------------------------------


func _reset_for_new_case() -> void:
	if _session != null and _session.phase_changed.is_connected(_on_phase_changed):
		_session.phase_changed.disconnect(_on_phase_changed)
	for tween in [_camera_tween, _hint_tween, _reveal_tween]:
		if tween != null:
			tween.kill()
	if _scene_content != null:
		_world.remove_child(_scene_content)
		_scene_content.queue_free()
	_actors.clear()
	_found_rings.clear()
	_hint_ring = null
	_free_question_view()
	_background_is_safe = false
	_result_visible = false
	_hide_all_panels()


func _populate_world(case_data: Dictionary) -> void:
	var scene: Dictionary = case_data["scene"]
	_scene_content = Node2D.new()
	_scene_content.name = "SceneContent"
	_world.add_child(_scene_content)
	_world.move_child(_scene_content, 0)
	_background_unsafe = _make_background(scene["background"]["unsafe"])
	_background_safe = _make_background(scene["background"]["safe"])
	_background_safe.modulate.a = 0.0
	for actor_data: Dictionary in scene["actors"]:
		_actors.append(_make_actor(actor_data))
	if "dust" in scene.get("ambient", []):
		_scene_content.add_child(_make_dust())
	_ring_layer = Node2D.new()
	_ring_layer.name = "Rings"
	_scene_content.add_child(_ring_layer)
	_hazard_bounds = _union_of_hazard_rects(case_data["hazards"])


func _make_background(texture_path: String) -> Sprite2D:
	var background := Sprite2D.new()
	background.texture = _load_texture(texture_path)
	background.centered = false
	_scene_content.add_child(background)
	return background


func _make_actor(actor_data: Dictionary) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = actor_data["id"]
	sprite.texture = _load_texture(actor_data["unsafe"])
	sprite.centered = false
	sprite.offset = _bottom_centre_offset(sprite.texture)
	sprite.position = _vector_from(actor_data["position"])
	sprite.scale = Vector2.ONE * float(actor_data["scale"])
	sprite.set_meta("safe_position", _vector_from(actor_data["safe_position"]))
	var safe_sprite := Sprite2D.new()
	safe_sprite.name = "Safe"
	safe_sprite.texture = _load_texture(actor_data["safe"])
	safe_sprite.centered = false
	safe_sprite.offset = _bottom_centre_offset(safe_sprite.texture)
	safe_sprite.modulate.a = 0.0
	sprite.add_child(safe_sprite)
	_scene_content.add_child(sprite)
	if animations_enabled:
		_start_idle_animation(sprite, actor_data.get("idle", ""))
	return sprite


## The sprite origin must be the feet (bottom-centre) so `position` and rotation pivot match the
## case file, which stores bottom-centre positions.
func _bottom_centre_offset(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var texture_size := texture.get_size()
	return Vector2(-texture_size.x / 2.0, -texture_size.y)


func _start_idle_animation(sprite: Sprite2D, idle_name: String) -> void:
	match idle_name:
		"breathe":
			var base_scale_y := sprite.scale.y
			var tween := sprite.create_tween().set_loops()
			(
				tween
				. tween_property(
					sprite, "scale:y", base_scale_y * (1.0 + BREATHE_SCALE_AMPLITUDE), BREATHE_HALF_CYCLE_SECONDS
				)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)
			(
				tween
				. tween_property(sprite, "scale:y", base_scale_y, BREATHE_HALF_CYCLE_SECONDS)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)
		"work":
			var tween := sprite.create_tween().set_loops()
			(
				tween
				. tween_property(sprite, "rotation", WORK_BOB_RADIANS, WORK_BOB_HALF_CYCLE_SECONDS)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)
			(
				tween
				. tween_property(sprite, "rotation", -WORK_BOB_RADIANS, WORK_BOB_HALF_CYCLE_SECONDS)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)
		"":
			pass
		_:
			push_error("CasePlayer: unknown idle animation '%s' on actor '%s'" % [idle_name, sprite.name])


func _make_dust() -> CPUParticles2D:
	var dust := CPUParticles2D.new()
	dust.name = "Dust"
	dust.texture = _soft_dot_texture
	dust.amount = DUST_PARTICLE_COUNT
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.position = Vector2(SCENE_SIZE.x / 2.0, 650.0)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(SCENE_SIZE.x / 2.0, 40.0)
	dust.direction = Vector2(1, -0.15)
	dust.spread = 20.0
	dust.initial_velocity_min = 12.0
	dust.initial_velocity_max = 30.0
	dust.gravity = Vector2.ZERO
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.4
	dust.color = Color(0.85, 0.72, 0.52, 0.35)
	dust.emitting = animations_enabled
	return dust


func _make_sparkle(hazard_rect: Rect2) -> CPUParticles2D:
	var sparkle := CPUParticles2D.new()
	sparkle.texture = _soft_dot_texture
	sparkle.position = hazard_rect.get_center()
	sparkle.amount = SPARKLE_PARTICLES_PER_HAZARD
	sparkle.one_shot = true
	sparkle.explosiveness = 0.85
	sparkle.lifetime = 1.1
	sparkle.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparkle.emission_rect_extents = hazard_rect.size / 2.0
	sparkle.direction = Vector2(0, -1)
	sparkle.spread = 180.0
	sparkle.initial_velocity_min = 25.0
	sparkle.initial_velocity_max = 60.0
	sparkle.gravity = Vector2.ZERO
	sparkle.scale_amount_min = 0.5
	sparkle.scale_amount_max = 1.0
	sparkle.color = Color(1.0, 0.95, 0.6, 0.95)
	sparkle.finished.connect(sparkle.queue_free)
	sparkle.emitting = true
	return sparkle


## A small radial gradient so particles are soft dots instead of hard squares.
func _make_soft_dot_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = SOFT_DOT_SIZE
	texture.height = SOFT_DOT_SIZE
	return texture


# ---- Phases --------------------------------------------------------------------------------


func _on_phase_changed(phase: CaseSession.Phase) -> void:
	match phase:
		CaseSession.Phase.HAZARD_HUNT:
			_enter_hazard_hunt()
		CaseSession.Phase.QUESTIONS:
			_enter_questions()
		CaseSession.Phase.SAFE_REVEAL:
			_enter_safe_reveal()
		CaseSession.Phase.RESULT:
			_enter_result()


func _enter_intro() -> void:
	_mentor.animations_enabled = animations_enabled
	_mentor.visible = true
	_mentor.say(_session.case_data["intro"])
	_continue_button.visible = true
	_refresh_texts()
	if animations_enabled:
		_play_intro_pan()
	else:
		_set_camera(_hunt_camera_position(), 1.0)


func _enter_hazard_hunt() -> void:
	_move_camera(_hunt_camera_position(), 1.0, CAMERA_MOVE_SECONDS)
	_counter_pill.visible = true
	_refresh_hazard_counter()
	_refresh_continue_button()


func _enter_questions() -> void:
	_counter_pill.visible = false
	_continue_button.visible = false
	_mentor.visible = false
	_hide_hint_ring()
	_move_camera(_question_camera_position(), 1.0, CAMERA_MOVE_SECONDS)
	_question_panel.visible = true
	_show_current_question()


func _enter_safe_reveal() -> void:
	_free_question_view()
	_question_panel.visible = false
	_mentor.visible = true
	_mentor.say(_session.case_data["outcome"]["mentor_line"])
	_rebuild_fixes_list()
	_fixes_panel.visible = true
	_continue_button.visible = true
	_refresh_texts()
	_move_camera(_hunt_camera_position(), 1.0, CAMERA_MOVE_SECONDS)
	_background_is_safe = true
	if animations_enabled:
		_play_reveal_animation()
	else:
		_apply_safe_state()


func _enter_result() -> void:
	_finish_reveal_immediately()
	_fixes_panel.visible = false
	_continue_button.visible = false
	_mentor.visible = false
	var result := _session.result()
	Progress.record_result(result["case_id"], result["stars"])
	_rebuild_result_card()
	_result_layer.visible = true
	_result_visible = true


# ---- Camera --------------------------------------------------------------------------------


func _hunt_camera_position() -> Vector2:
	return Vector2(SCENE_SIZE.x / 2.0, HUNT_CAMERA_TOP + get_viewport_rect().size.y / 2.0)


## Puts the left part of the screen (everything not covered by the question panel) over the scaffold.
## Screen x = 0 shows scene x = window_left, so the camera centre is window_left + half the screen.
func _question_camera_position() -> Vector2:
	var screen_size := get_viewport_rect().size
	var visible_width := screen_size.x - QUESTION_PANEL_WIDTH
	var window_left := _hazard_bounds.end.x + QUESTION_FOCUS_PADDING - visible_width
	window_left = clampf(window_left, 0.0, maxf(0.0, SCENE_SIZE.x - visible_width))
	return Vector2(window_left + screen_size.x / 2.0, screen_size.y / 2.0)


func _set_camera(target_position: Vector2, target_zoom: float) -> void:
	_camera.position = target_position
	_camera.zoom = Vector2.ONE * target_zoom


func _move_camera(target_position: Vector2, target_zoom: float, duration: float) -> void:
	if _camera_tween != null:
		_camera_tween.kill()
	if not animations_enabled:
		_set_camera(target_position, target_zoom)
		return
	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(_camera, "position", target_position, duration)
	_camera_tween.tween_property(_camera, "zoom", Vector2.ONE * target_zoom, duration)


## Starts zoomed in on the scaffold and pulls out to the full view, so the whole scene is seen once.
func _play_intro_pan() -> void:
	_set_camera(INTRO_START_FOCUS, INTRO_ZOOM)
	_move_camera(_hunt_camera_position(), 1.0, INTRO_PAN_SECONDS)


func _screen_to_scene(screen_point: Vector2) -> Vector2:
	return _world.get_global_transform_with_canvas().affine_inverse() * screen_point


# ---- Hazard hunt ---------------------------------------------------------------------------


func _on_tap_catcher_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _session == null:
		return
	if _session.phase == CaseSession.Phase.INTRO:
		skip_intro()
		return
	var scene_point := _screen_to_scene(mouse_event.position)
	# Taps in the empty bars beside the scene are not guesses and must not count as misses.
	if Rect2(Vector2.ZERO, SCENE_SIZE).has_point(scene_point):
		handle_scene_tap(scene_point)


func _show_hazard_hit(tap_result: Dictionary) -> void:
	var hazard := _hazard_by_id(tap_result["hazard_id"])
	if tap_result["already_found"]:
		_mentor.say(_ui_text("already_found"))
		return
	_add_found_ring(hazard)
	_mentor.say(hazard["explain"], hazard["label"])


func _add_found_ring(hazard: Dictionary) -> void:
	var ring := HazardRing.new()
	ring.configure(_rect_from(hazard["rect"]), FOUND_RING_COLOR)
	_ring_layer.add_child(ring)
	_found_rings[hazard["id"]] = ring
	if not animations_enabled:
		return
	ring.scale = Vector2.ONE * 1.5
	ring.modulate.a = 0.0
	var pop := create_tween().set_parallel(true)
	pop.tween_property(ring, "scale", Vector2.ONE, FOUND_POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	pop.tween_property(ring, "modulate:a", 1.0, FOUND_POP_SECONDS * 0.5)


func _show_hint() -> void:
	var hint_id := _session.hint_hazard_id()
	if hint_id.is_empty():
		return
	_mentor.say(_session.case_data["hazard_hint"], _ui_text("not_a_hazard"))
	if _hint_ring == null:
		_hint_ring = HazardRing.new()
		_ring_layer.add_child(_hint_ring)
	_hint_ring.configure(_rect_from(_hazard_by_id(hint_id)["rect"]), HINT_RING_COLOR)
	_hint_ring.visible = true
	if not animations_enabled:
		return
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_ring.scale = Vector2.ONE
	_hint_tween = create_tween().set_loops(HINT_PULSE_COUNT)
	_hint_tween.tween_property(_hint_ring, "scale", Vector2.ONE * 1.25, HINT_PULSE_SECONDS).set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(_hint_ring, "scale", Vector2.ONE, HINT_PULSE_SECONDS).set_trans(Tween.TRANS_SINE)
	_hint_tween.finished.connect(_hide_hint_ring)


func _hide_hint_ring() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
		_hint_tween = null
	if _hint_ring != null:
		_hint_ring.visible = false


func _refresh_hazard_counter() -> void:
	var found := _session.found_hazard_ids().size()
	var total: int = _session.case_data["hazards"].size()
	_counter_label.text = Loc.ui("hazards_found", {"found": found, "total": total})
	_all_found_label.text = Loc.ui("all_hazards_found")
	_all_found_label.visible = _session.all_hazards_found()


func _refresh_continue_button() -> void:
	if _session.phase == CaseSession.Phase.HAZARD_HUNT:
		_continue_button.visible = _session.all_hazards_found()


func _on_mentor_tapped() -> void:
	# A tap on the mentor strip continues only where a Continue button is showing.
	if _continue_button.visible:
		advance()


# ---- Questions -----------------------------------------------------------------------------


func _show_current_question() -> void:
	_free_question_view()
	var question_view := QuestionFactory.create(_session.current_question())
	if question_view == null:
		push_error("CasePlayer: no view for question %d" % _session.question_index())
		return
	_question_view = question_view
	_question_slot.add_child(question_view)
	question_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	question_view.answer_submitted.connect(_on_answer_submitted)
	_next_button.visible = false
	_refresh_question_counter()


func _free_question_view() -> void:
	if _question_view == null:
		return
	_question_slot.remove_child(_question_view)
	_question_view.queue_free()
	_question_view = null


func _on_answer_submitted(answer: Variant) -> void:
	if _question_view == null:
		return
	var result := _session.submit_answer(answer)
	if result.is_empty():
		return
	_question_view.show_result(result)
	_next_button.visible = result["correct"]


func _advance_question() -> void:
	if _question_view == null or not _question_view.is_locked():
		return
	if _session.next_question():
		_show_current_question()


func _refresh_question_counter() -> void:
	var values := {"number": _session.question_index() + 1, "total": _session.question_count()}
	_question_counter_label.text = Loc.ui("question_counter", values)


# ---- Safe reveal ---------------------------------------------------------------------------


func _play_reveal_animation() -> void:
	_reveal_tween = create_tween().set_parallel(true)
	_reveal_tween.tween_property(_background_safe, "modulate:a", 1.0, REVEAL_FADE_SECONDS)
	_reveal_tween.tween_property(_ring_layer, "modulate:a", 0.0, REVEAL_FADE_SECONDS * 0.5)
	for actor in _actors:
		var safe_sprite := actor.get_node("Safe") as Sprite2D
		_reveal_tween.tween_property(actor, "self_modulate:a", 0.0, REVEAL_FADE_SECONDS)
		_reveal_tween.tween_property(safe_sprite, "modulate:a", 1.0, REVEAL_FADE_SECONDS)
		var move := _reveal_tween.tween_property(
			actor, "position", actor.get_meta("safe_position"), REVEAL_MOVE_SECONDS
		)
		move.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reveal_tween.tween_callback(_emit_sparkles).set_delay(SPARKLE_DELAY_SECONDS)
	_reveal_tween.finished.connect(_apply_safe_state)


func _emit_sparkles() -> void:
	for hazard: Dictionary in _session.case_data["hazards"]:
		_scene_content.add_child(_make_sparkle(_rect_from(hazard["rect"])))


## The end state of the reveal, also used to jump there when the player continues early.
func _apply_safe_state() -> void:
	_background_safe.modulate.a = 1.0
	_background_unsafe.visible = false
	_ring_layer.visible = false
	for actor in _actors:
		actor.self_modulate.a = 0.0
		(actor.get_node("Safe") as Sprite2D).modulate.a = 1.0
		actor.position = actor.get_meta("safe_position")


func _finish_reveal_immediately() -> void:
	if _reveal_tween != null:
		_reveal_tween.kill()
		_reveal_tween = null
	_apply_safe_state()


func _rebuild_fixes_list() -> void:
	for existing_child in _fixes_list.get_children():
		_fixes_list.remove_child(existing_child)
		existing_child.queue_free()
	var title := Label.new()
	title.theme_type_variation = "HeadingLabel"
	title.text = Loc.ui("safe_scene_title")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fixes_list.add_child(title)
	for fix: Dictionary in _session.case_data["outcome"]["fixes"]:
		_fixes_list.add_child(_make_fix_row(Loc.text(fix)))


func _make_fix_row(fix_text: String) -> HBoxContainer:
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


# ---- Result --------------------------------------------------------------------------------


func _rebuild_result_card() -> void:
	for existing_child in _result_card_holder.get_children():
		_result_card_holder.remove_child(existing_child)
		existing_child.queue_free()
	var result := _session.result()
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 0)
	_result_card_holder.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)

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

	if str(_session.case_data.get("review_status", "")).begins_with("draft"):
		var draft_notice := Label.new()
		draft_notice.theme_type_variation = "SmallLabel"
		draft_notice.text = Loc.ui("draft_notice")
		draft_notice.add_theme_color_override("font_color", Color(0.7, 0.3, 0.05))
		draft_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(draft_notice)

	_add_references(column)
	column.add_child(_make_result_buttons())


func _add_references(column: VBoxContainer) -> void:
	var references: Array = _session.case_data["outcome"].get("references", [])
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
	play_again_button.pressed.connect(_on_play_again_pressed)
	buttons.add_child(play_again_button)
	var back_button := Button.new()
	back_button.text = Loc.ui("back_to_map")
	back_button.custom_minimum_size = Vector2(300, 72)
	back_button.pressed.connect(_on_back_to_map_pressed)
	buttons.add_child(back_button)
	return buttons


func _on_play_again_pressed() -> void:
	start_case(_case_path)


func _on_back_to_map_pressed() -> void:
	get_tree().change_scene_to_file(SECTOR_MAP_SCENE)


# ---- Text ----------------------------------------------------------------------------------


func _refresh_texts() -> void:
	_continue_button.text = Loc.ui("continue")
	_next_button.text = Loc.ui("next")
	if _session == null:
		return
	_refresh_hazard_counter()
	if _session.phase == CaseSession.Phase.QUESTIONS:
		_refresh_question_counter()


func _on_language_changed(_language: String) -> void:
	_refresh_texts()
	if _session == null:
		return
	if _fixes_panel.visible:
		_rebuild_fixes_list()
	if _result_visible:
		_rebuild_result_card()


## Wraps a UI string key as a localized dictionary so it can be passed to MentorPanel.say.
func _ui_text(key: String) -> Dictionary:
	var localized := {}
	var previous_language := Loc.language
	# Assigning the variable (not set_language) reads each language without emitting
	# language_changed, which would rebuild every screen in the middle of this loop.
	for language_code in Loc.SUPPORTED_LANGUAGES:
		Loc.language = language_code
		localized[language_code] = Loc.ui(key)
	Loc.language = previous_language
	return localized


# ---- Helpers -------------------------------------------------------------------------------


func _hazard_by_id(hazard_id: String) -> Dictionary:
	for hazard: Dictionary in _session.case_data["hazards"]:
		if hazard["id"] == hazard_id:
			return hazard
	push_error("CasePlayer: unknown hazard id '%s'" % hazard_id)
	return {}


func _union_of_hazard_rects(hazards: Array) -> Rect2:
	var bounds := _rect_from(hazards[0]["rect"])
	for hazard: Dictionary in hazards:
		bounds = bounds.merge(_rect_from(hazard["rect"]))
	return bounds


func _rect_from(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])


func _vector_from(values: Array) -> Vector2:
	return Vector2(values[0], values[1])


func _load_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("CasePlayer: cannot load texture '%s'" % path)
	return texture
