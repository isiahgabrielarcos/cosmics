extends CharacterBody2D

const GeometryEscape := preload("res://scripts/systems/geometry_escape.gd")

signal hp_changed(current: int, maximum: int)
signal shield_changed(current: float, maximum: int)
signal ammo_changed(current: int, maximum: int, reloading: bool)
signal xp_changed(current: int, required: int, level: int)
signal damaged(amount: int)
signal leveled_up(level: int)
signal player_died

@onready var ship_body: AnimatedSprite2D = $AnimatedSprite2D
@onready var shield_regen_timer: Timer   = $Timers/ShieldRegenTimer
@onready var shield_hit: Sprite2D        = $shieldHit
@onready var _top_order: Area2D          = $TopOrder
@onready var _low_order: Area2D          = $LowOrder

# Movement / Boost — the shield bar doubles as dash fuel: boosting drains it
# continuously, and once it hits empty you can't boost again until it has
# regenerated back up to DASH_UNLOCK_RATIO of max.
const NORMAL_SPEED     := 600.0
const BOOST_SPEED      := NORMAL_SPEED * 2
const DASH_DISTANCE    := 50.0
const DASH_DURATION    := 0.1
const TURN_RATE        := 5.0
## Dash fuel is spent and regenerated as a FRACTION of the meter, so raising
## the maximum makes the bar bigger without making a dash last any longer.
const DASH_DRAIN_FRACTION := 0.10   # 10% of the meter per second -> ~10s
const DASH_REGEN_FRACTION := 0.05   # per regen tick
## Floor for the dash meter regardless of the saved baseShield stat.
const DASH_BASE_MAX := 100
const DASH_UNLOCK_RATIO := 0.2   # must regen to 20% of max before boosting again once empty

# Health regen — a slow trickle that rewards disengaging, not a second health
# bar. HEAL_PER_TICK hp every (REGEN_INTERVAL / rate) seconds, and only once
# you've been out of trouble for REGEN_COMBAT_DELAY.
const HEAL_PER_TICK       := 5
const REGEN_INTERVAL      := 20.0
const REGEN_COMBAT_DELAY  := 5.0

## Invulnerability granted after spending a revival.
const REVIVE_GRACE := 3.0

## Damage the ship gains per level, matched against the +20 HP per level that
## every enemy gains.
const DAMAGE_PER_LEVEL := 4

## Shrink Device (legendary module)
const SHRINK_SCALE := 0.5
const SHRINK_SPEED_BONUS := 0.5

## Experience for a kill, as a fraction of a common shard's worth — killing
## things should feed the bar a little even when no shard drops.
const KILL_EXPERIENCE_RATIO := 0.25

## Levelling curve. Was a flat 30 per level, which made the later levels no
## harder to reach than the first — and each one hands out a module pick, so
## they have to cost progressively more.
##   L1 30 · L2 73 · L3 124 · L5 241 · L10 578 · L20 1401
const XP_BASE := 30.0
const XP_EXPONENT := 1.28

## Dash cooldown — stops boost being mashed for permanent invuln-ish movement.
const DASH_COOLDOWN := 0.5

const HIT_DEATH_FX := preload("res://scenes/effects/particle_player_hit_death.tscn")
const LEVEL_UP_FX   := preload("res://scenes/effects/particle_level_up.tscn")

var current_speed  := NORMAL_SPEED
var is_boosting    := false
var _shield_locked := false

## Temporary movement buff (Energy Overdrive). 1.0 = normal.
var speed_multiplier: float = 1.0

## Permanent movement bonus stacked up from module picks (+5% each).
var speed_bonus: float = 0.0

## Anti-Collision module — the ship stops bumping into enemies and passes
## through them. It can still be hit; only the physics push is removed.
var got_anti_collision: bool = false

## Revivals banked from godly picks — death spends one instead of ending
## the run.
var revivals: int = 0

# Health / Shield / XP (initialised from SaveManager stats in _ready)
var max_hp: int     = 100
var hp: int         = 100
var max_shield: int = 50
var shield: float   = 50.0

var level: int             = 1
var current_exp: int       = 0
var exp_to_next_level: int = 30

var shield_regen_rate: float = 0.3   # baseShieldRegen (ticks scale with it)
var health_regen_rate: float = 5.0   # baseHealthRegen

var invincible: bool = false
var is_alive: bool = true

