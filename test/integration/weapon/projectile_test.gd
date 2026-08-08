extends GutTest

func test_projectile_moves_in_configured_direction() -> void:
	var projectile_scene: PackedScene = load("res://scenes/projectile/projectile.tscn")
	var projectile: Projectile = add_child_autofree(projectile_scene.instantiate())
	projectile.direction = Vector2.RIGHT
	projectile.speed = 100.0
	projectile.damage = 5
	projectile.global_position = Vector2(500, 500)

	var starting_position: Vector2 = projectile.global_position
	await wait_physics_frames(5)

	assert_gt(projectile.global_position.x, starting_position.x, "projectile should have moved to the right")
	assert_almost_eq(projectile.global_position.y, starting_position.y, 0.1)

func test_projectile_damages_target_status_on_contact_and_self_destructs() -> void:
	var projectile_scene: PackedScene = load("res://scenes/projectile/projectile.tscn")
	var projectile: Projectile = add_child_autofree(projectile_scene.instantiate())
	var enemy := WeaponTestHelpers.make_enemy(self)

	var health: HealthComponent = enemy.get_node("Status").get_node("HealthComponent")
	var starting_health: int = health.current_health

	projectile.damage = 65
	projectile.direction = Vector2.ZERO
	projectile.global_position = enemy.global_position

	await wait_physics_frames(2)

	assert_eq(health.current_health, starting_health - 65)
	assert_true(not is_instance_valid(projectile) or projectile.is_queued_for_deletion(), "projectile should self-destruct on contact")

func test_projectile_self_destructs_when_hitting_a_status_less_body() -> void:
	var projectile_scene: PackedScene = load("res://scenes/projectile/projectile.tscn")
	var projectile: Projectile = add_child_autofree(projectile_scene.instantiate())

	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 8
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	body.add_child(shape)
	add_child_autofree(body)

	projectile.damage = 5
	projectile.direction = Vector2.ZERO
	# The projectile's own CollisionShape2D is offset from its origin
	# (position = Vector2(17, 0) in projectile.tscn, matching the sprite's
	# arrowhead), so the body must be placed at that same offset to actually
	# overlap it -- placing both at global_position (0,0) would put the body
	# under the projectile's origin, not its hitbox.
	body.global_position = projectile.global_position + Vector2(17, 0)

	await wait_physics_frames(2)

	assert_true(not is_instance_valid(projectile) or projectile.is_queued_for_deletion(), "projectile should self-destruct even without a Status target")

func test_projectile_despawns_when_leaving_world_bounds() -> void:
	var projectile_scene: PackedScene = load("res://scenes/projectile/projectile.tscn")
	var projectile: Projectile = add_child_autofree(projectile_scene.instantiate())
	projectile.direction = Vector2.LEFT
	projectile.speed = 10000.0
	projectile.damage = 5
	projectile.global_position = Vector2(50, 50)

	GameEvents.world_size_changed.emit(Vector2(1600, 1200))
	await wait_physics_frames(3)

	assert_true(not is_instance_valid(projectile) or projectile.is_queued_for_deletion(), "projectile should despawn after leaving world bounds")
