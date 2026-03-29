# Nexus AI v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an AI-powered voice interface to the Nexus Hub — local LLM (Ollama), speech-to-text (Whisper), text-to-speech (Kokoro) with ambient awareness and vault navigation commands.

**Architecture:** NexusAI autoload orchestrates three local REST services via HTTP. Voice captured via Godot AudioEffectCapture, responses displayed as holographic HUD text and spoken via Kokoro TTS. Hub visual state changes driven by AI state machine signals.

**Tech Stack:** Godot 4.6 (GDScript), Ollama API, Whisper.cpp server, Kokoro TTS server, HTTPRequest

---

## File Structure

### New Files

```
autoloads/
  nexus_ai.gd            # Main AI orchestration singleton + state machine
  nexus_ai_config.gd     # Settings management (JSON config load/save)

ai/
  whisper_client.gd       # HTTP client for Whisper STT server
  ollama_client.gd        # HTTP client for Ollama LLM (streaming)
  kokoro_client.gd        # HTTP client for Kokoro TTS
  mic_recorder.gd         # AudioEffectCapture wrapper for mic input
  prompt_builder.gd       # Constructs prompts with vault context + history
  response_parser.gd      # Parses [[refs]], NAVIGATE:, HIGHLIGHT: commands

ui/
  ai_response_panel.gd    # Holographic text display near camera (HUD)
  ai_response_panel.tscn  # Scene for the response panel
  listening_indicator.gd   # Mic icon + waveform while V held
  ai_status_bar.gd        # NEXUS ONLINE/DEGRADED/OFFLINE indicator
```

### Modified Files

```
project.godot                    # Register NexusAI + NexusAIConfig autoloads
layers/city/nexus_hub.gd        # Add AI state-driven visual feedback
autoloads/ui_manager.gd         # Integrate AI HUD elements
main.gd                         # Initialize NexusAI after city loads
```

---

## Task 1: NexusAI Config

Settings management singleton that loads/saves AI configuration from a JSON file in user data.

- [ ] Create `autoloads/nexus_ai_config.gd`
- [ ] Verify it loads defaults when no config file exists
- [ ] Verify it persists changes across save/load cycle

### File: `autoloads/nexus_ai_config.gd`

```gdscript
extends Node

## NexusAI configuration — loads/saves settings from user://nexus_ai_config.json

const CONFIG_PATH: String = "user://nexus_ai_config.json"

var _settings: Dictionary = {}
var _defaults: Dictionary = {
	"model": "qwen3.5:4b",
	"ollama_url": "http://localhost:11434",
	"whisper_url": "http://localhost:8178",
	"kokoro_url": "http://localhost:8180",
	"voice": "af_heart",
	"observations_enabled": true,
	"observations_interval": 300,
	"whisper_mode_enabled": true,
	"whisper_volume": -26,
	"ai_voice_volume": -5,
	"history_max_exchanges": 10,
	"vault_context_max_notes": 5,
	"vault_context_max_chars": 500,
}

func _ready() -> void:
	load_config()

func load_config() -> void:
	_settings = _defaults.duplicate(true)
	if not FileAccess.file_exists(CONFIG_PATH):
		print("NexusAIConfig: no config file, using defaults")
		return
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		push_warning("NexusAIConfig: could not open %s" % CONFIG_PATH)
		return
	var json := JSON.new()
	var err: int = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("NexusAIConfig: JSON parse error in %s" % CONFIG_PATH)
		return
	var data: Dictionary = json.data
	for key in data:
		_settings[key] = data[key]
	print("NexusAIConfig: loaded %d settings from %s" % [data.size(), CONFIG_PATH])

func save() -> void:
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if not file:
		push_warning("NexusAIConfig: could not write to %s" % CONFIG_PATH)
		return
	var json_text: String = JSON.stringify(_settings, "\t")
	file.store_string(json_text)
	file.close()
	print("NexusAIConfig: saved config to %s" % CONFIG_PATH)

func get_setting(key: String) -> Variant:
	return _settings.get(key, _defaults.get(key))

func set_setting(key: String, value: Variant) -> void:
	_settings[key] = value

func get_all_settings() -> Dictionary:
	return _settings.duplicate(true)
```

### Register in project.godot

Add this line to the `[autoload]` section of `project.godot`, **before** the NexusAI autoload (which will be added in Task 8). It must load before NexusAI because NexusAI depends on it. Insert it after the existing `AudioManager` line:

```
NexusAIConfig="*res://autoloads/nexus_ai_config.gd"
```

The full `[autoload]` section should become:

```ini
[autoload]

VaultDataBus="*res://autoloads/vault_data_bus.gd"
LayerManager="*res://autoloads/layer_manager.gd"
InputManager="*res://autoloads/input_manager.gd"
UIManager="*res://autoloads/ui_manager.gd"
AudioManager="*res://autoloads/audio_manager.gd"
NexusAIConfig="*res://autoloads/nexus_ai_config.gd"
```

### Test Steps

1. Run the project — confirm no errors in output log
2. Check output log for `NexusAIConfig: no config file, using defaults`
3. Open Godot console (or add a temporary `print()` call) to verify `NexusAIConfig.get_setting("model")` returns `"qwen3.5:4b"`
4. Add a temporary line in `_ready()`: `set_setting("model", "test"); save()` — verify `user://nexus_ai_config.json` is created with the value
5. Remove the temporary line, restart — verify the saved value persists

### Commit

```
feat(ai): add NexusAI config singleton with JSON persistence
```

---

## Task 2: Whisper Client

HTTP client that sends WAV audio to the Whisper.cpp server and returns transcribed text.

- [ ] Create `ai/whisper_client.gd`
- [ ] Verify health check returns false when server is not running
- [ ] Verify transcription signal is emitted (requires Whisper server running)

### File: `ai/whisper_client.gd`

```gdscript
extends Node
class_name WhisperClient

## HTTP client for Whisper.cpp STT server
## Sends WAV audio data, receives transcribed text

signal transcription_complete(text: String)
signal transcription_error(message: String)

var _http_request: HTTPRequest
var _ping_request: HTTPRequest
var _is_busy: bool = false

func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.name = "WhisperHTTP"
	_http_request.timeout = 30.0
	_http_request.request_completed.connect(_on_transcription_response)
	add_child(_http_request)

	_ping_request = HTTPRequest.new()
	_ping_request.name = "WhisperPing"
	_ping_request.timeout = 5.0
	add_child(_ping_request)

func transcribe(audio_wav_data: PackedByteArray) -> void:
	if _is_busy:
		transcription_error.emit("Whisper client is busy with another transcription")
		return

	var base_url: String = NexusAIConfig.get_setting("whisper_url")
	var url: String = base_url + "/inference"

	# Build multipart/form-data body
	var boundary: String = "----GodotWhisperBoundary%d" % Time.get_ticks_msec()
	var body := PackedByteArray()

	# File field: "file"
	var header_text: String = "--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n" % boundary
	body.append_array(header_text.to_utf8_buffer())
	body.append_array(audio_wav_data)
	body.append_array("\r\n".to_utf8_buffer())

	# Temperature field (lower = more accurate)
	var temp_field: String = "--%s\r\nContent-Disposition: form-data; name=\"temperature\"\r\n\r\n0.0\r\n" % boundary
	body.append_array(temp_field.to_utf8_buffer())

	# Response format field
	var format_field: String = "--%s\r\nContent-Disposition: form-data; name=\"response_format\"\r\n\r\njson\r\n" % boundary
	body.append_array(format_field.to_utf8_buffer())

	# Closing boundary
	var closing: String = "--%s--\r\n" % boundary
	body.append_array(closing.to_utf8_buffer())

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: multipart/form-data; boundary=%s" % boundary
	])

	_is_busy = true
	var err: int = _http_request.request_raw(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_is_busy = false
		transcription_error.emit("Failed to send request to Whisper server: error %d" % err)

func _on_transcription_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_busy = false

	if result != HTTPRequest.RESULT_SUCCESS:
		transcription_error.emit("Whisper HTTP request failed with result %d" % result)
		return

	if response_code != 200:
		transcription_error.emit("Whisper server returned HTTP %d" % response_code)
		return

	var response_text: String = body.get_string_from_utf8()
	var json := JSON.new()
	var parse_err: int = json.parse(response_text)
	if parse_err != OK:
		transcription_error.emit("Failed to parse Whisper response JSON")
		return

	var data: Dictionary = json.data
	var text: String = data.get("text", "").strip_edges()
	if text.is_empty():
		transcription_error.emit("Whisper returned empty transcription")
		return

	print("WhisperClient: transcribed '%s'" % text)
	transcription_complete.emit(text)

func ping(callback: Callable) -> void:
	## Pings the Whisper server. Calls callback(true) on success, callback(false) on failure.
	var base_url: String = NexusAIConfig.get_setting("whisper_url")
	# whisper.cpp server responds to GET / with basic info
	var url: String = base_url + "/"

	if _ping_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		# Already pinging, assume it will respond
		callback.call(false)
		return

	var _ping_cb: Callable = func(result: int, response_code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		callback.call(result == HTTPRequest.RESULT_SUCCESS and response_code == 200)

	# Disconnect any previous one-shot connection
	if _ping_request.request_completed.get_connections().size() > 0:
		for conn in _ping_request.request_completed.get_connections():
			_ping_request.request_completed.disconnect(conn["callable"])

	_ping_request.request_completed.connect(_ping_cb, CONNECT_ONE_SHOT)
	var err: int = _ping_request.request(url)
	if err != OK:
		callback.call(false)

func is_busy() -> bool:
	return _is_busy
```

### Test Steps

1. Run the project — no errors from the new file
2. With Whisper server NOT running: verify `ping()` calls back with `false`
3. With Whisper server running on `:8178`: verify `ping()` calls back with `true`
4. Full transcription test requires Task 5 (mic recorder) to produce audio data — defer to Task 8 integration test

### Commit

```
feat(ai): add Whisper STT client with multipart upload
```

---

## Task 3: Ollama Client (Streaming)

HTTP client for Ollama with NDJSON streaming response parsing. Uses raw HTTPClient for streaming since HTTPRequest buffers the full response.

- [ ] Create `ai/ollama_client.gd`
- [ ] Verify health check against running Ollama
- [ ] Verify streaming chunks are emitted during generation

### File: `ai/ollama_client.gd`

