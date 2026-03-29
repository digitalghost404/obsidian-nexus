extends Node
class_name AmbientWhisper

## Ambient Whisper Mode — plays quiet TTS snippets when player is near towers.
## Checks nearest tower every ~8 seconds, whispers the first 15-20 words at low volume.
## Per-tower cooldown prevents repetition.

var _check_timer: Timer
var _whisper_player: AudioStreamPlayer
var _whisper_http: HTTPRequest
var _cooldowns: Dictionary = {}  # note_id → timestamp of last whisper
const COOLDOWN_SECONDS: float = 120.0  # 2-minute per-tower cooldown
const PROXIMITY_THRESHOLD: float = 5.0
const CHECK_INTERVAL: float = 8.0
var _enabled: bool = true
var _is_whispering: bool = false

func _ready() -> void:
	_enabled = NexusAIConfig.get_setting("whisper_mode_enabled")

	# Separate audio player for whispers at low volume
	_whisper_player = AudioStreamPlayer.new()
	_whisper_player.name = "WhisperPlayer"
	_whisper_player.bus = "Master"
	_whisper_player.volume_db = NexusAIConfig.get_setting("whisper_volume")
	_whisper_player.finished.connect(func(): _is_whispering = false)
	add_child(_whisper_player)

	# HTTP request for TTS
	_whisper_http = HTTPRequest.new()
	_whisper_http.name = "WhisperTTSHTTP"
	_whisper_http.timeout = 15.0
	_whisper_http.request_completed.connect(_on_tts_response)
	add_child(_whisper_http)

	# Check timer
	_check_timer = Timer.new()
	_check_timer.wait_time = CHECK_INTERVAL
	_check_timer.timeout.connect(_on_check_timer)
	add_child(_check_timer)
	if _enabled:
		_check_timer.start()

func set_enabled(value: bool) -> void:
	_enabled = value
	if _enabled:
		_check_timer.start()
	else:
		_check_timer.stop()

func _on_check_timer() -> void:
	if not _enabled or _is_whispering:
		return
	if not NexusAI or not NexusAI.kokoro_online:
		return
	if NexusAI.current_state != NexusAI.State.IDLE:
		return

	var cam: Node3D = LayerManager.current_camera
	if not cam:
		return

	var city_layer: Node3D = LayerManager.current_scene
	if not city_layer or not city_layer.has_method("get_tower_positions"):
		return

	var tower_positions: Dictionary = city_layer.get_tower_positions()
	var cam_pos: Vector3 = cam.global_position
	var nearest_id: String = ""
	var nearest_dist: float = PROXIMITY_THRESHOLD + 1.0

	for note_id in tower_positions:
		var tpos: Vector3 = tower_positions[note_id]
		var dist: float = cam_pos.distance_to(tpos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = note_id

	if nearest_id.is_empty() or nearest_dist > PROXIMITY_THRESHOLD:
		return

	# Check cooldown
	var now: float = Time.get_unix_time_from_system()
	if _cooldowns.has(nearest_id):
		var last_time: float = _cooldowns[nearest_id]
		if now - last_time < COOLDOWN_SECONDS:
			return

	# Get note content snippet
	var note: RefCounted = VaultDataBus.graph.get_note(nearest_id)
	if not note or note.content.is_empty():
		return

	# Extract first 15-20 words
	var words: PackedStringArray = note.content.strip_edges().split(" ")
	var word_count: int = mini(words.size(), 18)
	var snippet: String = " ".join(words.slice(0, word_count))
	if words.size() > word_count:
		snippet += "..."

	# Send to Kokoro TTS
	_cooldowns[nearest_id] = now
	_request_whisper_tts(snippet)

func _request_whisper_tts(text: String) -> void:
	var base_url: String = NexusAIConfig.get_setting("kokoro_url")
	var url: String = base_url + "/tts"
	var voice: String = NexusAIConfig.get_setting("voice")

	var body_dict: Dictionary = {
		"text": text,
		"voice": voice,
	}
	var body_json: String = JSON.stringify(body_dict)
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
	])

	var err: int = _whisper_http.request(url, headers, HTTPClient.METHOD_POST, body_json)
	if err != OK:
		push_warning("AmbientWhisper: TTS request failed")

func _on_tts_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	if body.size() < 44:
		return

	# Reuse Kokoro's WAV parser (same format)
	var audio_stream: AudioStreamWAV = _parse_wav_simple(body)
	if not audio_stream:
		return

	_whisper_player.volume_db = NexusAIConfig.get_setting("whisper_volume")
	_whisper_player.stream = audio_stream
	_whisper_player.play()
	_is_whispering = true

func _parse_wav_simple(wav_bytes: PackedByteArray) -> AudioStreamWAV:
	## Simplified WAV parser for Kokoro output (same as KokoroClient._parse_wav)
	if wav_bytes.size() < 44:
		return null
	var riff: String = wav_bytes.slice(0, 4).get_string_from_ascii()
	if riff != "RIFF":
		return null

	var num_channels: int = wav_bytes.decode_u16(22)
	var sample_rate: int = wav_bytes.decode_u32(24)
	var bits_per_sample: int = wav_bytes.decode_u16(34)

	# Find data chunk
	var data_offset: int = 12
	var data_size: int = 0
	while data_offset < wav_bytes.size() - 8:
		var chunk_id: String = wav_bytes.slice(data_offset, data_offset + 4).get_string_from_ascii()
		var chunk_size: int = wav_bytes.decode_u32(data_offset + 4)
		if chunk_id == "data":
			data_offset += 8
			data_size = chunk_size
			break
		data_offset += 8 + chunk_size

	if data_size == 0:
		return null

	var audio_data: PackedByteArray = wav_bytes.slice(data_offset, data_offset + data_size)
	var stream := AudioStreamWAV.new()
	stream.data = audio_data
	stream.mix_rate = sample_rate
	stream.stereo = (num_channels == 2)
	if bits_per_sample == 16:
		stream.format = AudioStreamWAV.FORMAT_16_BITS
	elif bits_per_sample == 8:
		stream.format = AudioStreamWAV.FORMAT_8_BITS
	else:
		return null
	return stream
