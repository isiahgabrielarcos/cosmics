extends CharacterBody2D
class_name EnemyUnit

# Shared enemy behaviour: health, death, contact damage, visuals, and the
# 3-layer physics split (chasers / ships / shooters) that lets different
# archetypes overlap instead of clumping into one mass. Archetype scripts
# (enemy_chaser / enemy_bomber / enemy_shooter / enemy_slasher) extend this
# and only implement _move(delta).

const LAYER_ENTITIES := 1     # layer 1 — player
const LAYER_CHASERS  := 4     # layer 3
const LAYER_SHIPS    := 8     # layer 4 — fast chasers
const LAYER_SLASHERS := 16    # layer 5
const LAYER_SHOOTERS := 32    # layer 6
const LAYER_WALLS    := 64    # layer 7
const LAYER_BOMBERS  := 128   # layer 8
const LAYER_BOSSES   := 256   # layer 9

const GROUP_LAYERS := {
	EnemyData.PhysicsGroup.CHASERS:  LAYER_CHASERS,
	EnemyData.PhysicsGroup.SHIPS:    LAYER_SHIPS,
	EnemyData.PhysicsGroup.SHOOTERS: LAYER_SHOOTERS,
	EnemyData.PhysicsGroup.SLASHERS: LAYER_SLASHERS,
	EnemyData.PhysicsGroup.BOMBERS:  LAYER_BOMBERS,
	EnemyData.PhysicsGroup.BOSSES:   LAYER_BOSSES,
}

## What anything friendly that deals damage should collide with: the player's
## layer plus every enemy lane. Projectiles and module effects all use this —
## hardcoding a bitmask meant adding the bomber and boss lanes silently made
## those two immune to every bullet in the game.
const HOSTILE_MASK := LAYER_ENTITIES | LAYER_CHASERS | LAYER_SHIPS \
	| LAYER_SLASHERS | LAYER_SHOOTERS | LAYER_BOMBERS | LAYER_BOSSES

const CONTACT_TICK := 0.8
## Small grace on top of the two collision radii, so a hit still registers on
## the frame the bodies are resolved apart by move_and_slide.
const CONTACT_TOLERANCE := 4.0

const DEATH_FX      := preload("res://scenes/effects/particle_enemy_death.tscn")
const BOSS_DEATH_FX := preload("res://scenes/effects/particle_boss_death.tscn")

@export var data: EnemyData
var split_depth: int = 0

var hp: int
var max_hp: int

# Scaled copies of the damage numbers. `data` is a cached resource shared by
# every enemy of this kind, so difficulty multipliers have to live on the
# instance rather than being written back into it.
var contact_damage: int
var projectile_damage: int

# Contact reach, derived from the real collision radii in _setup_collision so
# hits land when the bodies actually meet.
var _contact_reach: float = 60.0
var _cached_player_radius: float = -1.0

# Status effects. Burning ticks damage over time (Scorching Temperature
# projectiles); paralysis freezes movement in place (Electric projectiles,
# Shockwave, Electro Shield). Both re-apply by refreshing rather than
# stacking, so a stream of procs keeps an enemy locked without runaway ticks.
var _burn_ticks_left: int = 0
var _burn_damage: int = 0
var _burn_tick_timer: float = 0.0
var _paralysis_left: float = 0.0

## Obstacle avoidance. Which way this one peels around scenery is decided once
## at spawn so a crowd splits both ways instead of forming a single queue.
const AVOID_LOOKAHEAD := 90.0
const AVOID_STRENGTH := 1.4
var _avoid_side: float = 1.0

var _sprite: AnimatedSprite2D
var _contact_cooldown: float = 0.0
var _shoot_timer: float = 0.0
var _player: Node2D

static var _frames_cache: Dictionary = {}


