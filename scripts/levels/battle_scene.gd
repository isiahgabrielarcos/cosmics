extends Node2D

# Battle scene controller — ports battle.lua's scene:create() flow:
# start music, set up the session, add the pause menu and mission-end screens,
# and start the mission timer for the stage type.

const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")
const MissionEndScreenScene := preload("res://scenes/ui/mission_end_screen.tscn")

@export var stage: int = 21              # default: endless stage for testing
@export var stage_difficulty: String = "normal"


var _run_minutes: float = 0.0
var _tier: int = 1


func _enter_tree() -> void:
	# Runs before any child _ready() so the stage is set when HUD and spawner init
	if GameManager.pending_stage > 0:
		stage = GameManager.pending_stage
		stage_difficulty = GameManager.pending_difficulty
		_tier = GameManager.pending_tier
		_run_minutes = GameManager.pending_run_minutes
		GameManager.pending_stage = -1
		GameManager.pending_run_minutes = 0.0
	GameManager.start_session(stage, stage_difficulty, _tier)


func _ready() -> void:
	AudioManager.play_music("lightSpeedChase")

	add_child(PauseMenuScene.instantiate())
	add_child(MissionEndScreenScene.instantiate())

	# Mission timer per stage type (loadAssets in battle.lua). A run launched
	# from the level selection with an explicit length overrides the default.
	if GameManager.is_endless_stage():
		GameManager.start_endless_timer()
	elif _run_minutes > 0.0:
		GameManager.start_timed_run(_run_minutes)
	elif stage == 32:
		GameManager.start_scavenge_timer()
	elif not GameManager.is_hub():
		GameManager.start_attack_timer()
