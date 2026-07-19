class_name MenuMusicPlayer extends AudioStreamPlayer

signal track_changed(track_index: int, track_data: Dictionary)
signal playback_state_changed(is_playing: bool)

const MUSIC_DIRECTORY := "res://sounds/musics"
const SUPPORTED_EXTENSIONS := ["mp3", "ogg", "wav"]
const TRACK_METADATA := {
	"music_1.mp3": {
		"title": "Iron Dawn",
		"subtitle": "Darwine Soundtrack",
	},
	"music_2.mp3": {
		"title": "Waiting in the Cold",
		"subtitle": "Darwine Soundtrack",
	},
	"music_3.mp3": {
		"title": "Whisper of the Ramparts",
		"subtitle": "Darwine Soundtrack",
	},
	"music_4.mp3": {
		"title": "Mud and Blood",
		"subtitle": "Darwine Soundtrack",
	},
	"music_5.mp3": {
		"title": "March of Courage",
		"subtitle": "Darwine Soundtrack",
	},
}

var track_count := 0
var loaded_track_paths: PackedStringArray = []
var track_titles: PackedStringArray = []
var current_track_index := -1
var playback_allowed := true

var _music_streams: Array[AudioStream] = []
var _track_data: Array[Dictionary] = []
var _playback_requested := true
var _resume_position := 0.0


func _ready() -> void:
	bus = &"Music"
	finished.connect(_on_track_finished)
	_load_playlist()
	if track_count > 0:
		play_track(randi_range(0, track_count - 1))


func _load_playlist() -> void:
	_music_streams.clear()
	_track_data.clear()
	loaded_track_paths.clear()
	track_titles.clear()

	var seen_paths := {}
	var file_names := DirAccess.get_files_at(MUSIC_DIRECTORY)
	file_names.sort()

	for file_name in file_names:
		var resource_name := file_name
		if resource_name.ends_with(".remap"):
			resource_name = resource_name.trim_suffix(".remap")
		if resource_name.get_extension().to_lower() not in SUPPORTED_EXTENSIONS:
			continue

		var resource_path := MUSIC_DIRECTORY.path_join(resource_name)
		if seen_paths.has(resource_path):
			continue
		seen_paths[resource_path] = true

		var loaded_stream := ResourceLoader.load(resource_path) as AudioStream
		if not loaded_stream:
			push_warning("Menü müziği yüklenemedi: %s" % resource_path)
			continue

		var playlist_stream := loaded_stream.duplicate() as AudioStream
		if not playlist_stream:
			playlist_stream = loaded_stream
		_disable_individual_loop(playlist_stream)

		var metadata: Dictionary = TRACK_METADATA.get(resource_name, {})
		var fallback_title := resource_name.get_basename().replace("_", " ").capitalize()
		var title := str(metadata.get("title", fallback_title))
		_music_streams.append(playlist_stream)
		loaded_track_paths.append(resource_path)
		track_titles.append(title)
		_track_data.append({
			"title": title,
			"subtitle": str(metadata.get("subtitle", "Darwine Soundtrack")),
			"path": resource_path,
			"duration": playlist_stream.get_length(),
		})

	track_count = _music_streams.size()
	if track_count == 0:
		push_warning("Menü müziği bulunamadı: %s" % MUSIC_DIRECTORY)


func play_track(track_index: int, from_position := 0.0) -> bool:
	if track_index < 0 or track_index >= track_count:
		return false
	stop()
	current_track_index = track_index
	stream = _music_streams[track_index]
	stream_paused = false
	var duration := float(_track_data[track_index].get("duration", 0.0))
	var safe_position := clampf(from_position, 0.0, maxf(duration - 0.05, 0.0))
	_resume_position = safe_position
	_playback_requested = true
	track_changed.emit(current_track_index, get_track_data(current_track_index))
	if playback_allowed:
		play(safe_position)
		playback_state_changed.emit(true)
	else:
		playback_state_changed.emit(false)
	return true


func next_track() -> bool:
	if track_count == 0:
		return false
	var next_index := 0 if current_track_index < 0 else (current_track_index + 1) % track_count
	return play_track(next_index)


func previous_track() -> bool:
	if track_count == 0:
		return false
	var previous_index := track_count - 1 if current_track_index < 0 else posmod(current_track_index - 1, track_count)
	return play_track(previous_index)


func toggle_pause() -> bool:
	if not playback_allowed:
		playback_state_changed.emit(false)
		return false
	if current_track_index < 0:
		return play_track(0)
	var is_playing := false
	if not playing:
		_playback_requested = true
		stream_paused = false
		play(_resume_position)
		is_playing = true
	elif stream_paused:
		_playback_requested = true
		stream_paused = false
		is_playing = true
	else:
		_resume_position = get_playback_position()
		_playback_requested = false
		stream_paused = true
	playback_state_changed.emit(is_playing)
	return is_playing


func set_playback_allowed(allowed: bool) -> void:
	if playback_allowed == allowed:
		if not allowed and playing:
			_resume_position = get_playback_position()
			stop()
			stream_paused = false
			playback_state_changed.emit(false)
		return

	if not allowed:
		if playing:
			_resume_position = get_playback_position()
		stop()
		stream_paused = false
		playback_allowed = false
		playback_state_changed.emit(false)
		return

	playback_allowed = true
	if _playback_requested and current_track_index >= 0:
		stream = _music_streams[current_track_index]
		stream_paused = false
		play(_resume_position)
		playback_state_changed.emit(true)
	else:
		playback_state_changed.emit(false)


func seek_to(position_seconds: float) -> bool:
	if current_track_index < 0 or stream == null:
		return false
	var duration := float(_track_data[current_track_index].get("duration", 0.0))
	_resume_position = clampf(position_seconds, 0.0, maxf(duration - 0.05, 0.0))
	if playing:
		seek(_resume_position)
	return true


func get_track_data(track_index: int) -> Dictionary:
	if track_index < 0 or track_index >= _track_data.size():
		return {}
	return _track_data[track_index].duplicate(true)


func get_all_track_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for data in _track_data:
		result.append(data.duplicate(true))
	return result


func get_current_track_data() -> Dictionary:
	return get_track_data(current_track_index)


func is_playback_active() -> bool:
	return playback_allowed and playing and not stream_paused


func get_current_position() -> float:
	return get_playback_position() if playing else _resume_position


func _on_track_finished() -> void:
	next_track()


func _disable_individual_loop(audio_stream: AudioStream) -> void:
	if audio_stream is AudioStreamMP3:
		(audio_stream as AudioStreamMP3).loop = false
	elif audio_stream is AudioStreamOggVorbis:
		(audio_stream as AudioStreamOggVorbis).loop = false
	elif audio_stream is AudioStreamWAV:
		(audio_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
