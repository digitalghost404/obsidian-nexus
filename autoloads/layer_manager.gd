extends Node

enum Layer { GRAPH, CITY, CORRIDOR }

var current_layer: Layer = Layer.CITY
var current_scene: Node3D = null
var current_camera: Node = null
var _transition_overlay: ColorRect
var _is_transitioning: bool = false

signal layer_changed(new_layer: Layer)
signal transition_started()
signal transition_completed()

const SCENES := {
	Layer.GRAPH: "res://layers/graph/graph_layer.tscn",
	Layer.CITY: "res://layers/city/city_layer.tscn",
	Layer.CORRIDOR: "res://layers/corridor/corridor_layer.tscn",
}

const CAMERAS := {
	Layer.GRAPH: "res://camera/flight_camera.tscn",
	Layer.CITY: "res://camera/player_camera.tscn",
	Layer.CORRIDOR: "res://camera/player_camera.tscn",
}

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	_transition_overlay = ColorRect.new()
	_transition_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_transition_overlay.color = Color(0.0, 0.0, 0.02, 1.0)
	_transition_overlay.visible = false
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_transition_overlay)
	add_child(canvas)

func load_layer(layer: Layer, context: Dictionary = {}) -> void:
	var scene_res = load(SCENES[layer])
	if not scene_res:
		push_error("LayerManager: Failed to load scene %s" % SCENES[layer])
		return
	var scene_instance: Node3D = scene_res.instantiate() as Node3D
	if not scene_instance:
		push_error("LayerManager: Failed to instantiate scene %s" % SCENES[layer])
		return

	if layer == Layer.CORRIDOR and context.has("note_id"):
		scene_instance.set("current_note_id", context["note_id"])

	var cam_res = load(CAMERAS[layer])
	var cam_instance = cam_res.instantiate()

	var main_node: Node = get_tree().root.get_node("Main")
	main_node.add_child(scene_instance)
	main_node.add_child(cam_instance)

	if context.has("camera_position"):
		cam_instance.global_position = context["camera_position"]
	elif layer == Layer.GRAPH:
		cam_instance.position = Vector3(0, 30, 80)
	elif layer == Layer.CITY:
		cam_instance.position = Vector3(60, 2, 60)
	elif layer == Layer.CORRIDOR:
		cam_instance.position = Vector3(0, 1, 2)

	current_scene = scene_instance
	current_camera = cam_instance
	current_layer = layer
	print("LayerManager: loaded %s" % Layer.keys()[layer])
	layer_changed.emit(layer)

func transition_to(target_layer: Layer, context: Dictionary = {}) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	transition_started.emit()

	# Fade to black
	_transition_overlay.color = Color(0, 0, 0.02, 0)
	_transition_overlay.visible = true
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color:a", 1.0, 0.4)
	await tween.finished

	# Swap scenes
	if current_scene:
		current_scene.queue_free()
	if current_camera:
		current_camera.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	load_layer(target_layer, context)

	# Wait for scene to initialize
	await get_tree().process_frame

	# Fade from black
	var tween2 := create_tween()
	tween2.tween_property(_transition_overlay, "color:a", 0.0, 0.6)
	await tween2.finished
	_transition_overlay.visible = false

	_is_transitioning = false
	transition_completed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			if current_layer == Layer.CORRIDOR:
				transition_to(Layer.CITY, {"camera_position": Vector3(60, 2, 60)})
			elif current_layer == Layer.CITY:
				transition_to(Layer.GRAPH)
