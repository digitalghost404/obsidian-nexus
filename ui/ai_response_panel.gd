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
