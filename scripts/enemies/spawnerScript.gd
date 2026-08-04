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

const MAX_SHARD_DROP_RATE := 6     # currentMaxShardDropRate
const REPOSITION_RADIUS := 1500.0

# Swarms — instead of a steady trickle, a tick can occasionally dump a whole
# patch of enemies in from one side. Common while the field is thin (so quiet
# stretches don't drag), rare once there's already a crowd to deal with.
const WAVE_SIZE := Vector2i(5, 10)
const WAVE_QUIET_THRESHOLD := 15   # "few enemies" line
const WAVE_CHANCE_QUIET := 15      # percent, below the threshold
const WAVE_CHANCE_BUSY := 1        # percent, at or above it
const WAVE_SPREAD := 350.0         # how loosely the patch is scattered


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


func _process(_delta: float) -> void:
	_check_and_reposition_enemies()


func _on_spawn_timer_timeout() -> void:
	if GameManager.game_done or GameManager.is_hub():
		return
	var cap: int = GameManager.get_spawner_settings().get("cap", 100)
	var live: int = get_tree().get_nodes_in_group("enemies").size()
	if live >= cap:
		return

	var wave_chance := WAVE_CHANCE_QUIET if live < WAVE_QUIET_THRESHOLD else WAVE_CHANCE_BUSY
	if rng.randi_range(1, 100) <= wave_chance:
		_spawn_wave(cap - live)
	else:
		_random_spawner()


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


func _random_spawner() -> void:
	# Free pickup drops near the player — rolled separately from the archetype
	# roll so a narrow roster doesn't also mean a shard shower.
	if rng.randi_range(1, 30) <= MAX_SHARD_DROP_RATE:
		ExperienceShard.spawn(get_tree().current_scene, _pickup_position())

	var faction := _stage_faction()
	if faction == 0:
		return   # hub or unknown stage — no spawns

	EnemyFactory.spawn_kind(get_tree().current_scene, faction, _roll_kind(), _spawn_position())
	spawn_count += 1

	# Now and then a second one tags along, so the field doesn't arrive at a
	# perfectly even drip.
	if rng.randi_range(1, 100) <= 20:
		EnemyFactory.spawn_kind(get_tree().current_scene, faction, _roll_kind(), _spawn_position())
		spawn_count += 1

	# every 50th spawn: this system's boss shows up
	if spawn_count % 50 == 0 and spawn_count > 10:
		EnemyFactory.spawn_system_boss(get_tree().current_scene, faction, _spawn_position())
		spawn_count += 1


## A patch of enemies dropped in together from one side, rather than the
## usual one-at-a-time trickle.
func _spawn_wave(room_left: int) -> void:
	var faction := _stage_faction()
	if faction == 0:
		return

	var count := mini(rng.randi_range(WAVE_SIZE.x, WAVE_SIZE.y), room_left)
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


func _stage_faction() -> int:
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
