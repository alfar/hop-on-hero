class_name Activity
extends Resource

@export var next_interval_min: float = 20.0
@export var next_interval_max: float = 40.0

func execute(rng: RandomNumberGenerator, world_size: Vector2, spawn_parent: Node) -> void:
	pass

func get_next_interval(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(next_interval_min, next_interval_max)
