extends Node2D

var _round_start_ticks_msec: int

func _ready() -> void:
	$HUD/InventoryDisplay.inventory = $Player.inventory
	add_to_group("game")
	_round_start_ticks_msec = Time.get_ticks_msec()
	GameEvents.round_ended.connect(_on_round_ended)
	GameEvents.paused.connect(_on_paused)
	GameEvents.resumed.connect(_on_resumed)
	$HUD/SummaryScreen.retry_pressed.connect(_on_retry_pressed)
	$HUD/SummaryScreen.new_seed_pressed.connect(_on_new_seed_pressed)

func get_time_played_seconds() -> float:
	return (Time.get_ticks_msec() - _round_start_ticks_msec) / 1000.0

func _on_round_ended(time_played_seconds: float) -> void:
	GameEvents.paused.emit()
	$HUD/SummaryScreen.show_summary(time_played_seconds)

## Game is the sole subscriber that translates the pause/resume *intent*
## (GameEvents.paused/resumed) into the real get_tree().paused toggle -- kept
## separate so tests can assert the intent fired without ever setting the
## actual SceneTree.paused flag, which would otherwise leak into every
## subsequent test in the same GUT run.
func _on_paused() -> void:
	get_tree().paused = true

func _on_resumed() -> void:
	get_tree().paused = false

func _on_retry_pressed() -> void:
	stage_next_seed($ActivityManager.level_seed)
	_restart()

func _on_new_seed_pressed() -> void:
	stage_next_seed(0)
	_restart()

## Stages the seed ActivityManager should use on the next scene load. Split
## out from _on_retry_pressed()/_on_new_seed_pressed() so it can be tested in
## isolation, without also calling _restart()'s reload_current_scene() --
## which errors when there's no current_scene set (e.g. under a test runner).
func stage_next_seed(seed_value: int) -> void:
	GameEvents.next_level_seed = seed_value

func _restart() -> void:
	GameEvents.resumed.emit()
	get_tree().reload_current_scene()
