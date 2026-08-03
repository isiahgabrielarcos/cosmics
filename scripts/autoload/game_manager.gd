extends Node

# ── Stage / Session ────────────────────────────────────────────────────────────
# Stage numbering mirrors Solar2D:
#   100        = hub / cosmic base (between missions)
#   1–4        = normal stages
#   11–14      = complex / dungeon stages
#   21–24      = endless stages
#   31         = defend the base
#   32         = scavenge material
#   33         = escort asset
#   34         = attack timer
var current_stage: int = 1
var difficulty: String = "normal"   # "normal" | "expert"
var game_paused: bool = false
var game_over: bool = false
var game_done: bool = false
var ui_open: bool = false           # a hub menu / shop panel is open

# Set by the CCC level selection before launching a battle
var pending_stage: int = -1
var pending_difficulty: String = "normal"
var pending_tier: int = 1            # inner difficulty selector, 1 (easy) .. 5 (hard)
var pending_run_minutes: float = 0.0  # >0 = fixed-length run, 0 = use the stage default

## Inner difficulty tier of the active session. Drives spawn rate, enemy cap
## and how many enemy archetypes the spawner is allowed to roll.
var difficulty_tier: int = 1
const MAX_TIER := 5

## How many of the 5 archetypes (chaser/shooter/bomber/slasher/ship) are in
## play per tier — tier 1 is chasers only, tier 5 is the full roster.
const TIER_VARIETY := { 1: 1, 2: 2, 3: 3, 4: 4, 5: 5 }

# ── Runtime Counters ───────────────────────────────────────────────────────────
var enemies_killed: int        = 0
var gathered_shards: int       = 0
var gathered_currency: int     = 0
var module_upgrade_count: int  = 0

# ── Mission timer (startMissionTimer) ─────────────────────────────────────────
var mission_time_left: float = 0.0
var mission_time_elapsed: float = 0.0
var mission_timer_running: bool = false
var mission_count_up: bool = false

# ── Signals ────────────────────────────────────────────────────────────────────
signal stage_changed(stage: int)
signal difficulty_changed(diff: String)
signal game_paused_changed(paused: bool)
signal enemy_killed_signal(experience: int)
signal game_over_triggered
signal mission_complete
signal mission_timer_updated(display_seconds: float, count_up: bool)
signal currency_changed(gems: int, shards: int, central: int)


func _process(delta: float) -> void:
	if not mission_timer_running or game_paused:
		return
	if mission_count_up:
		mission_time_elapsed += delta
		mission_timer_updated.emit(mission_time_elapsed, true)
	else:
		mission_time_left -= delta
		mission_timer_updated.emit(maxf(mission_time_left, 0.0), false)
		if mission_time_left <= 0.0:
			mission_timer_running = false
			trigger_mission_complete()


# ── Stage control ──────────────────────────────────────────────────────────────

func set_stage(stage: int) -> void:
	current_stage = stage
	stage_changed.emit(stage)


func is_hub() -> bool:
	return current_stage == 100


func is_normal_stage() -> bool:
	return current_stage >= 1 and current_stage <= 4


func is_endless_stage() -> bool:
	return current_stage >= 21 and current_stage <= 24


## Spawner tuning per mission (enemySpawner variants in globalFunctions.lua).
## Returns { interval: seconds, cap: max concurrent enemies }.
func get_spawner_settings() -> Dictionary:
	var s: Dictionary
	if current_stage == 32:
		s = { "interval": 1.3, "cap": 100 }   # scavenge (slower)
	elif current_stage == 33:
		s = { "interval": 1.0, "cap": 200 }   # escort (bigger cap)
	elif current_stage == 31:
		s = { "interval": 1.3, "cap": 100 }   # defend the base
	elif difficulty == "expert":
		s = { "interval": 0.85, "cap": 100 }  # expert (faster)
	else:
		s = { "interval": 1.0, "cap": 100 }   # normal

	# Inner tier: tier 1 spawns at ~1.4x the interval (calmer) and caps lower,
	# tier 5 at ~0.6x (relentless) with the full cap.
	var t := clampi(difficulty_tier, 1, MAX_TIER)
	var interval_mult := 1.4 - (t - 1) * 0.2      # 1.4 · 1.2 · 1.0 · 0.8 · 0.6
	var cap_mult := 0.5 + (t - 1) * 0.125         # 0.5 · 0.625 · 0.75 · 0.875 · 1.0
	s["interval"] = float(s["interval"]) * interval_mult
	s["cap"] = maxi(20, int(float(s["cap"]) * cap_mult))
	s["variety"] = int(TIER_VARIETY.get(t, 5))
	return s


# ── Mission timers (attackTimer / endlessTimer / scavageTimer) ────────────────

