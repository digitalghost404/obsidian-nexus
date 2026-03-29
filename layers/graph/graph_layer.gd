extends Node3D

const GraphNodeMeshScene = preload("res://layers/graph/graph_node_mesh.tscn")

var edge_renderer: Node3D
var nodes_container: Node3D
var _node_map: Dictionary = {}

func _ready() -> void:
	nodes_container = Node3D.new()
	nodes_container.name = "Nodes"
	add_child(nodes_container)

	var EdgeRenderer = load("res://layers/graph/graph_edge_renderer.gd")
	edge_renderer = Node3D.new()
	edge_renderer.set_script(EdgeRenderer)
	edge_renderer.name = "Edges"
	add_child(edge_renderer)

	build_from_graph(VaultDataBus.graph)
	VaultDataBus.graph.note_updated.connect(_on_note_updated)

func build_from_graph(graph) -> void:
	for child in nodes_container.get_children():
		child.queue_free()
	_node_map.clear()

	var all_ids: Array = graph.get_all_note_ids()
	if all_ids.is_empty():
		return

	if graph.get_position(all_ids[0]) == Vector3.ZERO:
		graph.compute_layout(500)

	for note in graph.get_all_notes():
		var node_instance = GraphNodeMeshScene.instantiate()
		node_instance.setup(
			note.id,
			note.title,
			graph.get_connection_count(note.id),
			graph.get_position(note.id)
		)
		nodes_container.add_child(node_instance)
		_node_map[note.id] = node_instance

	edge_renderer.build_edges(graph)

func _on_note_updated(note_id: String) -> void:
	if _node_map.has(note_id):
		_node_map[note_id].queue_free()
	var note = VaultDataBus.graph.get_note(note_id)
	if note:
		var node_instance = GraphNodeMeshScene.instantiate()
		node_instance.setup(
			note.id,
			note.title,
			VaultDataBus.graph.get_connection_count(note.id),
			VaultDataBus.graph.get_position(note.id)
		)
		nodes_container.add_child(node_instance)
		_node_map[note_id] = node_instance
	edge_renderer.build_edges(VaultDataBus.graph)

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
				var mat = node.get_node("MeshInstance3D").get_surface_override_material(0)
				if mat:
					mat = mat.duplicate()
					mat.set_shader_parameter("emission_strength", 8.0)
					node.get_node("MeshInstance3D").set_surface_override_material(0, mat)
		else:
			if node.has_node("MeshInstance3D"):
				var mat = node.get_node("MeshInstance3D").get_surface_override_material(0)
				if mat:
					mat = mat.duplicate()
					mat.set_shader_parameter("emission_strength", 0.1)
					node.get_node("MeshInstance3D").set_surface_override_material(0, mat)

func clear_highlights() -> void:
	for note_id in _node_map:
		var node: Node3D = _node_map[note_id]
		var conns := VaultDataBus.graph.get_connection_count(note_id)
		var temp := clampf(conns / 25.0, 0.0, 1.0)
		if node.has_node("MeshInstance3D"):
			var mat = node.get_node("MeshInstance3D").get_surface_override_material(0)
			if mat:
				mat = mat.duplicate()
				mat.set_shader_parameter("emission_strength", 1.5 + temp * 4.0)
				node.get_node("MeshInstance3D").set_surface_override_material(0, mat)
