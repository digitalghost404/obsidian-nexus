# main.gd
extends Node3D

@export var vault_path: String = ""

func _ready() -> void:
	print("Obsidian Nexus — initializing")

	if vault_path.is_empty():
		vault_path = OS.get_environment("OBSIDIAN_VAULT_PATH")
		if vault_path.is_empty():
			var config_path := "user://vault_config.txt"
			if FileAccess.file_exists(config_path):
				vault_path = FileAccess.get_file_as_string(config_path).strip_edges()

	if vault_path.is_empty():
		push_error("No vault path. Set OBSIDIAN_VAULT_PATH env var.")
		return

	VaultDataBus.vault_loaded.connect(_on_vault_loaded)
	VaultDataBus.initialize(vault_path)

func _on_vault_loaded() -> void:
	print("Vault loaded: %d notes, %d links" % [VaultDataBus.graph.get_note_count(), VaultDataBus.graph.get_link_count()])
	# DEBUG TEST: load corridor AND keep a bare camera to see if it overrides
	# Step 1: Load corridor normally
	LayerManager.load_layer(LayerManager.Layer.CORRIDOR, {"note_id": "ai-engineering/Building AI Agents"})

	# Step 2: AFTER corridor loads, force a new bare camera as current
	await get_tree().process_frame
	await get_tree().process_frame
	var test_cam := Camera3D.new()
	test_cam.position = Vector3(0, 1.5, 2)
	test_cam.rotation.y = PI  # Face +Z
	test_cam.current = true
	add_child(test_cam)
	print("DEBUG: forced test camera at (0, 1.5, 2), current=%s" % str(test_cam.current))
