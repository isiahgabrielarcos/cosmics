extends Node2D

# Ports randomSpawner() from enemiesMap.lua:
#   stage picks the faction (1 FlaschBourn · 2 Strogghold · 3 Frokenvinter ·
#   4 Squilltrant · 11–20 & 31–39: any faction),
#   roll 1..30 picks the archetype, roll 25–30 spawns an extra enemy,
#   roll ≤ maxShardDropRate drops a free XP shard, roll ≤ 2 drops a module chest,
#   and every 50th spawn calls in a boss.

@export var spawn_margin: float = 300.0

@export var player_path: NodePath
@export var camera_path: NodePath

var rng := RandomNumberGenerator.new()
@onready var spawn_timer: Timer = Timer.new()
var player: Node2D
var camera: Camera2D

var spawn_interval: float = 1.0
var spawn_count: int = 0
var _session_faction: int = 0

## Weighted archetype table for the session's difficulty (GameManager's
## TIER_ROSTER) — which enemy kinds may spawn and how often.
var _roster: Dictionary = {}
var _roster_total: int = 0

const MODULE_CHEST_DROP_RATE := 2  # percent per spawn tick

## How far an enemy can drift before it's teleported back to just outside the
## camera. Kept generous — a tight leash was the main reason the opening
## minutes felt relentless, since nothing you outran ever actually left.
const REPOSITION_RADIUS := 2800.0

# ── Difficulty curve ──────────────────────────────────────────────────────────
# The run ramps on a clock rather than all at once. Each band says how big a
# batch can be, how crowded the field may already be before batches stop, and
# how much to stretch the trickle interval — so the first five minutes are
# genuinely quiet and the fifteen-minute mark is busy.
# `target` is the live population the band wants to sustain: once the field
# reaches it the trickle stops and only kills bring it back down. Without it
# the drip alone put ~37 enemies a minute on screen in the opening band, which
# is what made the first few minutes feel like the tenth.
const SPAWN_BANDS := [
	{ "until": 3.0,  "batch": Vector2i(2, 3), "batch_cap": 5,  "target": 8,
	  "chance": 18, "interval": 2.3 },
	{ "until": 5.0,  "batch": Vector2i(2, 4), "batch_cap": 7,  "target": 11,
	  "chance": 24, "interval": 1.7 },
	{ "until": 10.0, "batch": Vector2i(3, 5), "batch_cap": 13, "target": 20,
	  "chance": 28, "interval": 1.2 },
	{ "until": 15.0, "batch": Vector2i(4, 7), "batch_cap": 18, "target": 30,
	  "chance": 26, "interval": 0.95 },
	{ "until": 1e9,  "batch": Vector2i(6, 9), "batch_cap": 22, "target": 42,
	  "chance": 24, "interval": 0.8 },
]

## The field never gets quieter than this. A lucky upgrade run can clear
## enemies faster than the band's pacing refills them, and an empty screen is
## worse than a hard one — below this the spawner backfills immediately,
## ignoring the tick interval.
const MIN_ACTIVE_ENEMIES := 5

## Batches never fire past this many live enemies, whatever the band says.
const HARD_BATCH_CAP := 22
## Nothing spawns at all past this, batch or trickle.
const HARD_SPAWN_CAP := 50

const WAVE_SPREAD := 350.0         # how loosely a batch is scattered

## Minimum gap between backfills, so clearing a wave doesn't instantly
## teleport a replacement one onto the player.
const BACKFILL_INTERVAL := 1.2

var _band_index: int = -1
var _backfill_cooldown: float = 0.0


func _ready() -> void:
	rng.randomize()

	player = get_node_or_null(player_path)
	camera = get_node_or_null(camera_path)
	if not player or not camera:
		push_error("Spawner: Player or Camera not assigned.")
		return

	# Per-mission tuning from GameManager (enemySpawner variants in the Lua)
	var settings: Dictionary = GameManager.get_spawner_settings()
	spawn_interval = settings.get("interval", 1.0)
	_set_roster(settings.get("roster", {}))

	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

	_session_faction = _pick_session_faction()
	set_process(true)


