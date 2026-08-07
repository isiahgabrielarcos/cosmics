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
## The sandbox stage: every faction, every archetype, one of each boss in
## rotation. Used by scenes/levels/testing_area.tscn.
const ALL_IN_ONE_STAGE := 101

var current_stage: int = 1
var difficulty: String = "normal"   # "normal" | "expert"
var game_paused: bool = false
var game_over: bool = false
var game_done: bool = false
var ui_open: bool = false           # a hub menu / shop panel is open

## Set when a click lands on an in-run UI control (the inventory tab, an
## ability icon). The inventory itself doesn't stop you shooting — only the
## click that operated it does, and only until the button comes back up, so
## pressing the tab never also fires a shot.
var ui_click_swallowed: bool = false

# Set by the CCC level selection before launching a battle
var pending_stage: int = -1
var pending_difficulty: String = "normal"
var pending_tier: int = 1            # inner difficulty selector, 1 (easy) .. 5 (hard)
var pending_run_minutes: float = 0.0  # >0 = fixed-length run, 0 = use the stage default
var last_talked_to : String = ""

# ── Gameplay loop ─────────────────────────────────────────────────────────────
# A "loop" is one contract seen through to an end screen. Hub content that
# should only refresh between runs — NPC dialogue, the trader's stock — keys
# off this rather than off entering the hub, so backing out of a mission
# doesn't let you reroll the shop or farm conversations. Quitting costs you
# the loop; you have to actually finish a run, win or lose, to move on.
signal run_loop_advanced(loop: int)

var run_loop: int = 0

## Which line each hub NPC is up to in their dialogue bank (HubDialogue).
## Lives here rather than on the NPC so it survives the hub scene being
## reloaded after every mission.
var dialogue_cursor: Dictionary = {}

## NPCs already spoken to this loop — they have nothing new until the next
## end screen.
var dialogue_spent: Dictionary = {}


## Called when a run reaches an end screen (either outcome). Everything that
## refreshes "between runs" hangs off this.
func advance_run_loop() -> void:
	run_loop += 1
	dialogue_spent.clear()
	run_loop_advanced.emit(run_loop)

## Difficulty of the active session: 1 Beginner · 2 Normal · 3 Hard ·
## 4 Space Cowboy. Drives spawn rate, enemy cap, which archetypes the spawner
## may roll, and how hard those enemies hit.
var difficulty_tier: int = 1
const MAX_TIER := 4

## Which archetypes each difficulty fields, and how often. Weights are
## relative, so every tier keeps a spread of enemy types rather than leaning
## on one — even Beginner mixes three.
const TIER_ROSTER := {
	1: { "chaser": 34, "ship": 33, "shooter": 33 },
	2: { "chaser": 28, "ship": 24, "shooter": 24, "bomber": 24 },
	3: { "chaser": 22, "ship": 20, "shooter": 19, "bomber": 19, "slasher": 20 },
	4: { "chaser": 22, "ship": 20, "shooter": 19, "bomber": 19, "slasher": 20 },
}

## Enemy health and damage multiplier per difficulty. Space Cowboy fields the
## same roster as Hard — it just hits twice as hard.
const TIER_STAT_MULT := { 1: 0.9, 2: 1.0, 3: 1.4, 4: 2.0 }

## Background star scale per difficulty — the sun looms larger the worse the
## contract is.
const TIER_STAR_SCALE := { 1: 0.85, 2: 1.0, 3: 1.25, 4: 1.55 }

const TIER_NAMES := { 1: "BEGINNER", 2: "NORMAL", 3: "HARD", 4: "SPACE COWBOY" }

# ── Runtime Counters ───────────────────────────────────────────────────────────
var enemies_killed: int        = 0
var gathered_shards: int       = 0
var gathered_currency: int     = 0
var module_upgrade_count: int  = 0

## Run-scoped values module picks can move (currentMaxShardDropRate /
## currentEnemyExperienceWorthAddition in the Lua). Reset per session.
var shard_drop_rate: int = 6
var experience_bonus: int = 0

## Module picks still owed to the player — a chest can grant several in a row.
var pending_module_picks: int = 0

# ── Module ledger ─────────────────────────────────────────────────────────────
# The CCC-Guild doesn't let mercenaries hoard salvage: every module fitted
# during a contract is surrendered on the way out and paid for in Central
# Cosmic Currency. Complete the contract and you're paid in full; wash out and
# the guild keeps most of it. The one module you're handed at the start of a
# run is the free one, and it counts toward the payout like any other.
var modules_taken: Dictionary = {
	"common": 0, "rare": 0, "epic": 0, "legendary": 0, "godly": 0,
}

## Every module fitted this run, in order — { rarity, name, desc }.
var module_log: Array = []

const MODULE_VALUES := {
	"common": 25, "rare": 60, "epic": 150, "legendary": 400, "godly": 1000,
}
const MODULE_LOSS_RATIO := 0.25   # paid out when the contract fails

