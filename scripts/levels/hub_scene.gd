extends Node2D

# Hub scene controller — the cosmic base village (stage 100).
# Plays the village music and adds the pause menu; no enemy spawns here.

const PauseMenuScript := preload("res://scripts/ui/pause_menu.gd")


func _ready() -> void:
	GameManager.start_session(100)

	AudioManager.play_music("cosmicVillage")

	var pause_menu := CanvasLayer.new()
	pause_menu.set_script(PauseMenuScript)
	add_child(pause_menu)
