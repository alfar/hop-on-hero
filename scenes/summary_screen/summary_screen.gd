class_name SummaryScreen
extends Control

signal retry_pressed
signal new_seed_pressed

@onready var time_label: Label = $CenterContainer/VBoxContainer/TimeLabel
@onready var outcome_label: Label = $CenterContainer/VBoxContainer/OutcomeLabel

func _ready() -> void:
	visible = false
	$CenterContainer/VBoxContainer/RetryButton.pressed.connect(func(): retry_pressed.emit())
	$CenterContainer/VBoxContainer/NewSeedButton.pressed.connect(func(): new_seed_pressed.emit())

func show_summary(time_played_seconds: float, outcome: GameEvents.RoundOutcome) -> void:
	var minutes := floori(time_played_seconds / 60)
	var seconds := int(time_played_seconds) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]
	outcome_label.text = _outcome_text(outcome)
	visible = true

func _outcome_text(outcome: GameEvents.RoundOutcome) -> String:
	match outcome:
		GameEvents.RoundOutcome.WON:
			return "You Won!"
		GameEvents.RoundOutcome.PYRRHIC_VICTORY:
			return "Pyrrhic Victory!"
		_:
			return "You Died"
