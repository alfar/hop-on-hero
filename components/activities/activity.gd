class_name Activity
extends Resource

@export var gate: ActivityGate = TimerActivityGate.new()
@export var weight: float = 1.0

func execute(_rng: RandomNumberGenerator, _world_size: Vector2, _spawn_parent: Node) -> void:
	pass
