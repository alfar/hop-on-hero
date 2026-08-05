class_name Status
extends Node2D

signal status_update(type: String, current_value: int, max_value: int)

func _ready() -> void:
	for child in get_children():
		if child is StatusComponent:
			child.value_changed.connect(_on_component_value_changed)

func apply_event(event: StatusEvent) -> void:
	for child in get_children():
		if child is StatusComponent:
			child.handle_event(event)

func _on_component_value_changed(status_type: String, current_value: int, max_value: int) -> void:
	status_update.emit(status_type, current_value, maxi(max_value, 1))
