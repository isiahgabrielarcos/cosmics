extends Node
class_name ModuleRegistry

# Ports createModuleUpgrades() / createModuleText() / whichUpgrade() from
# enemiesMap.lua — the table of everything a module pick can offer.
#
# The Lua built each option as a nested if-chain that both wrote the label and
# set an upgradeID the click handler switched on. Here an option is one
# dictionary: a `name`, a `desc`, and an `apply` Callable. Same behaviour,
# but the wording and the effect can't drift apart.
#
# Three shapes of option, matching the three the Lua used:
#   flat      — a stat bump, capped by `available`. Most commons.
#   unlock    — turns a passive on the first time, then offers one of its
#               upgrade variants at random. Most rares.
#   maxed     — when nothing in a family is left to improve, the pick pays
#               out currency instead (upgradeIDs 1000/1001/1002).

## Rarity roll, out of 1000 for finer control at the top end. Each card is
## rolled independently, so a hand of three sees a rarity at roughly three
## times these odds — the previous 1-in-100 bands put legendaries in front of
## the player more often than epics.
##
##   common 52.0% · rare 30.0% · epic 14.0% · legendary 3.5% · godly 0.5%
##
## Over a 15-minute run that's still a handful of epics and a legendary or two.
const RARITY_BANDS := [
	{ "rarity": "common",    "max": 520 },
	{ "rarity": "rare",      "max": 820 },
	{ "rarity": "epic",      "max": 960 },
	{ "rarity": "legendary", "max": 995 },
	{ "rarity": "godly",     "max": 1000 },
]
const RARITY_ROLL_MAX := 1000

const RARITY_COLORS := {
	"common":    Color(0.78, 0.82, 0.88),
	"rare":      Color(0.42, 0.72, 1.0),
	"epic":      Color(0.76, 0.45, 1.0),
	"legendary": Color(1.0, 0.72, 0.25),
	"godly":     Color(1.0, 0.38, 0.42),
}

## Card art per rarity — moduleUpgrades1 is the common frame, and so on.
const RARITY_ART := {
	"common":    preload("res://assets/art/ui/moduleUpgrades1.png"),
	"rare":      preload("res://assets/art/ui/moduleUpgrades2.png"),
	"epic":      preload("res://assets/art/ui/moduleUpgrades.png"),
	"legendary": preload("res://assets/art/ui/moduleUpgrades3.png"),
	"godly":     preload("res://assets/art/ui/moduleUpgrades4.png"),
}

# Scrap payouts when a family has nothing left to give (upgradeID 1000/1001/1002)
const SCRAP_CURRENCY := {
	"name": "Scrap Module", "desc": "+20 Central Cosmic Currency",
	"scrap": { "currency": 20 },
}
const SCRAP_CRYSTALS := {
	"name": "Scrap Crystals", "desc": "+10 Cosmic Crystals",
	"scrap": { "shards": 10 },
}
const SCRAP_BOTH := {
	"name": "Scrap Metals and Crystals",
	"desc": "+40 Cosmic Currency\n+15 Cosmic Crystals",
	"scrap": { "currency": 40, "shards": 15 },
}


static func roll_rarity() -> String:
	var roll := randi_range(1, RARITY_ROLL_MAX)
	for band in RARITY_BANDS:
		if roll <= int(band["max"]):
			return band["rarity"]
	return "common"


## Builds one offer of the given rarity for the player's current state.
## `ws` is the WeaponSystem, `ms` the ModuleSystem, `player` the ship.
##
## A family whose upgrade branch is fully capped drops out of the pool
## (_family returns null, _compact strips it), so the roll lands on whatever
## else that rarity still has to offer. Scrap is the last resort only — it
## comes up when nothing in the entire rarity can be improved any further.
static func roll_option(rarity: String, player: Node, ws: Node, ms: Node) -> Dictionary:
	var pool: Array = _pool_for(rarity, player, ws, ms)
	if pool.is_empty():
		return _scrap_for(rarity)
	return pool[randi_range(0, pool.size() - 1)]


