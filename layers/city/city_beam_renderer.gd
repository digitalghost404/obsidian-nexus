extends Node3D

var _mesh_instance: MeshInstance3D
var _mesh: ImmediateMesh

func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.5, 0.4, 0.93, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_instance.set_surface_override_material(0, mat)
	add_child(_mesh_instance)

func build_beams(tower_positions: Dictionary, graph) -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for note_id in tower_positions:
		var note = graph.get_note(note_id)
		if not note:
			continue
		var from_pos: Vector3 = tower_positions[note_id]
		for link in note.outgoing_links:
			if tower_positions.has(link):
				var to_pos: Vector3 = tower_positions[link]
				var mid_y := maxf(from_pos.y, to_pos.y) + 5.0
				var mid_pos := (from_pos + to_pos) / 2.0
				mid_pos.y = mid_y

				var temp := clampf((graph.get_connection_count(note_id) + graph.get_connection_count(link)) / 50.0, 0.0, 1.0)
				var beam_color := Color(0.32, 0.4, 0.93, 0.15).lerp(Color(0.98, 0.58, 0.09, 0.3), temp)

				_mesh.surface_set_color(beam_color)
				_mesh.surface_add_vertex(from_pos)
				_mesh.surface_set_color(beam_color)
				_mesh.surface_add_vertex(mid_pos)

				_mesh.surface_set_color(beam_color)
				_mesh.surface_add_vertex(mid_pos)
				_mesh.surface_set_color(beam_color)
				_mesh.surface_add_vertex(to_pos)

	_mesh.surface_end()
