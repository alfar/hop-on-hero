extends GutTest

func after_each() -> void:
	# GameEvents.next_level_seed is shared autoload state -- reset it so a
	# value set here can't leak into unrelated tests instancing ActivityManager.
	GameEvents.next_level_seed = 0

func test_uses_next_level_seed_when_set() -> void:
	GameEvents.next_level_seed = 12345

	var activity_manager := ActivityManager.new()
	add_child_autofree(activity_manager)

	assert_eq(activity_manager.level_seed, 12345)

func test_falls_back_to_randomize_when_next_level_seed_is_unset() -> void:
	GameEvents.next_level_seed = 0

	var activity_manager := ActivityManager.new()
	add_child_autofree(activity_manager)

	assert_ne(activity_manager.level_seed, 0, "level_seed should be randomized when neither an exported value nor a staged next_level_seed is set")
