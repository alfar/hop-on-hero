extends GutTest

var _activity: BossActivity
var _world_size := Vector2(1000, 800)
var _origin := Vector2(200, 300)

func before_each() -> void:
	_activity = BossActivity.new()

func test_reachable_distance_facing_right() -> void:
	var distance: float = _activity._max_reachable_distance(_origin, Vector2.RIGHT, _world_size)

	assert_almost_eq(distance, _world_size.x - _origin.x, 0.001)

func test_reachable_distance_facing_left() -> void:
	var distance: float = _activity._max_reachable_distance(_origin, Vector2.LEFT, _world_size)

	assert_almost_eq(distance, _origin.x, 0.001)

func test_reachable_distance_facing_down() -> void:
	var distance: float = _activity._max_reachable_distance(_origin, Vector2.DOWN, _world_size)

	assert_almost_eq(distance, _world_size.y - _origin.y, 0.001)
	assert_ne(distance, INF)

func test_reachable_distance_facing_up() -> void:
	var distance: float = _activity._max_reachable_distance(_origin, Vector2.UP, _world_size)

	assert_almost_eq(distance, _origin.y, 0.001)

func test_reachable_distance_facing_diagonal_is_limited_by_nearest_edge() -> void:
	# From (200, 300) heading down-right at 45 degrees: right edge is 800 away,
	# bottom edge is 500 away, so the diagonal travel is limited by the y-axis
	# to reach the bottom edge first: distance * sin(45) = 500 -> distance = 500 / sin(45) ~= 707.107
	var direction := Vector2.ONE.normalized()

	var distance: float = _activity._max_reachable_distance(_origin, direction, _world_size)

	assert_almost_eq(distance, 707.107, 0.001)
