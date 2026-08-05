class_name Projectile
extends Area2D

@export var speed: float = 600.0

var damage: int
var direction: Vector2

var _world_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	GameEvents.world_size_changed.subscribe(_on_world_size_changed)
	body_entered.connect(_on_body_entered)

func _on_world_size_changed(size: Vector2) -> void:
	_world_size = size

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	if _world_size != Vector2.ZERO and not Rect2(Vector2.ZERO, _world_size).has_point(global_position):
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	var status := body.get_node_or_null("Status")
	if status:
		status.apply_event(StatusEvent.new("physical_damage", damage))
	queue_free()