static func _pool_for(rarity: String, player: Node, ws: Node, ms: Node) -> Array:
	match rarity:
		"common":    return _common_pool(player, ws)
		"rare":      return _rare_pool(ms)
		"epic":      return _epic_pool(ws, ms, player)
		"legendary": return _legendary_pool(player, ws, ms)
		"godly":     return _godly_pool(player, ms, ws)
	return []


static func _scrap_for(rarity: String) -> Dictionary:
	match rarity:
		"common": return SCRAP_CURRENCY
		"rare":   return SCRAP_CRYSTALS
	return SCRAP_BOTH


# ── Common: flat stat bumps ───────────────────────────────────────────────────
# Commons are the pick you see most, so each one has to actually register.
# Every step here is roughly a tenth of the relevant base stat or better, and
# each has a hard cap so a long run can't stack one line into absurdity.

const COMMON_DAMAGE_STEP := 0.35    # of the run's starting damage
const COMMON_DAMAGE_CAP := 8        # picks
const COMMON_SPEED_STEP := 0.08
const COMMON_SPEED_CAP := 0.48
const COMMON_ATTACK_SPEED_STEP := 0.035
const COMMON_ATTACK_SPEED_FLOOR := 0.08
const COMMON_RELOAD_STEP := 0.15
const COMMON_RELOAD_FLOOR := 0.9
const COMMON_AMMO_STEP := 4
const COMMON_AMMO_CAP := 20
const COMMON_HEALTH_STEP := 35
const COMMON_HEALTH_CAP := 420
const COMMON_DASH_STEP := 25
const COMMON_DASH_CAP := 260
const COMMON_RANGE_STEP := 60.0
const COMMON_RANGE_CAP := 700.0


static func _common_pool(player: Node, ws: Node) -> Array:
	var pool: Array = []

	if ws.weapon_range < COMMON_RANGE_CAP:
		pool.append({
			"name": "More Range!", "desc": "+%d Range" % int(COMMON_RANGE_STEP),
			"apply": func(): ws.weapon_range += COMMON_RANGE_STEP,
		})
	if ws.base_damage < ws.starting_damage * (1.0 + COMMON_DAMAGE_STEP * COMMON_DAMAGE_CAP):
		pool.append({
			"name": "More Energy! More Damage!",
			"desc": "+%d%% Damage" % int(COMMON_DAMAGE_STEP * 100.0),
			"apply": func(): ws.base_damage += maxi(1,
				int(ws.starting_damage * COMMON_DAMAGE_STEP)),
		})
	if player.shield_regen_rate < 5.0:
		pool.append({
			"name": "Improved Dash Regen", "desc": "+25% Dash Recharge",
			"apply": func(): player.set_shield_regen(player.shield_regen_rate + 0.25),
		})
	if player.speed_bonus < COMMON_SPEED_CAP:
		pool.append({
			"name": "Approaching Light Speed!",
			"desc": "+%d%% Speed" % int(COMMON_SPEED_STEP * 100.0),
			"apply": func(): player.speed_bonus += COMMON_SPEED_STEP,
		})
	if ws.attack_speed > COMMON_ATTACK_SPEED_FLOOR:
		pool.append({
			"name": "Improved Firing Module!", "desc": "+15% Attack Speed",
			"apply": func(): ws.attack_speed = maxf(COMMON_ATTACK_SPEED_FLOOR,
				ws.attack_speed - COMMON_ATTACK_SPEED_STEP),
		})
	if GameManager.shard_drop_rate < 30:
		pool.append({
			"name": "More Crystal Shards", "desc": "+50% Spawnrate of Crystal Shards",
			"apply": func(): GameManager.shard_drop_rate += 4,
		})
	if GameManager.experience_bonus < 10:
		pool.append({
			"name": "Quick Innovator", "desc": "+20% Experience Gain",
			"apply": func(): GameManager.experience_bonus += 2,
		})
	if ws.reload_time > COMMON_RELOAD_FLOOR:
		pool.append({
			"name": "Decrease Reload Cooldown!", "desc": "-0.15s Reload",
			"apply": func(): ws.reload_time = maxf(COMMON_RELOAD_FLOOR,
				ws.reload_time - COMMON_RELOAD_STEP),
		})
	if ws.bonus_ammo < COMMON_AMMO_CAP:
		pool.append({
			"name": "Increase Ammo Capacity!", "desc": "+%d Ammo Capacity" % COMMON_AMMO_STEP,
			"apply": func(): ws.add_bonus_ammo(COMMON_AMMO_STEP),
		})
	if player.max_hp < COMMON_HEALTH_CAP:
		pool.append({
			"name": "Reinforced Ship", "desc": "+%d Max Health" % COMMON_HEALTH_STEP,
			"apply": func(): player.add_max_health(COMMON_HEALTH_STEP),
		})
	if player.max_shield < COMMON_DASH_CAP:
		pool.append({
			"name": "Extended Dash Cells", "desc": "+%d Max Dash" % COMMON_DASH_STEP,
			"apply": func(): player.add_max_shield(COMMON_DASH_STEP),
		})
	return pool


