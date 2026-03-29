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
