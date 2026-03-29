extends Node

signal note_hovered(note_id: String)
signal note_unhovered()
signal note_clicked(note_id: String)
signal search_requested()
signal tag_filter_requested()

var _raycast_distance := 100.0
var _hovered_note_id: String = ""

func _physics_process(_delta: float) -> void:
	_update_hover()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _hovered_note_id.is_empty():
			note_clicked.emit(_hovered_note_id)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SLASH:
			search_requested.emit()
		elif event.keycode == KEY_T:
			tag_filter_requested.emit()

func _update_hover() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * _raycast_distance

	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)

	if result:
		var collider = result["collider"]
		var node = collider
		while node:
			if node.has_meta("note_id"):
				var note_id: String = node.get_meta("note_id")
				if note_id != _hovered_note_id:
					_hovered_note_id = note_id
					note_hovered.emit(note_id)
				return
			node = node.get_parent()

	if not _hovered_note_id.is_empty():
		_hovered_note_id = ""
		note_unhovered.emit()
