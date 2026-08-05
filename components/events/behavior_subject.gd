class_name BehaviorSubject
extends RefCounted

signal value_changed(value)

var _value
var _has_value := false

func _init(initial = null) -> void:
	_value = initial

func emit(value) -> void:
	_value = value
	_has_value = true
	value_changed.emit(value)

func get_value():
	return _value

func has_value() -> bool:
	return _has_value

func subscribe(callable: Callable) -> void:
	value_changed.connect(callable)
	if _has_value:
		callable.call(_value)
