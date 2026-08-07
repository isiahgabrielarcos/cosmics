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
## The damage the run started at. Percentage module picks step off this rather
## than off the running total, so stacking them adds a fixed amount each time
## instead of compounding into the millions.
var starting_damage: int = 20
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

# ── "Can the player actually shoot?" watchdog ─────────────────────────────────
# Every gate in try_shoot() (bursting, reloading, _can_fire, the UI-click
# guard) is a flag some other piece of code promises to clear. History says
# that promise gets broken — a paused-tree edge case, a freed node, a timer
# that never got the chance to fire — and the player is left holding a gun
# that silently does nothing for the rest of the run with no error to point
# at why. Rather than trust each call site to always self-heal, this checks
# periodically whether firing should be possible and forces it back open if
# something's been stuck well past when it should have cleared on its own.
const WATCHDOG_INTERVAL := 2.0
var _bursting_deadline_msec: int = 0
var _reloading_deadline_msec: int = 0

## Set while the Burst Projectile skill is unloading the magazine. The trigger
## is locked out for the duration — you can still steer and aim, and the burst
## follows wherever you point it.
var bursting: bool = false

# Module hooks (set by ModuleSystem)
var got_anti_flank_module: bool = false
var got_side_guns_module: bool = false
var repeater_cannon_amount: int = 1
var got_scorching_module: bool = false
var scorching_chance: int = 3       # out of 10
var got_electric_module: bool = false
var electric_chance: int = 3        # out of 10

# ── Legendary / godly shot modifiers ──────────────────────────────────────────
# These reshape individual rounds rather than adding flat stats, so they're
# resolved per shot in _shot_modifiers() from the ammo left in the magazine.

## Ultimate Shot — the FIRST round out of a fresh magazine hits far harder,
## so reloading early to line up an opening strike is worth doing.
var got_ultimate_shot: bool = false
const ULTIMATE_SHOT_DAMAGE := 4.0
const ULTIMATE_SHOT_SIZE := 2.0

## Fluctuating Energy — every odd round in the magazine comes out hotter.
var got_fluctuating_energy: bool = false
const FLUCTUATING_MULT := 1.25

## Shrink Device — shrinks the ship itself and speeds it up. Lives on the
## player, not the rounds; kept here only so the pick can be offered once.
var got_shrink_device: bool = false

## State of the Art Ship — a flat multiplier on everything the ship deals.
var overall_damage_mult: float = 1.0

## Super Energy Module — finishing a reload spins the cannons up briefly.
var got_super_energy_module: bool = false
const SUPER_ENERGY_MULT := 1.5
const SUPER_ENERGY_DURATION := 2.0
var _reload_buff_left: float = 0.0

# ── Volleys ───────────────────────────────────────────────────────────────────
# A shot is one or more volleys, each of one or more rounds fired abreast.
#
#   Repeater Double Shoot widens a volley to two rounds side by side.
#   Cannon Repeater adds whole extra volleys behind the first.
#
# Double Shoot sits first on the stack, so with both you get two abreast now
# and two more abreast a beat later — four rounds off one trigger pull.
const REPEATER_SPACING := 26.0
const VOLLEY_DELAY := 0.2

## Repeater Double Shoot (legendary) — two rounds abreast per volley.
var got_double_shoot: bool = false

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

	var watchdog := Timer.new()
	watchdog.wait_time = WATCHDOG_INTERVAL
	watchdog.timeout.connect(_check_can_fire_watchdog)
	add_child(watchdog)
	watchdog.start()

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
	starting_damage = base_damage
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


## Module pick — bigger magazines on every weapon. Tops up the live slot so
## the extra rounds are usable immediately rather than after the next reload.
func add_bonus_ammo(amount: int) -> void:
	bonus_ammo += amount
	_slot_ammo[_selected_slot()] = current_ammo + amount
	_load_slot()
	_emit_ammo()


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


func _physics_process(delta: float) -> void:
	if _reload_buff_left > 0.0:
		_reload_buff_left = maxf(0.0, _reload_buff_left - delta)

	# Release clears the "that click was for the UI" flag. This has to happen
	# out here: try_shoot() only runs while the button is held, so checking
	# for the release inside it could never fire and the flag stuck on
	# forever, permanently disabling the guns.
	if not Input.is_action_pressed("shoot"):
		GameManager.ui_click_swallowed = false
		return

	try_shoot()


# ── Firing (attack / autoAttack / whichWeapon) ────────────────────────────────

