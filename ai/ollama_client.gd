extends Node
class_name OllamaClient

## HTTP client for Ollama LLM — uses HTTPRequest (non-streaming)
## Simpler and more reliable than raw HTTPClient streaming

signal chunk_received(text: String)
signal generation_complete(full_text: String)
signal generation_error(message: String)

var _http_request: HTTPRequest
var _ping_request: HTTPRequest
var _is_generating: bool = false

func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.name = "OllamaHTTP"
	_http_request.timeout = 60.0
	_http_request.request_completed.connect(_on_response)
	add_child(_http_request)

	_ping_request = HTTPRequest.new()
	_ping_request.name = "OllamaPing"
	_ping_request.timeout = 5.0
	add_child(_ping_request)

func generate(prompt: String, model: String) -> void:
	if _is_generating:
		generation_error.emit("Ollama client is busy")
		return

	_is_generating = true

	var url: String = NexusAIConfig.get_setting("ollama_url") + "/api/generate"
	# Force IPv4
	url = url.replace("localhost", "127.0.0.1")

	var body_dict: Dictionary = {
		"model": model,
		"prompt": prompt,
		"stream": false,  # Get complete response at once — simpler and reliable
	}
	var body_json: String = JSON.stringify(body_dict)
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
	])

	print("OllamaClient: sending to %s (model=%s, prompt=%d chars)" % [url, model, prompt.length()])
	var err: int = _http_request.request(url, headers, HTTPClient.METHOD_POST, body_json)
	if err != OK:
		_is_generating = false
		generation_error.emit("Failed to send request to Ollama: error %d" % err)

func _on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_generating = false

	if result != HTTPRequest.RESULT_SUCCESS:
		generation_error.emit("Ollama HTTP request failed with result %d" % result)
		return

	if response_code != 200:
		var error_text: String = body.get_string_from_utf8().substr(0, 200)
		generation_error.emit("Ollama returned HTTP %d: %s" % [response_code, error_text])
		return

	var response_text: String = body.get_string_from_utf8()
	var json := JSON.new()
	var parse_err: int = json.parse(response_text)
	if parse_err != OK:
		generation_error.emit("Failed to parse Ollama response JSON")
		return

	var data: Dictionary = json.data
	var full_response: String = data.get("response", "")

	if full_response.is_empty():
		generation_error.emit("Ollama returned empty response")
		return

	print("OllamaClient: generation complete (%d chars)" % full_response.length())
	# Emit the full response as one chunk for the UI to display
	chunk_received.emit(full_response)
	generation_complete.emit(full_response)

func cancel() -> void:
	if _is_generating:
		_http_request.cancel_request()
		_is_generating = false
		generation_complete.emit("")

func ping(callback: Callable) -> void:
	var base_url: String = NexusAIConfig.get_setting("ollama_url")
	var url: String = base_url.replace("localhost", "127.0.0.1") + "/api/tags"

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
