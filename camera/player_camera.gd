extends CharacterBody3D

@export var walk_speed: float = 8.0
@export var sprint_speed: float = 16.0
@export var mouse_sensitivity: float = 0.002
@export var camera_height: float = 1.7

var _mouse_captured: bool = false
var _spawn_frames: int = 0  # Grace period before enabling gravity

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true
	camera.position.y = camera_height
	_spawn_frames = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.0, PI / 2.0)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_mouse_captured = not _mouse_captured
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	_spawn_frames += 1

	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	input_dir = input_dir.normalized()
	input_dir = transform.basis * input_dir

	var speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed

	# Don't apply gravity for the first 10 frames — let physics register floor collision
	if _spawn_frames > 10:
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = 0
	else:
		velocity.y = 0

	move_and_slide()
