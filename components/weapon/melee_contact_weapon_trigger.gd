class_name MeleeContactWeaponTrigger
extends WeaponTrigger

@export var hit_area: Area2D
@export var enemy: Enemy
@export var knockback_distance: float = 150.0
@export var knockback_speed: float = 600.0

func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var status := body.get_node_or_null("Status")
	if status == null:
		return

	var total_damage := weapon_system.get_total_damage()
	status.apply_event(StatusEvent.new("physical_damage", total_damage))

	_bounce_away_from(body)

func _bounce_away_from(body: Node2D) -> void:
	var direction := (enemy.global_position - body.global_position).normalized()
	if direction == Vector2.ZERO:
		return

	var knockback := TargetMovementBehavior.new()
	knockback.target = enemy.global_position + direction * knockback_distance
	knockback.speed = knockback_speed
	enemy.movement_stack.push_behavior(knockback)
