extends Node
class_name KokoroClient

## HTTP client for Kokoro TTS server — sends text, receives and plays WAV audio

signal speech_started()
signal speech_finished()
signal speech_error(message: String)

var _http_request: HTTPRequest
var _ping_request: HTTPRequest
var _audio_player: AudioStreamPlayer
var _is_speaking: bool = false

func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.name = "KokoroHTTP"
	_http_request.timeout = 30.0
	_http_request.request_completed.connect(_on_tts_response)
	add_child(_http_request)

	_ping_request = HTTPRequest.new()
	_ping_request.name = "KokoroPing"
	_ping_request.timeout = 5.0
	add_child(_ping_request)

	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "TTSPlayer"
	_audio_player.bus = "Master"
	_audio_player.volume_db = NexusAIConfig.get_setting("ai_voice_volume")
	_audio_player.finished.connect(_on_playback_finished)
	add_child(_audio_player)

func speak(text: String, voice: String = "") -> void:
	if voice.is_empty():
		voice = NexusAIConfig.get_setting("voice")

	if _is_speaking:
		stop()

	var base_url: String = NexusAIConfig.get_setting("kokoro_url")
	var url: String = base_url + "/tts"

	var body_dict: Dictionary = {
		"text": text,
		"voice": voice,
	}
	var body_json: String = JSON.stringify(body_dict)
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
	])

	var err: int = _http_request.request(url, headers, HTTPClient.METHOD_POST, body_json)
	if err != OK:
		speech_error.emit("Failed to send TTS request: error %d" % err)

func _on_tts_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		speech_error.emit("Kokoro HTTP request failed with result %d" % result)
		return

	if response_code != 200:
		speech_error.emit("Kokoro server returned HTTP %d" % response_code)
		return

	if body.size() < 44:
		speech_error.emit("Kokoro returned too-small response (%d bytes)" % body.size())
		return

	# Parse WAV header to get format info
	var audio_stream: AudioStreamWAV = _parse_wav(body)
	if not audio_stream:
		speech_error.emit("Failed to parse WAV audio from Kokoro response")
		return

	_audio_player.volume_db = NexusAIConfig.get_setting("ai_voice_volume")
	_audio_player.stream = audio_stream
	_audio_player.play()
	_is_speaking = true
	speech_started.emit()
	print("KokoroClient: playing TTS audio (%d bytes)" % body.size())

func _parse_wav(wav_bytes: PackedByteArray) -> AudioStreamWAV:
	## Parses a WAV file from raw bytes into an AudioStreamWAV resource.
	## Supports 16-bit PCM WAV files (Kokoro's output format).
	if wav_bytes.size() < 44:
		return null

	# Verify RIFF header
	var riff: String = wav_bytes.slice(0, 4).get_string_from_ascii()
	if riff != "RIFF":
		push_warning("KokoroClient: not a valid WAV file (no RIFF header)")
		return null

	# Read format info from WAV header
	var audio_format: int = wav_bytes.decode_u16(20)
	var num_channels: int = wav_bytes.decode_u16(22)
	var sample_rate: int = wav_bytes.decode_u32(24)
	var bits_per_sample: int = wav_bytes.decode_u16(34)

	if audio_format != 1:
		push_warning("KokoroClient: unsupported WAV format %d (only PCM supported)" % audio_format)
		return null

	# Find the "data" chunk — it may not start at offset 44 if there are extra chunks
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
		push_warning("KokoroClient: no data chunk found in WAV")
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
		push_warning("KokoroClient: unsupported bit depth %d" % bits_per_sample)
		return null

	return stream

func _on_playback_finished() -> void:
	_is_speaking = false
	speech_finished.emit()

func stop() -> void:
	if _is_speaking:
		_audio_player.stop()
		_is_speaking = false
		speech_finished.emit()

func ping(callback: Callable) -> void:
	## Pings the Kokoro TTS server. Calls callback(true) on success, callback(false) on failure.
	var base_url: String = NexusAIConfig.get_setting("kokoro_url")
	# Try a simple GET to the base URL
	var url: String = base_url + "/"

	if _ping_request.request_completed.get_connections().size() > 0:
		for conn in _ping_request.request_completed.get_connections():
			_ping_request.request_completed.disconnect(conn["callable"])

	var _ping_cb: Callable = func(result: int, response_code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		callback.call(result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 404))

	_ping_request.request_completed.connect(_ping_cb, CONNECT_ONE_SHOT)
	var err: int = _ping_request.request(url)
	if err != OK:
		callback.call(false)

func is_speaking() -> bool:
	return _is_speaking

func get_audio_player() -> AudioStreamPlayer:
	## Returns the AudioStreamPlayer for amplitude monitoring (used by hub visual feedback).
	return _audio_player
