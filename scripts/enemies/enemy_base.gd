extends CharacterBody2D
class_name EnemyBase

# Generic enemy — ports the archetype behaviours from enemiesMap.lua:
#   chasers(), stationaryEnemies(), shipChaserDashers(), shipSlasher(),
#   enemyShooter(), whereSpawn() sizing/health rules.
# Built in code by EnemyFactory — no per-enemy scene needed.

enum Behavior { CHASER, STATIONARY_SHOOTER, BOMBER, SHIP_SLASHER, SHIP_DASHER, BOSS_CHASER, BOSS_SLASHER }

var behavior: Behavior = Behavior.CHASER
var speed: float = 325.0
var max_hp: int = 80
var hp: int = 80
var contact_damage: int = 5
var experience_value: int = 5
var is_boss: bool = false
var is_mama_slime: bool = false

const CONTACT_TICK := 0.8        # seconds between contact damage ticks
const ORBIT_RADIUS := 255.0      # shipSlasher: 150 * 1.70
const SHOOT_INTERVAL := 3.0      # enemyShooter fires every 3 s

var _sprite: AnimatedSprite2D
var _contact_cooldown: float = 0.0
var _shoot_timer: float = 0.0
var _player: Node2D


func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp

	# fade in like the Lua transition.to alpha
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func _physics_process(delta: float) -> void:
	_player = _find_player()
	if _player == null:
		velocity = Vector2.ZERO
		return

	match behavior:
		Behavior.CHASER, Behavior.BOMBER, Behavior.BOSS_CHASER:
			_chase(delta)
		Behavior.SHIP_DASHER:
			_chase(delta)
			_face_player(delta, 8.0)
		Behavior.SHIP_SLASHER, Behavior.BOSS_SLASHER:
			_orbit(delta)
		Behavior.STATIONARY_SHOOTER:
			velocity = Vector2.ZERO

	move_and_slide()

	# stationary shooters + shooter-type bosses fire at the player
	if behavior == Behavior.STATIONARY_SHOOTER:
		_shoot_timer += delta
		if _shoot_timer >= SHOOT_INTERVAL:
			_shoot_timer = 0.0
			_fire_at_player()

	# contact damage tick
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
	if _contact_cooldown == 0.0:
		_check_contact()


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("friendlies")
	if players.is_empty():
		return null
	return players[0] as Node2D


# ── Movement (chasers / shipSlasher orbits) ────────────────────────────────────

func _chase(_delta: float) -> void:
	var offset := _player.global_position - global_position
	if offset.length() < 50.0:
		velocity = Vector2.ZERO
		return
	velocity = offset.normalized() * speed
	if behavior != Behavior.SHIP_DASHER and _sprite:
		_sprite.rotation = lerp_angle(_sprite.rotation, offset.angle() + PI / 2.0, 0.1)


func _orbit(delta: float) -> void:
	var offset := _player.global_position - global_position
	var dist := offset.length()
	var radius := ORBIT_RADIUS * (1.3 if is_boss else 1.0)

	if dist <= radius:
		# circle around the hero (shipSlasher circumference movement)
		var angle := (-offset).angle()
		var target := _player.global_position + Vector2(cos(angle), sin(angle)) * radius
		velocity = (target - global_position) * 6.0
	else:
		velocity = offset.normalized() * speed
	_face_player(delta, 6.0)


func _face_player(_delta: float, turn: float) -> void:
	if _sprite:
		var to_player := _player.global_position - global_position
		_sprite.rotation = lerp_angle(_sprite.rotation, to_player.angle() + PI / 2.0, turn * 0.016)


# ── Attacks ────────────────────────────────────────────────────────────────────

func _check_contact() -> void:
	if _player == null:
		return
	var reach := 60.0 * scale.x if not is_boss else 250.0
	if global_position.distance_to(_player.global_position) > reach:
		return
	if _player.has_method("take_damage"):
		_player.take_damage(contact_damage)
	_contact_cooldown = CONTACT_TICK

	if behavior == Behavior.BOMBER:
		_explode()


func _explode() -> void:
	# Bombers blow up on contact
	AudioManager.play_sfx("explosionSound")
	if _player and _player.has_method("take_damage"):
		_player.take_damage(contact_damage)
	_die(false)


func _fire_at_player() -> void:
	if _player == null or get_tree().paused:
		return
	var proj := EnemyProjectile.new()
	proj.direction = (_player.global_position - global_position).normalized()
	proj.global_position = global_position
	get_tree().current_scene.add_child(proj)


# ── Damage / Death ─────────────────────────────────────────────────────────────

func apply_damage(amount: int) -> void:
	hp -= amount
	# hit flash
	modulate = Color(2, 2, 2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
	if hp <= 0:
		_die(true)


func _die(with_drops: bool) -> void:
	if is_mama_slime:
		# Mama slime splits into baby slimes (enemy6)
		for i in 3:
			EnemyFactory.spawn_baby_slime(get_tree().current_scene,
				global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)))

	if with_drops:
		if is_boss:
			AudioManager.play_sfx("bossDeathSound")
			for i in 5:
				ExperienceShard.spawn(get_tree().current_scene, global_position,
					"godly" if i == 0 else "epic")
		else:
			AudioManager.play_sfx("enemyDeath")
			ExperienceShard.spawn(get_tree().current_scene, global_position)
	GameManager.on_enemy_killed(experience_value)
	queue_free()


# ── Build helpers (called by EnemyFactory) ─────────────────────────────────────

func setup_visual(frames: SpriteFrames, visual_scale: float) -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.play("idle")
	add_child(_sprite)
	scale = Vector2.ONE * visual_scale

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 60.0 if is_boss else 16.0
	shape.shape = circle
	add_child(shape)

	collision_layer = 1
	collision_mask = 1 | 64   # other enemies + walls
