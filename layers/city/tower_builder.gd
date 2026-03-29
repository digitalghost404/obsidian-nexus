extends RefCounted
class_name TowerBuilder

const VaultParser = preload("res://autoloads/vault_parser.gd")

static func build_tower(note: VaultParser.NoteData, connection_count: int, position_2d: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Tower_%s" % note.id.replace("/", "_")

	var height := clampf(note.word_count / 200.0, 1.0, 30.0)

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, height, 2.0)
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(position_2d.x, height / 2.0, position_2d.y)

	var mat := StandardMaterial3D.new()
	var temperature := clampf(connection_count / 25.0, 0.0, 1.0)
	mat.albedo_color = Color(0.05, 0.08, 0.15)
	mat.emission_enabled = true
	var emit_color := Color(0.14, 0.33, 0.93).lerp(Color(0.98, 0.58, 0.09), temperature)
	mat.emission = emit_color
	mat.emission_energy_multiplier = 0.5 + temperature * 3.0
	mesh_instance.set_surface_override_material(0, mat)

	root.add_child(mesh_instance)

	var hex_shader = load("res://shaders/hex_grid.gdshader")
	if hex_shader:
		var overlay := MeshInstance3D.new()
		var overlay_box := BoxMesh.new()
		overlay_box.size = Vector3(2.05, height + 0.05, 2.05)
		overlay.mesh = overlay_box
		overlay.position = mesh_instance.position
		var hex_mat := ShaderMaterial.new()
		hex_mat.shader = hex_shader
		hex_mat.set_shader_parameter("line_color", Color(emit_color.r, emit_color.g, emit_color.b, 0.12))
		overlay.set_surface_override_material(0, hex_mat)
		root.add_child(overlay)

	var label := Label3D.new()
	label.text = note.title
	label.position = Vector3(position_2d.x, height + 1.0, position_2d.y)
	label.font_size = 24
	label.modulate = Color(0.8, 0.85, 0.95, 0.7)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)

	root.set_meta("note_id", note.id)
	root.set_meta("connection_count", connection_count)

	return root
