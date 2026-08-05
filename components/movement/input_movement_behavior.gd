class_name InputMovementBehavior
extends MovementBehavior

@export var speed = 400

func get_velocity(position: Vector2):
	var input_direction = Input.get_vector("left", "right", "up", "down")
	return input_direction * speed
