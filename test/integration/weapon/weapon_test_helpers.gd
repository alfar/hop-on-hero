## Shared setup helpers for weapon integration tests. Not a test itself.
class_name WeaponTestHelpers
extends RefCounted

## Instances enemy.tscn under test_context (via add_child_autofree, so GUT
## still owns its lifecycle) and gives it a no-op (empty) MovementStack, since
## enemy.tscn has none by default (only game.tscn/BossActivity supply one).
static func make_enemy(test_context: GutTest) -> Node2D:
	var enemy_scene: PackedScene = load("res://scenes/enemy/enemy.tscn")
	var enemy: Node2D = test_context.add_child_autofree(enemy_scene.instantiate())
	enemy.movement_stack = MovementStack.new()
	return enemy