func _ready() -> void:
	add_to_group("enemies")
	_avoid_side = 1.0 if randf() < 0.5 else -1.0
	_setup_visual()
	_setup_collision()

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func _physics_process(delta: float) -> void:
	_tick_status(delta)

	_player = _find_player()
	if _player == null:
		velocity = Vector2.ZERO
		return

	if _paralysis_left > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_move(delta)
	_steer_around_obstacles()
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


## Nudges velocity sideways when scenery is directly ahead.
##
## The archetypes all steer straight at the player, and move_and_slide alone
## just grinds them along an asteroid's edge — with a big enough rock they
## stall against it indefinitely. Probing ahead and adding a perpendicular
## component makes them peel around it instead. Which way they peel is fixed
## per enemy, so a group splits either side rather than all picking the same
## direction and forming a queue.
func _steer_around_obstacles() -> void:
	if velocity == Vector2.ZERO:
		return

	var space := get_world_2d().direct_space_state
	var ahead := velocity.normalized() * (_contact_reach + AVOID_LOOKAHEAD)

	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + ahead, LAYER_WALLS)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return

	var side := velocity.normalized().rotated(PI / 2.0) * _avoid_side
	velocity = (velocity.normalized() + side * AVOID_STRENGTH).normalized() * velocity.length()


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

## The distance at which this enemy is actually touching the ship: its own
## collision radius plus the player's, with a small grace. Archetypes that
## override _check_contact (the bomber) share it rather than inventing their
## own reach.
func contact_reach() -> float:
	return _contact_reach + _player_radius() + CONTACT_TOLERANCE


## Contact damage lands only once the two hulls actually meet, rather than
## from a flat radius well outside the enemy's own sprite.
func _check_contact() -> void:
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) > contact_reach():
		return
	if _player.has_method("take_damage"):
		_player.take_damage(contact_damage, self)
	_contact_cooldown = CONTACT_TICK


func _player_radius() -> float:
	if _cached_player_radius >= 0.0:
		return _cached_player_radius
	_cached_player_radius = 24.0
	var shape := _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.shape is CircleShape2D:
		_cached_player_radius = (shape.shape as CircleShape2D).radius * _player.scale.x
	return _cached_player_radius


func _fire_at_player() -> void:
	if _player == null or get_tree().paused:
		return
	var proj := EnemyProjectile.new()
	proj.direction = (_player.global_position - global_position).normalized()
	proj.speed = data.projectile_speed
	proj.damage = projectile_damage
	proj.global_position = global_position
	get_tree().current_scene.add_child(proj)


# ── Status effects ─────────────────────────────────────────────────────────────

const BURN_TICK_INTERVAL := 0.2

## Sets something alight — `ticks` hits of `damage_per_tick`, 5 per second.
## Re-applying refreshes the duration instead of stacking a second burn.
func apply_burn(damage_per_tick: int, ticks: int) -> void:
	if data.immune_to_status:
		return
	var was_burning := _burn_ticks_left > 0
	_burn_damage = maxi(_burn_damage, damage_per_tick)
	_burn_ticks_left = maxi(_burn_ticks_left, ticks)
	if not was_burning:
		_burn_tick_timer = BURN_TICK_INTERVAL
		HitText.spawn_status(get_tree().current_scene, global_position, "BURN!", HitText.BURN_COLOR)
	_refresh_status_tint()


## Locks an enemy in place. Re-applying keeps whichever duration is longer.
func apply_paralysis(duration: float) -> void:
	if data.immune_to_status:
		return
	var was_paralyzed := _paralysis_left > 0.0
	_paralysis_left = maxf(_paralysis_left, duration)
	if not was_paralyzed:
		HitText.spawn_status(get_tree().current_scene, global_position,
			"PARALYZED!", HitText.PARALYSIS_COLOR)
	_refresh_status_tint()


