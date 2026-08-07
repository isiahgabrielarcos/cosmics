extends Area2D
class_name WeaponProjectile

# Shared runtime for the 7 baked weapon scenes (scenes/weapons/*.tscn) —
# visuals + collision shape are real scene nodes, stats come from the
# WeaponData resource assigned in each scene. WeaponSystem instances one of
# these per shot and only sets `direction`, `damage`, and `follow_target`.
#
# module_system.gd's skill effects still use the older HeroProjectile
# factory (hero_projectile.gd) — untouched, unrelated to these 7 weapons.

const POP_FX := preload("res://scenes/effects/particle_projectile_pop.tscn")

# Scorching Temperature — burns for 3 seconds at 5 ticks/sec. The per-tick
# damage tracks hero level for the same reason module damage does: enemy
# health grows every level, so a flat burn stops mattering.
const BURN_BASE_DAMAGE := 4
const BURN_DAMAGE_PER_LEVEL := 1
const BURN_TICKS := 15
# Electric Projectiles — the Lua's eletroProjectileDuration
const PARALYSIS_DURATION := 3.0

@export var data: WeaponData

var direction: Vector2 = Vector2.UP
var follow_target: Node2D = null
var damage: int = 0

## Shrinks the round without touching the weapon's own visual_scale — the
## side guns and anti-flank cannon fire at half size.
var scale_mult: float = 1.0

## Shrink Device makes rounds travel faster without editing the resource.
var speed_mult: float = 1.0

## data.pierce plus whatever upgrades add, already clamped to the weapon's
## pierce_cap by WeaponSystem. -1 falls back to the resource's own value.
var pierce_override: int = -1

var scorching: bool = false
var electric: bool = false

var _age: float = 0.0
var _pierce_left: int = 0
var _hit_enemies: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	_pierce_left = pierce_override if pierce_override >= 0 else data.pierce
	scale = Vector2.ONE * data.visual_scale * scale_mult

	# The scenes carry hand-authored collision (the slash arcs are convex
	# polygons traced to their sprites). Only fall back to a circle from
	# hit_radius when a scene hasn't been given a shape of its own —
	# generating one unconditionally threw the authored shapes away.
	var shape: CollisionShape2D = $CollisionShape2D
	if shape.shape == null:
		var circle := CircleShape2D.new()
		circle.radius = data.hit_radius
		shape.shape = circle

	collision_layer = 2           # Bullets
	collision_mask  = EnemyUnit.HOSTILE_MASK   # every enemy lane, not bullets/walls
	# Blades that swat incoming fire also have to watch the Bullets layer
	if data.destroys_projectiles:
		collision_mask |= 2

	# Burning rounds glow red; electric ones trail yellow sparks.
	if scorching:
		modulate = Color(1, 0.35, 0.35)
	elif electric:
		modulate = Color(1, 1, 0.35)
		add_child(_make_spark_trail())

	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("moving")

	if data.archetype == WeaponData.Archetype.SHIELD:
		_shield_burst()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= data.lifetime:
		_pop()
		return

	match data.archetype:
		WeaponData.Archetype.BOLT:
			global_position += direction * data.speed * speed_mult * delta
		WeaponData.Archetype.SWEEP:
			if follow_target and is_instance_valid(follow_target):
				global_position = follow_target.global_position
		WeaponData.Archetype.THRUST:
			if follow_target and is_instance_valid(follow_target):
				global_position = follow_target.global_position + direction * (data.hit_radius * 0.6)
		WeaponData.Archetype.SHIELD:
			if follow_target and is_instance_valid(follow_target):
				global_position = follow_target.global_position


# ── Shield archetype — knockback + brief invulnerability on cast ──────────────

func _shield_burst() -> void:
	if data.invuln_duration <= 0.0 or follow_target == null:
		return
	if "invincible" in follow_target:
		follow_target.invincible = true
		get_tree().create_timer(data.invuln_duration).timeout.connect(func():
			if is_instance_valid(follow_target):
				follow_target.invincible = false)


# ── Hits ───────────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	# Enemy fire is an Area2D in its own right, not a child of anything, so
	# it's checked before falling through to the enemy-parent lookup.
	if data.destroys_projectiles and area.is_in_group("enemy_projectiles"):
		if area.has_method("destroy"):
			area.destroy()
		return
	_try_hit(area.get_parent())


func _try_hit(node: Node) -> void:
	if node == null or not node.is_in_group("enemies"):
		return
	if node in _hit_enemies:
		return
	_hit_enemies.append(node)

	if node.has_method("apply_damage"):
		node.apply_damage(damage)

	# Status procs — the burn is where a scorching round's real damage is,
	# and the electric round trades damage for lockdown.
	if is_instance_valid(node):
		if scorching and node.has_method("apply_burn"):
			node.apply_burn(
				BURN_BASE_DAMAGE + BURN_DAMAGE_PER_LEVEL * GameManager.get_hero_level(),
				BURN_TICKS)
		elif electric and node.has_method("apply_paralysis"):
			node.apply_paralysis(PARALYSIS_DURATION)

	if not is_instance_valid(node):
		_pierce_left -= 1
		if _pierce_left <= 0 and follow_target == null:
			_pop()
		return

	# Any weapon with a knockback_force shoves what it hits — the melee
	# archetypes lean on this to make contact read as an impact, not just a
	# number popping off the enemy.
	if data.knockback_force > 0.0 and node is CharacterBody2D:
		var offset: Vector2 = node.global_position - global_position
		if offset == Vector2.ZERO:
			offset = direction
		node.velocity += offset.normalized() * data.knockback_force

	_pierce_left -= 1
	if _pierce_left <= 0 and follow_target == null:
		_pop()


func _pop() -> void:
	ParticleEffect.spawn(POP_FX, get_tree().current_scene, global_position)
	queue_free()


## Yellow sparks riding an electric round, so it reads as charged at a glance.
func _make_spark_trail() -> GPUParticles2D:
	var sparks := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = data.hit_radius * 0.5
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 70.0
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	mat.color = Color(1.0, 0.95, 0.3)
	sparks.process_material = mat
	sparks.amount = 12
	sparks.lifetime = 0.25
	sparks.local_coords = false
	sparks.emitting = true
	return sparks
