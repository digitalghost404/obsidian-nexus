extends Node3D

var _mesh_instance: MeshInstance3D
var _mesh: ImmediateMesh

var _material: StandardMaterial3D

func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(0.32, 0.4, 0.93, 0.3)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = false
	add_child(_mesh_instance)

func build_edges(graph) -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for note_id in graph.get_all_note_ids():
		var note = graph.get_note(note_id)
		if not note:
			continue
		var from_pos := graph.get_position(note_id)
		for link in note.outgoing_links:
			var to_pos := graph.get_position(link)
			if to_pos == Vector3.ZERO and not graph.get_note(link):
				continue
			var from_conns := graph.get_connection_count(note_id)
			var to_conns := graph.get_connection_count(link)
			var avg_temp := clampf((from_conns + to_conns) / 50.0, 0.0, 1.0)
			var edge_color := Color(0.32, 0.4, 0.93, 0.2).lerp(Color(0.98, 0.58, 0.09, 0.4), avg_temp)

			_mesh.surface_set_color(edge_color)
			_mesh.surface_add_vertex(from_pos)
			_mesh.surface_set_color(edge_color)
			_mesh.surface_add_vertex(to_pos)

	_mesh.surface_end()
	_mesh_instance.set_surface_override_material(0, _material)