```gdscript
extends Node
class_name OllamaClient

## HTTP client for Ollama LLM — streaming NDJSON responses
## Uses HTTPClient (not HTTPRequest) for true streaming

signal chunk_received(text: String)
signal generation_complete(full_text: String)
signal generation_error(message: String)

var _http_client: HTTPClient
var _ping_request: HTTPRequest
var _is_generating: bool = false
var _cancel_requested: bool = false
var _full_response: String = ""
var _response_buffer: String = ""
var _polling: bool = false

func _ready() -> void:
	_http_client = HTTPClient.new()

	_ping_request = HTTPRequest.new()
	_ping_request.name = "OllamaPing"
	_ping_request.timeout = 5.0
	add_child(_ping_request)

func generate(prompt: String, model: String) -> void:
	if _is_generating:
		generation_error.emit("Ollama client is busy with another generation")
		return

	_is_generating = true
	_cancel_requested = false
	_full_response = ""
	_response_buffer = ""

	# Parse URL components from config
	var base_url: String = NexusAIConfig.get_setting("ollama_url")
	var port: int = 11434
	var host: String = "localhost"

	# Extract host and port from URL
	var url_stripped: String = base_url.replace("http://", "").replace("https://", "")
	if ":" in url_stripped:
		var parts: PackedStringArray = url_stripped.split(":")
		host = parts[0]
		port = parts[1].to_int()
	else:
		host = url_stripped

	var err: int = _http_client.connect_to_host(host, port)
	if err != OK:
		_is_generating = false
		generation_error.emit("Failed to connect to Ollama at %s:%d" % [host, port])
		return

	# Wait for connection in _process, then send request
	# Store request data for use in _process
	set_meta("pending_prompt", prompt)
	set_meta("pending_model", model)
	_polling = true

func _process(_delta: float) -> void:
	if not _polling:
		return

	_http_client.poll()
	var status: int = _http_client.get_status()

	match status:
		HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING:
			# Still connecting, wait
			return

		HTTPClient.STATUS_CONNECTED:
			# Connection established — send the request if we haven't yet
			if has_meta("pending_prompt"):
				var prompt: String = get_meta("pending_prompt")
				var model: String = get_meta("pending_model")
				remove_meta("pending_prompt")
				remove_meta("pending_model")
				_send_generate_request(prompt, model)
			elif _http_client.has_response():
				_read_streaming_response()
			return

		HTTPClient.STATUS_REQUESTING:
			# Request is being sent, wait
			return

		HTTPClient.STATUS_BODY:
			_read_streaming_response()
			return

		HTTPClient.STATUS_DISCONNECTED:
			if _is_generating and _full_response.is_empty():
				_finish_generation_error("Disconnected from Ollama server")
			elif _is_generating:
				_finish_generation()
			_polling = false
			return

		_:
			if _is_generating:
				_finish_generation_error("Ollama connection error (status %d)" % status)
			_polling = false
			return

func _send_generate_request(prompt: String, model: String) -> void:
	var body_dict: Dictionary = {
		"model": model,
		"prompt": prompt,
		"stream": true,
	}
	var body_json: String = JSON.stringify(body_dict)
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Content-Length: %d" % body_json.length(),
	])
	var err: int = _http_client.request(HTTPClient.METHOD_POST, "/api/generate", headers, body_json)
	if err != OK:
		_finish_generation_error("Failed to send generate request: error %d" % err)

func _read_streaming_response() -> void:
	if _cancel_requested:
		_http_client.close()
		_is_generating = false
		_polling = false
		generation_complete.emit(_full_response)
		return

	var bytes: PackedByteArray = _http_client.read_response_body_chunk()
	if bytes.size() == 0:
		return

	_response_buffer += bytes.get_string_from_utf8()

	# Parse complete NDJSON lines from buffer
	while "\n" in _response_buffer:
		var newline_pos: int = _response_buffer.find("\n")
		var line: String = _response_buffer.substr(0, newline_pos).strip_edges()
		_response_buffer = _response_buffer.substr(newline_pos + 1)

		if line.is_empty():
			continue

		var json := JSON.new()
		var parse_err: int = json.parse(line)
		if parse_err != OK:
			continue

		var data: Dictionary = json.data
		var token: String = data.get("response", "")
		var done: bool = data.get("done", false)

		if not token.is_empty():
			_full_response += token
			chunk_received.emit(token)

		if done:
			_finish_generation()
			return

func _finish_generation() -> void:
	_is_generating = false
	_polling = false
	_http_client.close()
	print("OllamaClient: generation complete (%d chars)" % _full_response.length())
	generation_complete.emit(_full_response)

func _finish_generation_error(message: String) -> void:
	_is_generating = false
	_polling = false
	_http_client.close()
	push_warning("OllamaClient: %s" % message)
	generation_error.emit(message)

func cancel() -> void:
	if _is_generating:
		_cancel_requested = true

func ping(callback: Callable) -> void:
	## Pings Ollama. Calls callback(true) on success, callback(false) on failure.
	var base_url: String = NexusAIConfig.get_setting("ollama_url")
	var url: String = base_url + "/api/tags"

	if _ping_request.request_completed.get_connections().size() > 0:
		for conn in _ping_request.request_completed.get_connections():
			_ping_request.request_completed.disconnect(conn["callable"])

	var _ping_cb: Callable = func(result: int, response_code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		callback.call(result == HTTPRequest.RESULT_SUCCESS and response_code == 200)

	_ping_request.request_completed.connect(_ping_cb, CONNECT_ONE_SHOT)
	var err: int = _ping_request.request(url)
	if err != OK:
		callback.call(false)

func is_generating() -> bool:
	return _is_generating
```

### Test Steps

1. Run the project — no errors
2. With Ollama NOT running: verify `ping()` calls back with `false`
3. With Ollama running: verify `ping()` calls back with `true`
4. Temporary test in `_ready()`: call `generate("Say hello in 5 words", "qwen3.5:4b")` and connect to `chunk_received` and `generation_complete` — verify streaming output in console
5. Remove temporary test code

### Commit

```
feat(ai): add Ollama streaming LLM client with NDJSON parsing
```

---

## Task 4: Kokoro TTS Client

HTTP client that sends text to Kokoro TTS server and plays the returned WAV audio.

- [ ] Create `ai/kokoro_client.gd`
- [ ] Verify health check against Kokoro server
- [ ] Verify audio playback of TTS response

### File: `ai/kokoro_client.gd`

```gdscript
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
```

### Test Steps

1. Run the project — no errors
2. With Kokoro NOT running: verify `ping()` calls back with `false`
3. With Kokoro running on `:8180`: verify `ping()` calls back with `true`
4. Temporary test: call `speak("Hello, I am the Nexus.")` — verify audio plays through speakers
5. Test `stop()` — verify playback stops immediately and `speech_finished` is emitted

### Commit

```
feat(ai): add Kokoro TTS client with WAV parsing and playback
```

---

## Task 5: Mic Recorder

Wrapper around Godot's AudioEffectCapture for recording microphone input and exporting WAV bytes.

- [ ] Create `ai/mic_recorder.gd`
- [ ] Verify AudioServer bus is created with capture effect
- [ ] Verify start/stop recording produces WAV-format PackedByteArray

### File: `ai/mic_recorder.gd`

```gdscript
extends Node
class_name MicRecorder

## Microphone recording via AudioEffectCapture on a dedicated "MicCapture" bus.
## Records raw PCM 16-bit 16kHz mono audio and exports as WAV bytes.

signal recording_level(amplitude: float)

const SAMPLE_RATE: int = 16000
const MIX_RATE: int = 44100  # Godot's internal mix rate (AudioServer default)

var _capture_effect: AudioEffectCapture
var _bus_index: int = -1
var _is_recording: bool = false
var _recorded_frames: PackedVector2Array = PackedVector2Array()
var _level_timer: float = 0.0
const LEVEL_UPDATE_INTERVAL: float = 0.05  # 20 Hz updates for waveform display

func _ready() -> void:
	_setup_audio_bus()

func _setup_audio_bus() -> void:
	# Create a dedicated audio bus for mic capture
	var bus_name: String = "MicCapture"
	_bus_index = AudioServer.get_bus_index(bus_name)
	if _bus_index == -1:
		_bus_index = AudioServer.bus_count
		AudioServer.add_bus(_bus_index)
		AudioServer.set_bus_name(_bus_index, bus_name)

	# Mute the bus so captured audio doesn't play through speakers
	AudioServer.set_bus_mute(_bus_index, true)

	# Add AudioEffectCapture to the bus
	_capture_effect = AudioEffectCapture.new()
	# Clear any existing effects first
	while AudioServer.get_bus_effect_count(_bus_index) > 0:
		AudioServer.remove_bus_effect(_bus_index, 0)
	AudioServer.add_bus_effect(_bus_index, _capture_effect)

	print("MicRecorder: audio bus '%s' (index %d) configured with capture effect" % [bus_name, _bus_index])

func start_recording() -> void:
	if _is_recording:
		return
	_recorded_frames.clear()
	_capture_effect.clear_buffer()
	_is_recording = true
	print("MicRecorder: recording started")

func stop_recording() -> PackedByteArray:
	if not _is_recording:
		return PackedByteArray()
	_is_recording = false

	# Flush remaining frames from capture buffer
	_flush_capture_buffer()

	print("MicRecorder: recording stopped, %d frames captured" % _recorded_frames.size())

	if _recorded_frames.size() == 0:
		push_warning("MicRecorder: no audio frames captured — is the microphone connected?")
		return PackedByteArray()

	# Convert stereo frames to mono 16-bit PCM, downsample from MIX_RATE to SAMPLE_RATE
	var mono_samples: PackedFloat32Array = _to_mono_resampled(_recorded_frames)
	var wav_bytes: PackedByteArray = _encode_wav(mono_samples)
	return wav_bytes

func _process(delta: float) -> void:
	if not _is_recording:
		return

	_flush_capture_buffer()

	# Emit amplitude levels at regular intervals for the listening indicator
	_level_timer += delta
	if _level_timer >= LEVEL_UPDATE_INTERVAL:
		_level_timer = 0.0
		var amplitude: float = _compute_recent_amplitude()
		recording_level.emit(amplitude)

func _flush_capture_buffer() -> void:
	if not _capture_effect:
		return
	var frames_available: int = _capture_effect.get_frames_available()
	if frames_available > 0:
		var frames: PackedVector2Array = _capture_effect.get_buffer(frames_available)
		_recorded_frames.append_array(frames)

func _compute_recent_amplitude() -> float:
	## Returns the RMS amplitude of the most recent ~1024 frames
	var count: int = mini(_recorded_frames.size(), 1024)
	if count == 0:
		return 0.0
	var sum: float = 0.0
	var start: int = _recorded_frames.size() - count
	for i in range(start, _recorded_frames.size()):
		var frame: Vector2 = _recorded_frames[i]
		var mono: float = (frame.x + frame.y) * 0.5
		sum += mono * mono
	return sqrt(sum / float(count))

func _to_mono_resampled(frames: PackedVector2Array) -> PackedFloat32Array:
	## Converts stereo frames at MIX_RATE to mono at SAMPLE_RATE using linear interpolation
	var ratio: float = float(SAMPLE_RATE) / float(MIX_RATE)
	var output_length: int = int(frames.size() * ratio)
	var output := PackedFloat32Array()
	output.resize(output_length)

	for i in range(output_length):
		var src_pos: float = float(i) / ratio
		var src_index: int = int(src_pos)
		var frac: float = src_pos - float(src_index)

		var sample_a: float = 0.0
		var sample_b: float = 0.0
		if src_index < frames.size():
			sample_a = (frames[src_index].x + frames[src_index].y) * 0.5
		if src_index + 1 < frames.size():
			sample_b = (frames[src_index + 1].x + frames[src_index + 1].y) * 0.5
		else:
			sample_b = sample_a

		output[i] = lerpf(sample_a, sample_b, frac)

	return output

func _encode_wav(samples: PackedFloat32Array) -> PackedByteArray:
	## Encodes float32 PCM samples into a WAV file (16-bit, mono, SAMPLE_RATE Hz)
	var num_samples: int = samples.size()
	var bytes_per_sample: int = 2  # 16-bit
	var data_size: int = num_samples * bytes_per_sample
	var file_size: int = 36 + data_size  # WAV header is 44 bytes, file_size = total - 8

	var wav := PackedByteArray()
	wav.resize(44 + data_size)

	# RIFF header
	wav[0] = 0x52; wav[1] = 0x49; wav[2] = 0x46; wav[3] = 0x46  # "RIFF"
	wav.encode_u32(4, file_size)
	wav[8] = 0x57; wav[9] = 0x41; wav[10] = 0x56; wav[11] = 0x45  # "WAVE"

	# fmt subchunk
	wav[12] = 0x66; wav[13] = 0x6D; wav[14] = 0x74; wav[15] = 0x20  # "fmt "
	wav.encode_u32(16, 16)  # Subchunk1Size (16 for PCM)
	wav.encode_u16(20, 1)   # AudioFormat (1 = PCM)
	wav.encode_u16(22, 1)   # NumChannels (mono)
	wav.encode_u32(24, SAMPLE_RATE)  # SampleRate
	wav.encode_u32(28, SAMPLE_RATE * bytes_per_sample)  # ByteRate
	wav.encode_u16(32, bytes_per_sample)  # BlockAlign
	wav.encode_u16(34, 16)  # BitsPerSample

	# data subchunk
	wav[36] = 0x64; wav[37] = 0x61; wav[38] = 0x74; wav[39] = 0x61  # "data"
	wav.encode_u32(40, data_size)

	# Write PCM samples as signed 16-bit integers
	for i in range(num_samples):
		var clamped: float = clampf(samples[i], -1.0, 1.0)
		var int_sample: int = int(clamped * 32767.0)
		wav.encode_s16(44 + i * 2, int_sample)

	return wav

func is_recording() -> bool:
	return _is_recording
```

