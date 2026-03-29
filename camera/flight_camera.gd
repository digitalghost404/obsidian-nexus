extends Camera3D

@export var base_speed: float = 20.0
@export var fast_speed: float = 60.0
@export var mouse_sensitivity: float = 0.002
@export var scroll_speed_step: float = 5.0

var _velocity: Vector3 = Vector3.ZERO
var _speed_multiplier: float = 1.0
var _mouse_captured: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true
	current = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		rotate_y(-event.relative.x * mouse_sensitivity)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
		rotation.x = clampf(rotation.x, -PI / 2.0, PI / 2.0)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _mouse_captured:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_mouse_captured = false
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_mouse_captured = true

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_speed_multiplier = clampf(_speed_multiplier + 0.2, 0.2, 5.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_speed_multiplier = clampf(_speed_multiplier - 0.2, 0.2, 5.0)

func _physics_process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += transform.basis.x
	if Input.is_key_pressed(KEY_Q):
		input_dir -= transform.basis.y
	if Input.is_key_pressed(KEY_E):
		input_dir += transform.basis.y

	input_dir = input_dir.normalized()
	var speed := fast_speed if Input.is_key_pressed(KEY_SHIFT) else base_speed
	speed *= _speed_multiplier
	_velocity = _velocity.lerp(input_dir * speed, 10.0 * delta)
	position += _velocity * delta