func _tick_status(delta: float) -> void:
	if _paralysis_left > 0.0:
		_paralysis_left = maxf(0.0, _paralysis_left - delta)
		if _paralysis_left == 0.0:
			_refresh_status_tint()

	if _burn_ticks_left <= 0:
		return
	_burn_tick_timer -= delta
	if _burn_tick_timer > 0.0:
		return
	_burn_tick_timer = BURN_TICK_INTERVAL
	_burn_ticks_left -= 1
	if _burn_ticks_left <= 0:
		_refresh_status_tint()
	# Burn ticks skip the white hit-flash so the fire tint stays readable
	hp -= _burn_damage
	HitText.spawn(get_tree().current_scene, global_position, _burn_damage, HitText.BURN_COLOR)
	if hp <= 0:
		_die()


## Paralysis reads over burning — being frozen matters more to the player.
func _refresh_status_tint() -> void:
	if _sprite == null:
		return
	if _paralysis_left > 0.0:
		_sprite.modulate = Color(1.0, 1.0, 0.4)
	elif _burn_ticks_left > 0:
		_sprite.modulate = Color(1.0, 0.45, 0.3)
	else:
		_sprite.modulate = Color.WHITE


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

	if with_drops and data.drops_loot:
		if data.is_boss:
			AudioManager.play_sfx("bossDeathSound")
			for i in 5:
				ExperienceShard.spawn(get_tree().current_scene, global_position,
					"godly" if i == 0 else "epic")
		else:
			AudioManager.play_sfx("enemyDeath")
			ExperienceShard.spawn(get_tree().current_scene, global_position)

	_grant_kill_experience()
	GameManager.on_enemy_killed(data.experience_value)
	queue_free()


## Kills feed the XP bar a little on their own, so clearing a wave still makes
## progress on the stretches where no shards happen to drop. Bosses are worth
## proportionally more, since experience_value already scales with the kill.
func _grant_kill_experience() -> void:
	if _player == null or not _player.has_method("add_experience"):
		return
	var common_worth: int = int(ExperienceShard.RARITY_DATA["common"]["worth"])
	var ratio: float = _player.KILL_EXPERIENCE_RATIO
	var amount := maxi(1, int(round(common_worth * ratio
		* (float(data.experience_value) / float(common_worth)))))
	_player.add_experience(amount)


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

	# Health climbs with the hero so late-run enemies stay a threat; both
	# health and damage then scale with the chosen difficulty.
	var mult := GameManager.get_enemy_stat_mult()
	max_hp = maxi(1, int(round(
		(data.max_hp + data.hp_per_hero_level * GameManager.get_hero_level()) * mult)))
	hp = max_hp
	contact_damage = maxi(1, int(round(data.contact_damage * mult)))
	projectile_damage = maxi(1, int(round(data.projectile_damage * mult)))

	scale = Vector2.ONE * (data.fixed_scale if data.fixed_scale > 0.0 else randf_range(data.scale_min, data.scale_max))


func _setup_collision() -> void:
	var shape: CollisionShape2D = $CollisionShape2D
	var circle := CircleShape2D.new()
	circle.radius = 60.0 if data.is_boss else 16.0
	shape.shape = circle
	# scale is already applied by _setup_visual, which runs first
	_contact_reach = circle.radius * scale.x

	# Bosses share a lane regardless of what they behave like, so they never
	# get jostled by the crowd they arrive with.
	var group_layer: int = LAYER_BOSSES if data.is_boss \
		else int(GROUP_LAYERS.get(data.physics_group, LAYER_CHASERS))

	collision_layer = group_layer
	collision_mask = group_layer | LAYER_ENTITIES | LAYER_WALLS

	# Spawned mid-run into a player who already took Anti-Collision
	var players := get_tree().get_nodes_in_group("friendlies")
	if not players.is_empty() and players[0].get("got_anti_collision"):
		set_passes_through_player(true)


## Anti-Collision module — stop bumping the ship while still colliding with
## other enemies and the walls.
func set_passes_through_player(enabled: bool) -> void:
	if enabled:
		collision_mask &= ~LAYER_ENTITIES
	else:
		collision_mask |= LAYER_ENTITIES


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
