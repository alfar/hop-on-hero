class_name EnemiesDefeatedActivityGate
extends ActivityGate

func is_ready(_elapsed_time: float, spawn_parent: Node) -> bool:
	return spawn_parent.get_tree().get_nodes_in_group("enemy").is_empty()