func start_attack_timer() -> void:
	# normal: 5 min · expert: 10 min
	var minutes := 10.0 if difficulty == "expert" else 5.0
	_start_mission_timer(minutes * 60.0, false)


func start_endless_timer() -> void:
	_start_mission_timer(0.0, true)


func start_scavenge_timer() -> void:
	_start_mission_timer(10.0 * 60.0, false)


## Fixed-length run picked from the level selection (e.g. the 15-Minute Run).
func start_timed_run(minutes: float) -> void:
	_start_mission_timer(minutes * 60.0, false)


func _start_mission_timer(seconds: float, count_up: bool) -> void:
	mission_time_left = seconds
	mission_time_elapsed = 0.0
	mission_count_up = count_up
	mission_timer_running = true


func stop_mission_timer() -> void:
	mission_timer_running = false


# ── Session lifecycle ─────────────────────────────────────────────────────────

func start_session(stage: int, diff: String = "normal", tier: int = 1) -> void:
	current_stage = stage
	difficulty = diff
	difficulty_tier = clampi(tier, 1, MAX_TIER)
	game_over = false
	game_done = false
	enemies_killed = 0
	gathered_shards = 0
	gathered_currency = 0
	stage_changed.emit(stage)


func trigger_game_over() -> void:
	if game_done:
		return
	game_done = true
	game_over = true
	stop_mission_timer()
	game_over_triggered.emit()


func trigger_mission_complete() -> void:
	if game_done:
		return
	game_done = true
	stop_mission_timer()
	_grant_mission_rewards()
	mission_complete.emit()


## Rewards from missionDonePlayer (stage < 29 branch)
func _grant_mission_rewards() -> void:
	var pd: Dictionary = SaveManager.player_data
	if difficulty == "expert":
		pd["gems"] = int(pd.get("gems", 0)) + 50
		pd["shards"] = int(pd.get("shards", 0)) + gathered_shards + 150
		pd["centralCurrency"] = int(pd.get("centralCurrency", 0)) + gathered_currency + 250
	else:
		pd["gems"] = int(pd.get("gems", 0)) + 15
		pd["shards"] = int(pd.get("shards", 0)) + gathered_shards + 50
		pd["centralCurrency"] = int(pd.get("centralCurrency", 0)) + gathered_currency + 150
	SaveManager.save_player_data()
	_emit_currency()


# ── Currency (updateCurrency / showCurrency) ──────────────────────────────────

func add_gems(amount: int) -> void:
	SaveManager.player_data["gems"] = int(SaveManager.player_data.get("gems", 0)) + amount
	SaveManager.save_player_data()
	_emit_currency()


func add_shards(amount: int) -> void:
	SaveManager.player_data["shards"] = int(SaveManager.player_data.get("shards", 0)) + amount
	SaveManager.save_player_data()
	_emit_currency()


func add_central_currency(amount: int) -> void:
	SaveManager.player_data["centralCurrency"] = int(SaveManager.player_data.get("centralCurrency", 0)) + amount
	SaveManager.save_player_data()
	_emit_currency()


func _emit_currency() -> void:
	var pd: Dictionary = SaveManager.player_data
	currency_changed.emit(
		int(pd.get("gems", 0)),
		int(pd.get("shards", 0)),
		int(pd.get("centralCurrency", 0)))


# ── Pause control ──────────────────────────────────────────────────────────────

func pause_game() -> void:
	if game_paused:
		return
	game_paused = true
	get_tree().paused = true
	game_paused_changed.emit(true)


func resume_game() -> void:
	if not game_paused:
		return
	game_paused = false
	get_tree().paused = false
	game_paused_changed.emit(false)


# ── Scene transitions (mirrors composer.gotoScene) ─────────────────────────────

func goto_battle() -> void:
	resume_game()
	ui_open = false
	game_over = false
	game_done = false
	get_tree().change_scene_to_file("res://scenes/levels/testing_area.tscn")


## Called by the CCC level selection — battle_scene picks these up on load.
## `minutes` > 0 forces a fixed-length run; 0 uses the stage's own timer rule.
func queue_battle(stage: int, diff: String, tier: int = 1, minutes: float = 0.0) -> void:
	pending_stage = stage
	pending_difficulty = diff
	pending_tier = clampi(tier, 1, MAX_TIER)
	pending_run_minutes = minutes
	AudioManager.play_sfx("playGame")
	goto_battle()


func goto_main_menu() -> void:
	resume_game()
	current_stage = 100
	get_tree().change_scene_to_file("res://scenes/levels/cosmic_hub.tscn")


func goto_level_select() -> void:
	resume_game()
	ui_open = false
	get_tree().change_scene_to_file("res://scenes/levels/future_CCC_level_selection.tscn")


# ── Enemy kill tracking ────────────────────────────────────────────────────────

func on_enemy_killed(experience: int) -> void:
	enemies_killed += 1
	enemy_killed_signal.emit(experience)
