extends Node2D

# Battle scene controller — ports battle.lua's scene:create() flow:
# start music, set up the session, add the pause menu and mission-end screens,
# and start the mission timer for the stage type.

const PauseMenuScript := preload("res://scripts/ui/pause_menu.gd")
const MissionEndScript := preload("res://scripts/ui/mission_end_screen.gd")

@export var stage: int = 21              # default: endless stage for testing
@export var stage_difficulty: String = "normal"


func _ready() -> void:
	# Mission queued from the CCC board overrides the scene default
	if GameManager.pending_stage > 0:
		stage = GameManager.pending_stage
		stage_difficulty = GameManager.pending_difficulty
		GameManager.pending_stage = -1

	GameManager.start_session(stage, stage_difficulty)

	AudioManager.play_music("lightSpeedChase")

	var pause_menu := CanvasLayer.new()
	pause_menu.set_script(PauseMenuScript)
	add_child(pause_menu)

	var end_screen := CanvasLayer.new()
	end_screen.set_script(MissionEndScript)
	add_child(end_screen)

	# Mission timer per stage type (loadAssets in battle.lua)
	if GameManager.is_endless_stage():
		GameManager.start_endless_timer()
	elif stage == 32:
		GameManager.start_scavenge_timer()
	elif not GameManager.is_hub():
		GameManager.start_attack_timer()
