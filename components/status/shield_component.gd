class_name ShieldComponent
extends StatusComponent

const STATUS_TYPE := "shield"

@export var max_shield: int = 50

var current_shield: int

func _ready() -> void:
	current_shield = max_shield

func handle_event(event: StatusEvent) -> void:
	if event.type != "physical_damage" or current_shield <= 0:
		return

	var absorbed: int = mini(roundi(event.amount), current_shield)
	current_shield -= absorbed
	event.amount -= absorbed
	value_changed.emit(STATUS_TYPE, current_shield, max_shield)