# Systems (created in _ready)
var weapon_system: WeaponSystem
var module_system: ModuleSystem

var _health_regen_timer: Timer
var _last_damage_msec: int = 0
var _dash_cooldown_left: float = 0.0


func _ready() -> void:
	# ── Stats from the save (enterStats) ──────────────────────────────────────
	var st: Dictionary = SaveManager.stats_data
	max_hp     = int(st.get("baseHealth", 100))
	hp         = max_hp
	max_shield = maxi(int(st.get("baseShield", 50)), DASH_BASE_MAX)
	shield     = float(max_shield)   # dash fuel — always starts full
	shield_regen_rate = maxf(float(st.get("baseShieldRegen", 1)), 1.0)
	health_regen_rate = maxf(float(st.get("baseHealthRegen", 5)), 1.0)

	level = int(st.get("baseHeroLevel", 1))
	exp_to_next_level = _xp_for_level(level)

	# Shield regen — doubled from the original 3000ms base so dash fuel
	# comes back at a pace that keeps up with being drained by boosting.
	shield_regen_timer.wait_time = 1.5 / minf(shield_regen_rate, 20.0)
	shield_regen_timer.timeout.connect(_on_shield_regen_tick)
	shield_regen_timer.start()

	_health_regen_timer = Timer.new()
	_health_regen_timer.wait_time = REGEN_INTERVAL / minf(health_regen_rate, 20.0)
	_health_regen_timer.timeout.connect(_on_health_regen_tick)
	add_child(_health_regen_timer)
	_health_regen_timer.start()

	# ── Combat systems ────────────────────────────────────────────────────────
	weapon_system = WeaponSystem.new()
	weapon_system.name = "WeaponSystem"
	add_child(weapon_system)

	module_system = ModuleSystem.new()
	module_system.name = "ModuleSystem"
	add_child(module_system)

	ship_body.play("idle")
	ship_body.animation_finished.connect(_on_body_anim_finished)

	add_to_group("friendlies")

	# Emit initial state so HUD can initialise its bars
	hp_changed.emit(hp, max_hp)
	shield_changed.emit(shield, max_shield)
	xp_changed.emit(current_exp, exp_to_next_level, level)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	if is_boosting:
		_handle_boost_movement(delta)
		_drain_shield_while_boosting(delta)
	else:
		_handle_normal_movement()
	_rotate_ship()
	_update_draw_order()
	# Backstop for ending up *inside* an asteroid rather than against it.
	if GeometryEscape.eject(self):
		velocity = Vector2.ZERO

	# Polled rather than using is_action_just_released: while the module pick
	# screen has the tree paused this function doesn't run, so the release
	# event fires and expires unseen and the ship stays locked in a dash
	# forever. Checking the key's actual state can't miss it.
	if is_boosting and not Input.is_action_pressed("boost"):
		_end_boost()

# ── Draw order ────────────────────────────────────────────────────────────────
# Same trick as the overworld: probes above and below the hull decide whether
# the ship passes in front of or behind the drifting scenery. The probes mask
# the walls layer only, so enemies and pickups never affect it.

const Z_IN_FRONT := 2
const Z_DEFAULT  := 1
const Z_BEHIND   := 0


func _update_draw_order() -> void:
	if _top_order == null or _low_order == null:
		return
	if _probe_hit(_top_order):
		z_index = Z_IN_FRONT
	elif _probe_hit(_low_order):
		z_index = Z_BEHIND
	else:
		z_index = Z_DEFAULT


## Shrines are deliberately excluded from the flip. Their geometry is tall and
## irregular, so flying past one had the ship popping in front of and behind it
## every few frames — the ordering read as a glitch rather than as depth.
## Everything else on the walls layer still orders normally.
func _probe_hit(probe: Area2D) -> bool:
	for body in probe.get_overlapping_bodies():
		var prop := body.get_parent()
		if prop != null and str(prop.get_meta("prop_category", "")) == "shrine":
			continue
		return true
	return false


# ── Movement ──────────────────────────────────────────────────────────────────

func _handle_normal_movement() -> void:
	var input_dir = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down")  - Input.get_action_strength("up")
	)
	if input_dir != Vector2.ZERO:
		velocity = input_dir.normalized() * current_speed * speed_multiplier * (1.0 + speed_bonus)
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if Input.is_action_just_pressed("boost") and _can_start_boost():
		_start_boost()

