extends Node

## Simplified layer manager — single city scene, no transitions
## Graph view removed due to Godot scene-swap issues

var current_scene: Node3D = null
var current_camera: Node = null

func load_city() -> void:
	var main_node: Node = get_tree().root.get_node("Main")

	var scene_res = load("res://layers/city/city_layer.tscn")
	var scene_instance: Node3D = scene_res.instantiate() as Node3D

	var cam_res = load("res://camera/player_camera.tscn")
	var cam_instance = cam_res.instantiate()

	main_node.add_child(scene_instance)
	main_node.add_child(cam_instance)

	cam_instance.position = Vector3(60, 2, 60)

	current_scene = scene_instance
	current_camera = cam_instance
	print("LayerManager: city loaded, camera at (60, 2, 60)")
