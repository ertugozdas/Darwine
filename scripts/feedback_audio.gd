class_name FeedbackAudio extends Node

signal feedback_played(event_id: String)

const MIX_RATE := 22050
const PLAYER_COUNT := 6
const EVENT_SPECS: Dictionary = {
	"attack": {"frequencies": [180.0, 120.0], "duration": 0.12, "volume": -15.0},
	"draw": {"frequencies": [440.0, 660.0], "duration": 0.12, "volume": -13.0},
	"deploy": {"frequencies": [220.0, 330.0, 440.0], "duration": 0.16, "volume": -17.0},
	"ability": {"frequencies": [360.0, 540.0], "duration": 0.20, "volume": -14.0},
	"menu_click": {"frequencies": [520.0], "duration": 0.06, "volume": -14.0},
	"damage": {"frequencies": [95.0, 68.0], "duration": 0.10, "volume": -13.0},
	"critical": {"frequencies": [210.0, 105.0, 52.0], "duration": 0.24, "volume": -11.0},
	"block": {"frequencies": [760.0, 420.0, 190.0], "duration": 0.16, "volume": -15.0},
	"armor_break": {"frequencies": [330.0, 165.0, 82.0], "duration": 0.19, "volume": -13.0},
	"heal": {"frequencies": [520.0, 720.0], "duration": 0.18, "volume": -18.0},
	"destroy": {"frequencies": [150.0, 58.0], "duration": 0.24, "volume": -12.0},
	"upgrade": {"frequencies": [440.0, 660.0, 880.0], "duration": 0.28, "volume": -17.0},
	"experience": {"frequencies": [620.0, 780.0], "duration": 0.10, "volume": -20.0},
	"move": {"frequencies": [260.0, 330.0], "duration": 0.12, "volume": -20.0},
	"phase": {"frequencies": [330.0, 495.0], "duration": 0.14, "volume": -21.0},
	"invalid": {"frequencies": [120.0, 105.0], "duration": 0.16, "volume": -17.0},
	"dominion_score": {"frequencies": [294.0, 440.0, 588.0], "duration": 0.24, "volume": -17.0},
	"dominion_match_point": {"frequencies": [392.0, 494.0, 659.0, 784.0], "duration": 0.34, "volume": -15.0},
	"victory": {"frequencies": [392.0, 523.0, 659.0], "duration": 0.42, "volume": -16.0},
}
const FILE_EVENT_STREAMS: Dictionary = {
	"attack": preload("res://sounds/fx/attack.mp3"),
	"draw": preload("res://sounds/fx/get_card.mp3"),
	"ability": preload("res://sounds/fx/use_ability.mp3"),
	"menu_click": preload("res://sounds/fx/menu_click.mp3"),
	"victory": preload("res://sounds/fx/game_over.mp3"),
}

var muted := false
var last_event_id := ""
var event_play_count := 0
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player_index := 0
var _button_feedback_root: Node = null

