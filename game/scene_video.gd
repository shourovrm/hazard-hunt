class_name SceneVideo
extends RefCounted
## Plays a case's optional video clips: "accident" shows what could happen after the hazard hunt and
## "safe_work" shows the safe way of working during the reveal. Each clip starts on the exact still
## scene, so it can take over without a jump. Clips are downloaded after install; without them the
## case plays with its still pictures only.

const VIDEO_ROOT := "user://videos/"
const PICTURE_ROOT := "res://assets/"
const FADE_SECONDS := 0.3
## Clips are rendered at the case scene size, so they cover the scene exactly.
const CLIP_SIZE := Vector2(1280, 720)


## Maps a case picture res://assets/<sector>/<case>/<file>.png and a clip name to
## user://videos/<sector>/<case>/<clip>.ogv.
static func clip_path(case_picture_path: String, clip_name: String) -> String:
	var case_folder := case_picture_path.trim_prefix(PICTURE_ROOT).get_base_dir()
	return VIDEO_ROOT + case_folder + "/" + clip_name + ".ogv"


## Plays the clip once on top of `parent`'s children and returns its player, or null when the clip
## was not downloaded. A finished player keeps showing its last frame until it is faded out.
static func play(parent: Node, path: String, fade_in: bool) -> VideoStreamPlayer:
	if not FileAccess.file_exists(path):
		return null
	var stream := VideoStreamTheora.new()
	stream.file = path
	var video := VideoStreamPlayer.new()
	video.name = "Clip_" + path.get_file().get_basename()
	video.stream = stream
	video.expand = true
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video.size = CLIP_SIZE
	if fade_in:
		video.modulate.a = 0.0
		video.create_tween().tween_property(video, "modulate:a", 1.0, FADE_SECONDS)
	parent.add_child(video)
	video.play()
	return video


## Fades the clip out and frees it. Takes a Variant because the clip may already be freed,
## and any Object-typed parameter rejects a freed object before this check can run.
static func fade_out(video: Variant) -> void:
	if not is_instance_valid(video) or video.has_meta("fading"):
		return
	video.set_meta("fading", true)
	var tween: Tween = video.create_tween()
	tween.tween_property(video, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(video.queue_free)