## Free module handed over at the start of every contract.
const STARTING_MODULE_ROUNDS := 1

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
signal modules_changed



func _process(delta: float) -> void:
	if not mission_timer_running or game_paused:
		return
	# Elapsed is tracked in both modes — a countdown mission still needs to
	# know how long the run has been going for the spawner's difficulty curve.
	mission_time_elapsed += delta
	if mission_count_up:
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

	# Beginner spawns at ~1.35x the interval (calmer) and caps lower;
	# Space Cowboy at ~0.7x (relentless) with the full cap.
	var t := clampi(difficulty_tier, 1, MAX_TIER)
	var interval_mult := 1.35 - (t - 1) * 0.22    # 1.35 · 1.13 · 0.91 · 0.69
	var cap_mult := 0.55 + (t - 1) * 0.15         # 0.55 · 0.70 · 0.85 · 1.0
	s["interval"] = float(s["interval"]) * interval_mult
	s["cap"] = maxi(20, int(float(s["cap"]) * cap_mult))
	s["roster"] = TIER_ROSTER.get(t, TIER_ROSTER[4])
	return s


## Minutes since the mission started, in either timer mode.
func mission_minutes() -> float:
	return mission_time_elapsed / 60.0


## Health/damage multiplier applied to every enemy spawned this session.
func get_enemy_stat_mult() -> float:
	return float(TIER_STAT_MULT.get(clampi(difficulty_tier, 1, MAX_TIER), 1.0))


## Which of the 4 solar systems the active stage belongs to (1-4), or 0 for
## the hub and the mission stages that aren't tied to one.
func get_system_index() -> int:
	if current_stage >= 1 and current_stage <= 4:
		return current_stage
	if current_stage >= 11 and current_stage <= 14:
		return current_stage - 10
	if current_stage >= 21 and current_stage <= 24:
		return current_stage - 20
	return 0


## Live hero level, so enemies scale as the run goes on rather than being
## locked to whatever the save said at load time.
func get_hero_level() -> int:
	var players := get_tree().get_nodes_in_group("friendlies")
	if not players.is_empty() and "level" in players[0]:
		return int(players[0].level)
	return int(SaveManager.stats_data.get("baseHeroLevel", 1))


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
	shard_drop_rate = 6
	experience_bonus = 0
	pending_module_picks = 0
	module_upgrade_count = 0
	modules_taken = { "common": 0, "rare": 0, "epic": 0, "legendary": 0, "godly": 0 }
	module_log.clear()
	stage_changed.emit(stage)


## Called by the pick panel whenever a module is fitted. The log keeps the
## wording as well as the count, so the inventory can list what you're
## carrying without re-deriving it from the systems.
func record_module(rarity: String, module_name: String, description: String) -> void:
	modules_taken[rarity] = int(modules_taken.get(rarity, 0)) + 1
	module_upgrade_count += 1
	module_log.append({ "rarity": rarity, "name": module_name, "desc": description })
	modules_changed.emit()


## Total CCC the fitted modules are worth before the completion ratio.
func modules_total_value() -> int:
	var total := 0
	for rarity in modules_taken:
		total += int(modules_taken[rarity]) * int(MODULE_VALUES.get(rarity, 0))
	return total


func modules_payout(completed: bool) -> int:
	var total := modules_total_value()
	return total if completed else int(round(total * MODULE_LOSS_RATIO))


func trigger_game_over() -> void:
	if game_done:
		return
	game_done = true
	game_over = true
	stop_mission_timer()
	# Surrendered salvage still pays, just at the failure rate
	_surrender_modules(false)
	advance_run_loop()
	game_over_triggered.emit()


func _surrender_modules(completed: bool) -> void:
	var payout := modules_payout(completed)
	if payout <= 0:
		return
	SaveManager.player_data["centralCurrency"] = \
		int(SaveManager.player_data.get("centralCurrency", 0)) + payout
	SaveManager.save_player_data()
	_emit_currency()


func trigger_mission_complete() -> void:
	if game_done:
		return
	game_done = true
	stop_mission_timer()
	_grant_mission_rewards()
	advance_run_loop()
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
	_surrender_modules(true)
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
	SceneTransition.change_scene(func():
		get_tree().change_scene_to_file("res://scenes/levels/testing_area.tscn"))


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
	SceneTransition.change_scene(func():
		get_tree().change_scene_to_file("res://scenes/levels/cosmic_hub.tscn"))


func goto_level_select() -> void:
	resume_game()
	ui_open = false
	SceneTransition.change_scene(func():
		get_tree().change_scene_to_file("res://scenes/levels/future_CCC_level_selection.tscn"))


# ── Enemy kill tracking ────────────────────────────────────────────────────────

func on_enemy_killed(experience: int) -> void:
	enemies_killed += 1
	enemy_killed_signal.emit(experience)
