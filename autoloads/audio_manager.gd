extends Node

## Central audio manager — handles ambient music, SFX, and UI sounds

var _music_player: AudioStreamPlayer
var _sfx_players: Dictionary = {}  # name → AudioStreamPlayer
var _ambient_hum: AudioStreamPlayer

func _ready() -> void:
	# Music player — loops background ambient
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Master"
	_music_player.volume_db = -8.0  # Subtle background
	add_child(_music_player)

	# Ambient low-frequency hum
	_ambient_hum = AudioStreamPlayer.new()
	_ambient_hum.name = "AmbientHum"
	_ambient_hum.bus = "Master"
	_ambient_hum.volume_db = -18.0
	add_child(_ambient_hum)

	# Pre-create SFX players for quick triggering
	var sfx_names := ["hover", "click", "close", "search", "hub_activate", "boot_key", "boot_ok", "boot_chime"]
	for sfx_name in sfx_names:
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%s" % sfx_name
		player.bus = "Master"
		player.volume_db = -5.0
		add_child(player)
		_sfx_players[sfx_name] = player

func play_music(path: String) -> void:
	var stream = load(path)
	if stream:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		_music_player.stream = stream
		_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func play_sfx(sfx_name: String) -> void:
	if _sfx_players.has(sfx_name):
		var player: AudioStreamPlayer = _sfx_players[sfx_name]
		if player.stream:
			player.play()

func load_sfx(sfx_name: String, path: String) -> void:
	if _sfx_players.has(sfx_name):
		var stream = load(path)
		if stream:
			_sfx_players[sfx_name].stream = stream

func set_music_volume(db: float) -> void:
	_music_player.volume_db = db

func set_sfx_volume(sfx_name: String, db: float) -> void:
	if _sfx_players.has(sfx_name):
		_sfx_players[sfx_name].volume_db = db
