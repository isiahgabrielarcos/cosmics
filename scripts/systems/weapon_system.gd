extends Node2D
class_name WeaponSystem

# Ports the weapon block of globalFunctions.lua:
#   shoot1..shoot7, switchWeapon, ammoUsed, reloadCooldown,
#   antiFlankShoot (module), sideShooting (module).
# Attach as a child of the player ship. Left-click fires, Q swaps primary/secondary.

const LASER_TEX    := preload("res://assets/art/characters/laserBeam.png")
const LASER2_TEX   := preload("res://assets/art/characters/laserBeam2.png")
const COSMIC_BALL  := preload("res://assets/art/characters/cosmicBall.png")
const LIGHT_WAVE   := preload("res://assets/art/characters/lightWave.png")
const HALF_MOON    := preload("res://assets/art/characters/halfMoonSlash.png")
const DASH_SLASH   := preload("res://assets/art/characters/dashSlash.png")
const SHIELD_WEP   := preload("res://assets/art/characters/shieldWeapon.png")
const RELOAD_SHEET := preload("res://assets/art/ui/cosmicReload.png")

var player: CharacterBody2D

# Loadout (from equippedData.json)
var primary_weapon: int = 1
var secondary_weapon: int = 1
var is_primary_selected: bool = true

# Stats (from baseStatData.json — enterStats())
var base_damage: int = 20
var attack_speed: float = 0.25      # baseAttackSpeed 250 ms
var ammo_capacity: int = 18         # baseAmmoCapacity
var reload_time: float = 2.0        # baseReloadTime
var pierce: int = 2                 # piercing
var weapon_range: float = 200.0     # baseRange (drives projectile lifetime)

var current_ammo: int = 18
var reloading: bool = false
var _can_fire: bool = true

# Module hooks (set by ModuleSystem)
var got_anti_flank_module: bool = false
var got_side_guns_module: bool = false
var repeater_cannon_amount: int = 1
var got_scorching_module: bool = false
var scorching_chance: int = 3       # out of 10
var got_electric_module: bool = false
var electric_chance: int = 3        # out of 10

var _fire_timer: Timer
var _reload_timer: Timer
var _reload_sprite: AnimatedSprite2D
var _frames_cache: Dictionary = {}


func _ready() -> void:
	player = get_parent() as CharacterBody2D

	_fire_timer = Timer.new()
	_fire_timer.one_shot = true
	_fire_timer.timeout.connect(func(): _can_fire = true)
	add_child(_fire_timer)

	_reload_timer = Timer.new()
	_reload_timer.one_shot = true
	_reload_timer.timeout.connect(_on_reload_done)
	add_child(_reload_timer)

	# Pull loadout + stats from the save (enterStats + loadPrimAndSecWeapon)
	var eq: Dictionary = SaveManager.equipped_data
	primary_weapon   = int(eq.get("weapon1Slot", 1))
	secondary_weapon = int(eq.get("weapon2Slot", 1))

	var st: Dictionary = SaveManager.stats_data
	base_damage   = int(st.get("baseDamage", 20))
	ammo_capacity = int(st.get("baseAmmoCapacity", 18))
	weapon_range  = float(st.get("baseRange", 200))
	current_ammo  = ammo_capacity

	_emit_ammo()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_weapon"):
		switch_weapon()


func _physics_process(_delta: float) -> void:
	if Input.is_action_pressed("shoot"):
		try_shoot()


# ── Firing (attack / autoAttack / whichWeapon) ────────────────────────────────

func try_shoot() -> void:
	if not _can_fire or reloading or get_tree().paused or GameManager.ui_open:
		return
	_can_fire = false
	_fire_timer.start(attack_speed)

	current_ammo -= 1

	for i in repeater_cannon_amount:
		_fire_current_weapon()

	if got_anti_flank_module:
		_anti_flank_shoot()
	if got_side_guns_module:
		_side_shooting()

	if current_ammo <= 0:
		_start_reload()
	else:
		_emit_ammo()


func _fire_current_weapon() -> void:
	var slot := primary_weapon if is_primary_selected else secondary_weapon
	match slot:
		1: _shoot1()
		2: _shoot2()
		3: _shoot3()
		4: _shoot4()
		5: _shoot5()
		6: _shoot6()
		7: _shoot7()
		_: _shoot1()


func switch_weapon() -> void:
	if get_tree().paused:
		return
	is_primary_selected = not is_primary_selected
	AudioManager.play_sfx("switchMode")


# ── Aim helpers ────────────────────────────────────────────────────────────────

func _aim_rotation() -> float:
	return player.ship_body.rotation


func _aim_dir() -> Vector2:
	return Vector2.UP.rotated(_aim_rotation())


func _roll_procs(cfg: Dictionary) -> Dictionary:
	if got_scorching_module and randi_range(1, 10) <= scorching_chance:
		cfg["scorching"] = true
	elif got_electric_module and randi_range(1, 10) <= electric_chance:
		cfg["electric"] = true
	return cfg


func _spawn(cfg: Dictionary) -> HeroProjectile:
	var proj := HeroProjectile.create(cfg)
	proj.scorching = cfg.get("scorching", false)
	proj.electric  = cfg.get("electric", false)
	proj.global_position = player.global_position
	get_tree().current_scene.add_child(proj)
	return proj


# ── The 7 weapons ──────────────────────────────────────────────────────────────

# Weapon 1 — laser beam (shoot1)
func _shoot1() -> void:
	_spawn(_roll_procs({
		"texture": LASER_TEX, "rotation": _aim_rotation(), "direction": _aim_dir(),
		"speed": 800.0, "damage": base_damage, "pierce": pierce,
		"lifetime": weapon_range / 200.0, "radius": 12.0,
	}))
	AudioManager.play_sfx("laserSound")


