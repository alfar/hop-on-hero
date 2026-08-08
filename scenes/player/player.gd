extends CharacterBody2D

@export var movement_behavior: MovementBehavior
@export var weapon_spawn_parent: Node
@export var _timer_weapon_trigger: TimerWeaponTrigger
@export var inventory: Inventory
@export var inventory_weapon_component: InventoryWeaponComponent
@export var _inventory_drop_input: InventoryDropInput

@onready var _animation_player: AnimationPlayer = $AnimationPlayer

var world_size: Vector2 = Vector2.ZERO
var half_size := Vector2(20, 20)

func _ready() -> void:
	add_to_group("player")
	_timer_weapon_trigger.spawn_parent = weapon_spawn_parent
	inventory_weapon_component.inventory = inventory
	_inventory_drop_input.spawn_parent = weapon_spawn_parent
	GameEvents.world_size_changed.subscribe(_on_world_size_changed)
	$Status/HealthComponent.died.connect(_on_died)

func _on_world_size_changed(size: Vector2) -> void:
	world_size = size

func _on_died() -> void:
	movement_behavior = StayStillMovementBehavior.new()
	_timer_weapon_trigger.stop()

	_animation_player.play("death")
	await _animation_player.animation_finished

	var time_played_seconds := 0.0
	var game := get_tree().get_first_node_in_group("game")
	if game != null:
		time_played_seconds = game.get_time_played_seconds()

	GameEvents.round_ended.emit(time_played_seconds)

func _physics_process(delta: float) -> void:
	velocity = movement_behavior.get_velocity(position)
	if velocity != Vector2.ZERO:
		$AnimatedSprite2D.play("run")
		$AnimatedSprite2D.flip_h = velocity.x < 0
	else:
		$AnimatedSprite2D.play("idle")
		
	move_and_slide()
	if world_size != Vector2.ZERO:
		global_position = global_position.clamp(half_size, world_size - half_size)
