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
	# Clear existing corridor geometry
	for child in get_children():
		child.queue_free()

	var note = VaultDataBus.graph.get_note(note_id)
	if not note:
		return

	var backlinks: Array = VaultDataBus.graph.get_backlinks(note_id)
	var layout := _hallway_gen.compute_layout({
		"id": note.id,
		"title": note.title,
		"content": note.content,
		"outgoing_links": note.outgoing_links,
		"backlinks": backlinks,
		"tags": note.tags,
		"word_count": note.word_count,
	})

	print("Corridor: building for '%s' — %d segments, %d panels, %d doorways" % [
		note.title, layout["segments"].size(), layout["wall_panels"].size(), layout["doorways"].size()
	])
	print("Corridor: total_length=%.1f, first segment z=%.1f" % [layout["total_length"], layout["segments"][0]["position_z"]])

	# DEBUG: skip all panels/doorways — just geometry + debug objects
	# _build_hallway_geometry(layout)

	# Just a bright cube and light — absolute minimum
	var debug_cube := MeshInstance3D.new()
	var debug_mesh := BoxMesh.new()
	debug_mesh.size = Vector3(1, 1, 1)
	debug_cube.mesh = debug_mesh
	debug_cube.position = Vector3(0, 1.5, 4)
	var debug_mat := StandardMaterial3D.new()
	debug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_mat.albedo_color = Color(1, 0, 0)
	debug_cube.set_surface_override_material(0, debug_mat)
	add_child(debug_cube)

	var debug_light := OmniLight3D.new()
	debug_light.light_color = Color(1, 1, 1)
	debug_light.light_energy = 10.0
	debug_light.omni_range = 30.0
	debug_light.position = Vector3(0, 3, 4)
	add_child(debug_light)

	print("Corridor: MINIMAL DEBUG — just red cube at (0,1.5,4) + light, children=%d" % get_child_count())

func _build_hallway_geometry(layout: Dictionary) -> void:
	for seg in layout["segments"]:
		var z: float = seg["position_z"]
		var w: float = seg["width"]
		var h: float = seg["height"]
		var l: float = seg["length"]

		# Floor with collision
		var floor_body := StaticBody3D.new()
		floor_body.position = Vector3(0, 0, z + l / 2.0)
		var floor_mesh := MeshInstance3D.new()
		var floor_plane := PlaneMesh.new()
		floor_plane.size = Vector2(w, l)
		floor_mesh.mesh = floor_plane
		var floor_mat := StandardMaterial3D.new()
		floor_mat.albedo_color = Color(0.03, 0.04, 0.08)
		floor_mat.metallic = 0.9
		floor_mat.roughness = 0.1
		floor_mesh.set_surface_override_material(0, floor_mat)
		floor_body.add_child(floor_mesh)
		var floor_col := CollisionShape3D.new()
		var floor_shape := BoxShape3D.new()
		floor_shape.size = Vector3(w, 0.1, l)
		floor_col.shape = floor_shape
		floor_col.position = Vector3(0, -0.05, 0)
		floor_body.add_child(floor_col)
		add_child(floor_body)

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

	# Ceiling lights along the corridor — every 6 meters
	var total_len: float = layout["total_length"]
	var hall_height: float = layout["segments"][0]["height"]
	var num_lights: int = maxi(ceili(total_len / 6.0), 2)
	for i in range(num_lights):
		var z_pos: float = (i + 0.5) * (total_len / float(num_lights))
		var light := OmniLight3D.new()
		light.light_color = Color(0.95, 0.6, 0.2)
		light.light_energy = 1.5
		light.omni_range = 8.0
		light.omni_attenuation = 1.5
		light.position = Vector3(0, hall_height - 0.3, z_pos)
		add_child(light)

	# Floor accent lights — dim blue at base of walls
	for i in range(maxi(ceili(total_len / 10.0), 1)):
		var z_pos: float = (i + 0.5) * (total_len / float(maxi(ceili(total_len / 10.0), 1)))
		var left_light := OmniLight3D.new()
		left_light.light_color = Color(0.1, 0.2, 0.8)
		left_light.light_energy = 0.6
		left_light.omni_range = 4.0
		left_light.position = Vector3(-1.5, 0.3, z_pos)
		add_child(left_light)
		var right_light := OmniLight3D.new()
		right_light.light_color = Color(0.1, 0.2, 0.8)
		right_light.light_energy = 0.6
		right_light.omni_range = 4.0
		right_light.position = Vector3(1.5, 0.3, z_pos)
		add_child(right_light)

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
