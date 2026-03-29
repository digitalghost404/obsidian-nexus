# main.gd
extends Node3D

func _ready() -> void:
	print("Obsidian Nexus — entering vault")
	# Vault is already loaded by boot_sequence.gd
	# Just load the city
	LayerManager.load_city()
