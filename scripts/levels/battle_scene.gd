extends Node2D

# Battle scene controller — ports battle.lua's scene:create() flow:
# start music, set up the session, add the pause menu and mission-end screens,
# and start the mission timer for the stage type.

const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")
const MissionEndScreenScene := preload("res://scenes/ui/mission_end_screen.tscn")
const ModulePickPanelScene := preload("res://scenes/ui/panels/module_pick_panel.tscn")
const ContractSystemScene := preload("res://scenes/ui/contract_system.tscn")

var _module_picks: ModulePickPanel

@export var stage: int = 101             # default: the all-in-one sandbox
@export var stage_difficulty: String = "normal"
## Difficulty when the scene is launched directly rather than from the CCC
## board — 2 is Normal.
@export var stage_tier: int = 2


var _run_minutes: float = 0.0
var _tier: int = 2


func _enter_tree() -> void:
	_tier = stage_tier
	# Runs before any child _ready() so the stage is set when HUD and spawner init
	if GameManager.pending_stage > 0:
		stage = GameManager.pending_stage
		stage_difficulty = GameManager.pending_difficulty
		_tier = GameManager.pending_tier
		_run_minutes = GameManager.pending_run_minutes
		GameManager.pending_stage = -1
		GameManager.pending_run_minutes = 0.0
	GameManager.start_session(stage, stage_difficulty, _tier)

	# Record the run as it actually resolved, not as it was requested. Restart
	# used to replay only what queue_battle had been told, so a run started any
	# other way — straight from the editor, or after the pending values had
	# been consumed — restarted into the sandbox stage at its default length
	# instead of the contract the player was actually in.
	GameManager.remember_run(stage, stage_difficulty, _tier, _run_minutes)


func _ready() -> void:
	AudioManager.play_music("lightSpeedChase")

	add_child(PauseMenuScene.instantiate())
	add_child(MissionEndScreenScene.instantiate())
	# Owns both contract panels; the calls start on its own timer.
	add_child(ContractSystemScene.instantiate())

	_module_picks = ModulePickPanelScene.instantiate()
	add_child(_module_picks)
	# The player is a sibling that may not be ready yet
	call_deferred("_connect_module_picks")

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


## Levelling up is what deals a hand of modules. Scavenge runs (stage 32) skip
## it, matching the Lua's early-out in createModuleUpgrades().
func _connect_module_picks() -> void:
	if stage == 32:
		return
	var players := get_tree().get_nodes_in_group("friendlies")
	if players.is_empty() or not players[0].has_signal("leveled_up"):
		return
	players[0].leveled_up.connect(func(_level: int): _module_picks.open())

	# The one module the guild lets you keep — dealt before the first enemy.
	if GameManager.STARTING_MODULE_ROUNDS > 0:
		GameManager.pending_module_picks += GameManager.STARTING_MODULE_ROUNDS - 1
		_module_picks.open()
