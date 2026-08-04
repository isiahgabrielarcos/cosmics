extends Area2D
class_name PurpleProjectile

# The Purple (skill 5). Two lives in one node:
#
#   CHARGING — rides the ship for CHARGE_TIME, growing from nothing to full
#              size and pointing wherever the ship points. It is armed and
#              fragile here: anything that touches it, or any hit the pilot
#              takes, sets it off in their face.
#   FLYING   — locks the aim it had at release and leaves very fast, cutting
#              through everything it meets (no pierce cap).
#
# ModuleSystem sets `damage` (100 + 5 per hero level) and `player` before
# adding it to the scene.

const CHARGE_TIME := 3.0
const FLIGHT_SPEED := 3200.0
const FLIGHT_LIFETIME := 1.5

## Going off early hurts: a flat bite out of the pilot's hull, and half the
## payload dumped into whatever set it off.
const SELF_DAMAGE := 20
const BACKLASH_RATIO := 0.5
const BACKLASH_RADIUS := 200.0

const POP_FX := preload("res://scenes/effects/particle_projectile_pop.tscn")

var damage: int = 100
var player: CharacterBody2D = null

var _charging: bool = true
var _spent: bool = false
var _age: float = 0.0
var _direction: Vector2 = Vector2.UP
var _hit_enemies: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	collision_layer = 2           # Bullets
	collision_mask  = 0b0111101   # Entities + all 3 enemy layers, not bullets/walls

	scale = Vector2.ZERO
	$AnimatedSprite2D.play("moving")

	# A hit on the pilot mid-charge detonates it too
	if player and player.has_signal("damaged"):
		player.damaged.connect(_on_player_damaged)

	create_tween().tween_property(self, "scale", Vector2.ONE, CHARGE_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _physics_process(delta: float) -> void:
	_age += delta

	if _charging:
		if not is_instance_valid(player):
			_detonate(null)
			return
		# Rides the hull, aimed wherever the ship is aimed
		global_position = player.global_position
		rotation = player.ship_body.rotation
		if _age >= CHARGE_TIME:
			_launch()
		return

	global_position += _direction * FLIGHT_SPEED * delta
	if _age >= CHARGE_TIME + FLIGHT_LIFETIME:
		queue_free()


func _launch() -> void:
	_charging = false
	_direction = Vector2.UP.rotated(rotation)
	if player and is_instance_valid(player) and player.damaged.is_connected(_on_player_damaged):
		player.damaged.disconnect(_on_player_damaged)
	AudioManager.play_sfx("laserBeamSkill")


# ── Hits ───────────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area.get_parent())


func _try_hit(node: Node) -> void:
	if node == null or not node.is_in_group("enemies"):
		return

	if _charging:
		_detonate(node)
		return

	if node in _hit_enemies:
		return
	_hit_enemies.append(node)
	if node.has_method("apply_damage"):
		node.apply_damage(damage)


func _on_player_damaged(_amount: int) -> void:
	_detonate(null)


# ── Detonation (interrupted while charging) ───────────────────────────────────

func _detonate(culprit: Node) -> void:
	if _spent:
		return
	_spent = true

	var backlash := int(damage * BACKLASH_RATIO)
	if culprit and is_instance_valid(culprit) and culprit.has_method("apply_damage"):
		culprit.apply_damage(backlash)
	else:
		# No single culprit (the pilot got hit from elsewhere) — everything
		# close enough to have caused it eats the backlash instead.
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy is Node2D \
					and enemy.global_position.distance_to(global_position) <= BACKLASH_RADIUS \
					and enemy.has_method("apply_damage"):
				enemy.apply_damage(backlash)

	if is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage.call_deferred(SELF_DAMAGE)

	AudioManager.play_sfx("explosionSound")
	ParticleEffect.spawn(POP_FX, get_tree().current_scene, global_position, 2.0)
	queue_free()
