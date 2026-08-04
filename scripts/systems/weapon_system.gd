extends Node2D
class_name WeaponSystem

# Ports the weapon block of globalFunctions.lua:
#   shoot1..shoot7, switchWeapon, ammoUsed, reloadCooldown,
#   antiFlankShoot (module), sideShooting (module).
# Attach as a child of the player ship. Left-click fires, Q swaps primary/secondary.
#
# The 7 weapons are baked scenes under scenes/weapons/ (WeaponProjectile +
# a WeaponData resource each) — this script just picks the equipped one,
# instances it, and scales its base_damage/fire_rate by the player's stats.

const RELOAD_SHEET := preload("res://assets/art/ui/cosmicReload.png")

const WEAPON_SCENES := {
	1: preload("res://scenes/weapons/laser_beam.tscn"),
	2: preload("res://scenes/weapons/laser_plasma.tscn"),
	3: preload("res://scenes/weapons/fireball.tscn"),
	4: preload("res://scenes/weapons/wide_slash.tscn"),
	5: preload("res://scenes/weapons/slash.tscn"),
	6: preload("res://scenes/weapons/pierce.tscn"),
	7: preload("res://scenes/weapons/shield.tscn"),
}

const WEAPON_SFX := {
	1: "laserSound", 2: "laserSound", 3: "cometProjectile", 4: "cometProjectile",
	5: "weapon5Shoot", 6: "weapon6Shoot", 7: "laserSound",
}

const BASE_STAT_DAMAGE := 20.0   # baseDamage reference the 7 weapons were tuned against
const BASE_ATTACK_SPEED := 0.25  # baseAttackSpeed reference for fire_rate scaling
const BASE_AMMO_CAPACITY := 18   # baseAmmoCapacity reference — anything above it is a bonus

# Comet and Shield Generator — temporarily pulled from the loadout
const DISABLED_WEAPONS := [3, 7]

var player: CharacterBody2D

# Loadout (from equippedData.json)
var primary_weapon: int = 1
var secondary_weapon: int = 1
var is_primary_selected: bool = true

# Stats (from baseStatData.json — enterStats())
var base_damage: int = 20
var attack_speed: float = 0.25      # baseAttackSpeed 250 ms
var reload_time: float = 2.0        # baseReloadTime
var weapon_range: float = 200.0     # baseRange (kept for parity; weapons carry their own lifetime now)

# Magazine size and pierce are per-weapon (WeaponData) now. These two are the
# upgrade channels on top of them — baseAmmoCapacity above the 18 reference
# adds rounds to every weapon, and bonus_pierce stacks onto each weapon's
# pierce up to its own pierce_cap.
var bonus_ammo: int = 0
var bonus_pierce: int = 0

# Mirrors of the selected slot, kept in sync by _load_slot() — the HUD reads
# these. Each of the two loadout slots keeps its own magazine in _slot_ammo,
# so swapping weapons doesn't hand you a free full clip.
var ammo_capacity: int = 18
var current_ammo: int = 18
var _slot_ammo := {1: 18, 2: 18}

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
var _weapon_data: Dictionary = {}   # slot -> WeaponData, read once from each scene


func _ready() -> void:
	player = get_parent() as CharacterBody2D

	for slot in WEAPON_SCENES:
		var probe: WeaponProjectile = WEAPON_SCENES[slot].instantiate()
		_weapon_data[slot] = probe.data
		probe.free()

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
	if primary_weapon in DISABLED_WEAPONS:
		primary_weapon = 1
	if secondary_weapon in DISABLED_WEAPONS:
		secondary_weapon = 1

	var st: Dictionary = SaveManager.stats_data
	base_damage   = int(st.get("baseDamage", 20))
	bonus_ammo    = int(st.get("baseAmmoCapacity", 18)) - BASE_AMMO_CAPACITY
	weapon_range  = float(st.get("baseRange", 200))

	# Both slots start loaded
	_slot_ammo[1] = _capacity_for(primary_weapon)
	_slot_ammo[2] = _capacity_for(secondary_weapon)
	_load_slot()

	_emit_ammo()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_weapon"):
		switch_weapon()
	elif event.is_action_pressed("reload"):
		try_reload()


# ── Slot / magazine bookkeeping ───────────────────────────────────────────────

func _selected_slot() -> int:
	return 1 if is_primary_selected else 2


func _selected_weapon() -> int:
	return primary_weapon if is_primary_selected else secondary_weapon


func _capacity_for(weapon_id: int) -> int:
	var data: WeaponData = _weapon_data[weapon_id]
	return maxi(1, data.ammo_capacity + bonus_ammo)


## Points current_ammo / ammo_capacity at whichever slot is selected.
func _load_slot() -> void:
	ammo_capacity = _capacity_for(_selected_weapon())
	current_ammo = mini(int(_slot_ammo[_selected_slot()]), ammo_capacity)


## Re-equips both slots (the Ship Status screen changing the loadout) and
## racks fresh magazines sized for the new weapons.
func set_loadout(slot1: int, slot2: int) -> void:
	primary_weapon = 1 if slot1 in DISABLED_WEAPONS else slot1
	secondary_weapon = 1 if slot2 in DISABLED_WEAPONS else slot2
	_slot_ammo[1] = _capacity_for(primary_weapon)
	_slot_ammo[2] = _capacity_for(secondary_weapon)
	_load_slot()
	_emit_ammo()