func _process(delta: float) -> void:
	_check_and_reposition_enemies()
	_keep_field_populated(delta)


## Backfills the field when it drops below MIN_ACTIVE_ENEMIES without waiting
## for the next tick, so a strong build clearing the screen doesn't leave the
## player circling an empty map.
func _keep_field_populated(delta: float) -> void:
	if GameManager.game_done or GameManager.is_hub():
		return
	_backfill_cooldown = maxf(0.0, _backfill_cooldown - delta)
	if _backfill_cooldown > 0.0:
		return

	var live: int = get_tree().get_nodes_in_group("enemies").size()
	if live >= MIN_ACTIVE_ENEMIES:
		return

	var faction := _stage_faction()
	if faction == 0:
		return
	for i in (MIN_ACTIVE_ENEMIES - live):
		EnemyFactory.spawn_kind(get_tree().current_scene, faction, _roll_kind(),
			_spawn_position())
		spawn_count += 1
	_backfill_cooldown = BACKFILL_INTERVAL


## Which band the run is currently in, and retunes the trickle interval the
## first tick after crossing into a new one.
func _current_band() -> Dictionary:
	var minutes := GameManager.mission_minutes()
	var index := SPAWN_BANDS.size() - 1
	for i in SPAWN_BANDS.size():
		if minutes < float(SPAWN_BANDS[i]["until"]):
			index = i
			break

	if index != _band_index:
		_band_index = index
		spawn_timer.wait_time = maxf(0.2, spawn_interval * float(SPAWN_BANDS[index]["interval"]))
		spawn_timer.start()
	return SPAWN_BANDS[index]


func _on_spawn_timer_timeout() -> void:
	if GameManager.game_done or GameManager.is_hub():
		return

	var band := _current_band()
	var live: int = get_tree().get_nodes_in_group("enemies").size()

	# Hard ceiling — the field is full, nothing else arrives until it thins.
	var cap: int = mini(int(GameManager.get_spawner_settings().get("cap", 100)), HARD_SPAWN_CAP)
	if live >= cap:
		return

	# Batches only while the field is still thin for this stage of the run;
	# past that it's a trickle, so a crowd never snowballs into a wall.
	var batch_ceiling: int = mini(int(band["batch_cap"]), HARD_BATCH_CAP)
	if live < batch_ceiling and rng.randi_range(1, 100) <= int(band["chance"]):
		_spawn_wave(band, cap - live)
		return

	# At or above the band's target the drip stops too, so the population
	# settles around what this stage of the run is meant to feel like
	# instead of climbing to the hard cap regardless of the clock.
	if live < int(band["target"]):
		_random_spawner()
	else:
		_drop_pickups()


# ── randomSpawner() ────────────────────────────────────────────────────────────

func _set_roster(roster: Dictionary) -> void:
	_roster = roster if not roster.is_empty() else GameManager.TIER_ROSTER[4]
	_roster_total = 0
	for kind in _roster:
		_roster_total += int(_roster[kind])


## Weighted pick from the difficulty's archetype table.
func _roll_kind() -> String:
	var pick := rng.randi_range(1, maxi(1, _roster_total))
	for kind in _roster:
		pick -= int(_roster[kind])
		if pick <= 0:
			return kind
	return "chaser"


## Shards and chests keep coming even on ticks that spawn nothing, so a full
## field doesn't also mean a drought of pickups.
func _drop_pickups() -> void:
	# Rolled separately from the archetype roll so a narrow roster doesn't
	# also mean a shard shower. The rate is the run's own, since More Crystal
	# Shards picks raise it.
	if rng.randi_range(1, 30) <= GameManager.shard_drop_rate:
		ExperienceShard.spawn(get_tree().current_scene, _pickup_position())

	# roll <= 2: a module chest (dropModuleChests)
	if rng.randi_range(1, 100) <= MODULE_CHEST_DROP_RATE:
		ModuleChest.spawn(get_tree().current_scene, _pickup_position())


