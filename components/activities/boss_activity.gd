class_name BossActivity
extends Activity

@export var boss_scene: PackedScene
@export var min_target_distance: float = 200.0

func execute(rng: RandomNumberGenerator, world_size: Vector2, spawn_parent: Node) -> void:
	if boss_scene == null:
		push_error("BossActivity: boss_scene is not set.")
		return

	var spawn_position := Vector2(rng.randf_range(0, world_size.x), rng.randf_range(0, world_size.y))
	var angle := rng.randf_range(0, TAU)
	var direction := Vector2.RIGHT.rotated(angle)

	var max_distance := _max_reachable_distance(spawn_position, direction, world_size)
	var target_distance: float
	if max_distance < min_target_distance:
		# min_target_distance isn't reachable in this direction within the world bounds;
		# clamp to the farthest reachable point instead of retrying, to guarantee termination.
		target_distance = max_distance
	else:
		target_distance = rng.randf_range(min_target_distance, max_distance)

	var target := spawn_position + direction * target_distance

	var instance := boss_scene.instantiate()
	instance.position = spawn_position

	var player := spawn_parent.get_tree().get_first_node_in_group("player") as Node2D

	var stack := MovementStack.new()

	var chase_behavior := ChasePlayerMovementBehavior.new()
	chase_behavior.player = player
	chase_behavior.speed = 300
	stack.push_behavior(chase_behavior)

	var behavior := TargetMovementBehavior.new()
	behavior.target = target
	behavior.speed = 200
	stack.push_behavior(behavior)

	instance.movement_behavior = stack

	spawn_parent.add_child.call_deferred(instance)

func _max_reachable_distance(origin: Vector2, direction: Vector2, world_size: Vector2) -> float:
	var distance := INF

	if direction.x > 0:
		distance = min(distance, (world_size.x - origin.x) / direction.x)
	elif direction.x < 0:
		distance = min(distance, -origin.x / direction.x)

	if direction.y > 0:
		distance = min(distance, (world_size.y - origin.y) / direction.y)
	elif direction.y < 0:
		distance = min(distance, -origin.y / direction.y)

	return distance
