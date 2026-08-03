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

@export var data: WeaponData

var direction: Vector2 = Vector2.UP
var follow_target: Node2D = null
var damage: int = 0
var scorching: bool = false
var electric: bool = false

var _age: float = 0.0
var _pierce_left: int = 0
var _hit_enemies: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	_pierce_left = data.pierce
	scale = Vector2.ONE * data.visual_scale

	var shape: CollisionShape2D = $CollisionShape2D
	var circle := CircleShape2D.new()
	circle.radius = data.hit_radius
	shape.shape = circle

	collision_layer = 2           # Bullets
	collision_mask  = 0b0111101   # Entities + all 3 enemy layers, not bullets/walls

	if scorching:
		modulate = Color(1, 0.35, 0.35)
	elif electric:
		modulate = Color(1, 1, 0.35)

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
			global_position += direction * data.speed * delta
		WeaponData.Archetype.SWEEP:
			if follow_target and is_instance_valid(follow_target):
				global_position = follow_target.global_position
			rotation += data.spin_speed * delta
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
	_try_hit(area.get_parent())


func _try_hit(node: Node) -> void:
	if node == null or not node.is_in_group("enemies"):
		return
	if node in _hit_enemies:
		return
	_hit_enemies.append(node)

	if node.has_method("apply_damage"):
		var final_damage := damage
		if scorching:
			final_damage = int(damage * 1.5)
		node.apply_damage(final_damage)

	if data.archetype == WeaponData.Archetype.SHIELD and node is CharacterBody2D:
		var offset: Vector2 = node.global_position - global_position
		node.velocity += offset.normalized() * data.knockback_force

	_pierce_left -= 1
	if _pierce_left <= 0 and follow_target == null:
		_pop()


func _pop() -> void:
	ParticleEffect.spawn(POP_FX, get_tree().current_scene, global_position)
	queue_free()