func _random_spawner() -> void:
	_drop_pickups()

	var faction := _stage_faction()
	if faction == 0:
		return   # hub or unknown stage — no spawns

	EnemyFactory.spawn_kind(get_tree().current_scene, faction, _roll_kind(), _spawn_position())
	spawn_count += 1

	# Now and then a second one tags along, so the field doesn't arrive at a
	# perfectly even drip. Held back in the opening minutes.
	if GameManager.mission_minutes() >= 5.0 and rng.randi_range(1, 100) <= 20:
		EnemyFactory.spawn_kind(get_tree().current_scene, faction, _roll_kind(), _spawn_position())
		spawn_count += 1

	# every 50th spawn: this system's boss shows up
	if spawn_count % 50 == 0 and spawn_count > 10:
		EnemyFactory.spawn_system_boss(get_tree().current_scene, faction, _spawn_position())
		spawn_count += 1


## A patch of enemies dropped in together from one side, rather than the
## usual one-at-a-time trickle.
func _spawn_wave(band: Dictionary, room_left: int) -> void:
	var faction := _stage_faction()
	if faction == 0:
		return

	var size: Vector2i = band["batch"]
	var count := mini(rng.randi_range(size.x, size.y), room_left)
	if count <= 0:
		return

	var anchor := _spawn_position()
	for i in count:
		var at := anchor + Vector2(
			rng.randf_range(-WAVE_SPREAD, WAVE_SPREAD),
			rng.randf_range(-WAVE_SPREAD, WAVE_SPREAD))
		EnemyFactory.spawn_kind(get_tree().current_scene, faction, _roll_kind(), at)
		spawn_count += 1


func _pick_session_faction() -> int:
	var stage := GameManager.current_stage
	match stage:
		1: return 1
		2: return 2
		3: return 3
		4: return 4
	if (stage >= 11 and stage <= 39) or stage == 101:
		return rng.randi_range(1, 4)
	return 0


## The all-in-one sandbox rerolls per spawn, so every faction shows up in the
## same run instead of the session picking one and sticking with it.
func _stage_faction() -> int:
	if GameManager.current_stage == GameManager.ALL_IN_ONE_STAGE:
		return rng.randi_range(1, 4)
	return _session_faction


# ── Positioning ────────────────────────────────────────────────────────────────

func _spawn_position() -> Vector2:
	return _pick_outside_position(get_camera_rect(), spawn_margin)


func _pickup_position() -> Vector2:
	# drops appear within reach of the player, not offscreen
	var angle := rng.randf() * TAU
	var dist := rng.randf_range(300.0, 700.0)
	return player.global_position + Vector2(cos(angle), sin(angle)) * dist


func _check_and_reposition_enemies() -> void:
	# if an enemy strays too far from the player, teleport it just outside camera
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D):
			continue
		if enemy.global_position.distance_to(player.global_position) > REPOSITION_RADIUS:
			enemy.global_position = _pick_outside_position(get_camera_rect(), spawn_margin)


func _pick_outside_position(cam_rect: Rect2, margin: float) -> Vector2:
	var side := rng.randi_range(0, 3)
	var x: float
	var y: float

	match side:
		0:
			x = cam_rect.position.x - margin
			y = rng.randf_range(cam_rect.position.y, cam_rect.position.y + cam_rect.size.y)
		1:
			x = cam_rect.position.x + cam_rect.size.x + margin
			y = rng.randf_range(cam_rect.position.y, cam_rect.position.y + cam_rect.size.y)
		2:
			y = cam_rect.position.y - margin
			x = rng.randf_range(cam_rect.position.x, cam_rect.position.x + cam_rect.size.x)
		_:
			y = cam_rect.position.y + cam_rect.size.y + margin
			x = rng.randf_range(cam_rect.position.x, cam_rect.position.x + cam_rect.size.x)
	return Vector2(x, y)


func get_camera_rect() -> Rect2:
	var screen_size := get_viewport().get_visible_rect().size
	var top_left := camera.global_position - screen_size * 0.5
	return Rect2(top_left, screen_size)