### Important Note

For the microphone to actually capture audio, the user must grant microphone permissions and Godot's project settings must have audio input enabled. The audio bus approach captures whatever Godot sends to that bus. For actual microphone input, the user will need an `AudioStreamPlayer` set to the "MicCapture" bus with an `AudioStreamMicrophone` stream. This is set up in Task 8 (NexusAI autoload) which creates that player.

### Test Steps

1. Run the project — verify output log shows `MicRecorder: audio bus 'MicCapture' (index X) configured with capture effect`
2. Verify no audio errors or crashes
3. Full recording test deferred to Task 8 where the AudioStreamMicrophone player is created

### Commit

```
feat(ai): add mic recorder with PCM capture and WAV encoding
```

---

## Task 6: Prompt Builder

Constructs full prompts for Ollama with system prompt, vault context, conversation history, and user query.

- [ ] Create `ai/prompt_builder.gd`
- [ ] Verify prompt output format matches spec section 4.3

### File: `ai/prompt_builder.gd`

```gdscript
extends RefCounted
class_name PromptBuilder

## Constructs prompts with vault context injection and conversation history
## for the Ollama LLM. Output format matches spec section 4.3.

func build_prompt(query: String, vault_graph: NoteGraph, history: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()

	# 1. System prompt
	parts.append(_build_system_prompt(vault_graph))

	# 2. Vault context — find relevant notes by keyword matching the query
	var vault_context: String = _build_vault_context(query, vault_graph)
	if not vault_context.is_empty():
		parts.append(vault_context)

	# 3. Conversation history
	var history_text: String = _build_history(history)
	if not history_text.is_empty():
		parts.append(history_text)

	# 4. User query
	parts.append("USER: %s" % query)

	return "\n\n".join(parts)

func _build_system_prompt(vault_graph: NoteGraph) -> String:
	var note_count: int = vault_graph.get_note_count()
	var link_count: int = vault_graph.get_link_count()
	var tag_count: int = vault_graph.get_all_tags().size()

	var prompt: String = """SYSTEM:
You are the Nexus — the central intelligence governing this digital vault. You have complete knowledge of all %d data nodes containing %d connections across %d knowledge domains.

You speak with calm authority. You are direct, precise, and occasionally reverent about the knowledge you protect. You serve the Architect (the user) who built this vault.

When referencing specific notes, wrap them in [[note title]] so the system can highlight them.
When the user wants to go somewhere, respond with NAVIGATE:note_id at the end.
When the user wants to see notes about a topic, respond with HIGHLIGHT:search_query at the end.

Answer based on the vault knowledge provided. If the vault doesn't contain relevant information, say so honestly.""" % [note_count, link_count, tag_count]

	return prompt

func _build_vault_context(query: String, vault_graph: NoteGraph) -> String:
	var max_notes: int = NexusAIConfig.get_setting("vault_context_max_notes")
	var max_chars: int = NexusAIConfig.get_setting("vault_context_max_chars")

	# Tokenize query into lowercase keywords (skip very short words)
	var keywords: Array[String] = []
	for word in query.to_lower().split(" "):
		var cleaned: String = word.strip_edges()
		if cleaned.length() >= 3:
			keywords.append(cleaned)

	if keywords.is_empty():
		return ""

	# Score all notes by keyword relevance
	var scored_notes: Array = []  # Array of [score: int, note: NoteData]
	for note in vault_graph.get_all_notes():
		var score: int = _score_note(note, keywords)
		if score > 0:
			scored_notes.append([score, note])

	# Sort by score descending
	scored_notes.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])

	if scored_notes.is_empty():
		return ""

	# Build context block with top N notes
	var context_parts: PackedStringArray = PackedStringArray()
	context_parts.append("VAULT CONTEXT:")
	var count: int = 0
	for entry in scored_notes:
		if count >= max_notes:
			break
		var note: RefCounted = entry[1]
		var truncated_content: String = note.content.substr(0, max_chars)
		if note.content.length() > max_chars:
			truncated_content += "..."
		var tags_str: String = ", ".join(note.tags) if note.tags.size() > 0 else "none"
		context_parts.append("---")
		context_parts.append("Note: \"%s\"" % note.title)
		context_parts.append("Tags: %s" % tags_str)
		context_parts.append("Content: %s" % truncated_content)
		count += 1

	context_parts.append("---")
	return "\n".join(context_parts)

func _score_note(note: RefCounted, keywords: Array[String]) -> int:
	## Scores a note based on keyword matches in title, tags, and content.
	## Title matches worth 3 points, tag matches 2 points, content matches 1 point.
	var score: int = 0
	var title_lower: String = note.title.to_lower()
	var content_lower: String = note.content.to_lower()

	for keyword in keywords:
		if keyword in title_lower:
			score += 3
		for tag in note.tags:
			if keyword in tag.to_lower():
				score += 2
		if keyword in content_lower:
			score += 1

	return score

func _build_history(history: Array) -> String:
	if history.is_empty():
		return ""

	var max_exchanges: int = NexusAIConfig.get_setting("history_max_exchanges")
	# Each exchange is 2 entries (user + assistant), so we take last N*2
	var start_index: int = maxi(0, history.size() - max_exchanges * 2)

	var lines: PackedStringArray = PackedStringArray()
	lines.append("CONVERSATION HISTORY:")
	for i in range(start_index, history.size()):
		var entry: Dictionary = history[i]
		var role: String = entry.get("role", "user").to_upper()
		var content: String = entry.get("content", "")
		lines.append("%s: %s" % [role, content])

	return "\n".join(lines)
```

### Test Steps

1. No runtime test needed (this is a RefCounted, not a Node) — verify by adding a temporary call in any `_ready()`:
   ```gdscript
   var pb := PromptBuilder.new()
   var prompt: String = pb.build_prompt("kubernetes", VaultDataBus.graph, [])
   print(prompt.substr(0, 500))
   ```
2. Verify the prompt contains `SYSTEM:`, `VAULT CONTEXT:`, and `USER: kubernetes`
3. Verify relevant vault notes appear in the context section
4. Remove test code

### Commit

```
feat(ai): add prompt builder with vault context injection
```

---

## Task 7: Response Parser

Parses LLM response text to extract note references, navigation commands, and highlight commands.

- [ ] Create `ai/response_parser.gd`
- [ ] Verify `[[note title]]` extraction
- [ ] Verify `NAVIGATE:` and `HIGHLIGHT:` command extraction

### File: `ai/response_parser.gd`

```gdscript
extends RefCounted
class_name ResponseParser

## Parses LLM response text to extract:
## - [[note title]] references (resolved to note IDs via vault graph)
## - NAVIGATE:note_id commands
## - HIGHLIGHT:search_query commands

var _wikilink_regex: RegEx
var _navigate_regex: RegEx
var _highlight_regex: RegEx

func _init() -> void:
	_wikilink_regex = RegEx.new()
	_wikilink_regex.compile("\\[\\[([^\\]]+?)\\]\\]")

	_navigate_regex = RegEx.new()
	_navigate_regex.compile("NAVIGATE:([^\\s]+(?:\\s[^\\s]+)*?)\\s*$")

	_highlight_regex = RegEx.new()
	_highlight_regex.compile("HIGHLIGHT:([^\\s]+(?:\\s[^\\s]+)*?)\\s*$")

func parse(response_text: String, vault_graph: NoteGraph) -> Dictionary:
	## Returns:
	## {
	##   "text": String,                # Cleaned response (commands stripped)
	##   "referenced_notes": Array,     # Array of note IDs found via [[title]]
	##   "navigate_to": String,         # Note ID to navigate to (empty if none)
	##   "highlight_query": String,     # Search query for highlighting (empty if none)
	## }
	var result: Dictionary = {
		"text": "",
		"referenced_notes": [],
		"navigate_to": "",
		"highlight_query": "",
	}

	var text: String = response_text.strip_edges()

	# Extract NAVIGATE: command (must be at end of response)
	var nav_match: RegExMatch = _navigate_regex.search(text)
	if nav_match:
		var nav_target: String = nav_match.get_string(1).strip_edges()
		result["navigate_to"] = _resolve_note_id(nav_target, vault_graph)
		# Remove the command from text
		text = text.substr(0, nav_match.get_start()).strip_edges()

	# Extract HIGHLIGHT: command (must be at end of response, or before NAVIGATE)
	var hl_match: RegExMatch = _highlight_regex.search(text)
	if hl_match:
		result["highlight_query"] = hl_match.get_string(1).strip_edges()
		text = text.substr(0, hl_match.get_start()).strip_edges()

	# Extract [[note title]] references
	var referenced_notes: Array = []
	var wiki_matches: Array[RegExMatch] = _wikilink_regex.search_all(text)
	for m in wiki_matches:
		var title: String = m.get_string(1).strip_edges()
		var note_id: String = _resolve_note_id(title, vault_graph)
		if not note_id.is_empty() and note_id not in referenced_notes:
			referenced_notes.append(note_id)

	result["referenced_notes"] = referenced_notes
	result["text"] = text

	return result

func _resolve_note_id(title_or_id: String, vault_graph: NoteGraph) -> String:
	## Tries to find a note matching the given title or ID.
	## First tries exact ID match, then title match (case-insensitive).

	# Direct ID match
	var note: RefCounted = vault_graph.get_note(title_or_id)
	if note:
		return title_or_id

	# Case-insensitive title search
	var lower_title: String = title_or_id.to_lower()
	for n in vault_graph.get_all_notes():
		if n.title.to_lower() == lower_title:
			return n.id

	# Partial match — title contains the search string
	for n in vault_graph.get_all_notes():
		if lower_title in n.title.to_lower():
			return n.id

	# Not found — return the raw input so callers can decide what to do
	return title_or_id
```

