extends GutTest

## Proves AC-08/AC-09 end-to-end on a real Player scene: equipping/unequipping
## an item through Inventory actually changes WeaponSystem.get_total_damage(),
## via the real Player._ready() wiring (not a hand-constructed
## InventoryWeaponComponent like inventory_weapon_component_test.gd uses).

func _make_player() -> Node2D:
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var player: Node2D = player_scene.instantiate()
	player.weapon_spawn_parent = player
	return add_child_autofree(player)

func test_equipping_an_item_increases_total_damage() -> void:
	var player := _make_player()
	var weapon_system: WeaponSystem = player.get_node("WeaponSystem")
	var inventory: Inventory = player.get_node("Inventory")

	var damage_without_item := weapon_system.get_total_damage()

	var weapon_component := FixedDamageWeaponComponent.new()
	weapon_component.damage = 25
	var item := Item.new()
	item.components = [weapon_component]
	inventory.equip(item)

	assert_eq(weapon_system.get_total_damage(), damage_without_item + 25)

func test_unequipping_an_item_reverts_total_damage() -> void:
	var player := _make_player()
	var weapon_system: WeaponSystem = player.get_node("WeaponSystem")
	var inventory: Inventory = player.get_node("Inventory")

	var damage_without_item := weapon_system.get_total_damage()

	var weapon_component := FixedDamageWeaponComponent.new()
	weapon_component.damage = 25
	var item := Item.new()
	item.components = [weapon_component]
	inventory.equip(item)
	inventory.unequip(0)

	assert_eq(weapon_system.get_total_damage(), damage_without_item)
