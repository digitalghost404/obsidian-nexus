extends Node3D

## The Nexus Hub — central monolithic data structure of the vault
## A towering multi-layered cylindrical construct with rotating rings,
## holographic displays, particle streams, and pulsing energy

var _rings: Array[MeshInstance3D] = []
var _hologram_panels: Array[Node3D] = []
var _pulse_rings: Array[MeshInstance3D] = []
var _pulse_timer: float = 0.0
const PULSE_INTERVAL := 3.0
const PULSE_SPEED := 25.0
const PULSE_MAX_RADIUS := 60.0

# ─── AI State Visual Feedback ────────────────────────────────────
var _ai_state: int = 0  # NexusAI.State.IDLE
var _core_mesh_instance: MeshInstance3D  # Reference to the main inner core
var _core_base_emission: float = 5.0
var _ring_base_speeds: Array[float] = [0.25, -0.35, 0.2, -0.45, 0.3]
var _ring_speed_multiplier: float = 1.0
var _scanner_active: bool = true
var _query_beams: Array[MeshInstance3D] = []
var _query_beam_fade_timer: float = 0.0
const QUERY_BEAM_FADE_DURATION: float = 5.0
var _thinking_particles: GPUParticles3D

func _ready() -> void:
	_build_hub()

func _build_hub() -> void:
	# ========================================
	# OUTER SHELL — layered cylinders with tower_surface shader
	# ========================================

	# Main outer cylinder — detailed server rack surface
	var tower_shader = load("res://shaders/tower_surface.gdshader")

	# Bottom section — wider base (industrial foundation)
	var base_cyl := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 5.0
	base_mesh.bottom_radius = 5.5
	base_mesh.height = 6.0
	base_mesh.radial_segments = 16
	base_cyl.mesh = base_mesh
	base_cyl.position = Vector3(0, 3, 0)
	if tower_shader:
		var bmat := ShaderMaterial.new()
		bmat.shader = tower_shader
		bmat.set_shader_parameter("temperature", 0.4)
		bmat.set_shader_parameter("emission_strength", 2.5)
		bmat.set_shader_parameter("panel_density", 8.0)
		bmat.set_shader_parameter("data_scroll_speed", 0.5)
		base_cyl.set_surface_override_material(0, bmat)
	add_child(base_cyl)

	# Mid section — main tower body
	var mid_cyl := MeshInstance3D.new()
	var mid_mesh := CylinderMesh.new()
	mid_mesh.top_radius = 4.0
	mid_mesh.bottom_radius = 4.8
	mid_mesh.height = 18.0
	mid_mesh.radial_segments = 16
	mid_cyl.mesh = mid_mesh
	mid_cyl.position = Vector3(0, 15, 0)
	if tower_shader:
		var mmat := ShaderMaterial.new()
		mmat.shader = tower_shader
		mmat.set_shader_parameter("temperature", 0.2)
		mmat.set_shader_parameter("emission_strength", 2.0)
		mmat.set_shader_parameter("panel_density", 12.0)
		mmat.set_shader_parameter("data_scroll_speed", 0.3)
		mid_cyl.set_surface_override_material(0, mmat)
	add_child(mid_cyl)

	# Top section — tapered crown
	var top_cyl := MeshInstance3D.new()
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 2.0
	top_mesh.bottom_radius = 3.8
	top_mesh.height = 8.0
	top_mesh.radial_segments = 16
	top_cyl.mesh = top_mesh
	top_cyl.position = Vector3(0, 28, 0)
	if tower_shader:
		var tmat := ShaderMaterial.new()
		tmat.shader = tower_shader
		tmat.set_shader_parameter("temperature", 0.6)
		tmat.set_shader_parameter("emission_strength", 3.0)
		tmat.set_shader_parameter("panel_density", 10.0)
		tmat.set_shader_parameter("data_scroll_speed", 0.8)
		top_cyl.set_surface_override_material(0, tmat)
	add_child(top_cyl)

	# ========================================
	# INNER CORE — bright energy column visible through gaps
	# ========================================
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 1.8
	core_mesh.bottom_radius = 1.8
	core_mesh.height = 40.0
	core_mesh.radial_segments = 12
	core.mesh = core_mesh
	core.position = Vector3(0, 20, 0)
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(0.25, 0.45, 1.0, 0.6)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.2, 0.4, 0.95)
	core_mat.emission_energy_multiplier = 5.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core.set_surface_override_material(0, core_mat)
	add_child(core)

	# Second inner core — pulsing orange energy
	var core2 := MeshInstance3D.new()
	var core2_mesh := CylinderMesh.new()
	core2_mesh.top_radius = 1.0
	core2_mesh.bottom_radius = 1.0
	core2_mesh.height = 35.0
	core2_mesh.radial_segments = 8
	core2.mesh = core2_mesh
	core2.position = Vector3(0, 17.5, 0)
	var core2_mat := StandardMaterial3D.new()
	core2_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core2_mat.albedo_color = Color(0.9, 0.4, 0.05, 0.4)
	core2_mat.emission_enabled = true
	core2_mat.emission = Color(0.85, 0.35, 0.05)
	core2_mat.emission_energy_multiplier = 3.5
	core2_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core2.set_surface_override_material(0, core2_mat)
	add_child(core2)

	# ========================================
	# ROTATING RINGS — 5 rings at different heights, speeds, tilts
	# ========================================
	var ring_configs := [
		{"y": 4.0, "inner": 6.0, "outer": 6.5, "color": Color(0.1, 0.3, 0.85), "speed": 0.25, "tilt_x": 0.0, "emission": 3.0},
		{"y": 10.0, "inner": 5.5, "outer": 6.0, "color": Color(0.85, 0.35, 0.05), "speed": -0.35, "tilt_x": 0.15, "emission": 2.5},
		{"y": 16.0, "inner": 5.0, "outer": 5.6, "color": Color(0.1, 0.35, 0.9), "speed": 0.2, "tilt_x": -0.1, "emission": 3.5},
		{"y": 22.0, "inner": 4.2, "outer": 4.7, "color": Color(0.9, 0.4, 0.05), "speed": -0.45, "tilt_x": 0.2, "emission": 2.8},
		{"y": 28.0, "inner": 3.0, "outer": 3.5, "color": Color(0.2, 0.5, 1.0), "speed": 0.3, "tilt_x": -0.15, "emission": 4.0},
	]
	for i in range(ring_configs.size()):
		var cfg: Dictionary = ring_configs[i]
		var ring := MeshInstance3D.new()
		var rmesh := TorusMesh.new()
		rmesh.inner_radius = cfg["inner"]
		rmesh.outer_radius = cfg["outer"]
		ring.mesh = rmesh
		ring.position = Vector3(0, cfg["y"], 0)
		ring.rotation.x = cfg["tilt_x"]
		ring.name = "Ring_%d" % i
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.albedo_color = cfg["color"]
		rmat.emission_enabled = true
		rmat.emission = cfg["color"]
		rmat.emission_energy_multiplier = cfg["emission"]
		ring.set_surface_override_material(0, rmat)
		add_child(ring)
		_rings.append(ring)

	# ========================================
	# HUB FLOOR — circuit pattern
	# ========================================
	var hub_floor := MeshInstance3D.new()
	var hub_floor_mesh := PlaneMesh.new()
	hub_floor_mesh.size = Vector2(66, 66)
	hub_floor.mesh = hub_floor_mesh
	hub_floor.position = Vector3(0, 0.02, 0)
	var hub_floor_shader = load("res://shaders/hub_circuit.gdshader")
	if hub_floor_shader:
		var hf_mat := ShaderMaterial.new()
		hf_mat.shader = hub_floor_shader
		hf_mat.set_shader_parameter("emission_strength", 3.0)
		hf_mat.set_shader_parameter("ring_count", 12.0)
		hf_mat.set_shader_parameter("trace_detail", 40.0)
		hub_floor.set_surface_override_material(0, hf_mat)
	add_child(hub_floor)

	# ========================================
	# HOLOGRAPHIC DATA PANELS — floating around the hub
	# ========================================
	var wall_shader = load("res://shaders/wall_schematic.gdshader")
	if wall_shader:
		for i in range(8):
			var angle := float(i) * PI * 2.0 / 8.0
			var dist := 8.0 + (i % 2) * 2.0
			var panel := MeshInstance3D.new()
			var pmesh := BoxMesh.new()
			pmesh.size = Vector3(3.0, 2.0, 0.05)
			panel.mesh = pmesh
			panel.position = Vector3(cos(angle) * dist, 6.0 + float(i % 3) * 4.0, sin(angle) * dist)
			panel.rotation.y = angle + PI  # Face toward center
			panel.name = "HoloPanel_%d" % i
			var pmat := ShaderMaterial.new()
			pmat.shader = wall_shader
			pmat.set_shader_parameter("emission_strength", 2.0)
			pmat.set_shader_parameter("panel_scale", 3.0)
			pmat.set_shader_parameter("scroll_speed", 0.08 + float(i) * 0.01)
			panel.set_surface_override_material(0, pmat)
			add_child(panel)
			_hologram_panels.append(panel)

	# ========================================
	# VERTICAL LIGHT BEAMS — shooting up from the top
	# ========================================
	for i in range(4):
		var angle := float(i) * PI / 2.0 + PI / 4.0
		var beam := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(0.15, 30.0, 0.15)
		beam.mesh = bmesh
		beam.position = Vector3(cos(angle) * 2.5, 35.0, sin(angle) * 2.5)
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.albedo_color = Color(0.15, 0.35, 0.9, 0.5)
		bmat.emission_enabled = true
		bmat.emission = Color(0.1, 0.3, 0.85)
		bmat.emission_energy_multiplier = 4.0
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam.set_surface_override_material(0, bmat)
		add_child(beam)

	# Central beam — bright white-blue
	var center_beam := MeshInstance3D.new()
	var cb_mesh := BoxMesh.new()
	cb_mesh.size = Vector3(0.3, 50.0, 0.3)
	center_beam.mesh = cb_mesh
	center_beam.position = Vector3(0, 40, 0)
	var cb_mat := StandardMaterial3D.new()
	cb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cb_mat.albedo_color = Color(0.4, 0.6, 1.0, 0.4)
	cb_mat.emission_enabled = true
	cb_mat.emission = Color(0.3, 0.5, 1.0)
	cb_mat.emission_energy_multiplier = 6.0
	cb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	center_beam.set_surface_override_material(0, cb_mat)
	add_child(center_beam)

	# ========================================
	# EDGE GLOW STRIPS — vertical lines on the outer shell
	# ========================================
	var edge_mat := StandardMaterial3D.new()
	edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_mat.albedo_color = Color(0.1, 0.25, 0.8)
	edge_mat.emission_enabled = true
	edge_mat.emission = Color(0.08, 0.2, 0.7)
	edge_mat.emission_energy_multiplier = 3.5
	for i in range(12):
		var angle := float(i) * PI * 2.0 / 12.0
		var strip := MeshInstance3D.new()
		var smesh := BoxMesh.new()
		smesh.size = Vector3(0.06, 32.0, 0.06)
		strip.mesh = smesh
		strip.position = Vector3(cos(angle) * 5.0, 16, sin(angle) * 5.0)
		strip.set_surface_override_material(0, edge_mat.duplicate())
		add_child(strip)

	# ========================================
	# LIGHTS — multi-level lighting
	# ========================================

	# Top beacon — bright, visible from anywhere
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(0.3, 0.5, 1.0)
	beacon.light_energy = 4.0
	beacon.omni_range = 50.0
	beacon.omni_attenuation = 0.8
	beacon.position = Vector3(0, 35, 0)
	add_child(beacon)

	# Mid-level blue accent
	var mid_light := OmniLight3D.new()
	mid_light.light_color = Color(0.15, 0.3, 0.9)
	mid_light.light_energy = 2.5
	mid_light.omni_range = 20.0
	mid_light.position = Vector3(0, 16, 0)
	add_child(mid_light)

	# Base warm glow
	var base_light := OmniLight3D.new()
	base_light.light_color = Color(0.9, 0.5, 0.1)
	base_light.light_energy = 2.5
	base_light.omni_range = 18.0
	base_light.position = Vector3(0, 2, 0)
	add_child(base_light)

	# Perimeter accent lights at ground level
	for i in range(6):
		var angle := float(i) * PI * 2.0 / 6.0
		var pl := OmniLight3D.new()
		pl.light_color = Color(0.1, 0.25, 0.85)
		pl.light_energy = 1.0
		pl.omni_range = 8.0
		pl.position = Vector3(cos(angle) * 10.0, 1.0, sin(angle) * 10.0)
		add_child(pl)

	# ========================================
	# PARTICLES — multiple emitter systems
	# ========================================

	# Rising core particles — dense blue motes spiraling upward
	var core_particles := GPUParticles3D.new()
	core_particles.amount = 800
	core_particles.lifetime = 5.0
	core_particles.position = Vector3(0, 15, 0)
	var cp_mat := ParticleProcessMaterial.new()
	cp_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	cp_mat.emission_ring_radius = 3.5
	cp_mat.emission_ring_inner_radius = 0.5
	cp_mat.emission_ring_height = 0.1
	cp_mat.emission_ring_axis = Vector3(0, 1, 0)
	cp_mat.direction = Vector3(0, 1, 0)
	cp_mat.spread = 8.0
	cp_mat.initial_velocity_min = 2.0
	cp_mat.initial_velocity_max = 5.0
	cp_mat.gravity = Vector3(0, 0, 0)
	cp_mat.scale_min = 0.02
	cp_mat.scale_max = 0.06
	cp_mat.color = Color(0.2, 0.5, 1.0, 0.8)
	core_particles.process_material = cp_mat
	var cp_draw := SphereMesh.new()
	cp_draw.radius = 0.03
	cp_draw.height = 0.06
	core_particles.draw_pass_1 = cp_draw
	add_child(core_particles)

	# Orbital sparks — fast particles circling the hub
	var orbit_particles := GPUParticles3D.new()
	orbit_particles.amount = 300
	orbit_particles.lifetime = 3.0
	orbit_particles.position = Vector3(0, 12, 0)
	var op_mat := ParticleProcessMaterial.new()
	op_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	op_mat.emission_ring_radius = 7.0
	op_mat.emission_ring_inner_radius = 6.0
	op_mat.emission_ring_height = 8.0
	op_mat.emission_ring_axis = Vector3(0, 1, 0)
	op_mat.direction = Vector3(1, 0.3, 0)
	op_mat.spread = 45.0
	op_mat.initial_velocity_min = 3.0
	op_mat.initial_velocity_max = 6.0
	op_mat.gravity = Vector3(0, 0, 0)
	op_mat.scale_min = 0.01
	op_mat.scale_max = 0.03
	op_mat.color = Color(0.8, 0.4, 0.05, 0.9)
	orbit_particles.process_material = op_mat
	var op_draw := SphereMesh.new()
	op_draw.radius = 0.015
	op_draw.height = 0.03
	orbit_particles.draw_pass_1 = op_draw
	add_child(orbit_particles)

	# Base embers — warm particles rising from the base
	var ember_particles := GPUParticles3D.new()
	ember_particles.amount = 200
	ember_particles.lifetime = 4.0
	ember_particles.position = Vector3(0, 1, 0)
	var ep_mat := ParticleProcessMaterial.new()
	ep_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	ep_mat.emission_ring_radius = 6.0
	ep_mat.emission_ring_inner_radius = 4.0
	ep_mat.emission_ring_height = 0.1
	ep_mat.emission_ring_axis = Vector3(0, 1, 0)
	ep_mat.direction = Vector3(0, 1, 0)
	ep_mat.spread = 15.0
	ep_mat.initial_velocity_min = 0.5
	ep_mat.initial_velocity_max = 1.5
	ep_mat.gravity = Vector3(0, 0, 0)
	ep_mat.scale_min = 0.01
	ep_mat.scale_max = 0.04
	ep_mat.color = Color(0.95, 0.5, 0.08, 0.7)
	ember_particles.process_material = ep_mat
	var ep_draw := SphereMesh.new()
	ep_draw.radius = 0.02
	ep_draw.height = 0.04
	ember_particles.draw_pass_1 = ep_draw
	add_child(ember_particles)

	# ========================================
	# SCANNER BEAM — rotating lighthouse sweep
	# ========================================
	var scanner := MeshInstance3D.new()
	var scanner_mesh := BoxMesh.new()
	scanner_mesh.size = Vector3(80.0, 0.3, 0.15)  # Long, thin, flat
	scanner.mesh = scanner_mesh
	scanner.position = Vector3(0, 8.0, 0)
	scanner.name = "ScannerBeam"
	var scan_mat := StandardMaterial3D.new()
	scan_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	scan_mat.albedo_color = Color(0.1, 0.3, 0.9, 0.15)
	scan_mat.emission_enabled = true
	scan_mat.emission = Color(0.08, 0.2, 0.7)
	scan_mat.emission_energy_multiplier = 2.0
	scan_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scanner.set_surface_override_material(0, scan_mat)
	add_child(scanner)

	# Second scanner at different height and speed
	var scanner2 := MeshInstance3D.new()
	var scanner2_mesh := BoxMesh.new()
	scanner2_mesh.size = Vector3(60.0, 0.2, 0.1)
	scanner2.mesh = scanner2_mesh
	scanner2.position = Vector3(0, 20.0, 0)
	scanner2.name = "ScannerBeam2"
	var scan_mat2 := StandardMaterial3D.new()
	scan_mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	scan_mat2.albedo_color = Color(0.8, 0.3, 0.05, 0.1)
	scan_mat2.emission_enabled = true
	scan_mat2.emission = Color(0.7, 0.25, 0.05)
	scan_mat2.emission_energy_multiplier = 1.5
	scan_mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scanner2.set_surface_override_material(0, scan_mat2)
	add_child(scanner2)

	# ========================================
	# NEXUS LABEL
	# ========================================
	var label := Label3D.new()
	label.text = "N E X U S"
	label.font_size = 72
	label.modulate = Color(0.95, 0.7, 0.15, 0.95)
	label.position = Vector3(0, 34, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.outline_modulate = Color(0.4, 0.2, 0.0, 0.6)
	add_child(label)

	# Sub-label with vault stats
	var stats_label := Label3D.new()
	stats_label.text = "%d NODES | %d LINKS" % [VaultDataBus.graph.get_note_count(), VaultDataBus.graph.get_link_count()]
	stats_label.font_size = 24
	stats_label.modulate = Color(0.4, 0.6, 0.95, 0.7)
	stats_label.position = Vector3(0, 32.5, 0)
	stats_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(stats_label)

	# Store reference to core for AI state feedback
	_core_mesh_instance = core

	# Connect to NexusAI signals (deferred to ensure NexusAI is ready)
	call_deferred("_connect_ai_signals")

	# ========================================
	# COLLISION
	# ========================================
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 6.0
	shape.height = 32.0
	col.shape = shape
	col.position = Vector3(0, 16, 0)
	body.add_child(col)
	body.set_meta("is_hub", true)
	body.set_meta("note_id", "__nexus_hub__")
	add_child(body)

func _process(delta: float) -> void:
	# Rotate all rings at configured speeds, modified by AI state
	for i in range(_rings.size()):
		if i < _ring_base_speeds.size():
			_rings[i].rotate_y(delta * _ring_base_speeds[i] * _ring_speed_multiplier)

	# Slowly orbit the holographic panels
	for i in range(_hologram_panels.size()):
		var panel: Node3D = _hologram_panels[i]
		var speed := 0.03 + float(i) * 0.005
		panel.rotate_y(delta * speed)
		# Bob up and down slightly
		panel.position.y += sin(Time.get_ticks_msec() * 0.001 + float(i)) * delta * 0.3

	# Rotate scanner beams (stopped during LISTENING state)
	if _scanner_active:
		var scanner = get_node_or_null("ScannerBeam")
		if scanner:
			scanner.rotate_y(delta * 0.4)
		var scanner2 = get_node_or_null("ScannerBeam2")
		if scanner2:
			scanner2.rotate_y(-delta * 0.25)

	# Fade query beams after response completes
	if _query_beam_fade_timer > 0:
		_query_beam_fade_timer -= delta
		var alpha_factor: float = _query_beam_fade_timer / QUERY_BEAM_FADE_DURATION
		for beam in _query_beams:
			if is_instance_valid(beam):
				var mat: StandardMaterial3D = beam.get_surface_override_material(0)
				if mat:
					mat.albedo_color.a = 0.6 * alpha_factor
					mat.emission_energy_multiplier = 5.0 * alpha_factor
		if _query_beam_fade_timer <= 0:
			_clear_query_beams()

	# Pulse core emission during SPEAKING state synced to audio amplitude
	if _ai_state == NexusAI.State.SPEAKING and _core_mesh_instance:
		var tts_player: AudioStreamPlayer = NexusAI.get_tts_player()
		if tts_player and tts_player.playing:
			# Approximate amplitude from playback position timing
			var wobble: float = sin(Time.get_ticks_msec() * 0.008) * 0.3
			var mat: StandardMaterial3D = _core_mesh_instance.get_surface_override_material(0)
			if mat:
				mat.emission_energy_multiplier = _core_base_emission + wobble * _core_base_emission

	# Energy pulse waves
	_pulse_timer += delta
	if _pulse_timer >= PULSE_INTERVAL:
		_pulse_timer = 0.0
		_spawn_pulse()

	# Update existing pulses
	var to_remove: Array[int] = []
	for i in range(_pulse_rings.size()):
		var ring: MeshInstance3D = _pulse_rings[i]
		var current_radius: float = ring.get_meta("radius", 1.0)
		current_radius += PULSE_SPEED * delta
		ring.set_meta("radius", current_radius)
		# Update torus size
		var tmesh := ring.mesh as TorusMesh
		tmesh.inner_radius = current_radius - 0.15
		tmesh.outer_radius = current_radius + 0.15
		# Fade out as it expands
		var alpha: float = 1.0 - (current_radius / PULSE_MAX_RADIUS)
		var mat: StandardMaterial3D = ring.get_surface_override_material(0)
		if mat:
			mat.albedo_color.a = alpha * 0.4
			mat.emission_energy_multiplier = alpha * 4.0
		if current_radius >= PULSE_MAX_RADIUS:
			to_remove.append(i)

	for i in range(to_remove.size() - 1, -1, -1):
		_pulse_rings[to_remove[i]].queue_free()
		_pulse_rings.remove_at(to_remove[i])

func _spawn_pulse() -> void:
	var ring := MeshInstance3D.new()
	var rmesh := TorusMesh.new()
	rmesh.inner_radius = 5.0
	rmesh.outer_radius = 5.3
	ring.mesh = rmesh
	ring.position = Vector3(0, 0.1, 0)
	ring.set_meta("radius", 5.0)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(0.15, 0.35, 0.95, 0.4)
	rmat.emission_enabled = true
	rmat.emission = Color(0.1, 0.3, 0.9)
	rmat.emission_energy_multiplier = 4.0
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.set_surface_override_material(0, rmat)
	add_child(ring)
	_pulse_rings.append(ring)

# ─── AI Signal Handlers ──────────────────────────────────────────

func _connect_ai_signals() -> void:
	if not NexusAI:
		return
	NexusAI.state_changed.connect(_on_ai_state_changed)
	NexusAI.response_complete.connect(_on_ai_response_complete)
	NexusAI.navigation_command.connect(_on_navigation_command)
	print("NexusHub: connected to NexusAI signals")

func _on_ai_state_changed(new_state: NexusAI.State) -> void:
	_ai_state = new_state
	match new_state:
		NexusAI.State.IDLE:
			_ring_speed_multiplier = 1.0
			_scanner_active = true
			_remove_thinking_particles()
		NexusAI.State.LISTENING:
			# 2x brightness on core, slow rings to 50%
			_ring_speed_multiplier = 0.5
			_scanner_active = false
			if _core_mesh_instance:
				var mat: StandardMaterial3D = _core_mesh_instance.get_surface_override_material(0)
				if mat:
					mat.emission_energy_multiplier = _core_base_emission * 2.0
		NexusAI.State.TRANSCRIBING:
			_ring_speed_multiplier = 1.0
		NexusAI.State.THINKING:
			# Orange pulse on core, 3x ring speed
			_ring_speed_multiplier = 3.0
			_scanner_active = true
			if _core_mesh_instance:
				var mat: StandardMaterial3D = _core_mesh_instance.get_surface_override_material(0)
				if mat:
					mat.emission = Color(0.9, 0.5, 0.1)
					mat.emission_energy_multiplier = _core_base_emission * 1.5
		NexusAI.State.SPEAKING:
			# Normal speed + wobble, core back to blue
			_ring_speed_multiplier = 1.0
			_scanner_active = true
			if _core_mesh_instance:
				var mat: StandardMaterial3D = _core_mesh_instance.get_surface_override_material(0)
				if mat:
					mat.emission = Color(0.2, 0.4, 0.95)
					mat.emission_energy_multiplier = _core_base_emission

func _on_ai_response_complete(full_text: String, referenced_notes: Array) -> void:
	# Spawn query beams from referenced towers toward hub
	_clear_query_beams()
	if referenced_notes.is_empty():
		return
	var city_layer: Node3D = get_parent()
	if not city_layer or not city_layer.has_method("get_tower_positions"):
		return
	var tower_positions: Dictionary = city_layer.get_tower_positions()
	for note_id in referenced_notes:
		if tower_positions.has(note_id):
			var tower_pos: Vector3 = tower_positions[note_id]
			var hub_pos: Vector3 = global_position + Vector3(0, 20, 0)
			_spawn_query_beam(tower_pos, hub_pos)
	_query_beam_fade_timer = QUERY_BEAM_FADE_DURATION

func _on_navigation_command(_target_note_id: String, _action: String) -> void:
	# Visual pulse on referenced towers handled by city_layer
	pass

func _spawn_query_beam(from: Vector3, to: Vector3) -> void:
	var beam := MeshInstance3D.new()
	var direction: Vector3 = to - from
	var length: float = direction.length()
	var midpoint: Vector3 = from + direction * 0.5

	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(0.15, length, 0.15)
	beam.mesh = bmesh
	beam.position = midpoint - global_position  # Local to hub

	# Orient beam along the from→to direction
	beam.look_at_from_position(midpoint - global_position, to - global_position, Vector3.UP)
	beam.rotate_object_local(Vector3(1, 0, 0), PI / 2.0)

	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(0.2, 0.5, 1.0, 0.6)
	bmat.emission_enabled = true
	bmat.emission = Color(0.15, 0.4, 0.95)
	bmat.emission_energy_multiplier = 5.0
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.set_surface_override_material(0, bmat)
	add_child(beam)
	_query_beams.append(beam)

func _clear_query_beams() -> void:
	for beam in _query_beams:
		if is_instance_valid(beam):
			beam.queue_free()
	_query_beams.clear()
	_query_beam_fade_timer = 0.0

func _remove_thinking_particles() -> void:
	if _thinking_particles and is_instance_valid(_thinking_particles):
		_thinking_particles.queue_free()
		_thinking_particles = null
