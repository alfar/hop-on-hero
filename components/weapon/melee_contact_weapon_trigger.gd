class_name MeleeContactWeaponTrigger
extends WeaponTrigger

@export var hit_area: Area2D

func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var status := body.get_node_or_null("Status")
	if status == null:
		return

	var total_damage := weapon_system.get_total_damage()
	status.apply_event(StatusEvent.new("physical_damage", total_damage))
