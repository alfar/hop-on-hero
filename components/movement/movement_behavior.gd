class_name MovementBehavior
extends Resource

func get_velocity(position: Vector2):
	return Vector2.ZERO

func is_finished(_position: Vector2) -> bool:
	return false
