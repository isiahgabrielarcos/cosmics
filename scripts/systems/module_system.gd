extends Node2D
class_name ModuleSystem

# Ports the module + skill block of globalFunctions.lua:
#   shockwaveModule, electricAuraModule, cometModule, forceFieldModule,
#   electroBubblesModules, energyOutburstModule, dashShockwaveModule,
#   whichSkill (skills 1–7 on Space with cooldown).
# Attach as a child of the player ship.

signal skill_cooldown_changed(remaining: float, total: float)

# Electric Shock and Giant Beam — temporarily pulled from the loadout
const DISABLED_SKILLS := [4, 6]

const SHOCKWAVE_FX   := preload("res://assets/art/vfx/shockwave.png")
const ELECTRIC_FX    := preload("res://assets/art/vfx/electricAura.png")
const HIT5_FX        := preload("res://assets/art/vfx/hitEffect5.png")
const SHOCK_BOMBS_FX := preload("res://assets/art/vfx/shockBombs.png")
const BURNING_FX     := preload("res://assets/art/vfx/burning.png")

## Both worn effects are their own scenes so the art, animation speed, scale
## and transparency can be tweaked in the editor instead of being built out of
## constructor arguments here.
const FORCE_FIELD_FX  := preload("res://scenes/effects/force_field.tscn")
const SUPER_SHIELD_FX := preload("res://scenes/effects/super_shield.tscn")
const COSMIC_BALL    := preload("res://assets/art/characters/cosmicBall.png")
const PURPLE_SCENE   := preload("res://scenes/weapons/purple.tscn")

# Skills that scale with the hero: flat base plus this much per level.
const SKILL_DAMAGE_PER_LEVEL := 5
const SHOCKWAVE_BASE_DAMAGE := 50
const PURPLE_BASE_DAMAGE := 100

# Energy Overdrive
const OVERDRIVE_DURATION := 6.0
const OVERDRIVE_FIRE_RATE := 0.4    # attack_speed multiplier — x2.5 faster
const OVERDRIVE_SPEED := 1.3        # +30% movement

var player: CharacterBody2D

# ── Module state ──────────────────────────────────────────────────────────────
# Ports upgradeModulesBaseInformation(). Every number here is something a
# module pick can move; ModuleRegistry owns the caps and the wording, this
# just holds the live values and runs them.

const COMET_SCENE           := preload("res://scenes/modules/comet.tscn")
const SHOCKWAVE_SCENE       := preload("res://scenes/modules/shockwave.tscn")
const ELECTRIC_AURA_SCENE   := preload("res://scenes/modules/electric_aura.tscn")
const ELECTRO_BUBBLE_SCENE  := preload("res://scenes/modules/electro_bubble.tscn")
const ENERGY_OUTBURST_SCENE := preload("res://scenes/modules/energy_outburst.tscn")
const DASH_SHOCKWAVE_SCENE  := preload("res://scenes/modules/dash_shockwave.tscn")

# Enemy health runs (50 + 20 per hero level) before difficulty, so a flat
# module damage number falls off a cliff as a run goes on. Every module's
# damage gets this added per level, which keeps a passive taken at level 2
# still worth its slot at level 20.
const MODULE_DAMAGE_PER_LEVEL := 3.0


## Module damage at the current hero level.
func _scaled(base_damage: int, per_level_mult: float = 1.0) -> int:
	return maxi(1, int(round(base_damage
		+ MODULE_DAMAGE_PER_LEVEL * per_level_mult * GameManager.get_hero_level())))


@export var got_comet_module: bool = false
@export var comet_cooldown: float = 8.0
@export var comet_damage: int = 30
@export var comet_amount: int = 3

@export var got_shockwave_module: bool = false
@export var shockwave_cooldown: float = 8.0
@export var shockwave_stun: float = 1.0
@export var shockwave_range: float = 150.0

@export var got_electric_aura_module: bool = false
@export var electric_aura_damage: int = 6
@export var electric_aura_range: float = 150.0

