extends Node2D

func _ready() -> void:
	$HUD/InventoryDisplay.inventory = $Player.inventory
	
