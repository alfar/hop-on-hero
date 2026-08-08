extends GutTest

## is_ready queries the "enemy" group via spawn_parent.get_tree(), so this
## needs a live scene tree and lives under test/integration/.
func test_is_ready_is_false_while_an_enemy_remains() -> void:
	var spawn_parent: Node = add_child_autofree(Node.new())
	var enemy := Node2D.new()
	enemy.add_to_group("enemy")
	add_child_autofree(enemy)

	var gate := EnemiesDefeatedActivityGate.new()

	assert_false(gate.is_ready(0.0, spawn_parent))

func test_is_ready_is_true_once_the_enemy_group_is_empty() -> void:
	var spawn_parent: Node = add_child_autofree(Node.new())
	var gate := EnemiesDefeatedActivityGate.new()

	assert_true(gate.is_ready(0.0, spawn_parent))
