class_name SummaryScreen
extends Control

signal retry_pressed
signal new_seed_pressed

@onready var time_label: Label = $CenterContainer/VBoxContainer/TimeLabel

func _ready() -> void:
	visible = false
	$CenterContainer/VBoxContainer/RetryButton.pressed.connect(func(): retry_pressed.emit())
	$CenterContainer/VBoxContainer/NewSeedButton.pressed.connect(func(): new_seed_pressed.emit())

func show_summary(time_played_seconds: float) -> void:
	var minutes := int(time_played_seconds) / 60
	var seconds := int(time_played_seconds) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]
	visible = true
