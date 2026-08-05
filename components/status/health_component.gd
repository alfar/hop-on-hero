class_name HealthComponent
extends StatusComponent

const STATUS_TYPE := "health"

signal died

@export var max_health: int = 100

var current_health: int

func _ready() -> void:
	current_health = max_health

func handle_event(event: StatusEvent) -> void:
	if event.type != "physical_damage" or current_health == 0 or roundi(event.amount) == 0:
		return

	current_health = clampi(current_health - roundi(event.amount), 0, max_health)
	value_changed.emit(STATUS_TYPE, current_health, max_health)
	if current_health == 0:
		died.emit()