# Weapon 2 — heavy laser (shoot2)
func _shoot2() -> void:
	_spawn(_roll_procs({
		"texture": LASER2_TEX, "rotation": _aim_rotation(), "direction": _aim_dir(),
		"speed": 700.0, "damage": int(base_damage * 1.5), "pierce": pierce + 1,
		"lifetime": weapon_range / 200.0, "radius": 30.0,
	}))
	AudioManager.play_sfx("laserSound")


# Weapon 3 — cosmic ball (shoot3)
func _shoot3() -> void:
	_spawn(_roll_procs({
		"frames": _sheet_frames(COSMIC_BALL, 128, 64, 4, 10.0),
		"rotation": _aim_rotation(), "direction": _aim_dir(),
		"speed": 650.0, "damage": int(base_damage * 1.25), "pierce": pierce,
		"lifetime": weapon_range / 200.0, "radius": 22.0, "visual_scale": 1.0,
	}))
	AudioManager.play_sfx("cometProjectile")


# Weapon 4 — light wave (shoot4)
func _shoot4() -> void:
	_spawn(_roll_procs({
		"frames": _sheet_frames(LIGHT_WAVE, 64, 128, 5, 12.0),
		"rotation": _aim_rotation(), "direction": _aim_dir(),
		"speed": 600.0, "damage": int(base_damage * 1.4), "pierce": pierce + 2,
		"lifetime": weapon_range / 200.0, "radius": 34.0, "visual_scale": 1.5,
	}))
	AudioManager.play_sfx("cometProjectile")


# Weapon 5 — half-moon slash: melee sweep that follows the hero (shoot5)
func _shoot5() -> void:
	_spawn(_roll_procs({
		"frames": _sheet_frames(HALF_MOON, 128, 64, 5, 12.0),
		"rotation": _aim_rotation(), "follow_target": player,
		"spin_speed": PI / 0.25, "damage": int(base_damage * 1.75), "pierce": 99,
		"lifetime": 0.25, "radius": 80.0, "visual_scale": 1.5, "alpha": 0.75,
	}))
	AudioManager.play_sfx("weapon5Shoot")


# Weapon 6 — dash slash: hero lunges forward, damaging along the way (shoot6)
func _shoot6() -> void:
	_spawn(_roll_procs({
		"frames": _sheet_frames(DASH_SLASH, 128, 64, 5, 20.0),
		"rotation": _aim_rotation(), "follow_target": player,
		"damage": int(base_damage * 2), "pierce": 99,
		"lifetime": 0.3, "radius": 45.0, "visual_scale": 1.2, "alpha": 0.7,
	}))
	var tw := create_tween()
	tw.tween_property(player, "global_position",
		player.global_position + _aim_dir() * (weapon_range * 0.75), 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("weapon6Shoot")


# Weapon 7 — shield bubble around the hero (shoot7)
func _shoot7() -> void:
	_spawn(_roll_procs({
		"texture": SHIELD_WEP, "follow_target": player,
		"damage": base_damage, "pierce": 99,
		"lifetime": weapon_range / 100.0, "radius": 50.0,
		"visual_scale": 2.0, "alpha": 0.5,
	}))
	AudioManager.play_sfx("laserSound")


# ── Module extra shots ─────────────────────────────────────────────────────────

# Anti-flank module — fires one laser backwards (antiFlankShoot)
func _anti_flank_shoot() -> void:
	_spawn({
		"texture": LASER_TEX, "rotation": _aim_rotation() + PI,
		"direction": -_aim_dir(), "speed": 800.0,
		"damage": base_damage, "pierce": pierce,
		"lifetime": weapon_range / 200.0, "radius": 12.0,
	})


# Side guns module — fires lasers at ±90° (sideShooting)
func _side_shooting() -> void:
	for side_angle in [-PI / 2.0, PI / 2.0]:
		_spawn({
			"texture": LASER_TEX, "rotation": _aim_rotation() + side_angle,
			"direction": _aim_dir().rotated(side_angle), "speed": 800.0,
			"damage": base_damage, "pierce": pierce,
			"lifetime": weapon_range / 200.0, "radius": 12.0,
		})


# ── Reload (ammoUsed / reloadCooldown) ─────────────────────────────────────────

func _start_reload() -> void:
	reloading = true
	_reload_timer.start(reload_time)
	_emit_ammo()

	# Animated reload bar above the ship (cosmicReload.png, 20 frames)
	_reload_sprite = AnimatedSprite2D.new()
	_reload_sprite.sprite_frames = _sheet_frames(RELOAD_SHEET, 64, 16, 20, 20.0 / reload_time)
	_reload_sprite.position = Vector2(0, -60)
	_reload_sprite.scale = Vector2(1.3, 1.3)
	_reload_sprite.modulate.a = 0.9
	_reload_sprite.play("moving")
	player.add_child(_reload_sprite)


func _on_reload_done() -> void:
	reloading = false
	current_ammo = ammo_capacity
	if _reload_sprite:
		_reload_sprite.queue_free()
		_reload_sprite = null
	_emit_ammo()


func _emit_ammo() -> void:
	if player.has_signal("ammo_changed"):
		player.ammo_changed.emit(current_ammo, ammo_capacity, reloading)


# ── Spritesheet helper ─────────────────────────────────────────────────────────

func _sheet_frames(tex: Texture2D, fw: int, fh: int, count: int, fps: float) -> SpriteFrames:
	var key := "%s_%d_%d_%d_%f" % [tex.resource_path, fw, fh, count, fps]
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
