class_name PaperMotion
extends Node
## Gives the parent Sprite2D the "boiling" look of a paper cut-out pushed by hand. On every step of
## a Timer the sprite jumps to a new small random offset, rotation and scale around its rest pose.
## Stepping instead of tweening is deliberate: smooth motion reads as a rig, not as paper.

const STEPS_PER_SECOND := 8.0
const OFFSET_JITTER_PIXELS := 1.5
const ROTATION_JITTER_RADIANS := 0.021  # about 1.2 degrees
const SCALE_JITTER_RATIO := 0.01

## Set before the node enters the tree. When false the rest pose is kept and the Timer never starts.
var animations_enabled := true

var _sprite: Sprite2D
var _rest_offset := Vector2.ZERO
var _rest_rotation := 0.0
var _rest_scale := Vector2.ONE
var _step_offset := Vector2.ZERO
var _step_rotation := 0.0
var _step_scale_ratio := 1.0
var _flip_scale_x := 1.0
var _step_timer: Timer


## Adds the PaperMotion child that drives `sprite`. Every paper actor gets one, even with animations
## disabled, so that the case structure is the same in tests and in play.
static func attach_to(sprite: Sprite2D, should_animate: bool) -> void:
	var motion := PaperMotion.new()
	motion.name = "PaperMotion"
	motion.animations_enabled = should_animate
	sprite.add_child(motion)


func _ready() -> void:
	_sprite = get_parent() as Sprite2D
	if _sprite == null:
		push_error("PaperMotion must be a child of a Sprite2D, not '%s'" % get_parent().name)
		return
	_rest_offset = _sprite.offset
	_rest_rotation = _sprite.rotation
	_rest_scale = _sprite.scale
	_step_timer = Timer.new()
	_step_timer.name = "StepTimer"
	_step_timer.wait_time = 1.0 / STEPS_PER_SECOND
	_step_timer.timeout.connect(_on_step_timeout)
	add_child(_step_timer)
	if animations_enabled:
		_step_timer.start()


## Called by the card flip. `progress` runs from 0 to 1 and maps to scale.x 1 → 0 → 1.
func set_card_flip_progress(progress: float) -> void:
	_flip_scale_x = absf(cos(PI * progress))
	_apply_pose()


## Returns the sprite to its face-up width, for a flip that was cut short.
func reset_card_flip() -> void:
	set_card_flip_progress(0.0)


func _on_step_timeout() -> void:
	_step_offset = Vector2(_random_symmetric(OFFSET_JITTER_PIXELS), _random_symmetric(OFFSET_JITTER_PIXELS))
	_step_rotation = _random_symmetric(ROTATION_JITTER_RADIANS)
	_step_scale_ratio = 1.0 + _random_symmetric(SCALE_JITTER_RATIO)
	_apply_pose()


func _random_symmetric(amount: float) -> float:
	return randf_range(-amount, amount)


## The flip is applied here as well as on each step, so a turning card is smooth between steps.
func _apply_pose() -> void:
	_sprite.offset = _rest_offset + _step_offset
	_sprite.rotation = _rest_rotation + _step_rotation
	_sprite.scale = Vector2(_rest_scale.x * _step_scale_ratio * _flip_scale_x, _rest_scale.y * _step_scale_ratio)
