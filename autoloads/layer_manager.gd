extends Node

enum Layer { GRAPH, CITY, CORRIDOR }

var current_layer: Layer = Layer.CITY
var current_scene: Node3D = null
var current_camera: Node = null

signal layer_changed(new_layer: Layer)

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

func load_layer(layer: Layer, context: Dictionary = {}) -> void:
	var main_node: Node = get_tree().root.get_node("Main")

	# Load new scene
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

	# Load new camera
	var cam_res = load(CAMERAS[layer])
	var cam_instance = cam_res.instantiate()

	# Add NEW nodes first — new camera's _ready sets current=true
	main_node.add_child(scene_instance)
	main_node.add_child(cam_instance)

	# Set camera position after adding to tree
	if context.has("camera_position"):
		cam_instance.global_position = context["camera_position"]
	elif layer == Layer.GRAPH:
		cam_instance.position = Vector3(0, 30, 80)
	elif layer == Layer.CITY:
		cam_instance.position = Vector3(60, 2, 60)
	elif layer == Layer.CORRIDOR:
		cam_instance.position = Vector3(0, 1, 2)
		cam_instance.rotation.y = PI

	# NOW queue_free the old nodes — safe, deferred cleanup
	if current_camera:
		current_camera.queue_free()
	if current_scene:
		current_scene.queue_free()

	current_scene = scene_instance
	current_camera = cam_instance
	current_layer = layer
	print("LayerManager: loaded %s, camera at %s" % [Layer.keys()[layer], str(cam_instance.position)])
	layer_changed.emit(layer)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				return
			if current_layer == Layer.CITY:
				load_layer(Layer.GRAPH)
			elif current_layer == Layer.GRAPH:
				load_layer(Layer.CITY)
