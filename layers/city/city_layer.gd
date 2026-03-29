extends Node3D

var _tower_positions: Dictionary = {}
var _tower_map: Dictionary = {}

func _ready() -> void:
	_build_city()

func _build_city() -> void:
	var graph = VaultDataBus.graph

	var folder_sizes: Dictionary = {}
	for folder in graph.get_all_folders():
		folder_sizes[folder] = graph.get_notes_by_folder(folder).size()
	var root_notes: Array = graph.get_notes_by_folder("")
	if root_notes.size() > 0:
		folder_sizes["_root"] = root_notes.size()

	var district_gen := DistrictGenerator.new()
	var city_size := Vector2(120.0, 120.0)  # Much denser
	var districts := district_gen.generate(folder_sizes, city_size)

	# Ground plane with grid shader and collision
	var ground := StaticBody3D.new()
	ground.position = Vector3(city_size.x / 2.0, 0, city_size.y / 2.0)

	# Visual ground with grid shader
	var ground_visual := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = city_size * 2.0  # Extend beyond city bounds
	ground_visual.mesh = ground_mesh
	var grid_shader = load("res://shaders/ground_grid.gdshader")
	if grid_shader:
		var grid_mat := ShaderMaterial.new()
		grid_mat.shader = grid_shader
		grid_mat.set_shader_parameter("grid_color", Color(0.12, 0.2, 0.7, 0.35))
		grid_mat.set_shader_parameter("grid_spacing", 3.0)
		grid_mat.set_shader_parameter("line_width", 0.03)
		ground_visual.set_surface_override_material(0, grid_mat)
	else:
		var ground_mat := StandardMaterial3D.new()
		ground_mat.albedo_color = Color(0.02, 0.03, 0.06)
		ground_mat.metallic = 0.8
		ground_mat.roughness = 0.2
		ground_visual.set_surface_override_material(0, ground_mat)
	ground.add_child(ground_visual)

	# Solid dark floor underneath the grid (so grid is an overlay)
	var floor_solid := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = city_size * 2.0
	floor_solid.mesh = floor_mesh
	floor_solid.position = Vector3(0, -0.01, 0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.01, 0.015, 0.03)
	floor_mat.metallic = 0.9
	floor_mat.roughness = 0.15
	floor_solid.set_surface_override_material(0, floor_mat)
	ground.add_child(floor_solid)

	var ground_col := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(city_size.x * 2.0, 0.1, city_size.y * 2.0)
	ground_col.shape = ground_shape
	ground_col.position = Vector3(0, -0.05, 0)
	ground.add_child(ground_col)
	add_child(ground)

	# Build districts
	for district in districts:
		var folder: String = district["folder"]
		var rect: Rect2 = district["rect"]
		var actual_folder := "" if folder == "_root" else folder
		var notes: Array = graph.get_notes_by_folder(actual_folder)

		# District boundary line (subtle floor marking instead of floating label)
		var sign_label := Label3D.new()
		sign_label.text = folder.get_file() if "/" in folder else folder
		sign_label.position = Vector3(rect.position.x + rect.size.x / 2.0, 0.1, rect.position.y + 0.5)
		sign_label.font_size = 20
		sign_label.modulate = Color(0.4, 0.3, 0.85, 0.5)
		sign_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sign_label.rotation.x = -PI / 2.0  # Flat on ground
		add_child(sign_label)

		# Pack towers tightly in grid — narrow streets
		var cols := ceili(sqrt(notes.size()))
		if cols == 0:
			continue
		# Tight spacing — towers close together
		var spacing_x := rect.size.x / maxf(cols, 1)
		var spacing_z := rect.size.y / maxf(ceili(float(notes.size()) / cols), 1)

		for i in range(notes.size()):
			var note = notes[i]
			var col := i % cols
			var row := i / cols
			var pos_2d := Vector2(
				rect.position.x + col * spacing_x + spacing_x / 2.0,
				rect.position.y + row * spacing_z + spacing_z / 2.0
			)
			var connections: int = graph.get_connection_count(note.id)
			var tower := TowerBuilder.build_tower(note, connections, pos_2d)
			add_child(tower)
			_tower_map[note.id] = tower

			var height := clampf(note.word_count / 150.0, 2.0, 25.0)
			_tower_positions[note.id] = Vector3(pos_2d.x, height, pos_2d.y)

	# Ambient particles — floating data motes
	var motes_scene = load("res://particles/ambient_motes.tscn")
	if motes_scene:
		var motes = motes_scene.instantiate()
		motes.position = Vector3(city_size.x / 2.0, 8.0, city_size.y / 2.0)
		add_child(motes)

	# Ember particles near center
	var ember_scene = load("res://particles/ember_rise.tscn")
	if ember_scene:
		var embers = ember_scene.instantiate()
		embers.position = Vector3(city_size.x / 2.0, 0.5, city_size.y / 2.0)
		add_child(embers)

	# Build link beams
	var beam_renderer_script = load("res://layers/city/city_beam_renderer.gd")
	var beam_renderer := Node3D.new()
	beam_renderer.set_script(beam_renderer_script)
	beam_renderer.name = "Beams"
	add_child(beam_renderer)
	await get_tree().process_frame
	beam_renderer.build_beams(_tower_positions, graph)

func highlight_notes(note_ids: Array) -> void:
	for note_id in _tower_map:
		var tower: Node3D = _tower_map[note_id]
		for child in tower.get_children():
			if child is MeshInstance3D:
				var mat = child.get_surface_override_material(0)
				if mat is StandardMaterial3D:
					mat = mat.duplicate()
					if note_id in note_ids:
						mat.emission_energy_multiplier = 12.0
					else:
						mat.emission_energy_multiplier = 0.1
					child.set_surface_override_material(0, mat)
				break

func clear_highlights() -> void:
	for note_id in _tower_map:
		var tower: Node3D = _tower_map[note_id]
		var conns: int = tower.get_meta("connection_count", 0)
		var temp := clampf(conns / 20.0, 0.0, 1.0)
		for child in tower.get_children():
			if child is MeshInstance3D:
				var mat = child.get_surface_override_material(0)
				if mat is StandardMaterial3D:
					mat = mat.duplicate()
					mat.emission_energy_multiplier = 2.0 + temp * 6.0
					child.set_surface_override_material(0, mat)
				break
