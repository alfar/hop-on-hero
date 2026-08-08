## Shared test doubles for activities-domain tests. Not a test itself.
class_name ActivitiesTestHelpers
extends RefCounted

## Records how many times execute() was called; used to verify ActivityManager's
## scheduling/selection decisions without depending on what a real Activity does.
class SpyActivity extends Activity:
	var execute_count: int = 0

	func execute(_rng: RandomNumberGenerator, _world_size: Vector2, _spawn_parent: Node) -> void:
		execute_count += 1

## A GameMode whose win condition is always true, regardless of state --
## used to deterministically exercise ActivityManager's win-declaration path.
class AlwaysWonGameMode extends GameMode:
	func is_round_won(_activities_triggered: int, _spawn_parent: Node) -> bool:
		return true
