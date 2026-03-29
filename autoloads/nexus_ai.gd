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

	# Connect navigation command to handler
	navigation_command.connect(_process_navigation_command)

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

# ─── Navigation Commands ─────────────────────────────────────────

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