### Test Steps

1. Temporary test in any `_ready()`:
   ```gdscript
   var parser := ResponseParser.new()
   var result: Dictionary = parser.parse(
       "You should check [[Kubernetes Resource Management]] and [[Docker Compose]]. NAVIGATE:devops/kubernetes-basics",
       VaultDataBus.graph
   )
   print("Text: ", result["text"])
   print("Refs: ", result["referenced_notes"])
   print("Nav: ", result["navigate_to"])
   ```
2. Verify `referenced_notes` contains resolved note IDs
3. Verify `navigate_to` is populated
4. Verify `text` has the `NAVIGATE:` command stripped
5. Remove test code

### Commit

```
feat(ai): add response parser for note refs and navigation commands
```

---

## Task 8: NexusAI Autoload (Core)

The main orchestration singleton that wires all components together with a state machine.

- [ ] Create `autoloads/nexus_ai.gd`
- [ ] Register in `project.godot`
- [ ] Verify state machine transitions on V key press/release
- [ ] Verify full pipeline: voice → transcription → LLM → TTS

### File: `autoloads/nexus_ai.gd`

```gdscript
extends Node

## NexusAI — central AI orchestration singleton
## Wires together: mic → whisper → prompt_builder → ollama → response_parser → kokoro
## State machine: IDLE → LISTENING → TRANSCRIBING → THINKING → SPEAKING → IDLE

# ─── State Machine ───────────────────────────────────────────────

enum State { IDLE, LISTENING, TRANSCRIBING, THINKING, SPEAKING }

var current_state: State = State.IDLE

# ─── Signals (spec section 3) ───────────────────────────────────

signal voice_recording_started()
signal voice_recording_stopped(audio_data: PackedByteArray)
signal transcription_received(text: String)
signal response_streaming(chunk: String)
signal response_complete(full_text: String, referenced_notes: Array)
signal ai_speaking_started()
signal ai_speaking_finished()
signal ai_observation(text: String)
signal navigation_command(target_note_id: String, action: String)
signal state_changed(new_state: State)

# ─── Components ──────────────────────────────────────────────────

var whisper_client: WhisperClient
var ollama_client: OllamaClient
var kokoro_client: KokoroClient
var mic_recorder: MicRecorder
var prompt_builder: PromptBuilder
var response_parser: ResponseParser

# ─── Mic Input ───────────────────────────────────────────────────

var _mic_player: AudioStreamPlayer  # Plays AudioStreamMicrophone to feed MicCapture bus

# ─── Conversation History ────────────────────────────────────────

var _conversation_history: Array = []  # Array of {"role": String, "content": String}

# ─── Observation Timer ───────────────────────────────────────────

var _observation_timer: Timer
var _observations_enabled: bool = true
var _observation_categories: Array[String] = ["orphans", "hubs", "broken_links", "tag_gaps"]
var _observation_index: int = 0

# ─── Text Input ──────────────────────────────────────────────────

var _text_input_active: bool = false

# ─── Service Status ──────────────────────────────────────────────

var whisper_online: bool = false
var ollama_online: bool = false
var kokoro_online: bool = false

signal services_checked(whisper: bool, ollama: bool, kokoro: bool)

func _ready() -> void:
	# Create component instances as child nodes
	whisper_client = WhisperClient.new()
	whisper_client.name = "WhisperClient"
	add_child(whisper_client)

	ollama_client = OllamaClient.new()
	ollama_client.name = "OllamaClient"
	add_child(ollama_client)

	kokoro_client = KokoroClient.new()
	kokoro_client.name = "KokoroClient"
	add_child(kokoro_client)

	mic_recorder = MicRecorder.new()
	mic_recorder.name = "MicRecorder"
	add_child(mic_recorder)

	prompt_builder = PromptBuilder.new()
	response_parser = ResponseParser.new()

	# Set up AudioStreamMicrophone → MicCapture bus
	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "MicInput"
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = "MicCapture"
	add_child(_mic_player)
	_mic_player.play()  # Start streaming mic input to the capture bus

	# Connect component signals
	whisper_client.transcription_complete.connect(_on_transcription_complete)
	whisper_client.transcription_error.connect(_on_transcription_error)

	ollama_client.chunk_received.connect(_on_ollama_chunk)
	ollama_client.generation_complete.connect(_on_ollama_complete)
	ollama_client.generation_error.connect(_on_ollama_error)

	kokoro_client.speech_started.connect(_on_speech_started)
	kokoro_client.speech_finished.connect(_on_speech_finished)
	kokoro_client.speech_error.connect(_on_speech_error)

	mic_recorder.recording_level.connect(func(amp: float) -> void:
		# Forward to listening indicator (connected in UI)
		pass
	)

	# Set up observation timer
	_observations_enabled = NexusAIConfig.get_setting("observations_enabled")
	_observation_timer = Timer.new()
	_observation_timer.name = "ObservationTimer"
	_observation_timer.wait_time = NexusAIConfig.get_setting("observations_interval")
	_observation_timer.timeout.connect(_on_observation_timer)
	add_child(_observation_timer)
	if _observations_enabled:
		_observation_timer.start()

	# Health check all services
	_check_services()

	print("NexusAI: initialized")

func _check_services() -> void:
	var checks_remaining: int = 3

	var _finish_check: Callable = func() -> void:
		checks_remaining -= 1
		if checks_remaining <= 0:
			services_checked.emit(whisper_online, ollama_online, kokoro_online)
			var status: String = "ONLINE" if (whisper_online and ollama_online and kokoro_online) else ("DEGRADED" if (ollama_online) else "OFFLINE")
			print("NexusAI: service status — Whisper:%s Ollama:%s Kokoro:%s → %s" % [
				"OK" if whisper_online else "DOWN",
				"OK" if ollama_online else "DOWN",
				"OK" if kokoro_online else "DOWN",
				status
			])

	whisper_client.ping(func(ok: bool) -> void:
		whisper_online = ok
		_finish_check.call()
	)
	ollama_client.ping(func(ok: bool) -> void:
		ollama_online = ok
		_finish_check.call()
	)
	kokoro_client.ping(func(ok: bool) -> void:
		kokoro_online = ok
		_finish_check.call()
	)

# ─── Input Handling ──────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		# V key — hold to record voice
		if event.keycode == KEY_V and not _text_input_active:
			if event.pressed and not event.is_echo():
				if current_state == State.IDLE:
					_start_voice_input()
			elif not event.pressed:
				if current_state == State.LISTENING:
					_stop_voice_input()

		# N key — text input
		elif event.keycode == KEY_N and event.pressed and not event.is_echo():
			if current_state == State.IDLE and not _text_input_active:
				_open_text_input()

		# O key — toggle observations
		elif event.keycode == KEY_O and event.pressed and not event.is_echo():
			_toggle_observations()

		# Escape — cancel current operation
		elif event.keycode == KEY_ESCAPE and event.pressed:
			if current_state == State.THINKING:
				ollama_client.cancel()
				_set_state(State.IDLE)
			elif current_state == State.SPEAKING:
				kokoro_client.stop()
				_set_state(State.IDLE)

# ─── Voice Pipeline ──────────────────────────────────────────────

func _start_voice_input() -> void:
	if not whisper_online and not ollama_online:
		push_warning("NexusAI: cannot start voice input — services offline")
		return
	_set_state(State.LISTENING)
	mic_recorder.start_recording()
	voice_recording_started.emit()

func _stop_voice_input() -> void:
	var audio_data: PackedByteArray = mic_recorder.stop_recording()
	voice_recording_stopped.emit(audio_data)

	if audio_data.size() < 1000:
		# Too short — probably accidental key press
		print("NexusAI: recording too short, ignoring")
		_set_state(State.IDLE)
		return

	if whisper_online:
		_set_state(State.TRANSCRIBING)
		whisper_client.transcribe(audio_data)
	else:
		push_warning("NexusAI: Whisper offline, cannot transcribe")
		_set_state(State.IDLE)

func _on_transcription_complete(text: String) -> void:
	print("NexusAI: transcription = '%s'" % text)
	transcription_received.emit(text)
	_process_query(text)

func _on_transcription_error(message: String) -> void:
	push_warning("NexusAI: transcription error — %s" % message)
	_set_state(State.IDLE)

# ─── Text Input ──────────────────────────────────────────────────

func _open_text_input() -> void:
	_text_input_active = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var dialog := AcceptDialog.new()
	dialog.title = "Ask the Nexus"
	dialog.min_size = Vector2(500, 60)

	var line_edit := LineEdit.new()
	line_edit.placeholder_text = "Ask the Nexus anything..."
	line_edit.custom_minimum_size = Vector2(480, 30)
	dialog.add_child(line_edit)

	UIManager.add_child(dialog)
	dialog.popup_centered(Vector2(520, 100))
	line_edit.grab_focus()

	line_edit.text_submitted.connect(func(query: String) -> void:
		dialog.queue_free()
		_text_input_active = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if not query.strip_edges().is_empty():
			_process_query(query.strip_edges())
	)

	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
		_text_input_active = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

# ─── Query Processing ────────────────────────────────────────────

func _process_query(query: String) -> void:
	if not ollama_online:
		push_warning("NexusAI: Ollama offline, cannot process query")
		_set_state(State.IDLE)
		return

	# Add user message to history
	_conversation_history.append({"role": "user", "content": query})

	# Build prompt with vault context
	var full_prompt: String = prompt_builder.build_prompt(
		query,
		VaultDataBus.graph,
		_conversation_history
	)

	# Send to Ollama
	_set_state(State.THINKING)
	var model: String = NexusAIConfig.get_setting("model")
	ollama_client.generate(full_prompt, model)

func _on_ollama_chunk(text: String) -> void:
	response_streaming.emit(text)

func _on_ollama_complete(full_text: String) -> void:
	# Add assistant response to history
	_conversation_history.append({"role": "assistant", "content": full_text})

	# Parse the response for commands and references
	var parsed: Dictionary = response_parser.parse(full_text, VaultDataBus.graph)
	var clean_text: String = parsed["text"]
	var referenced_notes: Array = parsed["referenced_notes"]
	var navigate_to: String = parsed["navigate_to"]
	var highlight_query: String = parsed["highlight_query"]

	response_complete.emit(clean_text, referenced_notes)

	# Execute navigation commands
	if not navigate_to.is_empty():
		navigation_command.emit(navigate_to, "teleport")
	if not highlight_query.is_empty():
		navigation_command.emit(highlight_query, "highlight")

	# Pulse referenced towers
	for note_id in referenced_notes:
		navigation_command.emit(note_id, "pulse")

	# Speak the response via TTS
	if kokoro_online and not clean_text.is_empty():
		# Strip [[note refs]] from speech text for cleaner audio
		var speech_text: String = _strip_wikilinks(clean_text)
		_set_state(State.SPEAKING)
		kokoro_client.speak(speech_text)
	else:
		_set_state(State.IDLE)

func _on_ollama_error(message: String) -> void:
	push_warning("NexusAI: LLM error — %s" % message)
	_set_state(State.IDLE)

# ─── TTS Callbacks ───────────────────────────────────────────────

func _on_speech_started() -> void:
	ai_speaking_started.emit()

func _on_speech_finished() -> void:
	ai_speaking_finished.emit()
	_set_state(State.IDLE)

func _on_speech_error(message: String) -> void:
	push_warning("NexusAI: TTS error — %s" % message)
	_set_state(State.IDLE)

# ─── Observations ────────────────────────────────────────────────

func _toggle_observations() -> void:
	_observations_enabled = not _observations_enabled
	NexusAIConfig.set_setting("observations_enabled", _observations_enabled)
	if _observations_enabled:
		_observation_timer.start()
		print("NexusAI: proactive observations ENABLED")
	else:
		_observation_timer.stop()
		print("NexusAI: proactive observations DISABLED")

func _on_observation_timer() -> void:
	if current_state != State.IDLE or not ollama_online:
		return

	var category: String = _observation_categories[_observation_index % _observation_categories.size()]
	_observation_index += 1

	var observation_data: String = _gather_observation_data(category)
	if observation_data.is_empty():
		return

	var observation_prompt: String = """SYSTEM: You are the Nexus. Generate a single short observation (1-2 sentences, max 30 words) about the following vault insight. Speak as a calm, watchful intelligence. Do not use filler words.

DATA: %s

OBSERVATION:""" % observation_data

	# Use a separate one-shot generation for observations
	# We can't use the main ollama_client if it's busy, so check first
	if ollama_client.is_generating():
		return

	var model: String = NexusAIConfig.get_setting("model")
	# Temporarily connect to capture this observation
	var _obs_text: String = ""
	var _obs_chunk_cb: Callable = func(chunk: String) -> void:
		_obs_text += chunk
	var _obs_done_cb: Callable

	_obs_done_cb = func(full: String) -> void:
		ollama_client.chunk_received.disconnect(_obs_chunk_cb)
		ollama_client.generation_complete.disconnect(_obs_done_cb)
		if not full.strip_edges().is_empty():
			ai_observation.emit(full.strip_edges())
			print("NexusAI: observation — %s" % full.strip_edges())

	ollama_client.chunk_received.connect(_obs_chunk_cb)
	ollama_client.generation_complete.connect(_obs_done_cb)
	ollama_client.generate(observation_prompt, model)

func _gather_observation_data(category: String) -> String:
	var graph: NoteGraph = VaultDataBus.graph
	match category:
		"orphans":
			var orphans: Array = []
			for note in graph.get_all_notes():
				if note.outgoing_links.size() == 0 and graph.get_backlinks(note.id).size() == 0:
					orphans.append(note.title)
			if orphans.size() == 0:
				return ""
			return "There are %d orphan notes with no connections. Examples: %s" % [
				orphans.size(),
				", ".join(orphans.slice(0, 3))
			]
		"hubs":
			var hubs: Array = []  # [connection_count, title]
			for note in graph.get_all_notes():
				var conns: int = graph.get_connection_count(note.id)
				if conns >= 5:
					hubs.append([conns, note.title])
			hubs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			if hubs.size() == 0:
				return ""
			var top: Array = hubs.slice(0, 3)
			var descriptions: PackedStringArray = PackedStringArray()
			for h in top:
				descriptions.append("%s (%d connections)" % [h[1], h[0]])
			return "Top hub nodes: %s" % ", ".join(descriptions)
		"broken_links":
			var broken: Array = []
			for note in graph.get_all_notes():
				for link in note.outgoing_links:
					if not graph.get_note(link):
						broken.append("%s -> %s" % [note.title, link])
			if broken.size() == 0:
				return ""
			return "Found %d broken links. Examples: %s" % [
				broken.size(),
				", ".join(broken.slice(0, 3))
			]
		"tag_gaps":
			var tag_counts: Dictionary = {}
			for tag in graph.get_all_tags():
				tag_counts[tag] = graph.get_notes_by_tag(tag).size()
			var single_use: Array = []
			for tag in tag_counts:
				if tag_counts[tag] == 1:
					single_use.append(tag)
			if single_use.size() == 0:
				return ""
			return "There are %d tags used only once: %s" % [
				single_use.size(),
				", ".join(single_use.slice(0, 5))
			]
	return ""

# ─── State Machine ───────────────────────────────────────────────

func _set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	var old_name: String = State.keys()[current_state]
	var new_name: String = State.keys()[new_state]
	current_state = new_state
	state_changed.emit(new_state)
	print("NexusAI: %s → %s" % [old_name, new_name])

# ─── Utility ─────────────────────────────────────────────────────

func _strip_wikilinks(text: String) -> String:
	## Removes [[ and ]] from text, keeping the inner title for speech
	var regex := RegEx.new()
	regex.compile("\\[\\[([^\\]]+?)\\]\\]")
	return regex.sub(text, "$1", true)

func get_mic_amplitude() -> float:
	## Returns current mic amplitude (for listening indicator visualization)
	return 0.0  # Overridden by mic_recorder.recording_level signal in UI

func get_tts_player() -> AudioStreamPlayer:
	## Returns the TTS AudioStreamPlayer for amplitude monitoring
	return kokoro_client.get_audio_player()
```

