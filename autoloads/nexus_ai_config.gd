extends Node

## NexusAI configuration — loads/saves settings from user://nexus_ai_config.json

const CONFIG_PATH: String = "user://nexus_ai_config.json"

var _settings: Dictionary = {}
var _defaults: Dictionary = {
	"model": "llama3.2:3b",
	"ollama_url": "http://127.0.0.1:11434",
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
