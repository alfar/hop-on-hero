class_name MovementStack
extends Resource

@export var behaviors: Array[MovementBehavior] = []

func push_behavior(behavior: MovementBehavior) -> void:
	behaviors.append(behavior)

func pop_behavior() -> MovementBehavior:
	return behaviors.pop_back()

func get_velocity(position: Vector2) -> Vector2:
	while behaviors.size() > 0 and behaviors[-1].is_finished(position):
		behaviors.pop_back()

	if behaviors.is_empty():
		return Vector2.ZERO

	return behaviors[-1].get_velocity(position)
