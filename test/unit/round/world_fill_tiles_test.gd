extends GutTest

## fill_tiles resolves tiles via the TileSet's terrain data, so these tests
## need the real world.tscn (with its authored TileSet/terrain), not a bare
## World.new() + TileMapLayer.new() with no TileSet assigned.
func _make_world() -> World:
	var world_scene: PackedScene = load("res://scenes/world/world.tscn")
	return world_scene.instantiate()

func test_fill_tiles_paints_every_cell_within_bounds() -> void:
	var world: World = add_child_autofree(_make_world())
	var rng := RandomNumberGenerator.new()

	world.fill_tiles(rng, Vector2i(5, 4))

	var tile_map_layer: TileMapLayer = world.get_node("TileMapLayer")

	for x in 5:
		for y in 4:
			assert_ne(tile_map_layer.get_cell_source_id(Vector2i(x, y)), -1, "cell (%d, %d) should be painted" % [x, y])

func test_fill_tiles_does_not_paint_outside_bounds() -> void:
	var world: World = add_child_autofree(_make_world())
	var rng := RandomNumberGenerator.new()

	world.fill_tiles(rng, Vector2i(5, 4))

	var tile_map_layer: TileMapLayer = world.get_node("TileMapLayer")

	assert_eq(tile_map_layer.get_cell_source_id(Vector2i(5, 0)), -1, "cells outside tile_bounds.x should stay empty")
	assert_eq(tile_map_layer.get_cell_source_id(Vector2i(0, 4)), -1, "cells outside tile_bounds.y should stay empty")

func test_fill_tiles_clears_existing_data_first() -> void:
	var world: World = add_child_autofree(_make_world())
	var tile_map_layer: TileMapLayer = world.get_node("TileMapLayer")
	tile_map_layer.set_cell(Vector2i(10, 10), 0, Vector2i(6, 1))

	world.fill_tiles(RandomNumberGenerator.new(), Vector2i(3, 3))

	assert_eq(tile_map_layer.get_cell_source_id(Vector2i(10, 10)), -1, "cells outside the new bounds should be cleared")