func _ready() -> void:
	for player_index in range(PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "FeedbackPlayer%d" % (player_index + 1)
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
	for event_id_variant in EVENT_SPECS.keys():
		var event_id := str(event_id_variant)
		if FILE_EVENT_STREAMS.has(event_id):
			var file_stream := FILE_EVENT_STREAMS[event_id] as AudioStream
			if file_stream:
				_streams[event_id] = file_stream
				continue
		var spec := EVENT_SPECS[event_id] as Dictionary
		var frequencies_variant: Variant = spec.get("frequencies", [440.0])
		var frequencies: Array[float] = []
		if frequencies_variant is Array:
			for frequency_variant in frequencies_variant:
				frequencies.append(float(frequency_variant))
		_streams[event_id] = _build_tone(
			frequencies,
			float(spec.get("duration", 0.12))
		)

func _exit_tree() -> void:
	var tree := get_tree()
	var node_added_callback := Callable(self, "_on_tree_node_added")
	if tree and tree.node_added.is_connected(node_added_callback):
		tree.node_added.disconnect(node_added_callback)
	for player in _players:
		player.stop()
		player.stream = null
	_players.clear()
	_streams.clear()
	_button_feedback_root = null

func bind_button_feedback(root: Node) -> void:
	if not root or not is_instance_valid(root):
		return
	_button_feedback_root = root
	_connect_button_feedback_recursive(root)
	var tree := get_tree()
	var node_added_callback := Callable(self, "_on_tree_node_added")
	if tree and not tree.node_added.is_connected(node_added_callback):
		tree.node_added.connect(node_added_callback)

func _on_tree_node_added(node: Node) -> void:
	# Scene changes can free a freshly-added node before a deferred call runs.
	# Passing the instance id keeps the message queue from retaining a stale,
	# strongly-typed Node argument during reconnects and rapid scene reloads.
	call_deferred("_connect_descendant_buttons_by_id", node.get_instance_id())

func _connect_descendant_buttons_by_id(instance_id: int) -> void:
	var candidate := instance_from_id(instance_id)
	if not candidate is Node:
		return
	_connect_descendant_buttons(candidate as Node)

func _connect_descendant_buttons(node: Node) -> void:
	if (
		not node
		or not is_instance_valid(node)
		or not _button_feedback_root
		or not is_instance_valid(_button_feedback_root)
	):
		return
	if node != _button_feedback_root and not _button_feedback_root.is_ancestor_of(node):
		return
	_connect_button_feedback_recursive(node)

func _connect_button_feedback_recursive(node: Node) -> void:
	_try_connect_button(node)
	for child in node.get_children():
		_connect_button_feedback_recursive(child)

func _try_connect_button(node: Node) -> void:
	var button := node as BaseButton
	if not button:
		return
	var button_down_callback := Callable(self, "_on_ui_button_down")
	if not button.button_down.is_connected(button_down_callback):
		button.button_down.connect(button_down_callback)

func _on_ui_button_down() -> void:
	play_event("menu_click")

func has_event(event_id: String) -> bool:
	return _streams.has(event_id.strip_edges().to_lower())

func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for player in _players:
			player.stop()

func toggle_muted() -> bool:
	set_muted(not muted)
	return muted

func play_event(event_id: String) -> bool:
	var normalized := event_id.strip_edges().to_lower()
	if muted or not _streams.has(normalized) or _players.is_empty():
		return false
	var player := _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	var spec := EVENT_SPECS[normalized] as Dictionary
	player.stop()
	player.stream = _streams[normalized] as AudioStream
	player.volume_db = float(spec.get("volume", -18.0))
	player.pitch_scale = 1.0
	player.play()
	last_event_id = normalized
	event_play_count += 1
	feedback_played.emit(normalized)
	return true

func _build_tone(frequencies: Array[float], duration: float) -> AudioStreamWAV:
	var safe_duration := maxf(0.04, duration)
	var sample_count := maxi(1, int(round(safe_duration * float(MIX_RATE))))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var tone_count := maxi(1, frequencies.size())
	for sample_index in range(sample_count):
		var time := float(sample_index) / float(MIX_RATE)
		var progress := float(sample_index) / float(maxi(1, sample_count - 1))
		var attack_envelope := minf(1.0, progress / 0.08)
		var release_envelope := pow(maxf(0.0, 1.0 - progress), 1.8)
		var envelope := attack_envelope * release_envelope
		var sample_value := 0.0
		for frequency_index in range(frequencies.size()):
			var base_frequency := frequencies[frequency_index]
			var glide := lerpf(1.08, 0.92, progress)
			sample_value += sin(TAU * base_frequency * glide * time + float(frequency_index) * 0.35)
		sample_value = (sample_value / float(tone_count)) * envelope * 0.42
		var encoded_sample := clampi(int(round(sample_value * 32767.0)), -32768, 32767)
		data.encode_s16(sample_index * 2, encoded_sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream
