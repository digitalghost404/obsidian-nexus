extends Node

enum Layer { GRAPH, CITY, CORRIDOR }

var current_layer: Layer = Layer.CITY
var current_scene: Node3D = null
var current_camera: Node = null
var _transition_overlay: ColorRect
var _transition_material: ShaderMaterial

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
	_transition_overlay.visible = false
	var shader = load("res://shaders/layer_shift.gdshader")
	_transition_material = ShaderMaterial.new()
	_transition_material.shader = shader
	_transition_overlay.material = _transition_material
	canvas.add_child(_transition_overlay)
	add_child(canvas)

func load_layer(layer: Layer, context: Dictionary = {}) -> void:
	var scene_res = load(SCENES[layer])
	var scene_instance = scene_res.instantiate()

	if layer == Layer.CORRIDOR and context.has("note_id"):
		scene_instance.current_note_id = context["note_id"]

	var cam_res = load(CAMERAS[layer])
	var cam_instance = cam_res.instantiate()

	if context.has("camera_position"):
		cam_instance.global_position = context["camera_position"]
	elif layer == Layer.GRAPH:
		cam_instance.position = Vector3(0, 30, 80)
	elif layer == Layer.CITY:
		cam_instance.position = Vector3(150, 2, 150)
	elif layer == Layer.CORRIDOR:
		cam_instance.position = Vector3(0, 1, 2)

	get_tree().root.get_node("Main").add_child(scene_instance)
	get_tree().root.get_node("Main").add_child(cam_instance)

	current_scene = scene_instance
	current_camera = cam_instance
	current_layer = layer
	layer_changed.emit(layer)

func transition_to(target_layer: Layer, context: Dictionary = {}) -> void:
	transition_started.emit()

	_transition_overlay.visible = true
	var tween := create_tween()
	tween.tween_method(func(v): _transition_material.set_shader_parameter("progress", v), 0.0, 1.0, 0.75)
	await tween.finished

	if current_scene:
		current_scene.queue_free()
	if current_camera:
		current_camera.queue_free()

	await get_tree().process_frame

	load_layer(target_layer, context)

	var tween2 := create_tween()
	tween2.tween_method(func(v): _transition_material.set_shader_parameter("progress", v), 1.0, 0.0, 0.75)
	await tween2.finished
	_transition_overlay.visible = false

	transition_completed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			if current_layer == Layer.CORRIDOR:
				var ctx := {"camera_position": Vector3(150, 2, 150)}
				transition_to(Layer.CITY, ctx)
			elif current_layer == Layer.CITY:
				transition_to(Layer.GRAPH)
