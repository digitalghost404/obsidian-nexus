extends RefCounted
class_name TowerBuilder

const VaultParser = preload("res://autoloads/vault_parser.gd")

static func build_tower(note: VaultParser.NoteData, connection_count: int, position_2d: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Tower_%s" % note.id.replace("/", "_")

	var height := clampf(note.word_count / 150.0, 1.5, 20.0)
	var width := clampf(0.8 + note.tags.size() * 0.2, 0.8, 2.2)
	var temperature := clampf(connection_count / 20.0, 0.0, 1.0)
	var emit_color := Color(0.08, 0.18, 0.65).lerp(Color(0.95, 0.45, 0.05), temperature)
	var edge_strength := 1.5 + temperature * 3.0

	# ---- MAIN BODY: tower_surface shader for detailed server rack look ----
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, width)
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(position_2d.x, height / 2.0, position_2d.y)
	var tower_shader = load("res://shaders/tower_surface.gdshader")
	if tower_shader:
		var mat := ShaderMaterial.new()
		mat.shader = tower_shader
		mat.set_shader_parameter("temperature", temperature)
		mat.set_shader_parameter("emission_strength", 1.5 + temperature * 2.0)
		mat.set_shader_parameter("panel_density", 4.0 + height * 0.3)
		mat.set_shader_parameter("data_scroll_speed", 0.1 + temperature * 0.4)
		mesh_instance.set_surface_override_material(0, mat)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.02, 0.03, 0.08)
		mat.emission_enabled = true
		mat.emission = emit_color * 0.3
		mat.emission_energy_multiplier = 0.2 + temperature * 0.5
		mat.metallic = 0.85
		mat.roughness = 0.15
		mesh_instance.set_surface_override_material(0, mat)
	root.add_child(mesh_instance)

	# ---- TOP CAP: bright emissive glow ----
	var cap := MeshInstance3D.new()
	var cap_mesh := PlaneMesh.new()
	cap_mesh.size = Vector2(width * 0.9, width * 0.9)
	cap.mesh = cap_mesh
	cap.position = Vector3(position_2d.x, height + 0.01, position_2d.y)
	var cap_mat := StandardMaterial3D.new()
	cap_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap_mat.albedo_color = emit_color
	cap_mat.emission_enabled = true
	cap_mat.emission = emit_color
	cap_mat.emission_energy_multiplier = edge_strength * 1.2
	cap.set_surface_override_material(0, cap_mat)
	root.add_child(cap)

	# ---- TOWER LABEL ----
	var label: Label3D = Label3D.new()
	label.text = note.title
	label.font_size = 16
	label.modulate = Color(0.75, 0.8, 0.95, 0.6)
	label.position = Vector3(position_2d.x, height + 0.4, position_2d.y)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.outline_size = 4
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.3)
	root.add_child(label)

	# ---- EDGE GLOW: 4 vertical strips on corners ----
	var strip_w := 0.04
	var strip_mat := StandardMaterial3D.new()
	strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	strip_mat.albedo_color = emit_color
	strip_mat.emission_enabled = true
	strip_mat.emission = emit_color
	strip_mat.emission_energy_multiplier = edge_strength

	var hw := width / 2.0
	var offsets := [
		Vector3(-hw, 0, -hw), Vector3(hw, 0, -hw),
		Vector3(-hw, 0, hw), Vector3(hw, 0, hw),
	]
	for offset in offsets:
		var strip := MeshInstance3D.new()
		var smesh := BoxMesh.new()
		smesh.size = Vector3(strip_w, height, strip_w)
		strip.mesh = smesh
		strip.position = Vector3(position_2d.x + offset.x, height / 2.0, position_2d.y + offset.z)
		strip.set_surface_override_material(0, strip_mat.duplicate())
		root.add_child(strip)

	# ---- BASE GLOW: bright ring at tower base ----
	var base_ring := MeshInstance3D.new()
	var base_mesh := TorusMesh.new()
	base_mesh.inner_radius = width * 0.5 + 0.1
	base_mesh.outer_radius = width * 0.5 + 0.25
	base_ring.mesh = base_mesh
	base_ring.position = Vector3(position_2d.x, 0.05, position_2d.y)
	var base_mat := StandardMaterial3D.new()
	base_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base_mat.albedo_color = emit_color
	base_mat.emission_enabled = true
	base_mat.emission = emit_color
	base_mat.emission_energy_multiplier = edge_strength * 0.6
	base_ring.set_surface_override_material(0, base_mat)
	root.add_child(base_ring)

	# ---- POINT LIGHT: high-connection towers ----
	if connection_count >= 8:
		var light := OmniLight3D.new()
		light.light_color = emit_color
		light.light_energy = 0.3 + temperature * 1.5
		light.omni_range = 4.0 + temperature * 4.0
		light.omni_attenuation = 2.0
		light.position = Vector3(position_2d.x, height * 0.6, position_2d.y)
		root.add_child(light)

	# ---- HOLOGRAM READOUT: floating data panel above important towers ----
	if connection_count >= 5:
		var holo_shader = load("res://shaders/wall_schematic.gdshader")
		if holo_shader:
			var holo := MeshInstance3D.new()
			var holo_mesh := BoxMesh.new()
			holo_mesh.size = Vector3(width * 1.2, width * 0.6, 0.02)
			holo.mesh = holo_mesh
			holo.position = Vector3(position_2d.x, height + 1.5, position_2d.y)
			holo.rotation.y = randf() * PI
			var holo_mat := ShaderMaterial.new()
			holo_mat.shader = holo_shader
			holo_mat.set_shader_parameter("emission_strength", 1.8)
			holo_mat.set_shader_parameter("panel_scale", 2.0)
			holo_mat.set_shader_parameter("scroll_speed", 0.06)
			holo.set_surface_override_material(0, holo_mat)
			root.add_child(holo)

	# ---- COLLISION ----
	var body := StaticBody3D.new()
	body.position = Vector3(position_2d.x, height / 2.0, position_2d.y)
	var col := CollisionShape3D.new()
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(width, height, width)
	col.shape = col_shape
	body.add_child(col)
	body.set_meta("note_id", note.id)
	root.add_child(body)

	root.set_meta("note_id", note.id)
	root.set_meta("connection_count", connection_count)
	return root
