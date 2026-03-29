extends Node3D

var note_id: String
var note_title: String
var connection_count: int = 0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D

func setup(p_note_id: String, p_title: String, p_connections: int, p_position: Vector3) -> void:
	note_id = p_note_id
	note_title = p_title
	connection_count = p_connections
	position = p_position

	var scale_factor := clampf(0.3 + (connection_count * 0.08), 0.3, 2.0)
	mesh_instance.scale = Vector3.ONE * scale_factor

	var temperature := clampf(connection_count / 25.0, 0.0, 1.0)
	var mat: ShaderMaterial = mesh_instance.get_surface_override_material(0)
	if mat:
		mat = mat.duplicate()
		mat.set_shader_parameter("temperature", temperature)
		mat.set_shader_parameter("emission_strength", 1.5 + temperature * 4.0)
		mesh_instance.set_surface_override_material(0, mat)

	label.text = p_title
	label.position = Vector3(0, scale_factor + 0.5, 0)
	label.font_size = 32
	label.modulate = Color(0.8, 0.85, 0.95, 0.8)

func _process(_delta: float) -> void:
	if label and get_viewport().get_camera_3d():
		label.look_at(get_viewport().get_camera_3d().global_position)
