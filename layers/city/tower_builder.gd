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
	# Edge/cap glow strength — controlled, not nuclear
	var edge_strength := 1.5 + temperature * 3.0

	# ---- MAIN BODY: Dark opaque with very subtle emission ----
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, width)
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(position_2d.x, height / 2.0, position_2d.y)
	var mat := StandardMaterial3D.new()
	# Dark body — the cube itself barely glows
	mat.albedo_color = Color(0.02, 0.03, 0.08)
	mat.emission_enabled = true
	mat.emission = emit_color * 0.3
	mat.emission_energy_multiplier = 0.2 + temperature * 0.5
	mat.metallic = 0.85
	mat.roughness = 0.15  # Shiny/reflective dark surface
	mesh_instance.set_surface_override_material(0, mat)
	root.add_child(mesh_instance)

	# ---- HEX GRID on body — subtle circuit pattern ----
	var hex_shader: Resource = load("res://shaders/hex_grid.gdshader")
	if hex_shader:
		var overlay := MeshInstance3D.new()
		var overlay_box := BoxMesh.new()
		overlay_box.size = Vector3(width + 0.01, height + 0.01, width + 0.01)
		overlay.mesh = overlay_box
		overlay.position = mesh_instance.position
		var hex_mat := ShaderMaterial.new()
		hex_mat.shader = hex_shader
		hex_mat.set_shader_parameter("line_color", Color(emit_color.r, emit_color.g, emit_color.b, 0.15 + temperature * 0.15))
		hex_mat.set_shader_parameter("scale", 4.0)
		hex_mat.set_shader_parameter("scroll_speed", 0.01 + temperature * 0.04)
		overlay.set_surface_override_material(0, hex_mat)
		root.add_child(overlay)

	# ---- TOP CAP: This is where the main glow comes from ----
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

	# ---- TOWER LABEL: note title above the cap ----
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
	var strip_w := 0.035
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

	# ---- HORIZONTAL BANDS: data lines across tower face ----
	var num_bands := int(height / 3.0)
	if num_bands > 0:
		var band_mat := StandardMaterial3D.new()
		band_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		band_mat.albedo_color = emit_color * 0.7
		band_mat.emission_enabled = true
		band_mat.emission = emit_color
		band_mat.emission_energy_multiplier = edge_strength * 0.4
		for b in range(num_bands):
			var band_y := (b + 1) * 3.0
			if band_y >= height:
				break
			var band := MeshInstance3D.new()
			var band_mesh := BoxMesh.new()
			band_mesh.size = Vector3(width + 0.02, 0.03, width + 0.02)
			band.mesh = band_mesh
			band.position = Vector3(position_2d.x, band_y, position_2d.y)
			band.set_surface_override_material(0, band_mat.duplicate())
			root.add_child(band)

	# ---- POINT LIGHT: only on high-connection towers ----
	if connection_count >= 8:
		var light := OmniLight3D.new()
		light.light_color = emit_color
		light.light_energy = 0.3 + temperature * 1.5
		light.omni_range = 4.0 + temperature * 4.0
		light.omni_attenuation = 2.0
		light.position = Vector3(position_2d.x, height * 0.6, position_2d.y)
		root.add_child(light)

	root.set_meta("note_id", note.id)
	root.set_meta("connection_count", connection_count)
	return root