@export var got_force_field_module: bool = false
@export var force_field_cooldown: float = 10.0
@export var force_field_stacks: int = 1

@export var got_electro_shield: bool = false
@export var electro_shield_duration: float = 5.0

@export var got_electro_bubbles_module: bool = false
@export var electro_bubbles_cooldown: float = 5.0
@export var electro_bubbles_damage: int = 25
@export var electro_bubbles_duration: float = 2.0

@export var got_energy_outburst_module: bool = false
@export var energy_outburst_cooldown: float = 8.0
@export var energy_outburst_damage: int = 60
@export var energy_outburst_range: float = 200.0

@export var got_dash_shockwave_module: bool = false
@export var dash_shockwave_damage: int = 25

## Retaliation — fires back at whatever just hurt you (rare 4 / rare 5).
@export var shield_thorns_damage: int = 0
@export var health_thorns_damage: int = 0

## Super Shield Module (godly) — a scheduled window of invulnerability.
@export var got_super_shield_module: bool = false
const SUPER_SHIELD_COOLDOWN := 30.0
const SUPER_SHIELD_DURATION := 5.0

var is_force_field_up: bool = false
var force_field_charges: int = 0

# ── Skill state (whichSkill) ───────────────────────────────────────────────────
var skill_slot: int = 1
var base_skill_cooldown: float = 10.0
var skill_ready: bool = true
var _skill_cd_left: float = 0.0
var _skill_cd_total: float = 0.0

var _timers: Dictionary = {}
var _frames_cache: Dictionary = {}


func _ready() -> void:
	player = get_parent() as CharacterBody2D
	skill_slot = int(SaveManager.equipped_data.get("skillSlot", 1))
	if skill_slot in DISABLED_SKILLS:
		skill_slot = 1

	_make_module_timer("shockwave", shockwave_cooldown, _do_shockwave)
	_make_module_timer("electric_aura", 0.5, _do_electric_aura)
	_make_module_timer("comet", comet_cooldown, _do_comets)
	_make_module_timer("force_field", force_field_cooldown, _do_force_field)
	_make_module_timer("electro_bubbles", electro_bubbles_cooldown, _do_electro_bubbles)
	_make_module_timer("energy_outburst", energy_outburst_cooldown, _do_energy_outburst)
	_make_module_timer("super_shield", SUPER_SHIELD_COOLDOWN, _do_super_shield)


func _make_module_timer(key: String, wait: float, fn: Callable) -> void:
	var t := Timer.new()
	t.wait_time = wait
	t.timeout.connect(fn)
	add_child(t)
	t.start()
	_timers[key] = t


## Cooldown upgrades have to reach the running timer, not just the variable.
func retune_timer(key: String, wait: float) -> void:
	var t: Timer = _timers.get(key)
	if t:
		t.wait_time = maxf(0.1, wait)
		t.start()


# ── Effect spawning ───────────────────────────────────────────────────────────

## Drops one of the scenes/modules/ effects into the world with this module's
## current numbers. `cfg` overrides whatever the scene defaults to.
func _spawn_module_effect(scene: PackedScene, at: Vector2, cfg: Dictionary = {}) -> ModuleEffect:
	var fx: ModuleEffect = scene.instantiate()
	fx.damage = int(cfg.get("damage", 0))
	fx.radius = float(cfg.get("radius", 100.0))
	fx.direction = cfg.get("direction", Vector2.RIGHT)
	fx.pierce = int(cfg.get("pierce", 99))
	fx.paralysis_duration = float(cfg.get("paralysis", 0.0))
	fx.burn_ticks = int(cfg.get("burn_ticks", 0))
	fx.burn_damage = int(cfg.get("burn_damage", 0))
	fx.follow_target = cfg.get("follow", null)
	if cfg.has("lifetime"):
		fx.lifetime = float(cfg["lifetime"])
	fx.global_position = at
	get_tree().current_scene.add_child(fx)
	return fx