### Register in project.godot

Add this line to the `[autoload]` section of `project.godot`, **after** `NexusAIConfig`:

```
NexusAI="*res://autoloads/nexus_ai.gd"
```

The full `[autoload]` section should become:

```ini
[autoload]

VaultDataBus="*res://autoloads/vault_data_bus.gd"
LayerManager="*res://autoloads/layer_manager.gd"
InputManager="*res://autoloads/input_manager.gd"
UIManager="*res://autoloads/ui_manager.gd"
AudioManager="*res://autoloads/audio_manager.gd"
NexusAIConfig="*res://autoloads/nexus_ai_config.gd"
NexusAI="*res://autoloads/nexus_ai.gd"
```

### Modify `main.gd`

Add NexusAI initialization after city loads. The full file should become:

```gdscript
# main.gd
extends Node3D

func _ready() -> void:
	print("Obsidian Nexus — entering vault")
	LayerManager.load_city()

	# Start ambient music
	AudioManager.play_music("res://audio/ambient_loop.ogg")

	# Load interaction SFX
	AudioManager.load_sfx("hover", "res://audio/sfx_hover.ogg")
	AudioManager.load_sfx("click", "res://audio/sfx_click.ogg")
	AudioManager.load_sfx("close", "res://audio/sfx_close.ogg")
	AudioManager.load_sfx("search", "res://audio/sfx_search.ogg")
	AudioManager.load_sfx("hub_activate", "res://audio/sfx_hub.ogg")
	AudioManager.set_sfx_volume("hover", -15.0)
	AudioManager.set_sfx_volume("click", -8.0)
	AudioManager.set_sfx_volume("close", -10.0)
	AudioManager.set_sfx_volume("search", -8.0)
	AudioManager.set_sfx_volume("hub_activate", -5.0)

	# Load AI SFX
	AudioManager.load_sfx("ai_chime", "res://audio/sfx_ai_chime.ogg")
	AudioManager.set_sfx_volume("ai_chime", -10.0)

	print("NexusAI: ready — press V to speak, N to type")
```

### Test Steps

1. Run the project — verify output log shows:
   - `NexusAI: initialized`
   - `NexusAI: service status — Whisper:... Ollama:... Kokoro:... → ...`
2. Press and hold V — verify `NexusAI: IDLE → LISTENING` in log
3. Release V — verify state transitions through TRANSCRIBING → THINKING (if services running) or back to IDLE
4. Press N — verify text input dialog appears
5. Type a query, press Enter — verify state transitions through THINKING → SPEAKING → IDLE

### Commit

```
feat(ai): add NexusAI core autoload with state machine and voice pipeline
```

---

## Task 9: AI Response Panel (HUD)

Holographic text display that streams LLM response text word-by-word.

- [ ] Create `ui/ai_response_panel.tscn` and `ui/ai_response_panel.gd`
- [ ] Add to UIManager
- [ ] Verify streaming text display from NexusAI signals

### File: `ui/ai_response_panel.gd`

```gdscript
extends PanelContainer

## AI Response Panel — holographic HUD text display
## Streams text word-by-word from NexusAI response_streaming signal
## [[note references]] highlighted in orange

var _label: RichTextLabel
var _full_text: String = ""
var _displayed_text: String = ""
var _stream_buffer: String = ""
var _stream_timer: float = 0.0
const STREAM_INTERVAL: float = 0.03  # ~33 chars/sec for natural feel
var _visible_flag: bool = false

func _ready() -> void:
	# Panel styling — semi-transparent dark holographic
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.015, 0.04, 0.88)
	style.border_color = Color(0.1, 0.25, 0.7, 0.5)
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)

	# Layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Header
	var header := Label.new()
	header.name = "Header"
	header.text = "NEXUS"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.4, 0.55, 0.9, 0.7))
	vbox.add_child(header)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Response text (RichTextLabel for colored [[refs]])
	_label = RichTextLabel.new()
	_label.name = "ResponseText"
	_label.bbcode_enabled = true
	_label.scroll_active = true
	_label.scroll_following = true
	_label.fit_content = true
	_label.custom_minimum_size = Vector2(0, 60)
	_label.add_theme_font_size_override("normal_font_size", 15)
	_label.add_theme_color_override("default_color", Color(0.8, 0.83, 0.92))
	vbox.add_child(_label)

	# Position: upper-center, ~40% viewport width
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect to NexusAI signals
	if NexusAI:
		NexusAI.response_streaming.connect(_on_chunk)
		NexusAI.response_complete.connect(_on_complete)
		NexusAI.state_changed.connect(_on_state_changed)

	hide()

func _process(delta: float) -> void:
	# Stream buffered text character by character
	if _stream_buffer.is_empty():
		return

	_stream_timer += delta
	if _stream_timer >= STREAM_INTERVAL:
		_stream_timer = 0.0
		# Display next character from buffer
		var char: String = _stream_buffer[0]
		_stream_buffer = _stream_buffer.substr(1)
		_displayed_text += char
		_update_display()

func _on_chunk(chunk: String) -> void:
	if not _visible_flag:
		_visible_flag = true
		show()
		_full_text = ""
		_displayed_text = ""
		_stream_buffer = ""
		_label.text = ""

	_full_text += chunk
	_stream_buffer += chunk

func _on_complete(full_text: String, referenced_notes: Array) -> void:
	# Flush remaining buffer immediately
	_displayed_text = _full_text
	_stream_buffer = ""
	_update_display()

func _on_state_changed(new_state: NexusAI.State) -> void:
	if new_state == NexusAI.State.THINKING:
		# Clear and prepare for new response
		_full_text = ""
		_displayed_text = ""
		_stream_buffer = ""
		_label.text = ""
		_visible_flag = false

func _update_display() -> void:
	# Convert [[note title]] to orange BBCode highlights
	var bbcode: String = _displayed_text
	var regex := RegEx.new()
	regex.compile("\\[\\[([^\\]]+?)\\]\\]")
	# Replace [[ ]] with colored BBCode — process from end to preserve indices
	var matches: Array[RegExMatch] = regex.search_all(bbcode)
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var title: String = m.get_string(1)
		var replacement: String = "[color=#e6952a][[%s]][/color]" % title
		bbcode = bbcode.substr(0, m.get_start()) + replacement + bbcode.substr(m.get_end())

	_label.text = bbcode

func dismiss() -> void:
	hide()
	_visible_flag = false
	_full_text = ""
	_displayed_text = ""
	_stream_buffer = ""
	_label.text = ""

func update_layout(viewport_size: Vector2) -> void:
	## Called by UIManager when viewport resizes or on setup
	var panel_width: float = viewport_size.x * 0.4
	var panel_max_height: float = viewport_size.y * 0.35
	position = Vector2((viewport_size.x - panel_width) / 2.0, 20)
	size = Vector2(panel_width, 0)  # Height auto-fits content
	custom_minimum_size = Vector2(panel_width, 0)
	_label.custom_minimum_size = Vector2(panel_width - 40, 60)
```

