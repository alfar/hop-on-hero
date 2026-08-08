## Shared setup helpers for weapon integration tests. Not a test itself.
class_name WeaponTestHelpers
extends RefCounted

## Instances enemy.tscn under test_context (via add_child_autofree, so GUT
## still owns its lifecycle) and gives it a no-op (empty) MovementStack, since
## enemy.tscn has none by default (only game.tscn/BossActivity supply one).
static func make_enemy(test_context: GutTest) -> Node2D:
	var enemy_scene: PackedScene = load("res://scenes/enemy/enemy.tscn")
	var enemy: Node2D = test_context.add_child_autofree(enemy_scene.instantiate())
	enemy.movement_behavior = MovementStack.new()
	return enemy

## Instances player.tscn under test_context (via add_child_autofree) and wires
## Player.weapon_spawn_parent to itself, since player.tscn has none by default
## (only game.tscn's override wires it to the game root) -- without this,
## TimerWeaponTrigger's spawn_parent stays null and crashes the first time its
## interval elapses during a test.
static func make_player(test_context: GutTest) -> Node2D:
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var player: Node2D = player_scene.instantiate()
	player.weapon_spawn_parent = player
	return test_context.add_child_autofree(player)
