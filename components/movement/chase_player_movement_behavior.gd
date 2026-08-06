class_name ChasePlayerMovementBehavior
extends MovementBehavior

## Not @export: Godot 4.7 fails to compile a Resource script that @exports a
## Node-derived type. Set by whoever constructs this behavior (BossActivity).
var player: Node2D
@export var speed = 400

func get_velocity(position: Vector2):
	if not is_instance_valid(player):
		return Vector2.ZERO

	return position.direction_to(player.global_position) * speed