func _can_start_boost() -> bool:
	return shield > 0.0 and not _shield_locked and _dash_cooldown_left <= 0.0

func _handle_boost_movement(delta: float) -> void:
	var to_mouse = (get_global_mouse_position() - global_position).normalized()
	var cur_dir = velocity.normalized()
	var new_dir = cur_dir.lerp(to_mouse, TURN_RATE * delta).normalized()
	velocity = new_dir * current_speed * speed_multiplier * (1.0 + speed_bonus)
	move_and_slide()

func _drain_shield_while_boosting(delta: float) -> void:
	shield = maxf(0.0, shield - max_shield * DASH_DRAIN_FRACTION * delta)
	shield_changed.emit(shield, max_shield)
	if shield <= 0.0:
		_shield_locked = true
		_end_boost()

func _start_boost() -> void:
	is_boosting   = true
	current_speed = BOOST_SPEED

	AudioManager.play_sfx("dashSoundEffect")
	module_system.do_dash_shockwave()

	ship_body.play("transition_to_boost")

	var dash_dir = velocity.normalized()
	if dash_dir != Vector2.ZERO:
		create_tween()\
			.tween_property(self, "global_position",
				global_position + dash_dir * DASH_DISTANCE,
				DASH_DURATION)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _end_boost() -> void:
	is_boosting   = false
	current_speed = NORMAL_SPEED
	_dash_cooldown_left = DASH_COOLDOWN
	ship_body.play("idle")

# ── Rotation ──────────────────────────────────────────────────────────────────

func _rotate_ship() -> void:
	var angle: float
	if is_boosting and velocity.length() > 0:
		angle = velocity.angle() + deg_to_rad(90)
	else:
		angle = (get_global_mouse_position() - global_position).angle() + deg_to_rad(90)
	ship_body.rotation = angle

# ── Health / Shield / XP ───────────────────────────────────────────────────────

## `attacker` lets the retaliation modules (thorns / Electro Shield) hit back
## at whatever landed the blow. Callers that can't identify it pass null.
func take_damage(amount: int, attacker: Node = null) -> void:
	if not is_alive or invincible:
		return

	# Force-field module absorbs one full hit
	if module_system and module_system.consume_force_field():
		module_system.retaliate(attacker, true)
		return
	if module_system:
		module_system.retaliate(attacker, shield > 0.0)

	if amount > 0:
		hp -= amount
		_last_damage_msec = Time.get_ticks_msec()
		hp_changed.emit(hp, max_hp)
		damaged.emit(amount)
		HitText.spawn(get_tree().current_scene, global_position, amount, Color(1, 0.15, 0.15))
		ParticleEffect.spawn(HIT_DEATH_FX, get_tree().current_scene, global_position)

	if hp <= 0:
		_die()

func _die() -> void:
	if not is_alive:
		return

	# A banked revival (State of the Art Ship) spends itself here rather than
	# ending the run — back at full health with a moment of grace.
	if revivals > 0:
		revivals -= 1
		hp = max_hp
		hp_changed.emit(hp, max_hp)
		ParticleEffect.spawn(LEVEL_UP_FX, get_tree().current_scene, global_position, 1.6)
		grant_invincibility(REVIVE_GRACE)
		return

	is_alive = false
	ParticleEffect.spawn(HIT_DEATH_FX, get_tree().current_scene, global_position, 1.6)
	player_died.emit()

func _flash_shield_hit() -> void:
	shield_hit.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(shield_hit, "modulate:a", 0.7, 0.1).set_trans(Tween.TRANS_LINEAR)
	t.tween_property(shield_hit, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_LINEAR)

func _on_shield_regen_tick() -> void:
	if not is_alive:
		return
	if shield < max_shield:
		if not is_boosting:
			shield = minf(shield + max_shield * DASH_REGEN_FRACTION, max_shield)
			shield_changed.emit(shield, max_shield)
	if _shield_locked and shield >= max_shield * DASH_UNLOCK_RATIO:
		_shield_locked = false

func _on_health_regen_tick() -> void:
	if not is_alive:
		return
	if Time.get_ticks_msec() - _last_damage_msec < int(REGEN_COMBAT_DELAY * 1000.0):
		return
	if hp <= max_hp - HEAL_PER_TICK:
		hp += HEAL_PER_TICK
		hp_changed.emit(hp, max_hp)

