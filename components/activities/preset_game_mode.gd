class_name PresetGameMode
extends GameMode

@export var activity_count: int = 5

func should_schedule_next_activity(activities_triggered: int) -> bool:
	return activities_triggered < activity_count

func is_round_won(activities_triggered: int, spawn_parent: Node) -> bool:
	if activities_triggered < activity_count:
		return false
	return spawn_parent.get_tree().get_nodes_in_group("enemy").is_empty()
