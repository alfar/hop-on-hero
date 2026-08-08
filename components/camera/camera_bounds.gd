extends Camera2D

func _ready() -> void:
	GameEvents.world_size_changed.subscribe(_on_world_size_changed)

func _on_world_size_changed(size: Vector2) -> void:
	limit_left = 0
	limit_top = 0
	limit_right = floori(size.x)
	limit_bottom = floori(size.y)
