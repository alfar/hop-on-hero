class_name GameMode
extends Resource

func should_schedule_next_activity(_activities_triggered: int) -> bool:
	return true

func is_round_won(_activities_triggered: int, _spawn_parent: Node) -> bool:
	return false
