extends GutTest

## Guards against a real regression: game.tscn used to override
## Player/TimerWeaponTrigger.spawn_parent directly (a property override on a
## node nested inside the instanced Player scene). Godot's editor pruned that
## override as stale on save, silently leaving spawn_parent null. Fixed by
## exposing Player.weapon_spawn_parent as a top-level @export that Player
## itself forwards to its TimerWeaponTrigger child in _ready() -- the same
## stable "override a property on the instance itself" pattern already used
## by Enemy.movement_stack. This test instances the actual game.tscn (not
## Player/Enemy in isolation) so it exercises game.tscn's own override wiring,
## not just the component-level defaults.
func test_player_weapon_spawn_parent_resolves_to_game_root() -> void:
	var game_scene: PackedScene = load("res://scenes/game.tscn")
	var game: Node2D = add_child_autofree(game_scene.instantiate())
	await wait_physics_frames(1)

	var player := game.get_node("Player")
	var trigger := player.get_node("TimerWeaponTrigger")

	assert_eq(player.weapon_spawn_parent, game, "Player.weapon_spawn_parent should be wired to Game's root by game.tscn")
	assert_eq(trigger.spawn_parent, game, "TimerWeaponTrigger.spawn_parent should be forwarded from Player.weapon_spawn_parent")

func test_enemy_collision_layer_is_not_overridden_in_game_scene() -> void:
	var game_scene: PackedScene = load("res://scenes/game.tscn")
	var game: Node2D = add_child_autofree(game_scene.instantiate())
	await wait_physics_frames(1)

	# game.tscn no longer has a static Enemy node; "Enemy" here is the
	# BossActivity-spawned instance (ActivityManager fires its first
	# activity synchronously on world_loaded, so it already exists by the
	# time wait_physics_frames(1) above resolves).
	var enemy := game.get_node("Enemy")

	# Regression guard: an editor-added `collision_layer = 1` override on
	# game.tscn's Enemy instance once silently reset it back to Godot's
	# default layer, undoing enemy.tscn's own `collision_layer = 5`
	# (default + enemy) and breaking melee contact detection for any Enemy
	# instanced via game.tscn.
	assert_eq(enemy.collision_layer, 5, "Enemy.collision_layer must include the 'enemy' bit (5 = default + enemy) for melee contact detection to work")