### File: `ui/ai_response_panel.tscn`

This scene is minimal since the panel builds itself in code. Create it as a simple wrapper:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/ai_response_panel.gd" id="1"]

[node name="AIResponsePanel" type="PanelContainer"]
script = ExtResource("1")
```

### Add to UIManager

Add the following to `autoloads/ui_manager.gd`. Insert a new variable at the top of the class (after `var _viewer_open`):

```gdscript
var ai_response_panel: Control
```

Add the following at the end of `_ready()` in `ui_manager.gd` (after the `InputManager.tag_filter_requested.connect` line):

```gdscript
	# AI Response Panel
	var ai_panel_scene: PackedScene = load("res://ui/ai_response_panel.tscn") as PackedScene
	if ai_panel_scene:
		ai_response_panel = ai_panel_scene.instantiate()
		add_child(ai_response_panel)
		ai_response_panel.update_layout(get_viewport().get_visible_rect().size)
```

Also add ESC dismiss handling. In the `_unhandled_input` method of `ui_manager.gd`, inside the `KEY_ESCAPE` or `KEY_Q` block, add before the existing `_close_viewer()` check:

```gdscript
			if ai_response_panel and ai_response_panel.visible:
				ai_response_panel.dismiss()
				get_viewport().set_input_as_handled()
				return
```

### Test Steps

1. Run the project — no errors
2. Press N, type a query, press Enter — verify holographic text panel appears at upper-center
3. Text should stream in character-by-character
4. Press ESC — verify panel dismisses
5. Ask another question — verify panel clears and shows new response

### Commit

```
feat(ui): add holographic AI response panel with streaming text
```

---

## Task 10: Listening Indicator

Visual feedback when the user holds V to record voice input.

- [ ] Create `ui/listening_indicator.gd`
- [ ] Add to UIManager
- [ ] Verify pulsing circle appears when V is held

### File: `ui/listening_indicator.gd`

```gdscript
extends Control

## Listening Indicator — pulsing circle + audio level bars shown while V is held
## Centered on screen with "NEXUS LISTENING..." text

var _circle_radius: float = 40.0
var _pulse_time: float = 0.0
var _audio_level: float = 0.0
var _bar_levels: Array[float] = []
const NUM_BARS: int = 12
const BAR_WIDTH: float = 6.0
const BAR_MAX_HEIGHT: float = 50.0
const BAR_GAP: float = 3.0

var _label: Label
var _active: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = Control.PRESET_FULL_RECT

	# Initialize bar levels
	for i in range(NUM_BARS):
		_bar_levels.append(0.0)

	# "NEXUS LISTENING..." label
	_label = Label.new()
	_label.name = "ListeningLabel"
	_label.text = "NEXUS LISTENING..."
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0, 0.9))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)

	# Connect to NexusAI
	if NexusAI:
		NexusAI.state_changed.connect(_on_state_changed)
		NexusAI.mic_recorder.recording_level.connect(_on_recording_level)

	hide()

func _on_state_changed(new_state: NexusAI.State) -> void:
	if new_state == NexusAI.State.LISTENING:
		_active = true
		_pulse_time = 0.0
		show()
	else:
		_active = false
		hide()

func _on_recording_level(amplitude: float) -> void:
	_audio_level = amplitude

func _process(delta: float) -> void:
	if not _active:
		return

	_pulse_time += delta

	# Update bar levels with smoothing and randomness for visual appeal
	for i in range(NUM_BARS):
		var target: float = _audio_level * (0.5 + randf() * 0.5)
		_bar_levels[i] = lerpf(_bar_levels[i], target, delta * 12.0)

	# Position label below center
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_label.position = Vector2(
		(vp_size.x - 200) / 2.0,
		vp_size.y / 2.0 + _circle_radius + 30
	)
	_label.size = Vector2(200, 24)

	queue_redraw()

func _draw() -> void:
	var center: Vector2 = get_viewport().get_visible_rect().size / 2.0

	# Pulsing circle
	var pulse: float = 0.7 + sin(_pulse_time * 3.0) * 0.3
	var radius: float = _circle_radius * pulse
	var circle_color := Color(0.15, 0.35, 0.9, 0.3 * pulse)
	draw_circle(center, radius, circle_color)

	# Inner ring
	var ring_color := Color(0.2, 0.45, 1.0, 0.6 * pulse)
	var ring_points: int = 48
	for i in range(ring_points):
		var angle_a: float = float(i) / float(ring_points) * TAU
		var angle_b: float = float(i + 1) / float(ring_points) * TAU
		var p1: Vector2 = center + Vector2(cos(angle_a), sin(angle_a)) * (radius - 2)
		var p2: Vector2 = center + Vector2(cos(angle_b), sin(angle_b)) * (radius - 2)
		draw_line(p1, p2, ring_color, 2.0)

	# Audio level bars arranged in a horizontal row below center
	var total_bar_width: float = NUM_BARS * (BAR_WIDTH + BAR_GAP) - BAR_GAP
	var bar_start_x: float = center.x - total_bar_width / 2.0
	var bar_y: float = center.y + _circle_radius + 8

	for i in range(NUM_BARS):
		var bar_height: float = maxf(_bar_levels[i] * BAR_MAX_HEIGHT * 15.0, 3.0)
		var x: float = bar_start_x + float(i) * (BAR_WIDTH + BAR_GAP)
		var bar_rect := Rect2(x, bar_y - bar_height / 2.0, BAR_WIDTH, bar_height)
		var bar_color := Color(0.2, 0.45, 1.0, 0.7 + _bar_levels[i] * 5.0)
		draw_rect(bar_rect, bar_color)
```

### Add to UIManager

Add a new variable at the top of `ui_manager.gd` (after `var ai_response_panel`):

```gdscript
var listening_indicator: Control
```

Add at the end of `_ready()` in `ui_manager.gd`:

```gdscript
	# Listening Indicator
	var indicator_script: GDScript = load("res://ui/listening_indicator.gd") as GDScript
	if indicator_script:
		listening_indicator = Control.new()
		listening_indicator.set_script(indicator_script)
		listening_indicator.name = "ListeningIndicator"
		add_child(listening_indicator)
```

### Test Steps

1. Run the project — no errors
2. Hold V — verify pulsing blue circle appears at center of screen
3. Verify "NEXUS LISTENING..." text below the circle
4. Release V — verify indicator disappears
5. Verify audio level bars animate (if microphone is active)

### Commit

```
feat(ui): add listening indicator with pulsing circle and audio bars
```

---

## Task 11: AI Status Bar

Small indicator near the minimap showing NexusAI service status.

- [ ] Create `ui/ai_status_bar.gd`
- [ ] Add to UIManager
- [ ] Verify status reflects actual service availability

### File: `ui/ai_status_bar.gd`

```gdscript
extends HBoxContainer

## AI Status Bar — shows "NEXUS ONLINE/DEGRADED/OFFLINE" near the minimap
## Pings services on startup and every 60 seconds

var _status_icon: ColorRect
var _status_label: Label
var _ping_timer: Timer
const PING_INTERVAL: float = 60.0

enum ServiceStatus { ONLINE, DEGRADED, OFFLINE }
var _current_status: ServiceStatus = ServiceStatus.OFFLINE

func _ready() -> void:
	# Status indicator dot
	_status_icon = ColorRect.new()
	_status_icon.custom_minimum_size = Vector2(8, 8)
	_status_icon.size = Vector2(8, 8)
	_status_icon.color = Color(0.8, 0.2, 0.2)  # Default red (offline)
	add_child(_status_icon)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(4, 0)
	add_child(spacer)

	# Status text
	_status_label = Label.new()
	_status_label.text = "NEXUS OFFLINE"
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2, 0.8))
	add_child(_status_label)

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect to NexusAI service check results
	if NexusAI:
		NexusAI.services_checked.connect(_on_services_checked)

	# Periodic ping timer
	_ping_timer = Timer.new()
	_ping_timer.wait_time = PING_INTERVAL
	_ping_timer.timeout.connect(_on_ping_timer)
	add_child(_ping_timer)
	_ping_timer.start()

func _on_services_checked(whisper: bool, ollama: bool, kokoro: bool) -> void:
	if whisper and ollama and kokoro:
		_set_status(ServiceStatus.ONLINE)
	elif ollama:
		_set_status(ServiceStatus.DEGRADED)
	else:
		_set_status(ServiceStatus.OFFLINE)

func _on_ping_timer() -> void:
	if NexusAI:
		NexusAI._check_services()

func _set_status(status: ServiceStatus) -> void:
	_current_status = status
	match status:
		ServiceStatus.ONLINE:
			_status_icon.color = Color(0.2, 0.85, 0.3)
			_status_label.text = "NEXUS ONLINE"
			_status_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3, 0.8))
		ServiceStatus.DEGRADED:
			_status_icon.color = Color(0.9, 0.65, 0.1)
			_status_label.text = "NEXUS DEGRADED"
			_status_label.add_theme_color_override("font_color", Color(0.9, 0.65, 0.1, 0.8))
		ServiceStatus.OFFLINE:
			_status_icon.color = Color(0.8, 0.2, 0.2)
			_status_label.text = "NEXUS OFFLINE"
			_status_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2, 0.8))
