extends Node3D

var _rotating_ring: MeshInstance3D

func _ready() -> void:
	_build_hub()

func _build_hub() -> void:
	# Central dark cylinder (outer shell)
	var outer := MeshInstance3D.new()
	var outer_mesh := CylinderMesh.new()
	outer_mesh.top_radius = 4.0
	outer_mesh.bottom_radius = 4.5
	outer_mesh.height = 20.0
	outer.mesh = outer_mesh
	outer.position = Vector3(0, 10, 0)
	var outer_mat := StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.02, 0.025, 0.06)
	outer_mat.metallic = 0.9
	outer_mat.roughness = 0.1
	outer_mat.emission_enabled = true
	outer_mat.emission = Color(0.05, 0.1, 0.4)
	outer_mat.emission_energy_multiplier = 0.3
	outer.set_surface_override_material(0, outer_mat)
	add_child(outer)

	# Inner glowing core
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 1.5
	core_mesh.bottom_radius = 1.5
	core_mesh.height = 25.0
	core.mesh = core_mesh
	core.position = Vector3(0, 12.5, 0)
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(0.3, 0.5, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.2, 0.4, 0.95)
	core_mat.emission_energy_multiplier = 4.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color.a = 0.7
	core.set_surface_override_material(0, core_mat)
	add_child(core)

	# Hub floor — circuit pattern plane
	var hub_floor := MeshInstance3D.new()
	var hub_floor_mesh := PlaneMesh.new()
	hub_floor_mesh.size = Vector2(60, 60)  # Covers the exclusion zone
	hub_floor.mesh = hub_floor_mesh
	hub_floor.position = Vector3(0, 0.02, 0)  # Slightly above ground to avoid z-fighting
	var hub_floor_shader = load("res://shaders/hub_circuit.gdshader")
	if hub_floor_shader:
		var hf_mat := ShaderMaterial.new()
		hf_mat.shader = hub_floor_shader
		hf_mat.set_shader_parameter("emission_strength", 2.5)
		hf_mat.set_shader_parameter("ring_count", 10.0)
		hf_mat.set_shader_parameter("trace_detail", 35.0)
		hub_floor.set_surface_override_material(0, hf_mat)
	add_child(hub_floor)

	# Rotating ring at mid height
	_rotating_ring = MeshInstance3D.new()
	var rot_mesh := TorusMesh.new()
	rot_mesh.inner_radius = 5.0
	rot_mesh.outer_radius = 5.4
	_rotating_ring.mesh = rot_mesh
	_rotating_ring.position = Vector3(0, 12.0, 0)
	var rot_mat := StandardMaterial3D.new()
	rot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rot_mat.albedo_color = Color(0.15, 0.35, 0.9)
	rot_mat.emission_enabled = true
	rot_mat.emission = Color(0.1, 0.3, 0.85)
	rot_mat.emission_energy_multiplier = 3.0
	_rotating_ring.set_surface_override_material(0, rot_mat)
	add_child(_rotating_ring)

	# Second rotating ring (opposite direction, higher)
	var ring2 := MeshInstance3D.new()
	var rot_mesh2 := TorusMesh.new()
	rot_mesh2.inner_radius = 3.5
	rot_mesh2.outer_radius = 3.8
	ring2.mesh = rot_mesh2
	ring2.position = Vector3(0, 18.0, 0)
	ring2.rotation.x = 0.3
	var rot_mat2 := StandardMaterial3D.new()
	rot_mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rot_mat2.albedo_color = Color(0.9, 0.4, 0.05)
	rot_mat2.emission_enabled = true
	rot_mat2.emission = Color(0.85, 0.35, 0.05)
	rot_mat2.emission_energy_multiplier = 2.5
	ring2.set_surface_override_material(0, rot_mat2)
	ring2.name = "Ring2"
	add_child(ring2)

	# Top beacon light — visible from everywhere
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(0.3, 0.5, 1.0)
	beacon.light_energy = 3.0
	beacon.omni_range = 40.0
	beacon.omni_attenuation = 1.0
	beacon.position = Vector3(0, 22, 0)
	add_child(beacon)

	# Base warm light
	var base_light := OmniLight3D.new()
	base_light.light_color = Color(0.9, 0.5, 0.1)
	base_light.light_energy = 2.0
	base_light.omni_range = 15.0
	base_light.position = Vector3(0, 2, 0)
	add_child(base_light)

	# Rising particle column
	var particles := GPUParticles3D.new()
	particles.amount = 500
	particles.lifetime = 4.0
	particles.position = Vector3(0, 10, 0)
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pmat.emission_ring_radius = 3.0
	pmat.emission_ring_inner_radius = 0.5
	pmat.emission_ring_height = 0.1
	pmat.emission_ring_axis = Vector3(0, 1, 0)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 10.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 4.0
	pmat.gravity = Vector3(0, 0, 0)
	pmat.scale_min = 0.02
	pmat.scale_max = 0.06
	pmat.color = Color(0.2, 0.5, 1.0, 0.8)
	particles.process_material = pmat
	var pdraw := SphereMesh.new()
	pdraw.radius = 0.03
	pdraw.height = 0.06
	particles.draw_pass_1 = pdraw
	add_child(particles)

	# "NEXUS" label
	var label := Label3D.new()
	label.text = "N E X U S"
	label.font_size = 64
	label.modulate = Color(0.95, 0.7, 0.15, 0.9)
	label.position = Vector3(0, 23, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.outline_modulate = Color(0.3, 0.15, 0.0, 0.5)
	add_child(label)

	# Collision for click interaction
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 5.0
	shape.height = 20.0
	col.shape = shape
	col.position = Vector3(0, 10, 0)
	body.add_child(col)
	body.set_meta("is_hub", true)
	body.set_meta("note_id", "__nexus_hub__")
	add_child(body)

func _process(delta: float) -> void:
	if _rotating_ring:
		_rotating_ring.rotate_y(delta * 0.3)
	var ring2 = get_node_or_null("Ring2")
	if ring2:
		ring2.rotate_y(-delta * 0.2)
