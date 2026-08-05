extends GutTest

func _make_enemy(damage: int = 100) -> Node2D:
	var enemy := WeaponTestHelpers.make_enemy(self)
	# Boosted well past the player's default shield capacity (50) so damage
	# actually reaches HealthComponent instead of being fully absorbed.
	var weapon_component: FixedDamageWeaponComponent = enemy.get_node("WeaponSystem").get_node("FixedDamageWeaponComponent")
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
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var enemy := _make_enemy()
	var player: Node2D = add_child_autofree(player_scene.instantiate())
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

func test_re_entering_contact_triggers_damage_again() -> void:
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var enemy := _make_enemy()
	var player: Node2D = add_child_autofree(player_scene.instantiate())
	enemy.global_position = player.global_position + Vector2(300, 0)

	var health: HealthComponent = player.get_node("Status").get_node("HealthComponent")

	await _approach(enemy, player.global_position)
	var health_after_first_contact: int = health.current_health

	enemy.global_position = player.global_position + Vector2(1000, 1000)
	await wait_physics_frames(2)

	await _approach(enemy, player.global_position)

	assert_lt(health.current_health, health_after_first_contact, "re-entering contact should deal damage again")