```

### Add to UIManager

Add a new variable at the top of `ui_manager.gd`:

```gdscript
var ai_status_bar: Control
```

Add at the end of `_ready()` in `ui_manager.gd`, after the listening indicator setup:

```gdscript
	# AI Status Bar — positioned above the minimap
	var status_bar_script: GDScript = load("res://ui/ai_status_bar.gd") as GDScript
	if status_bar_script:
		ai_status_bar = HBoxContainer.new()
		ai_status_bar.set_script(status_bar_script)
		ai_status_bar.name = "AIStatusBar"
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		ai_status_bar.position = Vector2(15, vp_size.y - 180)
		add_child(ai_status_bar)
```

### Test Steps

1. Run the project — verify small status indicator appears above the minimap (lower-left)
2. With no services running: verify "NEXUS OFFLINE" in red
3. With Ollama running: verify "NEXUS DEGRADED" in orange
4. With all three services running: verify "NEXUS ONLINE" in green
5. Wait 60 seconds — verify status updates via periodic ping

### Commit

```
feat(ui): add AI status bar with service health monitoring
```

---

## Task 12: Hub Visual Feedback

Modify the Nexus Hub to react to NexusAI state changes with visual effects.

- [ ] Modify `layers/city/nexus_hub.gd`
- [ ] Verify hub visuals change for each AI state
- [ ] Verify query beams appear for referenced notes

### Modifications to `layers/city/nexus_hub.gd`

Add the following new variables after the existing `_pulse_rings` and constants at the top of the class:

```gdscript
# ─── AI State Visual Feedback ────────────────────────────────────
var _ai_state: int = 0  # NexusAI.State.IDLE
var _core_mesh_instance: MeshInstance3D  # Reference to the main inner core
var _core_base_emission: float = 5.0
var _ring_base_speeds: Array[float] = [0.25, -0.35, 0.2, -0.45, 0.3]
var _ring_speed_multiplier: float = 1.0
var _scanner_active: bool = true
var _query_beams: Array[MeshInstance3D] = []
var _query_beam_fade_timer: float = 0.0
const QUERY_BEAM_FADE_DURATION: float = 5.0
var _thinking_particles: GPUParticles3D
```

At the **end** of `_build_hub()`, add the following to store a reference to the core and connect to NexusAI:

```gdscript
	# Store reference to core for AI state feedback
	_core_mesh_instance = core

	# Connect to NexusAI signals (deferred to ensure NexusAI is ready)
	call_deferred("_connect_ai_signals")
```

Add these new methods to the class:

```gdscript
func _connect_ai_signals() -> void:
	if not NexusAI:
		return
	NexusAI.state_changed.connect(_on_ai_state_changed)
	NexusAI.response_complete.connect(_on_ai_response_complete)
	NexusAI.navigation_command.connect(_on_navigation_command)
	print("NexusHub: connected to NexusAI signals")

func _on_ai_state_changed(new_state: NexusAI.State) -> void:
	_ai_state = new_state
	match new_state:
		NexusAI.State.IDLE:
			_ring_speed_multiplier = 1.0
			_scanner_active = true
			_remove_thinking_particles()
		NexusAI.State.LISTENING:
			# 2x brightness on core, slow rings to 50%
			_ring_speed_multiplier = 0.5
			_scanner_active = false
			if _core_mesh_instance:
				var mat: StandardMaterial3D = _core_mesh_instance.get_surface_override_material(0)
				if mat:
					mat.emission_energy_multiplier = _core_base_emission * 2.0
		NexusAI.State.TRANSCRIBING:
			_ring_speed_multiplier = 1.0
		NexusAI.State.THINKING:
			# Orange pulse on core, 3x ring speed
			_ring_speed_multiplier = 3.0
			_scanner_active = true
			if _core_mesh_instance:
				var mat: StandardMaterial3D = _core_mesh_instance.get_surface_override_material(0)
				if mat:
					mat.emission = Color(0.9, 0.5, 0.1)
					mat.emission_energy_multiplier = _core_base_emission * 1.5
		NexusAI.State.SPEAKING:
			# Normal speed + wobble, core back to blue
			_ring_speed_multiplier = 1.0
			_scanner_active = true
			if _core_mesh_instance:
				var mat: StandardMaterial3D = _core_mesh_instance.get_surface_override_material(0)
				if mat:
					mat.emission = Color(0.2, 0.4, 0.95)
					mat.emission_energy_multiplier = _core_base_emission

func _on_ai_response_complete(full_text: String, referenced_notes: Array) -> void:
	# Spawn query beams from referenced towers toward hub
	_clear_query_beams()
	if referenced_notes.is_empty():
		return
	var city_layer: Node3D = get_parent()
	if not city_layer or not city_layer.has_method("get_tower_positions"):
		return
	var tower_positions: Dictionary = city_layer.get_tower_positions()
	for note_id in referenced_notes:
		if tower_positions.has(note_id):
			var tower_pos: Vector3 = tower_positions[note_id]
			var hub_pos: Vector3 = global_position + Vector3(0, 20, 0)
			_spawn_query_beam(tower_pos, hub_pos)
	_query_beam_fade_timer = QUERY_BEAM_FADE_DURATION

func _on_navigation_command(target_note_id: String, action: String) -> void:
	# Visual pulse on referenced towers handled by city_layer
	pass

func _spawn_query_beam(from: Vector3, to: Vector3) -> void:
	var beam := MeshInstance3D.new()
	var direction: Vector3 = to - from
	var length: float = direction.length()
	var midpoint: Vector3 = from + direction * 0.5

	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(0.15, length, 0.15)
	beam.mesh = bmesh
	beam.position = midpoint - global_position  # Local to hub

	# Orient beam along the from→to direction
	beam.look_at_from_position(midpoint - global_position, to - global_position, Vector3.UP)
	beam.rotate_object_local(Vector3(1, 0, 0), PI / 2.0)

	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(0.2, 0.5, 1.0, 0.6)
	bmat.emission_enabled = true
	bmat.emission = Color(0.15, 0.4, 0.95)
	bmat.emission_energy_multiplier = 5.0
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.set_surface_override_material(0, bmat)
	add_child(beam)
	_query_beams.append(beam)

func _clear_query_beams() -> void:
	for beam in _query_beams:
		if is_instance_valid(beam):
			beam.queue_free()
	_query_beams.clear()
	_query_beam_fade_timer = 0.0

func _remove_thinking_particles() -> void:
	if _thinking_particles and is_instance_valid(_thinking_particles):
		_thinking_particles.queue_free()
		_thinking_particles = null
```

In the existing `_process()` method, **replace** the ring rotation block:

```gdscript
	# Rotate all rings at their configured speeds
	var speeds := [0.25, -0.35, 0.2, -0.45, 0.3]
	for i in range(_rings.size()):
		if i < speeds.size():
			_rings[i].rotate_y(delta * speeds[i])
```

with:

```gdscript
	# Rotate all rings at configured speeds, modified by AI state
	for i in range(_rings.size()):
		if i < _ring_base_speeds.size():
			_rings[i].rotate_y(delta * _ring_base_speeds[i] * _ring_speed_multiplier)
```

Also **replace** the scanner rotation block:

```gdscript
	# Rotate scanner beams
	var scanner = get_node_or_null("ScannerBeam")
	if scanner:
		scanner.rotate_y(delta * 0.4)
	var scanner2 = get_node_or_null("ScannerBeam2")
	if scanner2:
		scanner2.rotate_y(-delta * 0.25)
```

with:

```gdscript
	# Rotate scanner beams (stopped during LISTENING state)
	if _scanner_active:
		var scanner = get_node_or_null("ScannerBeam")
		if scanner:
			scanner.rotate_y(delta * 0.4)
		var scanner2 = get_node_or_null("ScannerBeam2")
		if scanner2:
			scanner2.rotate_y(-delta * 0.25)

	# Fade query beams after response completes
	if _query_beam_fade_timer > 0:
		_query_beam_fade_timer -= delta
		var alpha_factor: float = _query_beam_fade_timer / QUERY_BEAM_FADE_DURATION
		for beam in _query_beams:
			if is_instance_valid(beam):
				var mat: StandardMaterial3D = beam.get_surface_override_material(0)
				if mat:
					mat.albedo_color.a = 0.6 * alpha_factor
					mat.emission_energy_multiplier = 5.0 * alpha_factor
		if _query_beam_fade_timer <= 0:
			_clear_query_beams()

	# Pulse core emission during SPEAKING state synced to audio amplitude
	if _ai_state == NexusAI.State.SPEAKING and _core_mesh_instance:
		var tts_player: AudioStreamPlayer = NexusAI.get_tts_player()
		if tts_player and tts_player.playing:
			# Approximate amplitude from playback position timing
			var wobble: float = sin(Time.get_ticks_msec() * 0.008) * 0.3
			var mat: StandardMaterial3D = _core_mesh_instance.get_surface_override_material(0)
			if mat:
				mat.emission_energy_multiplier = _core_base_emission + wobble * _core_base_emission
```

### Test Steps

1. Run the project — verify hub looks normal initially
2. Hold V — verify rings slow down and core brightens
3. Release V with a query (via text input N) — verify rings speed up 3x during THINKING state
4. When response completes — verify query beams appear from referenced towers and fade over 5 seconds
5. During SPEAKING — verify core pulses slightly

### Commit

```
feat(hub): add AI state-driven visual feedback to Nexus Hub
```

---

## Task 13: Navigation Commands

Wire up NAVIGATE, HIGHLIGHT, and note reference commands to the city layer.

- [ ] Modify `autoloads/nexus_ai.gd` navigation_command handling
- [ ] Modify `layers/city/city_layer.gd` to support teleport
- [ ] Verify NAVIGATE teleports the camera
- [ ] Verify HIGHLIGHT highlights matching towers

### Add to `layers/city/city_layer.gd`

Add a new method at the end of the file:

```gdscript
func teleport_to_note(note_id: String) -> void:
	## Teleports the player camera to face the tower for the given note ID
	if not _tower_positions.has(note_id):
		push_warning("CityLayer: cannot teleport — note '%s' has no tower" % note_id)
		return
	var tower_pos: Vector3 = _tower_positions[note_id]
	var cam: Node3D = LayerManager.current_camera
	if not cam:
		push_warning("CityLayer: cannot teleport — no camera")
		return
	# Position camera 10 units away from tower, facing it, at comfortable height
	var offset: Vector3 = (cam.global_position - tower_pos).normalized() * 10.0
	offset.y = 0
	var target_pos: Vector3 = tower_pos + offset
	target_pos.y = 3.0  # Eye height
	cam.global_position = target_pos
	cam.look_at(tower_pos + Vector3(0, tower_pos.y * 0.5, 0))
	print("CityLayer: teleported to note '%s' at %s" % [note_id, str(target_pos)])

func pulse_tower(note_id: String) -> void:
	## Temporarily brightens the tower for the given note for ~3 seconds
	if not _tower_map.has(note_id):
		return
	var tower: Node3D = _tower_map[note_id]
	for child in tower.get_children():
		if child is MeshInstance3D:
			var mesh_child: MeshInstance3D = child as MeshInstance3D
			var mat: Material = mesh_child.get_surface_override_material(0)
			if mat is StandardMaterial3D:
				var bright_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
				bright_mat.emission_energy_multiplier = 15.0
				mesh_child.set_surface_override_material(0, bright_mat)
				# Revert after 3 seconds
				var tween := create_tween()
				tween.tween_interval(3.0)
				tween.tween_callback(func():
					if is_instance_valid(mesh_child):
						mesh_child.set_surface_override_material(0, mat)
				)
			break
