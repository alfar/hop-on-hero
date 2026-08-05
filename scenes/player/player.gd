extends CharacterBody2D

@export var movement_behavior: MovementBehavior

var world_size: Vector2 = Vector2.ZERO
var half_size := Vector2(20, 20)

func _ready() -> void:
	GameEvents.world_size_changed.subscribe(_on_world_size_changed)

func _on_world_size_changed(size: Vector2) -> void:
	world_size = size

func _physics_process(delta: float) -> void:
	velocity = movement_behavior.get_velocity(position)
	move_and_slide()
	if world_size != Vector2.ZERO:
		global_position = global_position.clamp(half_size, world_size - half_size)
