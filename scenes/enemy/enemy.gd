extends CharacterBody2D

@export var speed = 400

@export var movement_stack: MovementStack

@export var death_fade_duration: float = 1.0

func _ready() -> void:
	add_to_group("enemy")
	$Status/HealthComponent.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	velocity = movement_stack.get_velocity(position)
	move_and_slide()

func _on_died() -> void:
	movement_stack = MovementStack.new()
	$HitArea.monitoring = false

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, death_fade_duration)
	await tween.finished

	queue_free()
