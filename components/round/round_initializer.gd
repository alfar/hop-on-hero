class_name RoundInitializer
extends Node

const TILE_SIZE := 64
const MAX_WORLD_SIZE_PX := 1600.0

@export var world: World
@export var activity_manager: ActivityManager

## Exposed so Game can stage the same seed again on Retry, mirroring how
## ActivityManager.level_seed used to be read before this responsibility
## moved here.
var level_seed: int = 0

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_resolve_seed()

	var size := _pick_world_size()
	world.world_size = size
	world.fill_tiles(_rng, Vector2i(floori(size.x / TILE_SIZE), floori(size.y / TILE_SIZE)))

	GameEvents.world_size_changed.emit(size)
	GameEvents.world_loaded.emit(true)

	activity_manager.rng = _rng
	activity_manager.start()

func _resolve_seed() -> void:
	level_seed = GameEvents.next_level_seed
	if level_seed == 0:
		level_seed = randi()
		print("RoundInitializer seed: ", level_seed)
	_rng.seed = level_seed

func _pick_world_size() -> Vector2:
	var screen_size := get_viewport().get_visible_rect().size
	return Vector2(
		_pick_axis_size(screen_size.x),
		_pick_axis_size(screen_size.y)
	)

## The world's minimum size on this axis is always the screen size (rounded
## up to the nearest tile), never a fixed tunable -- if that minimum already
## exceeds MAX_WORLD_SIZE_PX, the axis collapses to that single value instead
## of a random range.
func _pick_axis_size(screen_axis_size: float) -> float:
	var min_tiles := ceili(screen_axis_size / TILE_SIZE)
	var max_tiles := floori(MAX_WORLD_SIZE_PX / TILE_SIZE)
	if min_tiles > max_tiles:
		max_tiles = min_tiles
	return _rng.randi_range(min_tiles, max_tiles) * TILE_SIZE
