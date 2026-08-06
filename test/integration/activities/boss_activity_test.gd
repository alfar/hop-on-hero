extends GutTest

## Covers AC-07/AC-08: BossActivity.execute() must resolve the "player" group
## member and inject it into a ChasePlayerMovementBehavior placed below the
## TargetMovementBehavior it always builds. Needs a live scene tree (for
## get_tree().get_first_node_in_group and the deferred add_child), so this
## lives under test/integration/ rather than test/unit/.
func test_execute_builds_stack_with_target_on_top_and_player_injected_below() -> void:
	var spawn_parent := Node.new()
	add_child_autofree(spawn_parent)

	var player := Node2D.new()
	player.add_to_group("player")
	spawn_parent.add_child(player)

	var activity := BossActivity.new()
	activity.boss_scene = load("res://scenes/enemy/enemy.tscn")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	activity.execute(rng, Vector2(1000, 800), spawn_parent)
	await wait_physics_frames(1)

	var enemy := spawn_parent.get_node("Enemy")
	autofree(enemy)

	var stack: MovementStack = enemy.movement_stack
	assert_eq(stack.behaviors.size(), 2, "stack should contain both the chase-player and target behaviors")

	var chase_behavior: ChasePlayerMovementBehavior = stack.behaviors[0]
	var target_behavior: TargetMovementBehavior = stack.behaviors[1]

	assert_true(chase_behavior is ChasePlayerMovementBehavior, "bottom of the stack should be the chase-player behavior")
	assert_eq(chase_behavior.player, player, "the resolved player group member should be injected into the chase-player behavior")
	assert_true(target_behavior is TargetMovementBehavior, "top of the stack should be the target behavior")

func test_execute_leaves_player_null_when_no_player_in_group() -> void:
	var spawn_parent := Node.new()
	add_child_autofree(spawn_parent)

	var activity := BossActivity.new()
	activity.boss_scene = load("res://scenes/enemy/enemy.tscn")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	activity.execute(rng, Vector2(1000, 800), spawn_parent)
	await wait_physics_frames(1)

	var enemy := spawn_parent.get_node("Enemy")
	autofree(enemy)

	var stack: MovementStack = enemy.movement_stack
	var chase_behavior: ChasePlayerMovementBehavior = stack.behaviors[0]

	assert_eq(chase_behavior.player, null, "no player in the group should leave the injected reference null")
