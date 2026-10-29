class_name AccidentClip
extends Node
## Runs a case's "what could happen" clip: plays it once, holds the last frame (the moment before
## impact) with a red tint, then fades it away and emits `ended`. The case player starts the
## questions on `ended`.

signal ended

const HOLD_SECONDS := 2.0
const FREEZE_TINT := Color(1.0, 0.6, 0.55)

var _video: VideoStreamPlayer
var _has_ended := false


## Starts the clip on top of `parent`, or returns null when it was not downloaded.
static func start(parent: Node, path: String) -> AccidentClip:
	var video := SceneVideo.play(parent, path, false)
	if video == null:
		return null
	var clip := AccidentClip.new()
	clip._video = video
	# A child of the video, so both are freed together with the scene.
	video.add_child(clip)
	video.finished.connect(clip._freeze)
	return clip


## Ends the clip at once, for a player who presses Continue instead of waiting.
func skip() -> void:
	_end()


func _freeze() -> void:
	_video.modulate = FREEZE_TINT
	get_tree().create_timer(HOLD_SECONDS).timeout.connect(_end)


func _end() -> void:
	if _has_ended:
		return
	_has_ended = true
	ended.emit()
	SceneVideo.fade_out(_video)
