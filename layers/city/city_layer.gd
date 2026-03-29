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
	var root_notes := graph.get_notes_by_folder("")
	if root_notes.size() > 0:
		folder_sizes["_root"] = root_notes.size()

	var district_gen := DistrictGenerator.new()
	var city_size := Vector2(300.0, 300.0)
	var districts := district_gen.generate(folder_sizes, city_size)

	# Ground plane
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = city_size
	ground.mesh = ground_mesh
	ground.position = Vector3(city_size.x / 2.0, 0, city_size.y / 2.0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.02, 0.03, 0.06)
	ground_mat.metallic = 0.8
	ground_mat.roughness = 0.2
	ground.set_surface_override_material(0, ground_mat)
	add_child(ground)

	# Build districts
	for district in districts:
		var folder: String = district["folder"]
		var rect: Rect2 = district["rect"]
		var actual_folder := "" if folder == "_root" else folder
		var notes := graph.get_notes_by_folder(actual_folder)

		# District name sign
		var sign_label := Label3D.new()
		sign_label.text = folder.get_file() if "/" in folder else folder
		sign_label.position = Vector3(rect.position.x + rect.size.x / 2.0, 0.5, rect.position.y)
		sign_label.font_size = 48
		sign_label.modulate = Color(0.5, 0.3, 0.93, 0.8)
		sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(sign_label)

		# Place towers in grid
		var cols := ceili(sqrt(notes.size()))
		if cols == 0:
			continue
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
			var connections := graph.get_connection_count(note.id)
			var tower := TowerBuilder.build_tower(note, connections, pos_2d)
			add_child(tower)
			_tower_map[note.id] = tower

			var height := clampf(note.word_count / 200.0, 1.0, 30.0)
			_tower_positions[note.id] = Vector3(pos_2d.x, height, pos_2d.y)

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
		# Find the main MeshInstance3D (first child)
		for child in tower.get_children():
			if child is MeshInstance3D:
				var mat = child.get_surface_override_material(0)
				if mat is StandardMaterial3D:
					mat = mat.duplicate()
					if note_id in note_ids:
						mat.emission_energy_multiplier = 8.0
					else:
						mat.emission_energy_multiplier = 0.1
					child.set_surface_override_material(0, mat)
				break

func clear_highlights() -> void:
	for note_id in _tower_map:
		var tower: Node3D = _tower_map[note_id]
		var conns: int = tower.get_meta("connection_count", 0)
		var temp := clampf(conns / 25.0, 0.0, 1.0)
		for child in tower.get_children():
			if child is MeshInstance3D:
				var mat = child.get_surface_override_material(0)
				if mat is StandardMaterial3D:
					mat = mat.duplicate()
					mat.emission_energy_multiplier = 0.5 + temp * 3.0
					child.set_surface_override_material(0, mat)
				break
