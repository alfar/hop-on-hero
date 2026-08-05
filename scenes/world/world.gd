extends Node2D

@export var world_size: Vector2 = Vector2(1600, 1200)

func _ready() -> void:
	GameEvents.world_size_changed.emit(world_size)
