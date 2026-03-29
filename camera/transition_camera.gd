extends Camera3D

signal transition_completed()

var _tween: Tween

func animate_to(target_pos: Vector3, target_rot: Vector3, duration: float = 1.5) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "global_position", target_pos, duration)
	_tween.tween_property(self, "rotation", target_rot, duration)
	_tween.set_parallel(false)
	_tween.tween_callback(func(): transition_completed.emit())
