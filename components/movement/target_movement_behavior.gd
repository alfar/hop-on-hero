class_name TargetMovementBehavior
extends MovementBehavior

@export var target: Vector2
@export var speed = 400;

func get_velocity(position: Vector2):
	if (position.distance_to(target) < 10):
		return Vector2.ZERO
	
	return position.direction_to(target) * speed;
