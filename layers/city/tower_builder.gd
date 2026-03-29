extends RefCounted
class_name TowerBuilder

const VaultParser = preload("res://autoloads/vault_parser.gd")

static func build_tower(note: VaultParser.NoteData, connection_count: int, position_2d: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Tower_%s" % note.id.replace("/", "_")

	# Height from word count (min 2, max 25)
	var height := clampf(note.word_count / 150.0, 2.0, 25.0)
	# Width from tag count (min 1.0, max 2.5)
	var width := clampf(1.0 + note.tags.size() * 0.3, 1.0, 2.5)
	# Temperature from connections
	var temperature := clampf(connection_count / 20.0, 0.0, 1.0)
	var emit_color := Color(0.14, 0.33, 0.93).lerp(Color(0.98, 0.58, 0.09), temperature)
	var emission_strength := 2.0 + temperature * 6.0

	# Main tower body
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, width)
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(position_2d.x, height / 2.0, position_2d.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.05, 0.12)
	mat.emission_enabled = true
	mat.emission = emit_color
	mat.emission_energy_multiplier = emission_strength
	mat.metallic = 0.6
	mat.roughness = 0.3
	mesh_instance.set_surface_override_material(0, mat)
	root.add_child(mesh_instance)

	# Hex grid overlay — more visible
	var hex_shader = load("res://shaders/hex_grid.gdshader")
	if hex_shader:
		var overlay := MeshInstance3D.new()
		var overlay_box := BoxMesh.new()
		overlay_box.size = Vector3(width + 0.02, height + 0.02, width + 0.02)
		overlay.mesh = overlay_box
		overlay.position = mesh_instance.position
		var hex_mat := ShaderMaterial.new()
		hex_mat.shader = hex_shader
		hex_mat.set_shader_parameter("line_color", Color(emit_color.r, emit_color.g, emit_color.b, 0.35))
		hex_mat.set_shader_parameter("scale", 3.0)
		hex_mat.set_shader_parameter("scroll_speed", 0.02 + temperature * 0.08)
		overlay.set_surface_override_material(0, hex_mat)
		root.add_child(overlay)

	# Top cap glow — bright emissive plane on top
	var cap := MeshInstance3D.new()
	var cap_mesh := PlaneMesh.new()
	cap_mesh.size = Vector2(width * 0.8, width * 0.8)
	cap.mesh = cap_mesh
	cap.position = Vector3(position_2d.x, height + 0.01, position_2d.y)
	var cap_mat := StandardMaterial3D.new()
	cap_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap_mat.albedo_color = emit_color
	cap_mat.emission_enabled = true
	cap_mat.emission = emit_color
	cap_mat.emission_energy_multiplier = emission_strength * 2.0
	cap.set_surface_override_material(0, cap_mat)
	root.add_child(cap)

	# Vertical edge glow strips (4 edges)
	var strip_width := 0.04
	var strip_mat := StandardMaterial3D.new()
	strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	strip_mat.albedo_color = emit_color * 1.5
	strip_mat.emission_enabled = true
	strip_mat.emission = emit_color
	strip_mat.emission_energy_multiplier = emission_strength * 1.5

	var half_w := width / 2.0
	var edge_offsets := [
		Vector3(-half_w, 0, -half_w),
		Vector3(half_w, 0, -half_w),
		Vector3(-half_w, 0, half_w),
		Vector3(half_w, 0, half_w),
	]
	for offset in edge_offsets:
		var strip := MeshInstance3D.new()
		var strip_mesh := BoxMesh.new()
		strip_mesh.size = Vector3(strip_width, height, strip_width)
		strip.mesh = strip_mesh
		strip.position = Vector3(position_2d.x + offset.x, height / 2.0, position_2d.y + offset.z)
		strip.set_surface_override_material(0, strip_mat.duplicate())
		root.add_child(strip)

	# Point light at top — casts colored light on surroundings
	var light := OmniLight3D.new()
	light.light_color = emit_color
	light.light_energy = 0.5 + temperature * 2.0
	light.omni_range = 3.0 + temperature * 5.0
	light.omni_attenuation = 1.5
	light.position = Vector3(position_2d.x, height + 0.5, position_2d.y)
	# Only add lights for notable towers (performance — 432 lights is too many)
	if connection_count >= 5:
		root.add_child(light)

	root.set_meta("note_id", note.id)
	root.set_meta("connection_count", connection_count)

	return root
