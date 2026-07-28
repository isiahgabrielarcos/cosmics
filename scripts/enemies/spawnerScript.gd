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

const MAX_SHARD_DROP_RATE := 6     # currentMaxShardDropRate
const REPOSITION_RADIUS := 1500.0


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

	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

	set_process(true)


func _process(_delta: float) -> void:
	_check_and_reposition_enemies()


func _on_spawn_timer_timeout() -> void:
	if GameManager.game_done or GameManager.is_hub():
		return
	var cap: int = GameManager.get_spawner_settings().get("cap", 100)
	if get_tree().get_nodes_in_group("enemies").size() >= cap:
		return

	_random_spawner()


# ── randomSpawner() ────────────────────────────────────────────────────────────

func _random_spawner() -> void:
	var roll := rng.randi_range(1, 30)
	var roll2 := rng.randi_range(1, 30)

	# Free pickup drops near the player
	if roll <= MAX_SHARD_DROP_RATE:
		ExperienceShard.spawn(get_tree().current_scene, _pickup_position())
	if roll <= 2:
		ModuleChest.spawn(get_tree().current_scene, _pickup_position())

	var faction := _stage_faction()
	if faction == 0:
		return   # hub or unknown stage — no spawns

	EnemyFactory.spawn_from_roll(get_tree().current_scene, faction, roll, _spawn_position())
	spawn_count += 1

	# roll 25–30: bonus enemy from a random faction
	if roll >= 25:
		EnemyFactory.spawn_from_roll(get_tree().current_scene,
			rng.randi_range(1, 4), roll2, _spawn_position())
		spawn_count += 1

	# every 50th spawn: a boss shows up
	if spawn_count % 50 == 0 and spawn_count > 10:
		EnemyFactory.spawn_random_boss(get_tree().current_scene, _spawn_position())
		spawn_count += 1


func _stage_faction() -> int:
	var stage := GameManager.current_stage
	match stage:
		1: return 1
		2: return 2
		3: return 3
		4: return 4
	# complex, endless, and mission stages: any faction
	if (stage >= 11 and stage <= 39) or stage == 101:
		return rng.randi_range(1, 4)
	return 0


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
