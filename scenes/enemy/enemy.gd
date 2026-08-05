extends CharacterBody2D

@export var speed = 400

@export var movement_behavior: MovementBehavior

func _physics_process(delta: float) -> void:
	velocity = movement_behavior.get_velocity(position)
	move_and_slide()
