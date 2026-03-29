extends Node3D

var text_content: String = ""
var panel_side: String = "left"

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var viewport: SubViewport = $SubViewport

const PANEL_WIDTH := 3.5
const PANEL_HEIGHT := 2.5

func _ready() -> void:
	_render_text()

func setup(p_text: String, p_side: String, z_position: float) -> void:
	text_content = p_text
	panel_side = p_side
	var x_offset := -2.0 if p_side == "left" else 2.0
	var y_rot := PI / 2.0 if p_side == "left" else -PI / 2.0
	position = Vector3(x_offset, 1.8, z_position)
	rotation.y = y_rot

func _render_text() -> void:
	viewport.size = Vector2i(1024, 768)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = text_content
	label.size = Vector2(1024, 768)
	label.add_theme_font_size_override("normal_font_size", 22)
	label.add_theme_color_override("default_color", Color.WHITE)
	viewport.add_child(label)

	await get_tree().process_frame
	await get_tree().process_frame

	var tex := viewport.get_texture()
	var shader = load("res://shaders/holographic_text.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("text_texture", tex)
	mat.set_shader_parameter("text_color", Color(0.98, 0.72, 0.2, 0.9))
	mesh.set_surface_override_material(0, mat)