func _process(delta: float) -> void:
	if _skill_cd_left > 0.0:
		_skill_cd_left = maxf(0.0, _skill_cd_left - delta)
		skill_cooldown_changed.emit(_skill_cd_left, _skill_cd_total)
		if _skill_cd_left == 0.0:
			skill_ready = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skill"):
		use_skill()


# ── Shared helpers ─────────────────────────────────────────────────────────────

func _damage_enemies_in_radius(radius: float, damage: int, knockback: float = 0.0) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D):
			continue
		var offset: Vector2 = enemy.global_position - player.global_position
		if offset.length() > radius:
			continue
		if enemy.has_method("apply_damage"):
			enemy.apply_damage(damage)
		if knockback > 0.0 and is_instance_valid(enemy) and enemy is CharacterBody2D:
			enemy.velocity += offset.normalized() * knockback


## Hero level, used by the skills that scale with it.
func _player_level() -> int:
	if player and "level" in player:
		return int(player.level)
	return 1


func _spawn_effect(tex: Texture2D, frame_size: int, count: int, duration: float,
		at: Node2D = null, effect_scale: float = 3.0, follow: bool = false) -> AnimatedSprite2D:
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = _sheet_frames(tex, frame_size, frame_size, count, count / duration)
	fx.scale = Vector2.ONE * effect_scale
	fx.play("moving")
	if follow:
		fx.position = Vector2.ZERO
		add_child(fx)
	else:
		fx.global_position = (at.global_position if at else player.global_position)
		get_tree().current_scene.add_child(fx)
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(fx):
			fx.queue_free())
	return fx


# ── Passive modules ────────────────────────────────────────────────────────────

## Paralysing pulse around the ship. Deals no damage — its job is the stun.
func _do_shockwave() -> void:
	if not got_shockwave_module or get_tree().paused:
		return
	_spawn_module_effect(SHOCKWAVE_SCENE, player.global_position, {
		"radius": shockwave_range, "paralysis": shockwave_stun, "follow": player,
	})
	AudioManager.play_sfx("electricShockSound")


func _do_electric_aura() -> void:
	if not got_electric_aura_module or get_tree().paused:
		return
	_spawn_module_effect(ELECTRIC_AURA_SCENE, player.global_position, {
		"damage": _scaled(electric_aura_damage, 0.5), "radius": electric_aura_range, "follow": player,
	})


func _do_comets() -> void:
	if not got_comet_module or get_tree().paused:
		return
	for i in comet_amount:
		var start := player.global_position + Vector2(-1400, randf_range(-400, 400))
		_spawn_module_effect(COMET_SCENE, start, {
			"damage": _scaled(comet_damage, 1.5), "radius": 26.0, "direction": Vector2.RIGHT,
		})
	AudioManager.play_sfx("cometProjectile")


func _do_force_field() -> void:
	if not got_force_field_module or get_tree().paused:
		return
	if force_field_charges >= force_field_stacks:
		return
	force_field_charges += 1
	is_force_field_up = true
	_show_worn_effect(FORCE_FIELD_FX, "ForceFieldFX")


## Called by the player when a force-field absorbs a hit.
func consume_force_field() -> bool:
	if force_field_charges <= 0:
		return false
	force_field_charges -= 1
	is_force_field_up = force_field_charges > 0
	if not is_force_field_up:
		_hide_worn_effect("ForceFieldFX")
	return true


func _do_electro_bubbles() -> void:
	if not got_electro_bubbles_module or get_tree().paused:
		return
	# A big, slow drifting field rather than a projectile — it re-ticks so
	# anything that wanders into it while it's passing still gets hit.
	_spawn_module_effect(ELECTRO_BUBBLE_SCENE, player.global_position, {
		"damage": _scaled(electro_bubbles_damage, 1.0), "radius": 160.0,
		"direction": Vector2.UP.rotated(player.ship_body.rotation),
		"lifetime": electro_bubbles_duration,
	})
	AudioManager.play_sfx("shockWaveSound")