# ── Rare: defence and attack passives ─────────────────────────────────────────

static func _rare_pool(ms: Node) -> Array:
	var pool: Array = []

	pool.append(_family(ms.got_comet_module,
		{ "name": "Comet Shower",
		  "desc": "%d comets shower the screen every %d seconds" % [ms.comet_amount, int(ms.comet_cooldown)],
		  "apply": func(): ms.got_comet_module = true },
		[
			_step(ms.comet_damage < 300, "+35 Damage to Comet Shower",
				func(): ms.comet_damage += 35),
			_step(ms.comet_cooldown > 5.0, "-1 Second on Cooldown to Comet Shower",
				func(): ms.comet_cooldown -= 1.0; ms.retune_timer("comet", ms.comet_cooldown)),
			_step(ms.comet_amount < 18, "+3 Comets to Comet Shower",
				func(): ms.comet_amount += 3),
		]))

	pool.append(_family(ms.got_shockwave_module,
		{ "name": "Shock Wave!",
		  "desc": "An AoE shockwave every %d seconds that paralyzes any enemy" % int(ms.shockwave_cooldown),
		  "apply": func(): ms.got_shockwave_module = true },
		[
			_step(ms.shockwave_stun < 5.0, "+0.5s Stun Duration to Shockwave",
				func(): ms.shockwave_stun += 0.5),
			_step(ms.shockwave_cooldown > 5.0, "-1 Second on Cooldown to Shockwave",
				func(): ms.shockwave_cooldown -= 1.0; ms.retune_timer("shockwave", ms.shockwave_cooldown)),
			_step(ms.shockwave_range < 400.0, "+15 Range to Shockwave",
				func(): ms.shockwave_range += 15.0),
		]))

	pool.append(_family(ms.got_electric_aura_module,
		{ "name": "Electric Aura!",
		  "desc": "An electric aura that damages any enemy that gets close",
		  "apply": func(): ms.got_electric_aura_module = true },
		[
			_step(ms.electric_aura_damage < 60, "+5 Damage to Electric Aura",
				func(): ms.electric_aura_damage += 5),
			_step(ms.electric_aura_range < 400.0, "+50 Range to Electric Aura",
				func(): ms.electric_aura_range += 50.0),
		]))

	if ms.shield_thorns_damage < 200:
		pool.append({
			"name": "Shield Retaliation Defense",
			"desc": "+40 Thorns Damage\n\nOnly activates through shield loss",
			"apply": func(): ms.shield_thorns_damage += 40,
		})
	if ms.health_thorns_damage < 400:
		pool.append({
			"name": "Health Retaliation Defense",
			"desc": "+80 Thorns Damage\n\nOnly activates through health loss",
			"apply": func(): ms.health_thorns_damage += 80,
		})

	pool.append(_family(ms.got_force_field_module,
		{ "name": "Force Field!",
		  "desc": "A shield every %d seconds that guarantees no damage once" % int(ms.force_field_cooldown),
		  "apply": func(): ms.got_force_field_module = true },
		[
			_step(ms.force_field_cooldown > 5.0, "-1 Second on Cooldown to Force Field",
				func(): ms.force_field_cooldown -= 1.0; ms.retune_timer("force_field", ms.force_field_cooldown)),
			_step(ms.force_field_stacks < 3, "+1 Stack to Force Field",
				func(): ms.force_field_stacks += 1),
		]))

	pool.append(_family(ms.got_electro_shield,
		{ "name": "Electro Shield!",
		  "desc": "Paralyzes an enemy for %.1fs if it damages your health or shield" % ms.electro_shield_duration,
		  "apply": func(): ms.got_electro_shield = true },
		[
			_step(ms.electro_shield_duration < 7.5, "+0.5s Duration to Electro Shield",
				func(): ms.electro_shield_duration += 0.5),
		]))

	pool.append(_family(ms.got_electro_bubbles_module,
		{ "name": "Electro Bubbles!",
		  "desc": "Throws an AoE electric bubble that pierces through enemies",
		  "apply": func(): ms.got_electro_bubbles_module = true },
		[
			_step(ms.electro_bubbles_cooldown > 2.0, "-1 Second on Cooldown to Electro Bubbles",
				func(): ms.electro_bubbles_cooldown -= 1.0; ms.retune_timer("electro_bubbles", ms.electro_bubbles_cooldown)),
			_step(ms.electro_bubbles_damage < 150, "+25 Damage to Electro Bubbles",
				func(): ms.electro_bubbles_damage += 25),
			_step(ms.electro_bubbles_duration < 3.0, "+0.2s Duration to Electro Bubbles",
				func(): ms.electro_bubbles_duration += 0.2),
		]))

	pool.append(_family(ms.got_energy_outburst_module,
		{ "name": "Energy Outburst!",
		  "desc": "Releases an energy wave that deals %d damage" % ms.energy_outburst_damage,
		  "apply": func(): ms.got_energy_outburst_module = true },
		[
			_step(ms.energy_outburst_cooldown > 5.0, "-1 Second on Cooldown to Energy Outburst",
				func(): ms.energy_outburst_cooldown -= 1.0; ms.retune_timer("energy_outburst", ms.energy_outburst_cooldown)),
			_step(ms.energy_outburst_damage < 500, "+70 Damage to Energy Outburst",
				func(): ms.energy_outburst_damage += 70),
			_step(ms.energy_outburst_range < 500.0, "+50 Range to Energy Outburst",
				func(): ms.energy_outburst_range += 50.0),
		]))

	return _compact(pool)