# ── Module hooks ──────────────────────────────────────────────────────────────
# Called by ModuleRegistry when a pick lands. Kept as methods rather than raw
# field writes so the HUD bars are refreshed with the change.

func add_max_health(amount: int) -> void:
	max_hp += amount
	hp += amount
	hp_changed.emit(hp, max_hp)


func add_max_shield(amount: int) -> void:
	max_shield += amount
	shield = minf(shield + amount, float(max_shield))
	shield_changed.emit(shield, max_shield)


func heal_full() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)


## Shrink Device — a smaller, faster hull. Halving the sprite and the
## collision shape makes the ship genuinely harder to hit, not just smaller
## looking.
func apply_shrink_device() -> void:
	ship_body.scale *= SHRINK_SCALE
	var shape := $CollisionShape2D as CollisionShape2D
	if shape:
		shape.scale *= SHRINK_SCALE
	# The dash trails are sized to the old hull, so they'd hang off a shrunk
	# ship like a cape unless they come in with it.
	for trail_name in ["Dash Outer", "Dash Inner"]:
		var trail := get_node_or_null(trail_name) as Line2D
		if trail:
			trail.width *= SHRINK_SCALE
	speed_bonus += SHRINK_SPEED_BONUS


## Super Energy Module — a visible flash while the post-reload surge is up.
## The multiplier itself is applied by WeaponSystem and ModuleSystem; this is
## the tell that it's active.
func set_damage_surge(_mult: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(ship_body, "modulate", Color(1.6, 1.3, 0.7), 0.12)
	tw.tween_interval(duration - 0.24)
	tw.tween_property(ship_body, "modulate", Color.WHITE, 0.12)


## Super Shield Module — flat invulnerability with the shield sprite showing
## for as long as it lasts.
func grant_invincibility(duration: float) -> void:
	if not is_alive:
		return
	invincible = true
	shield_hit.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(shield_hit, "modulate:a", 0.75, 0.15)
	tw.tween_interval(duration - 0.3)
	tw.tween_property(shield_hit, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): invincible = false)


func set_shield_regen(rate: float) -> void:
	shield_regen_rate = rate
	shield_regen_timer.wait_time = 1.5 / minf(maxf(rate, 1.0), 20.0)
	shield_regen_timer.start()


## Enemies are the ones that collide with the ship, not the other way round —
## so passing through them means clearing the player layer out of *their*
## masks. Done to the enemies already on the field here, and to everything
## spawned afterwards by EnemyUnit._setup_collision.
##
## The ship stays on layer 1, so enemy projectiles still hit it.
func set_anti_collision(enabled: bool) -> void:
	got_anti_collision = enabled
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("set_passes_through_player"):
			enemy.set_passes_through_player(enabled)


## Experience needed to leave `lv`. Superlinear, so later levels are real
## milestones rather than something you trip over.
func _xp_for_level(lv: int) -> int:
	return maxi(1, int(round(XP_BASE * pow(float(lv), XP_EXPONENT))))


func add_experience(amount: int) -> void:
	# +10% per Quick Innovator pick
	current_exp += int(round(amount * (1.0 + GameManager.experience_bonus * 0.1)))
	var levels_gained := 0
	while current_exp >= exp_to_next_level and level < 30:
		current_exp -= exp_to_next_level
		level += 1
		levels_gained += 1
		exp_to_next_level = _xp_for_level(level)
		# Enemy health climbs every level, so the ship's does too — without
		# this, levelling up actively makes the run harder.
		if weapon_system:
			weapon_system.base_damage += DAMAGE_PER_LEVEL
		AudioManager.play_sfx("levelUp")
		ParticleEffect.spawn(LEVEL_UP_FX, get_tree().current_scene, global_position)
	xp_changed.emit(current_exp, exp_to_next_level, level)
	if levels_gained > 0:
		# Extra levels in one go bank extra picks rather than being swallowed
		GameManager.pending_module_picks += levels_gained - 1
		leveled_up.emit(level)

# ── Animation ─────────────────────────────────────────────────────────────────

func _on_body_anim_finished() -> void:
	if is_boosting and ship_body.animation == "transition_to_boost":
		ship_body.play("boost")

# ── Collision with Enemies ────────────────────────────────────────────────────

func _on_area_entered(area):
	if area.get_parent().is_in_group("enemies"):
		var enemy = area.get_parent()
		if enemy.has_method("stun"):
			enemy.stun()
