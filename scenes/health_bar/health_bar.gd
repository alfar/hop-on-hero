class_name HealthBar
extends Node2D

@export var status: Status

@onready var fill: ColorRect = $Fill

var _full_width: float

func _ready() -> void:
	_full_width = fill.size.x
	visible = false
	status.status_update.connect(_on_status_update)

func _on_status_update(type: String, current_value: int, max_value: int) -> void:
	if type != "health":
		return

	fill.size.x = _full_width * (float(current_value) / float(max_value))
	visible = current_value < max_value
