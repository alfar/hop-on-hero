extends GutTest

func _make_enemy_with_fast_fade() -> Node2D:
	var enemy := WeaponTestHelpers.make_enemy(self)
	enemy.death_fade_duration = 0.1
	return enemy

func test_died_stops_movement_and_disables_hit_area_immediately() -> void:
	var enemy := _make_enemy_with_fast_fade()
	var moving_behavior := TargetMovementBehavior.new()
	moving_behavior.target = Vector2(500, 0)
	moving_behavior.speed = 400
	enemy.movement_behavior = moving_behavior

	var health: HealthComponent = enemy.get_node("Status").get_node("HealthComponent")
	health.died.emit()

	# Both effects must be visible immediately (same frame died fires), before
	# any await -- only the fade's completion is asynchronous.
	assert_eq(enemy.movement_behavior.get_velocity(enemy.position), Vector2.ZERO, "movement should stop as soon as died fires")
	assert_false(enemy.get_node("HitArea").monitoring, "HitArea should stop monitoring as soon as died fires")

func test_died_fades_out_and_frees_the_enemy() -> void:
	var enemy := _make_enemy_with_fast_fade()

	var health: HealthComponent = enemy.get_node("Status").get_node("HealthComponent")
	assert_eq(enemy.modulate.a, 1.0)

	health.died.emit()
	await wait_seconds(enemy.death_fade_duration + 0.1)

	assert_true(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(), "enemy should be freed after the fade-out completes")

func test_dead_enemy_deals_no_further_contact_damage() -> void:
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var enemy := _make_enemy_with_fast_fade()
	var weapon_component: FixedDamageWeaponComponent = enemy.get_node("WeaponSystem").get_node("FixedDamageWeaponComponent")
	weapon_component.damage = 100
	var player: Node2D = add_child_autofree(player_scene.instantiate())
	enemy.global_position = player.global_position

	var health: HealthComponent = enemy.get_node("Status").get_node("HealthComponent")
	health.died.emit()
	await wait_physics_frames(2)

	var player_health: HealthComponent = player.get_node("Status").get_node("HealthComponent")
	var health_after_death := player_health.current_health

	# Enemy and player are already overlapping; give physics a few more
	# frames to prove no further contact damage occurs while the (disabled)
	# HitArea would otherwise still be touching the player.
	await wait_physics_frames(5)

	assert_eq(player_health.current_health, health_after_death, "a dead enemy's disabled HitArea should not deal further contact damage")
