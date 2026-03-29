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
