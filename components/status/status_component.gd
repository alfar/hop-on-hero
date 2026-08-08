class_name StatusComponent
extends Node

## Emitted by subclasses whenever their tracked value changes. status_type
## identifies which kind of value changed (e.g. "health", "shield"), matching
## the subclass's own STATUS_TYPE constant.
signal value_changed(status_type: String, current_value: int, max_value: int)

func handle_event(_event: StatusEvent) -> void:
	pass

func emit_value_changed(status_type: String, current_value: int, max_value: int):
	value_changed.emit(status_type, current_value, max_value)
