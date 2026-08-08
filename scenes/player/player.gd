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

## Set synchronously the instant _on_died() starts (before the death
## animation await) so ActivityManager's own win-check can observe "the
## player is dying" immediately, rather than only after the animation
## finishes -- see _resolve_round_outcome().
var is_dead: bool = false

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
	is_dead = true
	movement_behavior = StayStillMovementBehavior.new()
	_timer_weapon_trigger.stop()

	_animation_player.play("death")
	await _animation_player.animation_finished

	_resolve_round_outcome()

## Resolves this round's final outcome once the death animation completes.
## If ActivityManager already declared the round won (its own win-check
## happened to run first, possibly upgrading to PYRRHIC_VICTORY because
## is_dead was already true), this is a no-op -- no double round_ended
## emission. Otherwise, this checks whether the win condition is ALSO true
## right now (a simultaneous win/loss) and emits PYRRHIC_VICTORY instead of
## a plain loss if so.
func _resolve_round_outcome() -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		GameEvents.emit_round_ended(0.0, GameEvents.RoundOutcome.LOST)
		return

	var activity_manager: ActivityManager = game.get_node_or_null("ActivityManager")
	if activity_manager == null or activity_manager.round_over:
		return

	activity_manager.round_over = true
	var won := activity_manager.game_mode.is_round_won(activity_manager.activities_triggered, activity_manager.spawn_parent)
	var outcome := GameEvents.RoundOutcome.PYRRHIC_VICTORY if won else GameEvents.RoundOutcome.LOST
	GameEvents.emit_round_ended(game.get_time_played_seconds(), outcome)

func _physics_process(_delta: float) -> void:
	velocity = movement_behavior.get_velocity(position)
	if velocity != Vector2.ZERO:
		$AnimatedSprite2D.play("run")
		$AnimatedSprite2D.flip_h = velocity.x < 0
	else:
		$AnimatedSprite2D.play("idle")
		
	move_and_slide()
	if world_size != Vector2.ZERO:
		global_position = global_position.clamp(half_size, world_size - half_size)
