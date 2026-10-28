extends Node
## Autoload "Sfx": plays the sound effects and the looping site ambience. The mute setting
## is kept here while the game runs and saved through Progress.

const SOUND_NAMES: Array[String] = [
	"tap",
	"select",
	"hazard_found",
	"miss",
	"correct",
	"wrong",
	"next",
	"case_complete",
]
const SOUND_FILE_TEMPLATE := "res://assets/audio/%s.ogg"
# Each effect gets its own player so two effects can overlap; the pool size caps the overlap.
const EFFECT_PLAYER_COUNT := 4
const AMBIENCE_VOLUME_DB := -14.0
# Godot treats -80 dB as silence; a muted ambience keeps playing at this level so unmuting
# resumes it in place instead of restarting it.
const SILENT_VOLUME_DB := -80.0
const FADE_SECONDS := 0.5

var _effect_streams: Dictionary = {}
var _effect_players: Array[AudioStreamPlayer] = []
var _next_effect_player_index := 0
var _ambience_player: AudioStreamPlayer
var _ambience_path := ""
var _fade_tween: Tween
var _muted := false


func _ready() -> void:
	_muted = not Progress.get_sound_enabled()
	for sound_name in SOUND_NAMES:
		var stream := _load_stream(SOUND_FILE_TEMPLATE % sound_name)
		if stream != null:
			_effect_streams[sound_name] = stream
	for player_index in EFFECT_PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_effect_players.append(player)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.volume_db = SILENT_VOLUME_DB
	add_child(_ambience_player)


func has_sound(sound_name: String) -> bool:
	return _effect_streams.has(sound_name)


func play(sound_name: String) -> void:
	if not has_sound(sound_name):
		push_error("Sfx: unknown sound '%s'" % sound_name)
		return
	if _muted:
		return
	var player := _take_free_effect_player()
	player.stream = _effect_streams[sound_name]
	player.play()


func play_ambience(path: String) -> void:
	if path == _ambience_path:
		return
	var stream := _load_looping_stream(path)
	if stream == null:
		return
	_ambience_path = path
	_ambience_player.stream = stream
	_ambience_player.volume_db = SILENT_VOLUME_DB
	_ambience_player.play()
	_fade_ambience(_ambience_target_volume_db(), false)


func stop_ambience() -> void:
	if _ambience_path.is_empty():
		return
	_ambience_path = ""
	_fade_ambience(SILENT_VOLUME_DB, true)


func current_ambience() -> String:
	return _ambience_path


func set_muted(muted: bool) -> void:
	_muted = muted
	Progress.set_sound_enabled(not muted)
	if not _ambience_path.is_empty():
		_fade_ambience(_ambience_target_volume_db(), false)


func is_muted() -> bool:
	return _muted


func _take_free_effect_player() -> AudioStreamPlayer:
	for player in _effect_players:
		if not player.playing:
			return player
	# Every player is busy, so the next one in turn is cut short to make room.
	var reused_player := _effect_players[_next_effect_player_index]
	_next_effect_player_index = (_next_effect_player_index + 1) % EFFECT_PLAYER_COUNT
	return reused_player


func _ambience_target_volume_db() -> float:
	return SILENT_VOLUME_DB if _muted else AMBIENCE_VOLUME_DB


# A tween instead of an instant change, so the ambience does not click when it starts, stops
# or is muted.
func _fade_ambience(target_volume_db: float, stop_when_done: bool) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_ambience_player, "volume_db", target_volume_db, FADE_SECONDS)
	if stop_when_done:
		_fade_tween.tween_callback(_ambience_player.stop)


func _load_stream(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("Sfx: cannot load '%s'" % path)
	return stream


# The loop flag is set on a copy, so the shared resource that other users of the file see
# is left unchanged.
func _load_looping_stream(path: String) -> AudioStreamOggVorbis:
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null:
		push_error("Sfx: cannot load ambience '%s'" % path)
		return null
	var looping_stream := stream.duplicate() as AudioStreamOggVorbis
	looping_stream.loop = true
	return looping_stream