func try_shoot() -> void:
	# A click that operated the HUD shouldn't also come out of the cannon —
	# hold fire until that press is released (cleared in _physics_process).
	if GameManager.ui_click_swallowed:
		return
	if bursting or not _can_fire or reloading or get_tree().paused or GameManager.ui_open:
		return

	var slot := _selected_weapon()
	var data: WeaponData = _weapon_data[slot]

	_can_fire = false
	_fire_timer.start(data.fire_rate * (attack_speed / BASE_ATTACK_SPEED))

	# Volleys of `width` rounds abreast. Every round costs ammo, and the whole
	# burst is decided up front so a magazine can't run dry mid-volley.
	var width := 2 if got_double_shoot else 1
	var volleys := maxi(1, repeater_cannon_amount)
	var wanted := width * volleys
	var rounds := mini(wanted, maxi(1, current_ammo))

	var ammo_before := current_ammo
	current_ammo -= rounds
	_slot_ammo[_selected_slot()] = current_ammo

	var mods := _shot_modifiers(ammo_before)
	for i in rounds:
		@warning_ignore("integer_division")
		var volley := i / width          # which wave this round belongs to
		var lane := i % width            # its position within that wave
		var offset := _barrel_offset(lane, width)
		if volley == 0:
			_fire_weapon(slot, data, mods, offset)
		else:
			# Later volleys trail the first, so a repeater build reads as a
			# burst rather than a single fat wall of bullets.
			_queue_volley(slot, data, mods, offset, volley * VOLLEY_DELAY)

	if got_anti_flank_module:
		_anti_flank_shoot()
	if got_side_guns_module:
		_side_shooting()

	if current_ammo <= 0:
		_start_reload()
	else:
		_emit_ammo()


## Per-shot modifiers, decided from the magazine before the round leaves it.
## Ultimate Shot wins over Fluctuating Energy when the last round is also an
## odd one — the bigger, more specific effect should be what you feel.
func _shot_modifiers(ammo_before: int) -> Dictionary:
	var damage_mult := overall_damage_mult
	var size_mult := 1.0
	var speed_mult := 1.0

	# The opening round out of a full magazine. Reloading deliberately to set
	# one up is the whole point of the pick.
	if got_ultimate_shot and ammo_before >= ammo_capacity:
		damage_mult *= ULTIMATE_SHOT_DAMAGE
		size_mult *= ULTIMATE_SHOT_SIZE
	elif got_fluctuating_energy and ammo_before % 2 == 1:
		damage_mult *= FLUCTUATING_MULT
		size_mult *= FLUCTUATING_MULT

	if _reload_buff_left > 0.0:
		damage_mult *= SUPER_ENERGY_MULT

	return { "damage": damage_mult, "size": size_mult, "speed": speed_mult }


# ── Burst Projectile skill ────────────────────────────────────────────────────

## How much of the weapon's own cadence the burst runs at, and the window the
## result is held to. A slow, heavy weapon ends up firing noticeably quicker
## than usual; a fast one only a little quicker, so the burst always reads as
## the same move rather than "the laser, but silly".
const BURST_RATE_SCALE := 0.35
const BURST_MIN_INTERVAL := 0.05
const BURST_MAX_INTERVAL := 0.12


## Empties a full magazine's worth of rounds straight ahead, one after
## another. Doesn't consume ammo — it's the skill's fantasy, not a reload
## sink. Returns the number of rounds queued.
func fire_burst() -> int:
	if bursting or player == null:
		return 0

	var slot := _selected_weapon()
	var data: WeaponData = _weapon_data[slot]
	var rounds := _capacity_for(slot)
	var interval := clampf(data.fire_rate * BURST_RATE_SCALE,
		BURST_MIN_INTERVAL, BURST_MAX_INTERVAL)

	bursting = true
	# Deadline for the watchdog below — real wall-clock, not "rounds ticks
	# from now", so a pause that stalls the burst doesn't also stall the
	# deadline that's supposed to catch it.
	_bursting_deadline_msec = Time.get_ticks_msec() + int(rounds * interval * 1000.0) + 500
	for i in rounds:
		var shot := i
		get_tree().create_timer(shot * interval).timeout.connect(func():
			# The trigger-lock has to clear on the last round NO MATTER WHAT —
			# this used to sit after the paused/invalid checks below, so a
			# module pick or pause menu opening mid-burst made the callback
			# return early and left `bursting` stuck true forever, silently
			# disabling the gun for the rest of the run. Only guard this on
			# `self` being valid; player/pause don't get a say in it.
			if is_instance_valid(self) and shot == rounds - 1:
				bursting = false
			if not is_instance_valid(self) or not is_instance_valid(player):
				return
			if get_tree().paused:
				return
			# Aim is read now, not when the burst started, so the stream
			# sweeps with the ship.
			_fire_weapon(slot, data, _shot_modifiers(ammo_capacity), Vector2.ZERO))
	return rounds


