extends Control
## Draws a top-down 2D map of the city with clickable note dots

var _positions: Dictionary = {}  # note_id → Vector3 (world position)
var _graph: RefCounted = null     # NoteGraph
var _city_size := Vector2(120, 120)
var _dot_data: Array = []  # [{note_id, screen_pos, color, radius}]
var _hovered_dot: String = ""

func set_data(positions: Dictionary, graph: RefCounted) -> void:
	_positions = positions
	_graph = graph
	_build_dots()
	queue_redraw()

func _build_dots() -> void:
	_dot_data.clear()
	if _positions.is_empty() or not _graph:
		return

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var margin := 60.0
	var map_area := Vector2(vp_size.x - margin * 2, vp_size.y - margin * 2 - 40)  # -40 for title

	for note_id in _positions:
		var world_pos: Vector3 = _positions[note_id]
		# Map world XZ to screen XY
		var screen_x: float = margin + (world_pos.x / _city_size.x) * map_area.x
		var screen_y: float = margin + 40 + (world_pos.z / _city_size.y) * map_area.y

		var conns: int = _graph.get_connection_count(note_id)
		var temperature: float = clampf(conns / 20.0, 0.0, 1.0)
		var color := Color(0.1, 0.25, 0.8).lerp(Color(0.95, 0.5, 0.1), temperature)
		var radius: float = 3.0 + temperature * 5.0

		_dot_data.append({
			"note_id": note_id,
			"screen_pos": Vector2(screen_x, screen_y),
			"color": color,
			"radius": radius,
		})

func _draw() -> void:
	# Grid background
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var margin := 60.0
	var map_area := Vector2(vp_size.x - margin * 2, vp_size.y - margin * 2 - 40)
	var origin := Vector2(margin, margin + 40)

	# Grid lines
	var grid_step := 20.0
	var grid_color := Color(0.08, 0.12, 0.35, 0.3)
	var x_steps: int = int(map_area.x / grid_step)
	for i in range(x_steps + 1):
		var x: float = origin.x + i * grid_step
		draw_line(Vector2(x, origin.y), Vector2(x, origin.y + map_area.y), grid_color, 1.0)
	var y_steps: int = int(map_area.y / grid_step)
	for i in range(y_steps + 1):
		var y: float = origin.y + i * grid_step
		draw_line(Vector2(origin.x, y), Vector2(origin.x + map_area.x, y), grid_color, 1.0)

	# Border
	draw_rect(Rect2(origin, map_area), Color(0.1, 0.15, 0.5, 0.5), false, 2.0)

	# Draw dots
	for dot in _dot_data:
		var pos: Vector2 = dot["screen_pos"]
		var color: Color = dot["color"]
		var radius: float = dot["radius"]
		var is_hovered: bool = dot["note_id"] == _hovered_dot

		if is_hovered:
			# Hovered — bright ring + label
			draw_circle(pos, radius + 3, Color(1, 1, 1, 0.3))
			draw_circle(pos, radius, color * 1.5)
			var note = _graph.get_note(dot["note_id"])
			if note:
				var font := ThemeDB.fallback_font
				draw_string(font, pos + Vector2(radius + 6, 4), note.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.88, 0.95))
		else:
			draw_circle(pos, radius, color)

	# Player position indicator
	var cam = get_viewport().get_camera_3d()
	if cam:
		var cam_world: Vector3 = cam.global_position
		var cam_screen_x: float = margin + (cam_world.x / _city_size.x) * map_area.x
		var cam_screen_y: float = margin + 40 + (cam_world.z / _city_size.y) * map_area.y
		var cam_pos := Vector2(cam_screen_x, cam_screen_y)
		# White crosshair for player
		draw_line(cam_pos + Vector2(-8, 0), cam_pos + Vector2(8, 0), Color.WHITE, 2.0)
		draw_line(cam_pos + Vector2(0, -8), cam_pos + Vector2(0, 8), Color.WHITE, 2.0)
		draw_circle(cam_pos, 4, Color(1, 1, 1, 0.6))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		_hovered_dot = ""
		for dot in _dot_data:
			if mouse_pos.distance_to(dot["screen_pos"]) < dot["radius"] + 5:
				_hovered_dot = dot["note_id"]
				break
		queue_redraw()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _hovered_dot.is_empty():
			# Teleport player
			var ui_mgr = get_node("/root/UIManager")
			if ui_mgr and ui_mgr.has_method("_teleport_to_note"):
				ui_mgr._teleport_to_note(_hovered_dot)
