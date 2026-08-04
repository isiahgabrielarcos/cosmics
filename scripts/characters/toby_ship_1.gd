extends CharacterBody2D

signal hp_changed(current: int, maximum: int)
signal shield_changed(current: float, maximum: int)
signal ammo_changed(current: int, maximum: int, reloading: bool)
signal xp_changed(current: int, required: int, level: int)
signal damaged(amount: int)
signal player_died

@onready var ship_body: AnimatedSprite2D = $AnimatedSprite2D
@onready var shield_regen_timer: Timer   = $Timers/ShieldRegenTimer
@onready var shield_hit: Sprite2D        = $shieldHit

# Movement / Boost — the shield bar doubles as dash fuel: boosting drains it
# continuously, and once it hits empty you can't boost again until it has
# regenerated back up to DASH_UNLOCK_RATIO of max.
const NORMAL_SPEED     := 600.0
const BOOST_SPEED      := NORMAL_SPEED * 2
const DASH_DISTANCE    := 50.0
const DASH_DURATION    := 0.1
const TURN_RATE        := 5.0
const DASH_DRAIN_RATE  := 5.0   # shield/sec drained while boosting
const DASH_UNLOCK_RATIO := 0.2   # must regen to 20% of max before boosting again once empty

# Health regen — a slow trickle that rewards disengaging, not a second health
# bar. HEAL_PER_TICK hp every (REGEN_INTERVAL / rate) seconds, and only once
# you've been out of trouble for REGEN_COMBAT_DELAY.
const HEAL_PER_TICK       := 2
const REGEN_INTERVAL      := 20.0
const REGEN_COMBAT_DELAY  := 5.0

const HIT_DEATH_FX := preload("res://scenes/effects/particle_player_hit_death.tscn")
const LEVEL_UP_FX   := preload("res://scenes/effects/particle_level_up.tscn")

var current_speed  := NORMAL_SPEED
var is_boosting    := false
var _shield_locked := false

## Temporary movement buff (Energy Overdrive). 1.0 = normal.
var speed_multiplier: float = 1.0

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


func _ready() -> void:
	# ── Stats from the save (enterStats) ──────────────────────────────────────
	var st: Dictionary = SaveManager.stats_data
	max_hp     = int(st.get("baseHealth", 100))
	hp         = max_hp
	max_shield = int(st.get("baseShield", 50))
	shield     = float(max_shield)   # dash fuel — always starts full
	shield_regen_rate = maxf(float(st.get("baseShieldRegen", 1)), 1.0)
	health_regen_rate = maxf(float(st.get("baseHealthRegen", 5)), 1.0)

	level = int(st.get("baseHeroLevel", 1))
	exp_to_next_level = 30 * level

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
	if is_boosting:
		_handle_boost_movement(delta)
		_drain_shield_while_boosting(delta)
	else:
		_handle_normal_movement()
	_rotate_ship()

	if is_boosting and Input.is_action_just_released("boost"):
		_end_boost()

# ── Movement ──────────────────────────────────────────────────────────────────

func _handle_normal_movement() -> void:
	var input_dir = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down")  - Input.get_action_strength("up")
	)
	if input_dir != Vector2.ZERO:
		velocity = input_dir.normalized() * current_speed * speed_multiplier
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if Input.is_action_just_pressed("boost") and _can_start_boost():
		_start_boost()

func _can_start_boost() -> bool:
	return shield > 0.0 and not _shield_locked

func _handle_boost_movement(delta: float) -> void:
	var to_mouse = (get_global_mouse_position() - global_position).normalized()
	var cur_dir = velocity.normalized()
	var new_dir = cur_dir.lerp(to_mouse, TURN_RATE * delta).normalized()
	velocity = new_dir * current_speed * speed_multiplier
	move_and_slide()

func _drain_shield_while_boosting(delta: float) -> void:
	shield = maxf(0.0, shield - DASH_DRAIN_RATE * delta)
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

func take_damage(amount: int) -> void:
	if not is_alive or invincible:
		return
	# Force-field module absorbs one full hit
	if module_system and module_system.consume_force_field():
		return

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
			shield = minf(shield + 2.5, max_shield)   # Lua: +2.5 per tick
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

func add_experience(amount: int) -> void:
	current_exp += amount
	while current_exp >= exp_to_next_level and level < 30:
		current_exp -= exp_to_next_level
		level += 1
		exp_to_next_level = 30 * level
		AudioManager.play_sfx("levelUp")
		ParticleEffect.spawn(LEVEL_UP_FX, get_tree().current_scene, global_position)
	xp_changed.emit(current_exp, exp_to_next_level, level)

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
