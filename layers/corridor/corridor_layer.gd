extends Node3D

const WallPanelScene = preload("res://layers/corridor/wall_panel.tscn")
const DoorwayScene = preload("res://layers/corridor/doorway.tscn")

var current_note_id: String = ""
var _hallway_gen := HallwayGenerator.new()

func _ready() -> void:
	if not current_note_id.is_empty():
		build_corridor(current_note_id)

func build_corridor(note_id: String) -> void:
	current_note_id = note_id
	# Clear existing corridor geometry (keep environment nodes)
	for child in get_children():
		if child is WorldEnvironment or child is DirectionalLight3D:
			continue
		child.queue_free()

	var note = VaultDataBus.graph.get_note(note_id)
	if not note:
		return

	var backlinks := VaultDataBus.graph.get_backlinks(note_id)
	var layout := _hallway_gen.compute_layout({
		"id": note.id,
		"title": note.title,
		"content": note.content,
		"outgoing_links": note.outgoing_links,
		"backlinks": backlinks,
		"tags": note.tags,
		"word_count": note.word_count,
	})

	_build_hallway_geometry(layout)

	# Place wall panels
	for panel_data in layout["wall_panels"]:
		var panel = WallPanelScene.instantiate()
		panel.setup(panel_data["text"], panel_data["side"], panel_data["position_z"])
		add_child(panel)

	# Place outgoing doorways
	for doorway_data in layout["doorways"]:
		var doorway = DoorwayScene.instantiate()
		var target_note = VaultDataBus.graph.get_note(doorway_data["target"])
		var title := target_note.title if target_note else doorway_data["target"]
		doorway.setup(doorway_data["target"], title, true)
		doorway.position = Vector3(doorway_data["position_x"], 0, doorway_data["position_z"])
		add_child(doorway)

	# Place sealed doors (backlinks)
	for door_data in layout["sealed_doors"]:
		var doorway = DoorwayScene.instantiate()
		var source_note = VaultDataBus.graph.get_note(door_data["source"])
		var title := source_note.title if source_note else door_data["source"]
		doorway.setup(door_data["source"], title, false)
		doorway.position = Vector3(door_data["position_x"], 0, door_data["position_z"])
		doorway.rotation.y = PI
		add_child(doorway)

	_connect_doorway_signals()

func _build_hallway_geometry(layout: Dictionary) -> void:
	for seg in layout["segments"]:
		var z: float = seg["position_z"]
		var w: float = seg["width"]
		var h: float = seg["height"]
		var l: float = seg["length"]

		# Floor
		var floor_mesh := MeshInstance3D.new()
		var floor_plane := PlaneMesh.new()
		floor_plane.size = Vector2(w, l)
		floor_mesh.mesh = floor_plane
		floor_mesh.position = Vector3(0, 0, z + l / 2.0)
		var floor_mat := StandardMaterial3D.new()
		floor_mat.albedo_color = Color(0.03, 0.04, 0.08)
		floor_mat.metallic = 0.9
		floor_mat.roughness = 0.1
		floor_mesh.set_surface_override_material(0, floor_mat)
		add_child(floor_mesh)

		# Ceiling
		var ceil_mesh := MeshInstance3D.new()
		ceil_mesh.mesh = floor_plane.duplicate()
		ceil_mesh.position = Vector3(0, h, z + l / 2.0)
		ceil_mesh.rotation.x = PI
		var ceil_mat := StandardMaterial3D.new()
		ceil_mat.albedo_color = Color(0.02, 0.02, 0.05)
		ceil_mesh.set_surface_override_material(0, ceil_mat)
		add_child(ceil_mesh)

		# Left wall with code rain
		var left_wall := MeshInstance3D.new()
		var wall_plane := PlaneMesh.new()
		wall_plane.size = Vector2(l, h)
		left_wall.mesh = wall_plane
		left_wall.position = Vector3(-w / 2.0, h / 2.0, z + l / 2.0)
		left_wall.rotation.y = PI / 2.0
		var rain_shader = load("res://shaders/code_rain.gdshader")
		var wall_mat := ShaderMaterial.new()
		wall_mat.shader = rain_shader
		wall_mat.set_shader_parameter("rain_color", Color(0.1, 0.8, 0.3, 0.15))
		wall_mat.set_shader_parameter("columns", 25.0)
		left_wall.set_surface_override_material(0, wall_mat)
		add_child(left_wall)

		# Right wall with code rain
		var right_wall := MeshInstance3D.new()
		right_wall.mesh = wall_plane.duplicate()
		right_wall.position = Vector3(w / 2.0, h / 2.0, z + l / 2.0)
		right_wall.rotation.y = -PI / 2.0
		var right_mat := wall_mat.duplicate()
		right_wall.set_surface_override_material(0, right_mat)
		add_child(right_wall)

	# Ambient light strip
	var light := OmniLight3D.new()
	light.light_color = Color(0.95, 0.6, 0.2)
	light.light_energy = 2.0
	light.omni_range = 15.0
	light.position = Vector3(0, layout["segments"][0]["height"] - 0.3, layout["total_length"] / 2.0)
	add_child(light)

func _connect_doorway_signals() -> void:
	for child in get_children():
		if child.has_meta("note_id") and child.has_meta("is_outgoing"):
			if child.get_meta("is_outgoing"):
				for subchild in child.get_children():
					if subchild is Area3D:
						subchild.body_entered.connect(func(_body):
							_on_doorway_entered(child.get_meta("note_id"))
						)

func _on_doorway_entered(target_note_id: String) -> void:
	build_corridor(target_note_id)
	# Reset player position
	var cam = get_viewport().get_camera_3d()
	if cam and cam.get_parent() is CharacterBody3D:
		cam.get_parent().global_position = Vector3(0, 1, 2)
