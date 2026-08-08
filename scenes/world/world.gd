class_name World
extends Node2D

@export var world_size: Vector2 = Vector2(1600, 1200)

const TERRAIN_SET := 0
const TERRAIN := 0

@onready var _tile_map_layer: TileMapLayer = $TileMapLayer

## Paints every cell within tile_bounds with the TileSet's terrain (terrain
## set 0, terrain 0), letting Godot pick the correct corner/edge/interior
## tile per cell from its terrain peering bits. rng is accepted (not read)
## so this stays call-compatible with a future version that randomly varies
## terrain placement -- this version fills a single uniform terrain.
func fill_tiles(_rng: RandomNumberGenerator, tile_bounds: Vector2i) -> void:
	_tile_map_layer.clear()

	var cells: Array[Vector2i] = []
	for x in tile_bounds.x:
		for y in tile_bounds.y:
			cells.append(Vector2i(x, y))

	_tile_map_layer.set_cells_terrain_connect(cells, TERRAIN_SET, TERRAIN)
