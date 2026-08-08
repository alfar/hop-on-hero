class_name TimerWeaponTrigger
extends WeaponTrigger

@export var interval: float = 1.0
@export var projectile_scene: PackedScene
@export var spawn_parent: Node

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = interval
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)
	_timer.start()

func stop() -> void:
	_timer.stop()

func _on_timeout() -> void:
	var target := _find_nearest_enemy()
	if target == null:
		return

	var total_damage := weapon_system.get_total_damage()
	var origin: Vector2 = get_parent().global_position

	var instance: Projectile = projectile_scene.instantiate()
	instance.global_position = origin
	instance.direction = origin.direction_to(target.global_position)
	instance.damage = total_damage
	spawn_parent.add_child.call_deferred(instance)

func _find_nearest_enemy() -> Node2D:
	var origin: Vector2 = get_parent().global_position
	var nearest: Node2D = null
	var nearest_distance := INF

	for enemy in get_tree().get_nodes_in_group("enemy"):
		var distance := origin.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy

	return nearest