func _do_energy_outburst() -> void:
	if not got_energy_outburst_module or get_tree().paused:
		return
	_spawn_module_effect(ENERGY_OUTBURST_SCENE, player.global_position, {
		"damage": _scaled(energy_outburst_damage, 2.0), "radius": energy_outburst_range,
	})
	AudioManager.play_sfx("shockWaveSound")


## Fired once at the start of a dash — damage only, no knockback.
func do_dash_shockwave() -> void:
	if not got_dash_shockwave_module:
		return
	_spawn_module_effect(DASH_SHOCKWAVE_SCENE, player.global_position, {
		"damage": _scaled(dash_shockwave_damage, 1.0), "radius": 200.0,
	})
	AudioManager.play_sfx("shockWaveSound")


func _do_super_shield() -> void:
	if not got_super_shield_module or get_tree().paused:
		return
	if player and player.has_method("grant_invincibility"):
		player.grant_invincibility(SUPER_SHIELD_DURATION)
	AudioManager.play_sfx("invincibleSkill")

	_show_worn_effect(SUPER_SHIELD_FX, "SuperShieldFX")
	get_tree().create_timer(SUPER_SHIELD_DURATION, false).timeout.connect(func():
		if is_instance_valid(self):
			_hide_worn_effect("SuperShieldFX"))