# ── Epic: weapon enhancements ─────────────────────────────────────────────────

static func _epic_pool(ws: Node, ms: Node, player: Node) -> Array:
	var pool: Array = []

	pool.append(_family(ws.got_scorching_module,
		{ "name": "Scorching Temperature Projectiles",
		  "desc": "Shots have a chance to set enemies burning",
		  "apply": func(): ws.got_scorching_module = true; ws.base_damage += 10 },
		[
			_step(ws.scorching_chance < 8, "+10% Chance to Shoot Scorching Projectiles",
				func(): ws.scorching_chance += 1),
		]))

	pool.append(_family(ws.got_electric_module,
		{ "name": "Electric Projectiles",
		  "desc": "Shots have a chance to paralyze enemies",
		  "apply": func(): ws.got_electric_module = true; ws.base_damage += 5 },
		[
			_step(ws.electric_chance < 8, "+10% Chance to Shoot Electric Projectiles",
				func(): ws.electric_chance += 1),
		]))

	pool.append(_family(ws.got_side_guns_module,
		{ "name": "Side Guns!",
		  "desc": "Cannons on both flanks firing at 50% size and 40% damage",
		  "apply": func(): ws.got_side_guns_module = true },
		[]))

	if ws.bonus_pierce < 5:
		pool.append({
			"name": "Piercing!", "desc": "+1 Piercing",
			"apply": func(): ws.bonus_pierce += 1,
		})

	pool.append(_family(ws.got_anti_flank_module,
		{ "name": "Anti-Flank Cannon",
		  "desc": "A rear cannon firing at 50% size and 50% damage",
		  "apply": func(): ws.got_anti_flank_module = true },
		[]))

	pool.append(_family(ms.got_dash_shockwave_module,
		{ "name": "On Dash Shockwave!",
		  "desc": "Deals %d AoE damage at the start of a dash" % ms.dash_shockwave_damage,
		  "apply": func(): ms.got_dash_shockwave_module = true },
		[
			_step(ms.dash_shockwave_damage < 100, "+20 Damage to Dash Shockwave",
				func(): ms.dash_shockwave_damage += 20),
		]))

	pool.append(_family(player.got_anti_collision,
		{ "name": "Anti-Collision",
		  "desc": "Pass through enemies instead of bumping into them",
		  "apply": func(): player.set_anti_collision(true) },
		[]))

	return _compact(pool)


