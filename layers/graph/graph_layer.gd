extends Node3D

const GraphNodeMeshScene = preload("res://layers/graph/graph_node_mesh.tscn")

var edge_renderer: Node3D
var nodes_container: Node3D
var _node_map: Dictionary = {}

func _ready() -> void:
	nodes_container = Node3D.new()
	nodes_container.name = "Nodes"
	add_child(nodes_container)

	var EdgeRenderer: GDScript = load("res://layers/graph/graph_edge_renderer.gd") as GDScript
	edge_renderer = Node3D.new()
	edge_renderer.set_script(EdgeRenderer)
	edge_renderer.name = "Edges"
	add_child(edge_renderer)

	build_from_graph(VaultDataBus.graph)
	VaultDataBus.graph.note_updated.connect(_on_note_updated)

func build_from_graph(graph: NoteGraph) -> void:
	for child in nodes_container.get_children():
		child.queue_free()
	_node_map.clear()

	var all_ids: Array = graph.get_all_note_ids()
	if all_ids.is_empty():
		return

	var first_pos: Vector3 = graph.get_position(all_ids[0])
	if first_pos == Vector3.ZERO:
		graph.compute_layout(500)

	var all_notes: Array = graph.get_all_notes()
	for note in all_notes:
		var nid: String = note.id
		var ntitle: String = note.title
		var conn_count: int = graph.get_connection_count(nid)
		var npos: Vector3 = graph.get_position(nid)
		var node_instance: Node3D = GraphNodeMeshScene.instantiate()
		node_instance.setup(nid, ntitle, conn_count, npos)
		nodes_container.add_child(node_instance)
		_node_map[nid] = node_instance

	edge_renderer.build_edges(graph)

func _on_note_updated(note_id: String) -> void:
	if _node_map.has(note_id):
		_node_map[note_id].queue_free()
	var g: NoteGraph = VaultDataBus.graph
	var note: RefCounted = g.get_note(note_id)
	if note:
		var nid: String = note.id
		var ntitle: String = note.title
		var conn_count: int = g.get_connection_count(nid)
		var npos: Vector3 = g.get_position(nid)
		var node_instance: Node3D = GraphNodeMeshScene.instantiate()
		node_instance.setup(nid, ntitle, conn_count, npos)
		nodes_container.add_child(node_instance)
		_node_map[note_id] = node_instance
	edge_renderer.build_edges(g)

func get_node_at_position(world_pos: Vector3, radius: float = 2.0) -> String:
	var closest_id := ""
	var closest_dist := radius
	for note_id in _node_map:
		var node_pos: Vector3 = _node_map[note_id].global_position
		var dist := node_pos.distance_to(world_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_id = note_id
	return closest_id

func highlight_notes(note_ids: Array) -> void:
	for note_id in _node_map:
		var node: Node3D = _node_map[note_id]
		if note_id in note_ids:
			if node.has_node("MeshInstance3D"):
				var mesh: MeshInstance3D = node.get_node("MeshInstance3D") as MeshInstance3D
				var mat: Material = mesh.get_surface_override_material(0)
				if mat:
					var duped: ShaderMaterial = mat.duplicate() as ShaderMaterial
					duped.set_shader_parameter("emission_strength", 8.0)
					mesh.set_surface_override_material(0, duped)
		else:
			if node.has_node("MeshInstance3D"):
				var mesh: MeshInstance3D = node.get_node("MeshInstance3D") as MeshInstance3D
				var mat: Material = mesh.get_surface_override_material(0)
				if mat:
					var duped: ShaderMaterial = mat.duplicate() as ShaderMaterial
					duped.set_shader_parameter("emission_strength", 0.1)
					mesh.set_surface_override_material(0, duped)

func clear_highlights() -> void:
	for note_id in _node_map:
		var node: Node3D = _node_map[note_id]
		var conns: int = VaultDataBus.graph.get_connection_count(note_id)
		var temp: float = clampf(conns / 25.0, 0.0, 1.0)
		if node.has_node("MeshInstance3D"):
			var mesh: MeshInstance3D = node.get_node("MeshInstance3D") as MeshInstance3D
			var mat: Material = mesh.get_surface_override_material(0)
			if mat:
				var duped: ShaderMaterial = mat.duplicate() as ShaderMaterial
				duped.set_shader_parameter("emission_strength", 1.5 + temp * 4.0)
				mesh.set_surface_override_material(0, duped)
