class_name Enemy
extends CharacterBody2D

@export var speed = 300

@export var movement_behavior: MovementBehavior

@export var death_fade_duration: float = 0.2

## Enemy's own decision engine pushes/pops temporary overrides through this;
## movement_behavior is always a MovementStack in practice (assigned by
## BossActivity or a scene override), so the cast is centralized here.
var movement_stack: MovementStack:
	get: return movement_behavior as MovementStack

func _ready() -> void:
	add_to_group("enemy")
	$Status/HealthComponent.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	velocity = movement_behavior.get_velocity(position)
	move_and_slide()

func _on_died() -> void:
	movement_behavior = StayStillMovementBehavior.new()
	$HitArea.monitoring = false

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, death_fade_duration)
	await tween.finished

	queue_free()
