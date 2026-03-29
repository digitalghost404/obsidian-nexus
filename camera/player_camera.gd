extends CharacterBody3D

@export var walk_speed: float = 8.0
@export var sprint_speed: float = 16.0
@export var mouse_sensitivity: float = 0.002
@export var camera_height: float = 1.7

var _spawn_frames: int = 0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.position.y = camera_height
	camera.current = true
	_spawn_frames = 0

func _unhandled_input(event: InputEvent) -> void:
	# Only process mouse look when cursor is captured (not when UI overlay is open)
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		print("POS: position=%s rotation=%s" % [str(global_position), str(rotation)])
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.0, PI / 2.0)

func _physics_process(delta: float) -> void:
	_spawn_frames += 1

	# Don't move when UI overlay is open
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		velocity = Vector3.ZERO
		return

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

	if _spawn_frames > 10:
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = 0
	else:
		velocity.y = 0

	move_and_slide()
