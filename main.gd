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
	# DEBUG: absolute minimum test — does Godot render ANYTHING after vault load?
	var cube := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2, 2, 2)
	cube.mesh = box
	cube.position = Vector3(0, 0, -5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0, 0)
	cube.set_surface_override_material(0, mat)
	add_child(cube)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 0)
	cam.current = true
	add_child(cam)

	var light := OmniLight3D.new()
	light.light_energy = 5.0
	light.omni_range = 20.0
	light.position = Vector3(0, 3, 0)
	add_child(light)

	print("DEBUG: bare test — red cube at (0,0,-5), camera at origin")
