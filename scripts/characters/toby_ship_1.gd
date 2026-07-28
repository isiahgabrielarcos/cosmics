extends CharacterBody2D

signal hp_changed(current: int, maximum: int)
signal shield_changed(current: float, maximum: int)
signal ammo_changed(current: int, maximum: int, reloading: bool)
signal xp_changed(current: int, required: int, level: int)
signal player_died

@onready var ship_body: AnimatedSprite2D = $AnimatedSprite2D
@onready var cooldown_timer: Timer       = $Timers/CooldownTimer
@onready var shield_regen_timer: Timer   = $Timers/ShieldRegenTimer
@onready var shield_hit: Sprite2D        = $shieldHit

# Movement / Boost
const NORMAL_SPEED   := 600.0
const BOOST_SPEED    := NORMAL_SPEED * 2
const DASH_DISTANCE  := 50.0
const DASH_DURATION  := 0.1
const BOOST_COOLDOWN := 1.0
const TURN_RATE      := 5.0

var current_speed := NORMAL_SPEED
var can_boost     := true
var is_boosting   := false

# Health / Shield / XP (initialised from SaveManager stats in _ready)
var max_hp: int     = 100
var hp: int         = 100
var max_shield: int = 50
var shield: float   = 50.0

var level: int             = 1
var current_exp: int       = 0
var exp_to_next_level: int = 30

var shield_regen_rate: float = 1.0   # baseShieldRegen (ticks scale with it)
var health_regen_rate: float = 5.0   # baseHealthRegen

var invincible: bool = false
var is_alive: bool = true

# Systems (created in _ready)
var weapon_system: WeaponSystem
var module_system: ModuleSystem

var _health_regen_timer: Timer


func _ready() -> void:
	# ── Stats from the save (enterStats) ──────────────────────────────────────
	var st: Dictionary = SaveManager.stats_data
	max_hp     = int(st.get("baseHealth", 100))
	hp         = max_hp
	max_shield = int(st.get("baseShield", 50))
	shield     = float(st.get("baseInitialShield", 0))
	shield_regen_rate = maxf(float(st.get("baseShieldRegen", 1)), 1.0)
	health_regen_rate = maxf(float(st.get("baseHealthRegen", 5)), 1.0)

	level = int(st.get("baseHeroLevel", 1))
	exp_to_next_level = 30 * level

	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = BOOST_COOLDOWN
	cooldown_timer.timeout.connect(_on_cooldown_timeout)

	# Shield regen — Lua: +2.5 shield every (3000 / regener) ms
	shield_regen_timer.wait_time = 3.0 / minf(shield_regen_rate, 20.0)
	shield_regen_timer.timeout.connect(_on_shield_regen_tick)
	shield_regen_timer.start()

	# Health regen — Lua: +5 hp every (5000 / regener) ms, only below max-5
	_health_regen_timer = Timer.new()
	_health_regen_timer.wait_time = 5.0 / minf(health_regen_rate, 20.0)
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
		velocity = input_dir.normalized() * current_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if Input.is_action_just_pressed("boost") and can_boost:
		_start_boost()

func _handle_boost_movement(delta: float) -> void:
	var to_mouse = (get_global_mouse_position() - global_position).normalized()
	var cur_dir = velocity.normalized()
	var new_dir = cur_dir.lerp(to_mouse, TURN_RATE * delta).normalized()
	velocity = new_dir * current_speed
	move_and_slide()

func _start_boost() -> void:
	can_boost     = false
	is_boosting   = true
	current_speed = BOOST_SPEED
	cooldown_timer.start()

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

func _on_cooldown_timeout() -> void:
	can_boost = true

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

	if shield > 0:
		var absorbed = minf(shield, amount)
		shield -= absorbed
		amount -= int(absorbed)
		_flash_shield_hit()
		shield_changed.emit(shield, max_shield)

	if amount > 0:
		hp -= amount
		hp_changed.emit(hp, max_hp)

	if hp <= 0:
		_die()

func _die() -> void:
	if not is_alive:
		return
	is_alive = false
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
		shield = minf(shield + 2.5, max_shield)   # Lua: +2.5 per tick
		shield_changed.emit(shield, max_shield)

func _on_health_regen_tick() -> void:
	if not is_alive:
		return
	if hp <= max_hp - 5:
		hp += 5   # Lua: +5 per tick
		hp_changed.emit(hp, max_hp)

func add_experience(amount: int) -> void:
	current_exp += amount
	while current_exp >= exp_to_next_level and level < 30:
		current_exp -= exp_to_next_level
		level += 1
		exp_to_next_level = 30 * level
		AudioManager.play_sfx("levelUp")
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
