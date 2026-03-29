extends Node3D

var note_id: String
var note_title: String
var connection_count: int = 0

var _setup_data: Dictionary = {}

func setup(p_note_id: String, p_title: String, p_connections: int, p_position: Vector3) -> void:
	note_id = p_note_id
	note_title = p_title
	connection_count = p_connections
	position = p_position
	# Store for _ready since @onready nodes aren't available yet
	_setup_data = {
		"title": p_title,
		"connections": p_connections,
	}

func _ready() -> void:
	var mesh_instance: MeshInstance3D = $MeshInstance3D
	var label: Label3D = $Label3D

	var scale_factor := clampf(0.3 + (connection_count * 0.08), 0.3, 2.0)
	mesh_instance.scale = Vector3.ONE * scale_factor

	var temperature := clampf(connection_count / 25.0, 0.0, 1.0)
	var mat: ShaderMaterial = mesh_instance.get_surface_override_material(0) as ShaderMaterial
	if mat:
		mat = mat.duplicate()
		mat.set_shader_parameter("temperature", temperature)
		mat.set_shader_parameter("emission_strength", 1.5 + temperature * 4.0)
		mesh_instance.set_surface_override_material(0, mat)

	label.text = note_title
	label.position = Vector3(0, scale_factor + 0.5, 0)
	label.font_size = 32
	label.modulate = Color(0.8, 0.85, 0.95, 0.8)

	# Add collision for click detection
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = scale_factor * 0.6
	col.shape = shape
	body.add_child(col)
	body.set_meta("note_id", note_id)
	add_child(body)

func _process(_delta: float) -> void:
	var label: Label3D = $Label3D
	if label and get_viewport().get_camera_3d():
		label.look_at(get_viewport().get_camera_3d().global_position)
