class_name ActorIdle
extends RefCounted
## Loops the idle motion of a smooth-style actor sprite: "breathe" stretches it vertically and
## "work" rocks it side to side. Paper cases use PaperMotion instead, so they never call this.

const BREATHE_SCALE_AMPLITUDE := 0.02
const BREATHE_HALF_CYCLE_SECONDS := 1.6
const WORK_BOB_RADIANS := 0.035
const WORK_BOB_HALF_CYCLE_SECONDS := 0.55


static func start(sprite: Sprite2D, idle_name: String) -> void:
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
