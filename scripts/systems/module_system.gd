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
const COSMIC_BALL    := preload("res://assets/art/characters/cosmicBall.png")

var player: CharacterBody2D

# ── Module flags (upgrades picked up in a run) ────────────────────────────────
@export var got_shockwave_module: bool = false
@export var got_electric_aura_module: bool = false
@export var got_comet_module: bool = false
@export var got_force_field_module: bool = false
@export var got_electro_bubbles_module: bool = false
@export var got_energy_outburst_module: bool = false
@export var got_dash_shockwave_module: bool = false

# ── Module tuning ──────────────────────────────────────────────────────────────
@export var shockwave_cooldown: float = 5.0
@export var shockwave_range: float = 200.0
@export var shockwave_damage: int = 15

@export var electric_aura_range: float = 120.0
@export var electric_aura_damage: int = 4      # every 0.5 s

@export var comet_cooldown: float = 6.0
@export var comet_amount: int = 2
@export var comet_damage: int = 25

@export var force_field_cooldown: float = 15.0

@export var electro_bubbles_cooldown: float = 8.0
@export var electro_bubbles_damage: int = 10

@export var energy_outburst_cooldown: float = 7.0
@export var energy_outburst_range: float = 250.0
@export var energy_outburst_damage: int = 20

var is_force_field_up: bool = false

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


func _make_module_timer(key: String, wait: float, fn: Callable) -> void:
	var t := Timer.new()
	t.wait_time = wait
	t.timeout.connect(fn)
	add_child(t)
	t.start()
	_timers[key] = t


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

func _do_shockwave() -> void:
	if not got_shockwave_module or get_tree().paused:
		return
	_spawn_effect(SHOCKWAVE_FX, 96, 8, 0.5, player, (shockwave_range / 100.0) * 2.0)
	_damage_enemies_in_radius(shockwave_range, shockwave_damage, 400.0)
	AudioManager.play_sfx("electricShockSound")


func _do_electric_aura() -> void:
	if not got_electric_aura_module or get_tree().paused:
		return
	_spawn_effect(ELECTRIC_FX, 96, 8, 0.5, player, (electric_aura_range / 100.0) * 2.0, true)
	_damage_enemies_in_radius(electric_aura_range, electric_aura_damage)


func _do_comets() -> void:
	if not got_comet_module or get_tree().paused:
		return
	for i in comet_amount:
		var start := player.global_position + Vector2(-1400, randf_range(-400, 400))
		var proj := HeroProjectile.create({
			"frames": _sheet_frames(COSMIC_BALL, 128, 64, 4, 10.0),
			"direction": Vector2.RIGHT, "speed": 1200.0,
			"damage": comet_damage, "pierce": 99,
			"lifetime": 2.5, "radius": 26.0, "visual_scale": 1.0,
			"rotation": PI / 2.0,
		})
		proj.global_position = start
		get_tree().current_scene.add_child(proj)
	AudioManager.play_sfx("cometProjectile")


func _do_force_field() -> void:
	if not got_force_field_module or is_force_field_up or get_tree().paused:
		return
	is_force_field_up = true
	var fx := _spawn_effect(BURNING_FX, 32, 3, 999.0, player, 3.0, true)
	fx.modulate.a = 0.5
	fx.name = "ForceFieldFX"


## Called by the player when a force-field absorbs a hit.
func consume_force_field() -> bool:
	if not is_force_field_up:
		return false
	is_force_field_up = false
	var fx := get_node_or_null("ForceFieldFX")
	if fx:
		fx.queue_free()
	return true


func _do_electro_bubbles() -> void:
	if not got_electro_bubbles_module or get_tree().paused:
		return
	var dir := Vector2.UP.rotated(player.ship_body.rotation)
	var proj := HeroProjectile.create({
		"frames": _sheet_frames(SHOCK_BOMBS_FX, 96, 96, 8, 8.0),
		"direction": dir, "speed": 250.0,
		"damage": electro_bubbles_damage, "pierce": 99,
		"lifetime": 3.0, "radius": 40.0, "visual_scale": 1.5,
	})
	proj.global_position = player.global_position
	get_tree().current_scene.add_child(proj)
	AudioManager.play_sfx("shockWaveSound")


func _do_energy_outburst() -> void:
	if not got_energy_outburst_module or get_tree().paused:
		return
	_spawn_effect(HIT5_FX, 96, 8, 0.5, player, (energy_outburst_range / 100.0) * 2.0)
	_damage_enemies_in_radius(energy_outburst_range, energy_outburst_damage)
	AudioManager.play_sfx("shockWaveSound")


## Called by the player on boost when the dash-shockwave module is owned.
func do_dash_shockwave() -> void:
	if not got_dash_shockwave_module:
		return
	_spawn_effect(HIT5_FX, 96, 8, 0.2, player, 3.0)
	_damage_enemies_in_radius(200.0, energy_outburst_damage, 500.0)
	AudioManager.play_sfx("shockWaveSound")


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


func _skill_burst_projectile() -> void:
	for i in 12:
		var ang := TAU * i / 12.0
		var proj := HeroProjectile.create({
			"texture": preload("res://assets/art/characters/laserBeam.png"),
			"rotation": ang + PI / 2.0, "direction": Vector2.UP.rotated(ang + PI / 2.0),
			"speed": 800.0, "damage": 25, "pierce": 3,
			"lifetime": 1.0, "radius": 12.0,
		})
		proj.global_position = player.global_position
		get_tree().current_scene.add_child(proj)
	AudioManager.play_sfx("skill1Sound")


func _skill_screen_shockwave() -> void:
	_spawn_effect(SHOCKWAVE_FX, 96, 8, 0.6, player, 10.0)
	_damage_enemies_in_radius(700.0, 40, 600.0)
	AudioManager.play_sfx("shockWaveSound")


func _skill_energy_overdrive() -> void:
	var ws: WeaponSystem = player.get_node_or_null("WeaponSystem")
	if ws:
		var old_speed := ws.attack_speed
		ws.attack_speed = old_speed * 0.4
		get_tree().create_timer(6.0).timeout.connect(func():
			if is_instance_valid(ws):
				ws.attack_speed = old_speed)
	_spawn_effect(HIT5_FX, 96, 8, 0.5, player, 3.0)
	AudioManager.play_sfx("skill1Sound")


func _skill_electric_shock() -> void:
	_spawn_effect(ELECTRIC_FX, 96, 8, 0.8, player, 8.0)
	_damage_enemies_in_radius(500.0, 35)
	AudioManager.play_sfx("electricShockSound")


func _skill_purple_blast() -> void:
	_spawn_effect(SHOCK_BOMBS_FX, 96, 8, 0.8, player, 8.0)
	_damage_enemies_in_radius(450.0, 60, 300.0)
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