## Fires a trailing volley after `delay`. The aim is re-read at fire time, so
## a burst tracks where the ship is pointing rather than where it was.
func _queue_volley(slot: int, data: WeaponData, mods: Dictionary,
		offset: Vector2, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(self) and is_instance_valid(player) \
				and not get_tree().paused:
			_fire_weapon(slot, data, mods, offset))


## Spreads volley rounds across the ship's beam so they fly side by side.
func _barrel_offset(index: int, total: int) -> Vector2:
	if total <= 1:
		return Vector2.ZERO
	var lateral := (index - (total - 1) * 0.5) * REPEATER_SPACING
	return _aim_dir().rotated(PI / 2.0) * lateral


func _fire_weapon(slot: int, data: WeaponData, mods: Dictionary = {},
		offset: Vector2 = Vector2.ZERO) -> void:
	var proj: WeaponProjectile = WEAPON_SCENES[slot].instantiate()
	proj.direction = _aim_dir()
	proj.rotation = _aim_rotation()
	proj.damage = maxi(1, int(data.base_damage * (base_damage / BASE_STAT_DAMAGE)
		* float(mods.get("damage", 1.0))))
	proj.scale_mult = float(mods.get("size", 1.0))
	proj.speed_mult = float(mods.get("speed", 1.0))
	proj.pierce_override = _pierce_for(data)
	_roll_procs(proj)

	if data.archetype != WeaponData.Archetype.BOLT:
		proj.follow_target = player

	proj.global_position = player.global_position + offset
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
# Full-size rounds at reduced damage, so they read as real cannons without
# outclassing whatever is in the main slot.

const AUX_SCALE := 1.0
const SIDE_GUN_DAMAGE := 0.75
const ANTI_FLANK_DAMAGE := 0.75


func _aux_shot(angle_offset: float, damage_mult: float) -> void:
	var data: WeaponData = _weapon_data[1]
	var proj: WeaponProjectile = WEAPON_SCENES[1].instantiate()
	proj.direction = _aim_dir().rotated(angle_offset)
	proj.rotation = _aim_rotation() + angle_offset
	proj.damage = maxi(1, int(data.base_damage * (base_damage / BASE_STAT_DAMAGE) * damage_mult))
	proj.scale_mult = AUX_SCALE
	proj.pierce_override = _pierce_for(data)
	_roll_procs(proj)
	proj.global_position = player.global_position
	get_tree().current_scene.add_child(proj)


func _anti_flank_shoot() -> void:
	_aux_shot(PI, ANTI_FLANK_DAMAGE)


func _side_shooting() -> void:
	for side_angle in [-PI / 2.0, PI / 2.0]:
		_aux_shot(side_angle, SIDE_GUN_DAMAGE)


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
	# _reload_timer is a real Timer, which pauses with the tree on its own —
	# this deadline is only the watchdog's fallback in case it's ever left
	# stranded some other way (freed and re-added, stat changed mid-flight).
	_reloading_deadline_msec = Time.get_ticks_msec() + int(reload_time * 1000.0) + 1500
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

	# Super Energy Module — a fresh magazine spins everything up for a moment
	if got_super_energy_module:
		_reload_buff_left = SUPER_ENERGY_DURATION
		if player and player.has_method("set_damage_surge"):
			player.set_damage_surge(SUPER_ENERGY_MULT, SUPER_ENERGY_DURATION)
	if _reload_sprite:
		_reload_sprite.queue_free()
		_reload_sprite = null
	_emit_ammo()


## Runs every WATCHDOG_INTERVAL seconds. Each check compares a gate against
## the wall-clock deadline it was given when it opened, so this never has to
## guess what "too long" means for a build with different fire rates or
## reload speeds — it just holds each promise to the schedule it made for
## itself.
func _check_can_fire_watchdog() -> void:
	var now := Time.get_ticks_msec()

	if bursting and now > _bursting_deadline_msec:
		push_warning("WeaponSystem: burst lock was still set past its own deadline — clearing.")
		bursting = false

	if reloading and now > _reloading_deadline_msec:
		push_warning("WeaponSystem: reload was still running past its own deadline — forcing it done.")
		_on_reload_done()

	# The UI-click guard normally clears itself the moment the mouse button is
	# released (see _physics_process) — but that only runs while unpaused, so
	# a click swallowed right before a pause, held through it, could in
	# principle outlive the physics loop that's supposed to notice the release.
	if GameManager.ui_click_swallowed and not Input.is_action_pressed("shoot"):
		GameManager.ui_click_swallowed = false

	# _can_fire is flipped back on by _fire_timer, a real Timer, within one
	# weapon's fire_rate of being set — always well under WATCHDOG_INTERVAL.
	# If it's still down with nothing legitimate holding it there, the timer
	# didn't do its job.
	if not _can_fire and not reloading and not bursting:
		push_warning("WeaponSystem: fire lock was stuck with nothing holding it — clearing.")
		_can_fire = true


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