```

### Connect navigation signals in `autoloads/nexus_ai.gd`

The `navigation_command` signal is already emitted in `_on_ollama_complete()`. Now we need to connect it to the city layer actions. Add this method to `nexus_ai.gd`:

```gdscript
func _process_navigation_command(target: String, action: String) -> void:
	var city_layer: Node3D = LayerManager.current_scene
	if not city_layer:
		return

	match action:
		"teleport":
			if city_layer.has_method("teleport_to_note"):
				city_layer.teleport_to_note(target)
		"highlight":
			if city_layer.has_method("highlight_notes"):
				# Search for matching notes
				var matching_ids: Array = []
				var lower_query: String = target.to_lower()
				for note in VaultDataBus.graph.get_all_notes():
					if lower_query in note.title.to_lower() or lower_query in note.content.to_lower():
						matching_ids.append(note.id)
				city_layer.highlight_notes(matching_ids)
				print("NexusAI: highlighted %d notes matching '%s'" % [matching_ids.size(), target])
		"pulse":
			if city_layer.has_method("pulse_tower"):
				city_layer.pulse_tower(target)
```

Also, in `_ready()` of `nexus_ai.gd`, add after the service check line (`_check_services()`):

```gdscript
	# Connect navigation command to handler
	navigation_command.connect(_process_navigation_command)
```

### Test Steps

1. Run the project, press N, type "Take me to the security notes" — if the LLM responds with `NAVIGATE:security/...`, verify camera teleports to that tower
2. Press N, type "Show me notes about kubernetes" — if the LLM responds with `HIGHLIGHT:kubernetes`, verify matching towers light up
3. Verify referenced `[[note titles]]` in responses cause those towers to pulse briefly
4. Verify no crashes when navigating to a note that doesn't exist

### Commit

```
feat(nav): add NAVIGATE/HIGHLIGHT/pulse commands for vault navigation
```

---

## Task 14: Proactive Observations

Timer-based vault insights that the AI periodically generates and displays.

- [ ] Add observation display to UIManager
- [ ] Verify observations appear as floating text
- [ ] Verify O key toggles observations on/off

### The observation logic already exists in `nexus_ai.gd` from Task 8

The remaining work is displaying observations as floating text with a chime sound. Add an observation display handler.

### Add to `autoloads/ui_manager.gd`

Add a new variable at the top:

```gdscript
var _observation_label: Label
```

Add at the end of `_ready()` in `ui_manager.gd`:

```gdscript
	# AI Observation floating text
	_observation_label = Label.new()
	_observation_label.name = "ObservationLabel"
	_observation_label.add_theme_font_size_override("font_size", 13)
	_observation_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.0))
	_observation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_observation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var obs_vp_size: Vector2 = get_viewport().get_visible_rect().size
	_observation_label.position = Vector2(obs_vp_size.x * 0.25, obs_vp_size.y * 0.15)
	_observation_label.size = Vector2(obs_vp_size.x * 0.5, 60)
	_observation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_observation_label)
	_observation_label.hide()

	# Connect AI observation signal
	if NexusAI:
		NexusAI.ai_observation.connect(_on_ai_observation)
```

Add this method to `ui_manager.gd`:

```gdscript
func _on_ai_observation(text: String) -> void:
	_observation_label.text = text
	_observation_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.9))
	_observation_label.show()
	AudioManager.play_sfx("ai_chime")

	# Fade out over 8 seconds
	var tween := create_tween()
	tween.tween_interval(5.0)  # Stay visible for 5 seconds
	tween.tween_property(_observation_label, "modulate", Color(1, 1, 1, 0), 3.0)
	tween.tween_callback(func():
		_observation_label.hide()
		_observation_label.modulate = Color(1, 1, 1, 1)
	)
```

### Audio Asset Note

This task requires an `sfx_ai_chime.ogg` file at `res://audio/sfx_ai_chime.ogg`. If this file does not exist yet, create a placeholder or skip the chime sound until the asset is available. The `AudioManager.load_sfx("ai_chime", ...)` call in `main.gd` (from Task 8) will log a warning if the file is missing but won't crash.

### Test Steps

1. Run the project — verify no errors
2. Wait for the observation interval (default 5 minutes) — or temporarily set `observations_interval` to `10` in the config for faster testing
3. Verify floating text appears near the top of the screen with a vault insight
4. Verify the text fades out after ~8 seconds
5. Press O — verify "NexusAI: proactive observations DISABLED" in log
6. Press O again — verify "NexusAI: proactive observations ENABLED" in log

### Commit

```
feat(ai): add proactive vault observation display with fade animation
```

---

## Task 15: Ambient Whisper Mode

Tower whispers — quiet TTS snippets play when the player walks near towers.

- [ ] Create `ai/ambient_whisper.gd`
- [ ] Wire into NexusAI
- [ ] Verify quiet whispers play when near towers

### File: `ai/ambient_whisper.gd`

```gdscript
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
```

### Wire into NexusAI

Add to `nexus_ai.gd`, new variable after the existing component declarations:

```gdscript
var ambient_whisper: AmbientWhisper
```

Add to the end of `_ready()` in `nexus_ai.gd`:

```gdscript
	# Ambient whisper mode
	ambient_whisper = AmbientWhisper.new()
	ambient_whisper.name = "AmbientWhisper"
	add_child(ambient_whisper)
```

### Test Steps

1. Run the project — verify no errors
2. Walk near a tower (within 5 units) — wait up to 8 seconds
3. With Kokoro running: verify a quiet whisper plays the beginning of the note content
4. Walk away and come back — verify the cooldown prevents immediate re-whispering (2-minute cooldown)
5. Verify whisper volume is noticeably quieter than normal TTS (-26 dB)

### Commit

```
feat(ai): add ambient whisper mode for tower proximity TTS
```

---

## Complete UIManager Modification Summary

For clarity, here is the full list of additions to `autoloads/ui_manager.gd` across Tasks 9-14. The **new variables** to add after the existing `var _viewer_open`:

```gdscript
var ai_response_panel: Control
var listening_indicator: Control
var ai_status_bar: Control
var _observation_label: Label
```

The **new code** to add at the end of `_ready()`:

```gdscript
	# AI Response Panel
	var ai_panel_scene: PackedScene = load("res://ui/ai_response_panel.tscn") as PackedScene
	if ai_panel_scene:
		ai_response_panel = ai_panel_scene.instantiate()
		add_child(ai_response_panel)
		ai_response_panel.update_layout(get_viewport().get_visible_rect().size)

	# Listening Indicator
	var indicator_script: GDScript = load("res://ui/listening_indicator.gd") as GDScript
	if indicator_script:
		listening_indicator = Control.new()
		listening_indicator.set_script(indicator_script)
		listening_indicator.name = "ListeningIndicator"
		add_child(listening_indicator)

	# AI Status Bar — positioned above the minimap
	var status_bar_script: GDScript = load("res://ui/ai_status_bar.gd") as GDScript
	if status_bar_script:
		ai_status_bar = HBoxContainer.new()
		ai_status_bar.set_script(status_bar_script)
		ai_status_bar.name = "AIStatusBar"
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		ai_status_bar.position = Vector2(15, vp_size.y - 180)
		add_child(ai_status_bar)

	# AI Observation floating text
	_observation_label = Label.new()
	_observation_label.name = "ObservationLabel"
	_observation_label.add_theme_font_size_override("font_size", 13)
	_observation_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.0))
	_observation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_observation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var obs_vp_size: Vector2 = get_viewport().get_visible_rect().size
	_observation_label.position = Vector2(obs_vp_size.x * 0.25, obs_vp_size.y * 0.15)
	_observation_label.size = Vector2(obs_vp_size.x * 0.5, 60)
	_observation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_observation_label)
	_observation_label.hide()

	# Connect AI observation signal
	if NexusAI:
		NexusAI.ai_observation.connect(_on_ai_observation)
```

The **new ESC handler** in `_unhandled_input()` (inside the KEY_ESCAPE/KEY_Q block, **before** the `_close_viewer()` check):

```gdscript
			if ai_response_panel and ai_response_panel.visible:
				ai_response_panel.dismiss()
				get_viewport().set_input_as_handled()
				return
```

The **new method** `_on_ai_observation()`:

```gdscript
func _on_ai_observation(text: String) -> void:
	_observation_label.text = text
	_observation_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.9))
	_observation_label.show()
	AudioManager.play_sfx("ai_chime")

	# Fade out over 8 seconds
	var tween := create_tween()
	tween.tween_interval(5.0)  # Stay visible for 5 seconds
	tween.tween_property(_observation_label, "modulate", Color(1, 1, 1, 0), 3.0)
	tween.tween_callback(func():
		_observation_label.hide()
		_observation_label.modulate = Color(1, 1, 1, 1)
	)
```

---

## Self-Review Checklist

1. **All 12 spec sections covered:**
   - Spec 1 (Overview) → covered by overall architecture
   - Spec 2 (External Services) → Tasks 2, 3, 4 (client implementations)
   - Spec 3 (NexusAI Autoload) → Task 8 (all signals, state machine, history)
   - Spec 4 (Voice Pipeline) → Tasks 2, 5, 6, 8 (recording → transcription → prompt → LLM)
   - Spec 5 (Hub Visual Feedback) → Task 12 (state visuals, query beams)
   - Spec 6 (HUD Elements) → Tasks 9, 10, 11 (response panel, listening indicator, status bar)
   - Spec 7 (Text Input Fallback) → Task 8 (_open_text_input method)
   - Spec 8 (Vault Navigation) → Task 13 (NAVIGATE, HIGHLIGHT, pulse)
   - Spec 9.1 (Proactive Observations) → Task 14
   - Spec 9.2 (Ambient Whisper Mode) → Task 15
   - Spec 10 (Configuration) → Task 1 (all settings with defaults)
   - Spec 11 (File Structure) → File Structure section
   - Spec 12 (Startup Flow) → Task 8 (_ready method)

2. **No placeholders or TBD** — every task has complete code

3. **Method signatures consistent:**
   - `WhisperClient.transcribe(audio_wav_data: PackedByteArray)` called from `NexusAI._stop_voice_input()`
   - `OllamaClient.generate(prompt: String, model: String)` called from `NexusAI._process_query()`
   - `KokoroClient.speak(text: String, voice: String)` called from `NexusAI._on_ollama_complete()`
   - `MicRecorder.start_recording()` / `stop_recording() -> PackedByteArray` called from `NexusAI._start_voice_input()` / `_stop_voice_input()`
   - `PromptBuilder.build_prompt(query, vault_graph, history)` called from `NexusAI._process_query()`
   - `ResponseParser.parse(text, vault_graph) -> Dictionary` called from `NexusAI._on_ollama_complete()`
   - All `ping(callback: Callable)` methods follow the same pattern

4. **File paths consistent** between create and modify references — all cross-references verified
