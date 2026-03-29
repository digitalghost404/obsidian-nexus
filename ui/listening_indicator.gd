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

	# Connect to NexusAI (deferred — mic_recorder may not exist yet)
	if NexusAI:
		NexusAI.state_changed.connect(_on_state_changed)
		if NexusAI.mic_recorder:
			NexusAI.mic_recorder.recording_level.connect(_on_recording_level)
		else:
			# Connect after NexusAI finishes setup
			call_deferred("_connect_mic_recorder")

	hide()

func _connect_mic_recorder() -> void:
	if NexusAI and NexusAI.mic_recorder:
		NexusAI.mic_recorder.recording_level.connect(_on_recording_level)

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
