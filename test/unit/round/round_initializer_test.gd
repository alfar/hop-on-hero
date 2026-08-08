extends GutTest

func after_each() -> void:
	# GameEvents.next_level_seed is shared autoload state -- reset it so a
	# value set here can't leak into unrelated tests.
	GameEvents.next_level_seed = 0

## fill_tiles resolves tiles via the TileSet's terrain data, so RoundInitializer
## needs the real world.tscn (with its authored TileSet/terrain), not a bare
## World.new() + TileMapLayer.new() with no TileSet assigned.
func _make_world() -> World:
	var world_scene: PackedScene = load("res://scenes/world/world.tscn")
	return world_scene.instantiate()

func _make_round_initializer() -> RoundInitializer:
	var round_initializer := RoundInitializer.new()
	round_initializer.world = _make_world()
	round_initializer.activity_manager = ActivityManager.new()
	round_initializer.activity_manager.world = round_initializer.world
	round_initializer.activity_manager.spawn_parent = round_initializer.activity_manager
	round_initializer.activity_manager.activities = [Activity.new()]
	add_child_autofree(round_initializer.activity_manager)
	add_child_autofree(round_initializer.world)
	add_child_autofree(round_initializer)
	return round_initializer

func test_uses_next_level_seed_when_set() -> void:
	GameEvents.next_level_seed = 12345

	var round_initializer := _make_round_initializer()

	assert_eq(round_initializer.level_seed, 12345)

func test_falls_back_to_randomize_when_next_level_seed_is_unset() -> void:
	GameEvents.next_level_seed = 0

	var round_initializer := _make_round_initializer()

	assert_ne(round_initializer.level_seed, 0, "level_seed should be randomized when no next_level_seed is staged")

func test_world_size_is_multiple_of_64_within_bounds() -> void:
	GameEvents.next_level_seed = 777

	var round_initializer := _make_round_initializer()
	var size := round_initializer.world.world_size

	assert_eq(fmod(size.x, 64.0), 0.0, "world_size.x should be a multiple of 64")
	assert_eq(fmod(size.y, 64.0), 0.0, "world_size.y should be a multiple of 64")
	assert_lte(size.x, 1600.0)
	assert_lte(size.y, 1600.0)

func test_same_seed_produces_same_world_size() -> void:
	GameEvents.next_level_seed = 555
	var first := _make_round_initializer()
	var first_size := first.world.world_size

	GameEvents.next_level_seed = 555
	var second := _make_round_initializer()
	var second_size := second.world.world_size

	assert_eq(first_size, second_size, "the same seed should produce the same world_size")
