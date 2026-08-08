class_name TimerActivityGate
extends ActivityGate

@export var wait_min: float = 20.0
@export var wait_max: float = 40.0

var _target_duration: float = 0.0

func start(rng: RandomNumberGenerator, _spawn_parent: Node) -> void:
	_target_duration = rng.randf_range(wait_min, wait_max)

func is_ready(elapsed_time: float, _spawn_parent: Node) -> bool:
	return elapsed_time >= _target_duration
