extends Node3D

var _tower_positions: Dictionary = {}
var _tower_map: Dictionary = {}

func _ready() -> void:
	_build_city()

func _build_city() -> void:
	var graph: NoteGraph = VaultDataBus.graph
	var city_size := Vector2(120.0, 120.0)

	var folder_sizes: Dictionary = {}
	var all_folders: Array = graph.get_all_folders()
	for folder in all_folders:
		var folder_notes: Array = graph.get_notes_by_folder(folder)
		folder_sizes[folder] = folder_notes.size()
	var root_notes: Array = graph.get_notes_by_folder("")
	if root_notes.size() > 0:
		folder_sizes["_root"] = root_notes.size()

	var district_gen: DistrictGenerator = DistrictGenerator.new()
	# city_size defined at top of _build_city
	var districts: Array = district_gen.generate(folder_sizes, city_size)

	# Ground plane with grid shader and collision
	var ground := StaticBody3D.new()
	ground.position = Vector3(city_size.x / 2.0, 0, city_size.y / 2.0)

	# Visual ground with grid shader
	var ground_visual := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = city_size * 2.0  # Extend beyond city bounds
	ground_visual.mesh = ground_mesh
	var grid_shader: Resource = load("res://shaders/circuit_floor.gdshader")
	if grid_shader:
		var grid_mat := ShaderMaterial.new()
		grid_mat.shader = grid_shader
		grid_mat.set_shader_parameter("tile_scale", 14.0)
		grid_mat.set_shader_parameter("emission_strength", 3.5)
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

	# Boundary walls with blue code rain
	var wall_shader = load("res://shaders/code_rain.gdshader")
	if wall_shader:
		var wall_height := 30.0
		var wall_thick := 0.3
		var w_mat := ShaderMaterial.new()
		w_mat.shader = wall_shader
		w_mat.set_shader_parameter("rain_color", Color(0.06, 0.18, 0.65, 0.6))
		w_mat.set_shader_parameter("scroll_speed", 1.2)
		w_mat.set_shader_parameter("columns", 50.0)
		w_mat.set_shader_parameter("char_rows", 60.0)
		w_mat.set_shader_parameter("brightness_variation", 0.7)
		# South wall
		var s_wall := MeshInstance3D.new()
		var s_mesh := BoxMesh.new()
		s_mesh.size = Vector3(city_size.x * 2.0, wall_height, wall_thick)
		s_wall.mesh = s_mesh
		s_wall.position = Vector3(city_size.x / 2.0, wall_height / 2.0, -15)
		s_wall.set_surface_override_material(0, w_mat)
		add_child(s_wall)
		# North wall
		var n_wall := MeshInstance3D.new()
		var n_mesh := BoxMesh.new()
		n_mesh.size = Vector3(city_size.x * 2.0, wall_height, wall_thick)
		n_wall.mesh = n_mesh
		n_wall.position = Vector3(city_size.x / 2.0, wall_height / 2.0, city_size.y + 15)
		n_wall.set_surface_override_material(0, w_mat.duplicate())
		add_child(n_wall)
		# West wall
		var w_wall := MeshInstance3D.new()
		var ww_mesh := BoxMesh.new()
		ww_mesh.size = Vector3(wall_thick, wall_height, city_size.y * 2.0)
		w_wall.mesh = ww_mesh
		w_wall.position = Vector3(-15, wall_height / 2.0, city_size.y / 2.0)
		w_wall.set_surface_override_material(0, w_mat.duplicate())
		add_child(w_wall)
		# East wall
		var e_wall := MeshInstance3D.new()
		var ew_mesh := BoxMesh.new()
		ew_mesh.size = Vector3(wall_thick, wall_height, city_size.y * 2.0)
		e_wall.mesh = ew_mesh
		e_wall.position = Vector3(city_size.x + 15, wall_height / 2.0, city_size.y / 2.0)
		e_wall.set_surface_override_material(0, w_mat.duplicate())
		add_child(e_wall)

	# Central Nexus Hub
	var hub_script: GDScript = load("res://layers/city/nexus_hub.gd") as GDScript
	var hub := Node3D.new()
	hub.set_script(hub_script)
	hub.position = Vector3(city_size.x / 2.0, 0, city_size.y / 2.0)
	hub.name = "NexusHub"
	add_child(hub)

	# Build districts
	for district in districts:
		var folder: String = district["folder"]
		var rect: Rect2 = district["rect"]
		var actual_folder: String = "" if folder == "_root" else folder
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
		var cols: int = ceili(sqrt(notes.size()))
		if cols == 0:
			continue
		# Tight spacing — towers close together
		var spacing_x: float = rect.size.x / maxf(cols, 1)
		var spacing_z: float = rect.size.y / maxf(ceili(float(notes.size()) / cols), 1)

		var hub_center := Vector2(city_size.x / 2.0, city_size.y / 2.0)
		var hub_exclusion_radius := 33.0  # Keep towers outside the ring zone

		for i in range(notes.size()):
			var note: RefCounted = notes[i]
			var col: int = i % cols
			var row: int = i / cols
			var pos_2d: Vector2 = Vector2(
				rect.position.x + col * spacing_x + spacing_x / 2.0,
				rect.position.y + row * spacing_z + spacing_z / 2.0
			)
			# Push towers out of the hub exclusion zone
			var dist_to_hub: float = pos_2d.distance_to(hub_center)
			if dist_to_hub < hub_exclusion_radius:
				var dir: Vector2 = (pos_2d - hub_center).normalized()
				if dir.length() < 0.01:
					dir = Vector2(1, 0)
				pos_2d = hub_center + dir * (hub_exclusion_radius + 2.0)
			var connections: int = graph.get_connection_count(note.id)
			var tower: Node3D = TowerBuilder.build_tower(note, connections, pos_2d)
			add_child(tower)
			_tower_map[note.id] = tower

			var height: float = clampf(note.word_count / 150.0, 2.0, 25.0)
			_tower_positions[note.id] = Vector3(pos_2d.x, height, pos_2d.y)

	# Ambient particles — floating data motes spread across the city
	var motes_scene: PackedScene = load("res://particles/ambient_motes.tscn") as PackedScene
	if motes_scene:
		var motes_positions: Array[Vector3] = [
			Vector3(city_size.x / 2.0, 8.0, city_size.y / 2.0),
			Vector3(city_size.x * 0.2, 6.0, city_size.y * 0.3),
			Vector3(city_size.x * 0.8, 10.0, city_size.y * 0.7),
			Vector3(city_size.x * 0.5, 5.0, city_size.y * 0.15),
		]
		for mpos in motes_positions:
			var motes: Node3D = motes_scene.instantiate()
			motes.position = mpos
			add_child(motes)

	# Additional ambient mote emitters spread across the city (expands total from 4 to 12)
	var extra_mote_positions: Array[Vector3] = [
		Vector3(city_size.x * 0.1, 7.0, city_size.y * 0.6),
		Vector3(city_size.x * 0.3, 9.0, city_size.y * 0.85),
		Vector3(city_size.x * 0.6, 6.0, city_size.y * 0.1),
		Vector3(city_size.x * 0.75, 8.0, city_size.y * 0.45),
		Vector3(city_size.x * 0.9, 5.0, city_size.y * 0.8),
		Vector3(city_size.x * 0.15, 11.0, city_size.y * 0.4),
		Vector3(city_size.x * 0.45, 7.0, city_size.y * 0.65),
		Vector3(city_size.x * 0.65, 9.5, city_size.y * 0.25),
	]
	if motes_scene:
		for mpos in extra_mote_positions:
			var motes: Node3D = motes_scene.instantiate()
			motes.position = mpos
			add_child(motes)

	# Dense ground-level data particles — everywhere in the streets
	for gx in range(4):
		for gz in range(4):
			var ground_particles := GPUParticles3D.new()
			ground_particles.amount = 80
			ground_particles.lifetime = 6.0
			ground_particles.position = Vector3(
				city_size.x * 0.1 + city_size.x * 0.2 * float(gx),
				1.5,
				city_size.y * 0.1 + city_size.y * 0.2 * float(gz)
			)
			var gp_mat := ParticleProcessMaterial.new()
			gp_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			gp_mat.emission_box_extents = Vector3(12, 2, 12)
			gp_mat.direction = Vector3(0, 0.1, 0)
			gp_mat.spread = 180.0
			gp_mat.initial_velocity_min = 0.05
			gp_mat.initial_velocity_max = 0.3
			gp_mat.gravity = Vector3(0, 0, 0)
			gp_mat.scale_min = 0.01
			gp_mat.scale_max = 0.04
			gp_mat.color = Color(0.1, 0.2, 0.7, 0.4)
			ground_particles.process_material = gp_mat
			var gp_draw := SphereMesh.new()
			gp_draw.radius = 0.02
			gp_draw.height = 0.04
			ground_particles.draw_pass_1 = gp_draw
			add_child(ground_particles)

	# Ember particles near center
	var ember_scene: PackedScene = load("res://particles/ember_rise.tscn") as PackedScene
	if ember_scene:
		var embers: Node3D = ember_scene.instantiate()
		embers.position = Vector3(city_size.x / 2.0, 0.5, city_size.y / 2.0)
		add_child(embers)

	# Atmospheric point lights at street intersections
	var atmo_colors: Array[Color] = [
		Color(0.15, 0.1, 0.6, 1.0),   # deep blue
		Color(0.6, 0.1, 0.5, 1.0),    # magenta
		Color(0.08, 0.35, 0.65, 1.0), # cyan-blue
		Color(0.5, 0.2, 0.05, 1.0),   # warm amber
		Color(0.1, 0.5, 0.4, 1.0),    # teal
		Color(0.4, 0.05, 0.6, 1.0),   # purple
		Color(0.05, 0.2, 0.55, 1.0),  # steel blue
		Color(0.55, 0.35, 0.05, 1.0), # gold
		Color(0.3, 0.05, 0.5, 1.0),   # violet
		Color(0.1, 0.45, 0.55, 1.0),  # aqua
	]
	var atmo_positions: Array[Vector3] = [
		Vector3(city_size.x * 0.15, 2.0, city_size.y * 0.15),
		Vector3(city_size.x * 0.5, 3.0, city_size.y * 0.1),
		Vector3(city_size.x * 0.85, 2.5, city_size.y * 0.2),
		Vector3(city_size.x * 0.1, 1.5, city_size.y * 0.55),
		Vector3(city_size.x * 0.9, 2.0, city_size.y * 0.5),
		Vector3(city_size.x * 0.3, 3.5, city_size.y * 0.8),
		Vector3(city_size.x * 0.7, 2.0, city_size.y * 0.85),
		Vector3(city_size.x * 0.5, 1.0, city_size.y * 0.5),
		Vector3(city_size.x * 0.2, 2.5, city_size.y * 0.4),
		Vector3(city_size.x * 0.75, 3.0, city_size.y * 0.35),
	]
	for idx in range(atmo_positions.size()):
		var atmo_light: OmniLight3D = OmniLight3D.new()
		atmo_light.light_color = atmo_colors[idx]
		atmo_light.light_energy = 0.15 + randf() * 0.2
		atmo_light.omni_range = 8.0 + randf() * 6.0
		atmo_light.omni_attenuation = 1.8
		atmo_light.position = atmo_positions[idx]
		atmo_light.name = "AtmoLight_%d" % idx
		add_child(atmo_light)

	# High-altitude fog volume — creates depth haze between distant towers
	var fog_volume := FogVolume.new()
	fog_volume.size = Vector3(city_size.x * 2.5, 8.0, city_size.y * 2.5)
	fog_volume.position = Vector3(city_size.x / 2.0, 4.0, city_size.y / 2.0)
	var fog_mat := FogMaterial.new()
	fog_mat.density = 0.015
	fog_mat.albedo = Color(0.01, 0.015, 0.05)
	fog_mat.emission = Color(0.005, 0.008, 0.025)
	fog_volume.material = fog_mat
	add_child(fog_volume)

	# Upper atmosphere fog — subtle haze at tower-top height
	var upper_fog := FogVolume.new()
	upper_fog.size = Vector3(city_size.x * 2.0, 5.0, city_size.y * 2.0)
	upper_fog.position = Vector3(city_size.x / 2.0, 18.0, city_size.y / 2.0)
	var upper_fog_mat := FogMaterial.new()
	upper_fog_mat.density = 0.008
	upper_fog_mat.albedo = Color(0.008, 0.01, 0.035)
	upper_fog.material = upper_fog_mat
	add_child(upper_fog)

	# Overhead data streams — animated lines of light flowing across the sky
	for i in range(30):
		var stream_particles := GPUParticles3D.new()
		stream_particles.amount = 40
		stream_particles.lifetime = 4.0
		stream_particles.position = Vector3(
			randf() * city_size.x,
			18.0 + randf() * 15.0,
			randf() * city_size.y
		)
		var sp_mat := ParticleProcessMaterial.new()
		sp_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		sp_mat.emission_box_extents = Vector3(0.1, 0.1, 0.1)
		var angle := randf() * PI * 2.0
		sp_mat.direction = Vector3(cos(angle), 0, sin(angle))
		sp_mat.spread = 5.0
		sp_mat.initial_velocity_min = 8.0
		sp_mat.initial_velocity_max = 15.0
		sp_mat.gravity = Vector3(0, 0, 0)
		sp_mat.scale_min = 0.02
		sp_mat.scale_max = 0.05
		var is_accent := randf() > 0.7
		if is_accent:
			sp_mat.color = Color(0.8, 0.35, 0.05, 0.7)
		else:
			sp_mat.color = Color(0.1, 0.25, 0.7, 0.6)
		stream_particles.process_material = sp_mat
		var sp_draw := SphereMesh.new()
		sp_draw.radius = 0.03
		sp_draw.height = 0.06
		stream_particles.draw_pass_1 = sp_draw
		stream_particles.trail_enabled = true
		stream_particles.trail_lifetime = 0.3
		add_child(stream_particles)

	# Build link beams
	var beam_renderer_script: GDScript = load("res://layers/city/city_beam_renderer.gd") as GDScript
	var beam_renderer: Node3D = Node3D.new()
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
				var mesh_child: MeshInstance3D = child as MeshInstance3D
				var mat: Material = mesh_child.get_surface_override_material(0)
				if mat is StandardMaterial3D:
					var std_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
					if note_id in note_ids:
						std_mat.emission_energy_multiplier = 12.0
					else:
						std_mat.emission_energy_multiplier = 0.1
					mesh_child.set_surface_override_material(0, std_mat)
				break

func get_tower_positions() -> Dictionary:
	return _tower_positions

func clear_highlights() -> void:
	for note_id in _tower_map:
		var tower: Node3D = _tower_map[note_id]
		var conns: int = tower.get_meta("connection_count", 0)
		var temp: float = clampf(conns / 20.0, 0.0, 1.0)
		for child in tower.get_children():
			if child is MeshInstance3D:
				var mesh_child: MeshInstance3D = child as MeshInstance3D
				var mat: Material = mesh_child.get_surface_override_material(0)
				if mat is StandardMaterial3D:
					var std_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
					std_mat.emission_energy_multiplier = 2.0 + temp * 6.0
					mesh_child.set_surface_override_material(0, std_mat)
				break
