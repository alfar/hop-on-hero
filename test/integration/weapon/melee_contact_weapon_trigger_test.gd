extends GutTest

func _make_enemy(damage: int = 100) -> Node2D:
	var enemy := WeaponTestHelpers.make_enemy(self)
	var weapon_component: FixedDamageWeaponComponent = enemy.get_node("WeaponSystem").components[0]
	weapon_component.damage = damage
	return enemy

## Moves body toward target_position in small steps, waiting a physics frame
## between each, so HitArea overlap is detected before the physical bodies
## interpenetrate deeply enough to trigger a large one-frame depenetration
## push (teleporting directly on top of another body skips overlap detection
## entirely, since move_and_slide's depenetration resolves faster than Area2D
## reports the overlap).
func _approach(body: Node2D, target_position: Vector2) -> void:
	var steps := 10
	var start_position := body.global_position
	for i in range(1, steps + 1):
		body.global_position = start_position.lerp(target_position, float(i) / steps)
		await wait_physics_frames(1)

func test_enemy_colliding_with_player_damages_player_status() -> void:
	var enemy := _make_enemy()
	var player: Node2D = WeaponTestHelpers.make_player(self)
	enemy.global_position = player.global_position + Vector2(300, 0)

	var health: HealthComponent = player.get_node("Status").get_node("HealthComponent")
	var starting_health: int = health.current_health

	await _approach(enemy, player.global_position)

	assert_lt(health.current_health, starting_health, "player health should drop after enemy contact")

func test_melee_trigger_does_not_error_when_colliding_with_a_status_less_body() -> void:
	var enemy := _make_enemy()
	enemy.global_position = Vector2(300, 0)

	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 4
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	body.add_child(shape)
	add_child_autofree(body)

	await _approach(enemy, body.global_position)

	assert_true(is_instance_valid(enemy), "enemy should remain valid after colliding with a Status-less body")

func test_enemy_bounces_away_from_player_on_contact() -> void:
	var enemy := _make_enemy()
	var player: Node2D = WeaponTestHelpers.make_player(self)
	# Enemy approaches from the +X side, so "away from the player" is a fixed,
	# known direction (Vector2.RIGHT) regardless of how close they end up --
	# recomputing it from final positions would be unreliable once _approach
	# lerps the enemy all the way to an overlapping position.
	enemy.global_position = player.global_position + Vector2(300, 0)

	await _approach(enemy, player.global_position)

	var velocity: Vector2 = enemy.movement_behavior.get_velocity(enemy.position)

	assert_gt(velocity.length(), 0.0, "enemy should have a pushed knockback behavior moving it after contact")
	assert_gt(velocity.normalized().dot(Vector2.RIGHT), 0.0, "enemy should move back toward +X (away from the player it approached from -X), not toward or past it")

func test_re_entering_contact_triggers_damage_again() -> void:
	# A smaller-than-max-health hit (rather than _make_enemy()'s 100-damage
	# default), so the player survives the first contact with health to
	# spare -- otherwise the first hit alone would already floor health at 0,
	# leaving no room to observe a further decrease on re-entry.
	var enemy := _make_enemy(30)
	var player: Node2D = WeaponTestHelpers.make_player(self)
	enemy.global_position = player.global_position + Vector2(300, 0)

	var health: HealthComponent = player.get_node("Status").get_node("HealthComponent")

	await _approach(enemy, player.global_position)
	var health_after_first_contact: int = health.current_health

	enemy.global_position = player.global_position + Vector2(1000, 1000)
	await wait_physics_frames(2)

	await _approach(enemy, player.global_position)

	assert_lt(health.current_health, health_after_first_contact, "re-entering contact should deal damage again")
