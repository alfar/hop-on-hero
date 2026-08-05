class_name StatusEvent
extends RefCounted

var type: String
var amount: float

func _init(p_type: String, p_amount: float) -> void:
	type = p_type
	amount = p_amount