# ── Legendary / godly ─────────────────────────────────────────────────────────

static func _legendary_pool(_player: Node, ws: Node, _ms: Node) -> Array:
	var player := _player
	var pool: Array = []

	if not ws.got_ultimate_shot:
		pool.append({
			"name": "Ultimate Shot",
			"desc": "First ammo used after reloading makes the last projectile 2x size and 4x damage",
			"apply": func(): ws.got_ultimate_shot = true,
		})
	if not ws.got_fluctuating_energy:
		pool.append({
			"name": "Fluctuating Energy",
			"desc": "Every odd number ammo, their projectile is 1.25x size and damage",
			"apply": func(): ws.got_fluctuating_energy = true,
		})
	if not ws.got_double_shoot:
		pool.append({
			"name": "Repeater Double Shoot",
			"desc": "Every volley fires two projectiles side by side",
			"apply": func(): ws.got_double_shoot = true,
		})
	if ws.repeater_cannon_amount < 3:
		pool.append({
			"name": "Cannon Repeater",
			"desc": "+1 volley, fired 0.2s behind the last\n\nEvery round costs ammo",
			"apply": func(): ws.repeater_cannon_amount += 1,
		})
	if not ws.got_shrink_device:
		pool.append({
			"name": "Shrink Device",
			"desc": "The ship becomes half its size and 1.5x faster",
			"apply": func():
				ws.got_shrink_device = true
				player.apply_shrink_device(),
		})
	return pool


static func _godly_pool(player: Node, ms: Node, ws: Node) -> Array:
	var pool: Array = []

	if not ws.got_super_energy_module:
		pool.append({
			"name": "Super Energy Module",
			"desc": "Every reload, everything you deal hits for 1.5x damage for 2 seconds",
			"apply": func(): ws.got_super_energy_module = true,
		})
	if not ms.got_super_shield_module:
		pool.append({
			"name": "Super Shield Module",
			"desc": "Become invincible for 5 seconds every 30 seconds",
			"apply": func(): ms.got_super_shield_module = true,
		})
	if player.revivals < 3:
		pool.append({
			"name": "State of the Art Ship",
			"desc": "+1 Revival of the ship\n1.25x damage overall",
			"apply": func():
				player.revivals += 1
				ws.overall_damage_mult *= 1.25,
		})
	return pool


# ── Option builders ───────────────────────────────────────────────────────────

## An "unlock first, then improve" family. Before it's owned, the pick is the
## unlock. After, it's one of the still-available steps at random — and if
## every step is capped out, nothing (so the caller falls through to scrap).
static func _family(owned: bool, unlock: Dictionary, steps: Array) -> Variant:
	if not owned:
		return unlock
	var open: Array = []
	for s in steps:
		if s != null:
			open.append(s)
	if open.is_empty():
		return null
	return open[randi_range(0, open.size() - 1)]


## One upgrade step, or null when it has hit its cap.
static func _step(available: bool, desc: String, apply: Callable) -> Variant:
	if not available:
		return null
	return { "name": "Module Upgrade", "desc": desc, "apply": apply }


static func _compact(pool: Array) -> Array:
	var out: Array = []
	for entry in pool:
		if entry != null:
			out.append(entry)
	return out


## Hands out a scrap payout. Kept here so the currency wording and the amounts
## can't drift apart.
static func grant_scrap(scrap: Dictionary) -> void:
	if scrap.has("currency"):
		GameManager.collect_currency(int(scrap["currency"]))
	if scrap.has("shards"):
		GameManager.collect_shards(int(scrap["shards"]))
