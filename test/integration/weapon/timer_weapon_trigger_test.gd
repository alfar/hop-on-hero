extends GutTest

func _make_spawn_parent() -> Node:
	var spawn_parent := Node.new()
	add_child_autofree(spawn_parent)
	return spawn_parent

func _make_player_with_spawn_parent(spawn_parent: Node) -> Node2D:
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var player: Node2D = add_child_autofree(player_scene.instantiate())
	var trigger: TimerWeaponTrigger = player.get_node("TimerWeaponTrigger")
	trigger.spawn_parent = spawn_parent
	return player

func test_fires_at_nearest_enemy_and_spawns_a_projectile() -> void:
	# Kept within [0, 1600]x[0, 1200] (the world bounds other tests in this
	# suite emit via GameEvents.world_size_changed, a cached autoload value
	# that persists across tests) so the spawned projectile doesn't
	# self-destruct as "out of bounds" before this test inspects it.
	var player_origin := Vector2(200, 200)
	var near_enemy := WeaponTestHelpers.make_enemy(self)
	var far_enemy := WeaponTestHelpers.make_enemy(self)
	var spawn_parent := _make_spawn_parent()
	var player := _make_player_with_spawn_parent(spawn_parent)
	player.global_position = player_origin

	# Placed far enough away that the fast-moving projectile (default speed
	# 600) won't reach and self-destruct against either enemy within the one
	# frame this test waits before inspecting it. Each test uses a distinct,
	# widely-separated origin so a not-yet-freed enemy/projectile left over
	# from another test (autofree defers queue_free) can never be closer to
	# this test's player than its own intended target.
	near_enemy.global_position = player_origin + Vector2(500, 0)
	far_enemy.global_position = player_origin + Vector2(1000, 0)

	var trigger: TimerWeaponTrigger = player.get_node("TimerWeaponTrigger")
	trigger._on_timeout()
	await wait_physics_frames(1)

	var found: Projectile = null
	for child in spawn_parent.get_children():
		if child is Projectile:
			found = child
	assert_not_null(found, "a projectile should have been spawned")
	if found:
		assert_almost_eq(found.direction.angle(), Vector2.RIGHT.angle(), 0.01, "projectile should aim at the nearer enemy")

func test_does_not_fire_when_no_enemy_exists() -> void:
	var spawn_parent := _make_spawn_parent()
	var player := _make_player_with_spawn_parent(spawn_parent)
	player.global_position = Vector2(50000, 0)

	var trigger: TimerWeaponTrigger = player.get_node("TimerWeaponTrigger")
	trigger._on_timeout()
	await wait_physics_frames(1)

	var found_projectile := false
	for child in spawn_parent.get_children():
		if child is Projectile:
			found_projectile = true
	assert_false(found_projectile, "no projectile should be spawned without an enemy target")

func test_spawned_projectile_carries_damage_computed_at_fire_time() -> void:
	# Kept within [0, 1600]x[0, 1200] (the world bounds other tests in this
	# suite emit via GameEvents.world_size_changed, a cached autoload value
	# that persists across tests) so the spawned projectile doesn't
	# self-destruct as "out of bounds" before this test inspects it. A large
	# but distinct y-offset from the other tests in this file still keeps
	# this test's own enemy unambiguously the nearest one.
	var player_origin := Vector2(200, 1100)
	var enemy := WeaponTestHelpers.make_enemy(self)
	var spawn_parent := _make_spawn_parent()
	var player := _make_player_with_spawn_parent(spawn_parent)
	player.global_position = player_origin
	enemy.global_position = player_origin + Vector2(500, 0)

	var weapon_system: WeaponSystem = player.get_node("WeaponSystem")
	var expected_damage: int = weapon_system.get_total_damage()

	var trigger: TimerWeaponTrigger = player.get_node("TimerWeaponTrigger")
	trigger._on_timeout()
	await wait_physics_frames(1)

	var found: Projectile = null
	for child in spawn_parent.get_children():
		if child is Projectile:
			found = child
	assert_not_null(found)
	if found:
		assert_eq(found.damage, expected_damage)
