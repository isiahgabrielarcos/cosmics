extends Node2D

# Hub scene controller — the cosmic base village (stage 100).
# Plays the village music and adds the pause menu; no enemy spawns here.
#
# Superseded by cosmic_hub.tscn / cosmic_hub.gd (the tilemap-built hub) —
# kept only for reference until confirmed safe to delete.

const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")


func _ready() -> void:
	GameManager.start_session(100)

	AudioManager.play_music("cosmicVillage")

	add_child(PauseMenuScene.instantiate())
