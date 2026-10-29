class_name SceneVideo
extends RefCounted
## Plays a downloaded looping video over a scene picture. Videos are optional extras fetched after
## install, so a picture without its video simply stays still.

const VIDEO_ROOT := "user://videos/"
const PICTURE_ROOT := "res://assets/"


## Maps res://assets/<sector>/<case>/<name>.png to user://videos/<sector>/<case>/<name>.ogv.
static func video_path_for(picture_path: String) -> String:
	var relative_path := picture_path.trim_prefix(PICTURE_ROOT).get_basename()
	return VIDEO_ROOT + relative_path + ".ogv"


## Adds a looping video as a child of `picture` when one was downloaded for `picture_path`.
## As a child, the video takes on every fade and slide the case player gives the picture.
static func attach_if_downloaded(picture: Sprite2D, picture_path: String) -> void:
	var video_path := video_path_for(picture_path)
	if not FileAccess.file_exists(video_path):
		return
	var stream := VideoStreamTheora.new()
	stream.file = video_path
	var video := VideoStreamPlayer.new()
	video.name = "Video"
	video.stream = stream
	video.loop = true
	video.autoplay = true
	video.expand = true
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video.size = picture.texture.get_size()
	picture.add_child(video)
