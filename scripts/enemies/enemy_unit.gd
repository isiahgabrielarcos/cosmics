extends CharacterBody2D
class_name EnemyUnit

# Shared enemy behaviour: health, death, contact damage, visuals, and the
# 3-layer physics split (chasers / ships / shooters) that lets different
# archetypes overlap instead of clumping into one mass. Archetype scripts
# (enemy_chaser / enemy_bomber / enemy_shooter / enemy_slasher) extend this
# and only implement _move(delta).

const LAYER_ENTITIES := 1    # layer 1 — player
const LAYER_CHASERS   := 4   # layer 3 — chasers + bombers
const LAYER_SHIPS     := 8   # layer 4 — fast chasers/ships + slashers
const LAYER_SHOOTERS  := 32  # layer 6 — shooters
const LAYER_WALLS     := 64  # layer 7

const CONTACT_TICK := 0.8

const DEATH_FX      := preload("res://scenes/effects/particle_enemy_death.tscn")
const BOSS_DEATH_FX := preload("res://scenes/effects/particle_boss_death.tscn")

@export var data: EnemyData
var split_depth: int = 0

var hp: int
var max_hp: int

var _sprite: AnimatedSprite2D
var _contact_cooldown: float = 0.0
var _shoot_timer: float = 0.0
var _player: Node2D

static var _frames_cache: Dictionary = {}


func _ready() -> void:
	add_to_group("enemies")
	_setup_visual()
	_setup_collision()

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func _physics_process(delta: float) -> void:
	_player = _find_player()
	if _player == null:
		velocity = Vector2.ZERO
		return

	_move(delta)
	move_and_slide()

	if data.fires_projectiles:
		_shoot_timer += delta
		if _shoot_timer >= data.shoot_interval:
			_shoot_timer = 0.0
			_fire_at_player()

	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
	if _contact_cooldown == 0.0:
		_check_contact()


## Overridden by archetype scripts to drive `velocity` each physics frame.
func _move(_delta: float) -> void:
	velocity = Vector2.ZERO


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("friendlies")
	if players.is_empty():
		return null
	return players[0] as Node2D


func _face_player(turn: float) -> void:
	if _sprite and _player:
		var to_player := _player.global_position - global_position
		_sprite.rotation = lerp_angle(_sprite.rotation, to_player.angle() + PI / 2.0, turn * 0.016)


# ── Contact damage / ranged attack ─────────────────────────────────────────────

func _check_contact() -> void:
	if _player == null:
		return
	var reach := 60.0 * scale.x if not data.is_boss else 250.0
	if global_position.distance_to(_player.global_position) > reach:
		return
	if _player.has_method("take_damage"):
		_player.take_damage(data.contact_damage)
	_contact_cooldown = CONTACT_TICK


func _fire_at_player() -> void:
	if _player == null or get_tree().paused:
		return
	var proj := EnemyProjectile.new()
	proj.direction = (_player.global_position - global_position).normalized()
	proj.speed = data.projectile_speed
	proj.damage = data.projectile_damage
	proj.global_position = global_position
	get_tree().current_scene.add_child(proj)


# ── Damage / Death ───────────────────────────────────────────────────────────

func apply_damage(amount: int) -> void:
	hp -= amount
	modulate = Color(2, 2, 2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
	HitText.spawn(get_tree().current_scene, global_position, amount, Color.WHITE)
	if hp <= 0:
		_die()


func _die(with_drops: bool = true) -> void:
	ParticleEffect.spawn(BOSS_DEATH_FX if data.is_boss else DEATH_FX,
		get_tree().current_scene, global_position, scale.x)

	if data.self_split_count > 0 and split_depth < data.self_split_max_depth:
		_split()
		queue_free()
		return

	if data.death_spawn_data and data.death_spawn_count > 0:
		for i in data.death_spawn_count:
			_spawn_variant(data.death_spawn_data,
				global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)))

	if with_drops:
		if data.is_boss:
			AudioManager.play_sfx("bossDeathSound")
			for i in 5:
				ExperienceShard.spawn(get_tree().current_scene, global_position,
					"godly" if i == 0 else "epic")
		else:
			AudioManager.play_sfx("enemyDeath")
			ExperienceShard.spawn(get_tree().current_scene, global_position)

	GameManager.on_enemy_killed(data.experience_value)
	queue_free()


func _split() -> void:
	for i in data.self_split_count:
		var child := _spawn_variant(data,
			global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
		if child:
			child.split_depth = split_depth + 1
			child.scale = scale * data.self_split_scale_mult
			child.max_hp = maxi(1, int(max_hp * data.self_split_hp_mult))
			child.hp = child.max_hp


func _spawn_variant(spawn_data: EnemyData, pos: Vector2) -> EnemyUnit:
	var scene: PackedScene = load(scene_file_path)
	var inst: EnemyUnit = scene.instantiate()
	inst.data = spawn_data
	inst.global_position = pos
	get_tree().current_scene.add_child(inst)
	return inst


# ── Build (visuals + physics layers) ───────────────────────────────────────────

func _setup_visual() -> void:
	_sprite = $AnimatedSprite2D
	_sprite.sprite_frames = _get_frames(data)
	_sprite.play("idle")

	max_hp = data.max_hp
	hp = max_hp

	scale = Vector2.ONE * (data.fixed_scale if data.fixed_scale > 0.0 else randf_range(data.scale_min, data.scale_max))


func _setup_collision() -> void:
	var shape: CollisionShape2D = $CollisionShape2D
	var circle := CircleShape2D.new()
	circle.radius = 60.0 if data.is_boss else 16.0
	shape.shape = circle

	var group_layer := LAYER_CHASERS
	match data.physics_group:
		EnemyData.PhysicsGroup.SHIPS:
			group_layer = LAYER_SHIPS
		EnemyData.PhysicsGroup.SHOOTERS:
			group_layer = LAYER_SHOOTERS

	collision_layer = group_layer
	collision_mask = group_layer | LAYER_ENTITIES | LAYER_WALLS


static func _get_frames(d: EnemyData) -> SpriteFrames:
	var key := d.sprite_sheet.resource_path if d.sprite_sheet else ""
	if key != "" and _frames_cache.has(key):
		return _frames_cache[key]

	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", d.fps)
	frames.set_animation_loop("idle", true)

	var tex := d.sprite_sheet
	var cols := maxi(1, int(tex.get_width() / d.frame_width))
	for i in d.frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		@warning_ignore("integer_division")
		atlas.region = Rect2((i % cols) * d.frame_width, (i / cols) * d.frame_height, d.frame_width, d.frame_height)
		frames.add_frame("idle", atlas)

	if key != "":
		_frames_cache[key] = frames
	return frames