## Worn effects ride on the player rather than the world, so they follow the
## ship without any per-frame work. Named so they can be found and removed
## again, and never doubled up if the module fires while one is already on.
func _show_worn_effect(scene: PackedScene, node_name: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.get_node_or_null(node_name) != null:
		return
	var fx := scene.instantiate()
	fx.name = node_name
	player.add_child(fx)


func _hide_worn_effect(node_name: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	var fx := player.get_node_or_null(node_name)
	if fx:
		fx.queue_free()


## Retaliation (Electro Shield / thorns) — the player calls this with whatever
## just damaged it, if it can be identified.
func retaliate(attacker: Node, shield_absorbed: bool) -> void:
	var damage := shield_thorns_damage if shield_absorbed else health_thorns_damage
	if attacker and is_instance_valid(attacker) and attacker.is_in_group("enemies"):
		if damage > 0 and attacker.has_method("apply_damage"):
			attacker.apply_damage(damage)
		if got_electro_shield and is_instance_valid(attacker) \
				and attacker.has_method("apply_paralysis"):
			attacker.apply_paralysis(electro_shield_duration)


# ── Skills (whichSkill — Space key) ────────────────────────────────────────────
# Slot names from savingData.lua:
#   1 Burst Projectile · 2 Screen Shockwave · 3 Energy Over Drive
#   4 Electric Shock · 5 Purple · 6 Beam · 7 Invincible Frame

func use_skill() -> void:
	if not skill_ready or get_tree().paused or GameManager.ui_open:
		return
	skill_ready = false

	var cd := base_skill_cooldown
	if skill_slot == 5 or skill_slot == 3:
		cd += 10.0
	elif skill_slot == 2 or skill_slot == 4:
		cd -= 5.0
	_skill_cd_total = cd
	_skill_cd_left = cd
	skill_cooldown_changed.emit(_skill_cd_left, _skill_cd_total)

	match skill_slot:
		1: _skill_burst_projectile()
		2: _skill_screen_shockwave()
		3: _skill_energy_overdrive()
		4: _skill_electric_shock()
		5: _skill_purple_blast()
		6: _skill_beam()
		7: _skill_invincible_frame()


## Dumps a whole magazine forward in one rapid stream, using whatever weapon
## is equipped. The trigger is locked out until it finishes — you can steer
## and aim through it, and the stream follows where you point.
func _skill_burst_projectile() -> void:
	var ws: WeaponSystem = player.get_node_or_null("WeaponSystem")
	if ws == null:
		return
	ws.fire_burst()
	AudioManager.play_sfx("skill1Sound")


func _skill_screen_shockwave() -> void:
	var damage := SHOCKWAVE_BASE_DAMAGE + SKILL_DAMAGE_PER_LEVEL * _player_level()
	_spawn_effect(SHOCKWAVE_FX, 96, 8, 0.6, player, 10.0)
	_damage_enemies_in_radius(700.0, damage, 600.0)
	AudioManager.play_sfx("shockWaveSound")


func _skill_energy_overdrive() -> void:
	var ws: WeaponSystem = player.get_node_or_null("WeaponSystem")
	if ws:
		var old_attack_speed := ws.attack_speed
		ws.attack_speed = old_attack_speed * OVERDRIVE_FIRE_RATE
		get_tree().create_timer(OVERDRIVE_DURATION).timeout.connect(func():
			if is_instance_valid(ws):
				ws.attack_speed = old_attack_speed)

	# Redlining the cannons pushes the drive too — the ship moves quicker
	# for as long as the overdrive holds.
	if "speed_multiplier" in player:
		player.speed_multiplier = OVERDRIVE_SPEED
		get_tree().create_timer(OVERDRIVE_DURATION).timeout.connect(func():
			if is_instance_valid(player):
				player.speed_multiplier = 1.0)

	_spawn_effect(HIT5_FX, 96, 8, 0.5, player, 3.0)
	AudioManager.play_sfx("skill1Sound")


func _skill_electric_shock() -> void:
	_spawn_effect(ELECTRIC_FX, 96, 8, 0.8, player, 8.0)
	_damage_enemies_in_radius(500.0, 35)
	AudioManager.play_sfx("electricShockSound")


## Spawns the Purple and hands off — it charges on the hull for three seconds
## before launching itself. See purple_projectile.gd.
func _skill_purple_blast() -> void:
	var purple: PurpleProjectile = PURPLE_SCENE.instantiate()
	purple.damage = PURPLE_BASE_DAMAGE + SKILL_DAMAGE_PER_LEVEL * _player_level()
	purple.player = player
	purple.global_position = player.global_position
	purple.rotation = player.ship_body.rotation
	get_tree().current_scene.add_child(purple)
	AudioManager.play_sfx("shockWaveSound")


func _skill_beam() -> void:
	# A wide, long-range piercing beam in the aim direction
	var dir := Vector2.UP.rotated(player.ship_body.rotation)
	for i in 6:
		var proj := HeroProjectile.create({
			"texture": preload("res://assets/art/characters/laserBeam2.png"),
			"rotation": player.ship_body.rotation, "direction": dir,
			"speed": 1600.0, "damage": 30, "pierce": 99,
			"lifetime": 0.8, "radius": 30.0,
		})
		proj.global_position = player.global_position + dir * (i * 40.0)
		get_tree().current_scene.add_child(proj)
	AudioManager.play_sfx("laserBeamSkill")


func _skill_invincible_frame() -> void:
	if "invincible" in player:
		player.invincible = true
		var fx := _spawn_effect(BURNING_FX, 32, 3, 5.0, player, 4.0, true)
		fx.modulate = Color(1, 1, 0.5, 0.6)
		get_tree().create_timer(5.0).timeout.connect(func():
			if is_instance_valid(player):
				player.invincible = false)
	AudioManager.play_sfx("invincibleSkill")


# ── Spritesheet helper ─────────────────────────────────────────────────────────

func _sheet_frames(tex: Texture2D, fw: int, fh: int, count: int, fps: float) -> SpriteFrames:
	var key := "%s_%d_%d_%d" % [tex.resource_path, fw, fh, count]
	if _frames_cache.has(key):
		return _frames_cache[key]

	var frames := SpriteFrames.new()
	frames.add_animation("moving")
	frames.set_animation_speed("moving", fps)
	frames.set_animation_loop("moving", true)

	var cols := int(tex.get_width() / fw)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		@warning_ignore("integer_division")
		atlas.region = Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)
		frames.add_frame("moving", atlas)

	_frames_cache[key] = frames
	return frames
