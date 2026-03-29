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
	var host: String = "127.0.0.1"  # Force IPv4 — localhost can try IPv6 first and fail

	# Extract host and port from URL
	var url_stripped: String = base_url.replace("http://", "").replace("https://", "")
	if ":" in url_stripped:
		var parts: PackedStringArray = url_stripped.split(":")
		var parsed_host: String = parts[0]
		port = parts[1].to_int()
		# Convert localhost to 127.0.0.1 to avoid IPv6 issues
		if parsed_host != "localhost":
			host = parsed_host
	else:
		if url_stripped != "localhost":
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
			elif not _is_generating:
				# No pending request AND not generating — stop polling
				_polling = false
			# If _is_generating, keep polling — waiting for STATUS_REQUESTING/BODY
			return

		HTTPClient.STATUS_REQUESTING:
			# Request is being sent, wait
			return

		HTTPClient.STATUS_BODY:
			if _is_generating:
				_read_streaming_response()
			else:
				_http_client.close()
				_polling = false
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
		"prompt": prompt + "\n/no_think",  # Disable thinking mode for qwen3.5
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

		# Some models (qwen3.5) emit "thinking" tokens before the response
		# We skip thinking tokens and only emit response tokens
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