func _pierce_for(data: WeaponData) -> int:
	var p := data.pierce + bonus_pierce
	if data.pierce_cap >= 0:
		p = mini(p, data.pierce_cap)
	return maxi(1, p)


func _physics_process(_delta: float) -> void:
	if Input.is_action_pressed("shoot"):
		try_shoot()


# ── Firing (attack / autoAttack / whichWeapon) ────────────────────────────────

func try_shoot() -> void:
	if not _can_fire or reloading or get_tree().paused or GameManager.ui_open:
		return

	var slot := _selected_weapon()
	var data: WeaponData = _weapon_data[slot]

	_can_fire = false
	_fire_timer.start(data.fire_rate * (attack_speed / BASE_ATTACK_SPEED))

	current_ammo -= 1
	_slot_ammo[_selected_slot()] = current_ammo

	for i in repeater_cannon_amount:
		_fire_weapon(slot, data)

	if got_anti_flank_module:
		_anti_flank_shoot()
	if got_side_guns_module:
		_side_shooting()

	if current_ammo <= 0:
		_start_reload()
	else:
		_emit_ammo()


func _fire_weapon(slot: int, data: WeaponData) -> void:
	var proj: WeaponProjectile = WEAPON_SCENES[slot].instantiate()
	proj.direction = _aim_dir()
	proj.rotation = _aim_rotation()
	proj.damage = int(data.base_damage * (base_damage / BASE_STAT_DAMAGE))
	proj.pierce_override = _pierce_for(data)
	_roll_procs(proj)

	if data.archetype != WeaponData.Archetype.BOLT:
		proj.follow_target = player

	proj.global_position = player.global_position
	get_tree().current_scene.add_child(proj)

	if data.archetype == WeaponData.Archetype.THRUST:
		# Pierce — the ship itself lunges forward, blade leading
		create_tween().tween_property(player, "global_position",
			player.global_position + _aim_dir() * data.thrust_distance, 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	AudioManager.play_sfx(WEAPON_SFX[slot])


## Swapping slots racks a fresh magazine, so you pay the reload either way
## instead of dodging it by flipping to the other weapon mid-clip.
func switch_weapon() -> void:
	if get_tree().paused or reloading:
		return
	_slot_ammo[_selected_slot()] = current_ammo
	is_primary_selected = not is_primary_selected
	_load_slot()
	AudioManager.play_sfx("switchMode")
	_start_reload()


# ── Aim helpers ────────────────────────────────────────────────────────────────

func _aim_rotation() -> float:
	return player.ship_body.rotation


func _aim_dir() -> Vector2:
	return Vector2.UP.rotated(_aim_rotation())


func _roll_procs(proj: WeaponProjectile) -> void:
	if got_scorching_module and randi_range(1, 10) <= scorching_chance:
		proj.scorching = true
	elif got_electric_module and randi_range(1, 10) <= electric_chance:
		proj.electric = true


# ── Module extra shots — always the plain laser, regardless of loadout ────────

func _anti_flank_shoot() -> void:
	var data: WeaponData = _weapon_data[1]
	var proj: WeaponProjectile = WEAPON_SCENES[1].instantiate()
	proj.direction = -_aim_dir()
	proj.rotation = _aim_rotation() + PI
	proj.damage = int(data.base_damage * (base_damage / BASE_STAT_DAMAGE))
	proj.global_position = player.global_position
	get_tree().current_scene.add_child(proj)


func _side_shooting() -> void:
	var data: WeaponData = _weapon_data[1]
	for side_angle in [-PI / 2.0, PI / 2.0]:
		var proj: WeaponProjectile = WEAPON_SCENES[1].instantiate()
		proj.direction = _aim_dir().rotated(side_angle)
		proj.rotation = _aim_rotation() + side_angle
		proj.damage = int(data.base_damage * (base_damage / BASE_STAT_DAMAGE))
		proj.global_position = player.global_position
		get_tree().current_scene.add_child(proj)


# ── Reload (ammoUsed / reloadCooldown) ─────────────────────────────────────────

## Manual reload (R) — top up before a fight instead of waiting to run dry.
func try_reload() -> void:
	if reloading or get_tree().paused or GameManager.ui_open:
		return
	if current_ammo >= ammo_capacity:
		return
	_start_reload()


func _start_reload() -> void:
	reloading = true
	_reload_timer.start(reload_time)
	_emit_ammo()

	# Animated reload bar above the ship (cosmicReload.png, 20 frames)
	if _reload_sprite and is_instance_valid(_reload_sprite):
		_reload_sprite.queue_free()
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
	_slot_ammo[_selected_slot()] = current_ammo
	if _reload_sprite:
		_reload_sprite.queue_free()
		_reload_sprite = null
	_emit_ammo()


func _emit_ammo() -> void:
	if player.has_signal("ammo_changed"):
		player.ammo_changed.emit(current_ammo, ammo_capacity, reloading)


# ── Spritesheet helper (reload bar only — weapon visuals are baked in-scene) ──

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
