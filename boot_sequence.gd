extends Control

## Terminal boot sequence — plays before loading the vault

var _lines: Array[String] = []
var _current_line: int = 0
var _current_char: int = 0
var _char_timer: float = 0.0
var _line_delay_timer: float = 0.0
var _phase: String = "typing"  # typing, line_delay, loading, done
var _displayed_text: String = ""
var _vault_loaded: bool = false

const CHAR_SPEED := 0.02  # seconds per character
const LINE_DELAY := 0.3   # delay between lines
const FAST_CHAR_SPEED := 0.005  # faster for long lines

@onready var terminal: RichTextLabel = $Terminal
@onready var cursor: Label = $Cursor
@onready var fade_rect: ColorRect = $FadeRect

func _ready() -> void:
	# Hide mouse
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Set up the boot text
	_lines = [
		"[color=#1a5fb4]████████████████████████████████████████████[/color]",
		"",
		"[color=#3584e4]  NEXUS DIGITAL VAULT SYSTEM v2.0[/color]",
		"[color=#1a5fb4]  ── Obsidian Knowledge Architecture ──[/color]",
		"",
		"[color=#1a5fb4]████████████████████████████████████████████[/color]",
		"",
		"[color=#888888]> Initializing Vulkan renderer...[/color]         [color=#26a269]OK[/color]",
		"[color=#888888]> Loading shader pipeline...[/color]              [color=#26a269]OK[/color]",
		"[color=#888888]> Establishing vault connection...[/color]        [color=#26a269]OK[/color]",
		"",
		"[color=#3584e4]> Scanning vault directory...[/color]",
		"  [color=#888888]Path: /home/digitalghost/obsidian-vault/dtg-vault[/color]",
		"",
		"__VAULT_STATS__",  # placeholder — replaced with real data
		"",
		"[color=#888888]> Building spatial index...[/color]               [color=#26a269]OK[/color]",
		"[color=#888888]> Generating city layout...[/color]               [color=#26a269]OK[/color]",
		"[color=#888888]> Compiling shaders...[/color]                    [color=#26a269]OK[/color]",
		"[color=#888888]> Initializing particle systems...[/color]        [color=#26a269]OK[/color]",
		"[color=#888888]> Activating Nexus Hub...[/color]                 [color=#26a269]OK[/color]",
		"",
		"[color=#e5a50a]> ALL SYSTEMS NOMINAL[/color]",
		"",
		"[color=#3584e4]> Entering digital vault...[/color]",
	]

	terminal.bbcode_enabled = true
	terminal.text = ""
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.visible = false

	# Start vault loading in background immediately
	VaultDataBus.vault_loaded.connect(_on_vault_loaded)
	var vault_path := OS.get_environment("OBSIDIAN_VAULT_PATH")
	if vault_path.is_empty():
		var config_path := "user://vault_config.txt"
		if FileAccess.file_exists(config_path):
			vault_path = FileAccess.get_file_as_string(config_path).strip_edges()
	if not vault_path.is_empty():
		VaultDataBus.initialize(vault_path)

	# Load boot SFX
	AudioManager.load_sfx("boot_key", "res://audio/sfx_boot_key.ogg")
	AudioManager.load_sfx("boot_ok", "res://audio/sfx_boot_ok.ogg")
	AudioManager.load_sfx("boot_chime", "res://audio/sfx_boot_chime.ogg")
	AudioManager.set_sfx_volume("boot_key", -12.0)
	AudioManager.set_sfx_volume("boot_ok", -8.0)
	AudioManager.set_sfx_volume("boot_chime", -3.0)

func _on_vault_loaded() -> void:
	_vault_loaded = true
	# Replace the stats placeholder
	for i in range(_lines.size()):
		if _lines[i] == "__VAULT_STATS__":
			_lines[i] = "  [color=#e5a50a]%d[/color] [color=#888888]notes detected[/color]  |  [color=#e5a50a]%d[/color] [color=#888888]links mapped[/color]  |  [color=#e5a50a]%d[/color] [color=#888888]tags indexed[/color]" % [
				VaultDataBus.graph.get_note_count(),
				VaultDataBus.graph.get_link_count(),
				VaultDataBus.graph.get_all_tags().size()
			]

func _process(delta: float) -> void:
	# Blinking cursor
	if cursor:
		cursor.visible = fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.6

	match _phase:
		"typing":
			_process_typing(delta)
		"line_delay":
			_line_delay_timer -= delta
			if _line_delay_timer <= 0:
				_current_line += 1
				_current_char = 0
				if _current_line >= _lines.size():
					_phase = "loading"
				else:
					_phase = "typing"
		"loading":
			# Wait for vault to finish loading, then fade out
			if _vault_loaded:
				_phase = "done"
				_start_fade()
		"done":
			pass

func _process_typing(delta: float) -> void:
	if _current_line >= _lines.size():
		_phase = "loading"
		return

	var line: String = _lines[_current_line]

	# Skip placeholder lines
	if line == "__VAULT_STATS__" and not _vault_loaded:
		line = "  [color=#888888]Scanning...[/color]"

	# Determine typing speed (fast for decorative lines)
	var speed := CHAR_SPEED
	if line.begins_with("[color=#1a5fb4]██") or line.is_empty():
		speed = FAST_CHAR_SPEED

	_char_timer += delta
	if _char_timer >= speed:
		_char_timer = 0.0
		_current_char += 1
		# Typing click — play every 3rd character to not be annoying
		if _current_char % 3 == 0:
			AudioManager.play_sfx("boot_key")

		# Strip BBCode for length calculation but display with BBCode
		var plain_length := _get_plain_length(line)
		if _current_char >= plain_length:
			# Line complete — add it
			_displayed_text += line + "\n"
			terminal.text = _displayed_text
			_phase = "line_delay"
			_line_delay_timer = LINE_DELAY
			# Faster delay for empty/decorative lines
			if line.is_empty() or line.begins_with("[color=#1a5fb4]██"):
				_line_delay_timer = 0.05
			# Play sound effects based on line content
			elif "OK" in line:
				AudioManager.play_sfx("boot_ok")
			elif "ALL SYSTEMS NOMINAL" in line:
				AudioManager.play_sfx("boot_chime")
			elif "Entering" in line:
				AudioManager.play_sfx("boot_chime")

	# Update cursor position
	if cursor:
		cursor.position.y = 20 + _current_line * 22

func _get_plain_length(bbcode_text: String) -> int:
	# Rough estimate — strip bbcode tags
	var regex := RegEx.new()
	regex.compile("\\[.*?\\]")
	var plain := regex.sub(bbcode_text, "", true)
	return plain.length()

func _start_fade() -> void:
	fade_rect.visible = true
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 1.5)
	tween.tween_callback(_load_main_scene)

func _load_main_scene() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file("res://main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	# Press any key to skip
	if event is InputEventKey and event.pressed:
		if _vault_loaded:
			_phase = "done"
			_start_fade()
