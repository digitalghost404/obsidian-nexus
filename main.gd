# main.gd
extends Node3D

func _ready() -> void:
	print("Obsidian Nexus — entering vault")
	LayerManager.load_city()

	# Start ambient music
	AudioManager.play_music("res://audio/ambient_loop.ogg")

	# Load interaction SFX
	AudioManager.load_sfx("hover", "res://audio/sfx_hover.ogg")
	AudioManager.load_sfx("click", "res://audio/sfx_click.ogg")
	AudioManager.load_sfx("close", "res://audio/sfx_close.ogg")
	AudioManager.load_sfx("search", "res://audio/sfx_search.ogg")
	AudioManager.load_sfx("hub_activate", "res://audio/sfx_hub.ogg")
	AudioManager.set_sfx_volume("hover", -15.0)
	AudioManager.set_sfx_volume("click", -8.0)
	AudioManager.set_sfx_volume("close", -10.0)
	AudioManager.set_sfx_volume("search", -8.0)
	AudioManager.set_sfx_volume("hub_activate", -5.0)
