extends Node3D

var target_note_id: String = ""
var is_outgoing: bool = true
var display_title: String = ""

@onready var frame_mesh: MeshInstance3D = $Frame
@onready var portal_mesh: MeshInstance3D = $Portal
@onready var label: Label3D = $Label3D

func setup(p_target_id: String, p_title: String, p_is_outgoing: bool) -> void:
	target_note_id = p_target_id
	display_title = p_title
	is_outgoing = p_is_outgoing

func _ready() -> void:
	label.text = display_title

	if is_outgoing:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.5, 0.98)
		mat.emission_energy_multiplier = 3.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.1, 0.3, 0.8, 0.4)
		portal_mesh.set_surface_override_material(0, mat)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.02, 0.02)
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.05, 0.05)
		mat.emission_energy_multiplier = 0.5
		portal_mesh.set_surface_override_material(0, mat)

	set_meta("note_id", target_note_id)
	set_meta("is_outgoing", is_outgoing)
