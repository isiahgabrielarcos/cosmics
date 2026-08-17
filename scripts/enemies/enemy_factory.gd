extends Node
class_name EnemyFactory

# Spawns enemy archetype scenes (chaser / bomber / shooter / slasher) with a
# per-faction EnemyData resource built from DEFS below. Faction art lives in
# assets/art/enemies/; behaviour + physics come from the shared archetype
# scene, so adding a new faction is just new rows in this table.
#
# Faction per stage (randomSpawner): 1 FlaschBourn · 2 Strogghold ·
# 3 Frokenvinter · 4 Squilltrant · missions 31–39 / complex: any faction.

const ChaserScene  := preload("res://scenes/enemies/enemy_chaser.tscn")
const BomberScene  := preload("res://scenes/enemies/enemy_bomber.tscn")
const ShooterScene := preload("res://scenes/enemies/enemy_shooter.tscn")
const SlasherScene := preload("res://scenes/enemies/enemy_slasher.tscn")

enum Archetype { CHASER, BOMBER, SHOOTER, SLASHER }

const SCENES := {
	Archetype.CHASER:  ChaserScene,
	Archetype.BOMBER:  BomberScene,
	Archetype.SHOOTER: ShooterScene,
	Archetype.SLASHER: SlasherScene,
}

const GROUP := EnemyData.PhysicsGroup

# sheet, frame geometry, archetype (behaviour script), physics group
# (which enemy collision layer — see enemy_unit.gd), and stats.
const DEFS := {
	# ── FlaschBourn (stage 1) ──
	"fb_chaser":  { "sheet": "res://assets/art/enemies/flaschBournChaser.png",     "fw": 32, "fh": 32, "count": 3, "fps": 6.0,  "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 5,  "xp": 5,  "speed": 260.0, "turn": 4.0 },
	"fb_shooter": { "sheet": "res://assets/art/enemies/flaschBournShooter.png",    "fw": 32, "fh": 32, "count": 3, "fps": 6.0,  "arch": Archetype.SHOOTER, "group": GROUP.SHOOTERS, "dmg": 10, "xp": 4,  "speed": 50.0 },
	"fb_bomber":  { "sheet": "res://assets/art/enemies/flaschBournBomber.png",     "fw": 32, "fh": 32, "count": 5, "fps": 6.7,  "arch": Archetype.BOMBER,  "group": GROUP.BOMBERS,  "dmg": 10, "xp": 5,  "speed": 200.0 },
	"fb_slasher": { "sheet": "res://assets/art/enemies/flaschBournSlasher.png",    "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.SLASHER, "group": GROUP.SLASHERS, "dmg": 12, "xp": 10, "speed": 220.0, "turn": 6.0 },
	"fb_ship":    { "sheet": "res://assets/art/enemies/flaschBournShip.png",       "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.CHASER,  "group": GROUP.SHIPS,    "dmg": 10, "xp": 10, "speed": 550.0, "turn": 10.0 },
	# ── Strogghold (stage 2) ──
	"sh_chaser":  { "sheet": "res://assets/art/enemies/red.png",                   "fw": 32, "fh": 32, "count": 9, "fps": 12.0, "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 5,  "xp": 5,  "speed": 260.0, "turn": 4.0 },
	"sh_shooter": { "sheet": "res://assets/art/enemies/squidAlien.png",            "fw": 32, "fh": 32, "count": 7, "fps": 7.0,  "arch": Archetype.SHOOTER, "group": GROUP.SHOOTERS, "dmg": 10, "xp": 4,  "speed": 50.0 },
	"sh_bomber":  { "sheet": "res://assets/art/enemies/bomber.png",                "fw": 32, "fh": 32, "count": 9, "fps": 12.0, "arch": Archetype.BOMBER,  "group": GROUP.BOMBERS,  "dmg": 10, "xp": 5,  "speed": 200.0 },
	"sh_slasher": { "sheet": "res://assets/art/enemies/stroggholdSlasher.png",     "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.SLASHER, "group": GROUP.SLASHERS, "dmg": 12, "xp": 10, "speed": 220.0, "turn": 6.0 },
	"sh_ship":    { "sheet": "res://assets/art/enemies/stroggholdEnemyShip.png",   "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.CHASER,  "group": GROUP.SHIPS,    "dmg": 10, "xp": 10, "speed": 550.0, "turn": 10.0 },
	# ── Frokenvinter (stage 3) ──
	"fv_chaser":  { "sheet": "res://assets/art/enemies/frokenvinterChaser.png",    "fw": 32, "fh": 32, "count": 3, "fps": 6.0,  "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 5,  "xp": 5,  "speed": 260.0, "turn": 4.0 },
	"fv_shooter": { "sheet": "res://assets/art/enemies/octo.png",                  "fw": 32, "fh": 32, "count": 6, "fps": 12.0, "arch": Archetype.SHOOTER, "group": GROUP.SHOOTERS, "dmg": 10, "xp": 4,  "speed": 50.0 },
	"fv_bomber":  { "sheet": "res://assets/art/enemies/frokenvinterBomber.png",    "fw": 32, "fh": 32, "count": 5, "fps": 6.7,  "arch": Archetype.BOMBER,  "group": GROUP.BOMBERS,  "dmg": 10, "xp": 5,  "speed": 200.0 },
	"fv_slasher": { "sheet": "res://assets/art/enemies/enemyShipFrokenVinter.png", "fw": 32, "fh": 32, "count": 4, "fps": 12.0, "arch": Archetype.SLASHER, "group": GROUP.SLASHERS, "dmg": 12, "xp": 10, "speed": 220.0, "turn": 6.0 },
	"fv_ship":    { "sheet": "res://assets/art/enemies/frokenvinterShip.png",      "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.CHASER,  "group": GROUP.SHIPS,    "dmg": 10, "xp": 10, "speed": 550.0, "turn": 10.0 },
	# ── Squilltrant (stage 4) ──
	"st_mama":    { "sheet": "res://assets/art/enemies/slime.png",                "fw": 32, "fh": 32, "count": 5, "fps": 10.0, "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 5,  "xp": 5,  "speed": 200.0, "turn": 4.0, "mama": true },
	"st_shooter": { "sheet": "res://assets/art/enemies/squilltrantShooter.png",    "fw": 32, "fh": 32, "count": 4, "fps": 8.0,  "arch": Archetype.SHOOTER, "group": GROUP.SHOOTERS, "dmg": 10, "xp": 4,  "speed": 50.0 },
	"st_bomber":  { "sheet": "res://assets/art/enemies/squilltrantBomber.png",     "fw": 32, "fh": 32, "count": 5, "fps": 6.7,  "arch": Archetype.BOMBER,  "group": GROUP.BOMBERS,  "dmg": 10, "xp": 5,  "speed": 200.0 },
	"st_slasher": { "sheet": "res://assets/art/enemies/squilltrantSlasher.png",    "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.SLASHER, "group": GROUP.SLASHERS, "dmg": 12, "xp": 10, "speed": 220.0, "turn": 6.0 },
	"st_ship":    { "sheet": "res://assets/art/enemies/enemyShipSqiulltrant.png",  "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.CHASER,  "group": GROUP.SHIPS,    "dmg": 10, "xp": 10, "speed": 550.0, "turn": 10.0 },
	# ── Baby slime (spawned when a mama slime dies) ──
	"baby_slime": { "sheet": "res://assets/art/enemies/slime1.png",               "fw": 64, "fh": 64, "count": 5, "fps": 10.0, "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 2,  "xp": 3,  "speed": 340.0, "turn": 5.0, "baby": true },
	# ── Bosses (every 50th spawn) — all fundamentally chasers, each with a twist ──
	"boss_strogghold":   { "sheet": "res://assets/art/enemies/cosmicBoss1.png", "fw": 128, "fh": 128, "count": 7, "fps": 8.75, "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 30, "xp": 100, "speed": 200.0, "turn": 3.0, "boss": true },
	"boss_frokenvinter": { "sheet": "res://assets/art/enemies/cosmicBoss2.png", "fw": 128, "fh": 128, "count": 3, "fps": 6.0,  "arch": Archetype.SLASHER, "group": GROUP.SLASHERS, "dmg": 25, "xp": 100, "speed": 220.0, "turn": 6.0, "boss": true },
	"boss_flaschbourn":  { "sheet": "res://assets/art/enemies/cosmicBoss3.png", "fw": 128, "fh": 128, "count": 3, "fps": 6.0,  "arch": Archetype.CHASER,  "group": GROUP.SHOOTERS, "dmg": 20, "xp": 100, "speed": 160.0, "turn": 3.0, "boss": true, "shoots": true, "shoot_rate": 1.5, "proj_scale": 3.0 },
	"boss_squilltrant":  { "sheet": "res://assets/art/enemies/cosmicBoss4.png", "fw": 128, "fh": 128, "count": 3, "fps": 6.0,  "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 20, "xp": 100, "speed": 220.0, "turn": 4.0, "boss": true, "split": true },
}

const FACTION_PREFIX := { 1: "fb", 2: "sh", 3: "fv", 4: "st" }

## Each solar system has its own boss — you always face that faction's own
## champion rather than a random one out of the pool.
const FACTION_BOSS := {
	1: "boss_flaschbourn",
	2: "boss_strogghold",
	3: "boss_frokenvinter",
	4: "boss_squilltrant",
}

static var _data_cache: Dictionary = {}


static func spawn(parent: Node, id: String, pos: Vector2) -> Node:
	var d := _build_data(id)
	var scene: PackedScene = SCENES[DEFS[id]["arch"]]
	var enemy = scene.instantiate()
	enemy.data = d
	enemy.global_position = pos
	parent.add_child(enemy)

	if d.is_boss:
		AudioManager.play_sfx("bossSpawnSound")
	return enemy


static func spawn_baby_slime(parent: Node, pos: Vector2) -> Node:
	return spawn(parent, "baby_slime", pos)


## Spawns one archetype ("chaser" / "shooter" / "bomber" / "slasher" / "ship")
## in the given faction's flavour. Squilltrant has no plain chaser — its
## mama slime fills that slot and splits into babies when killed.
static func spawn_kind(parent: Node, faction: int, kind: String, pos: Vector2) -> Node:
	var prefix: String = FACTION_PREFIX.get(faction, "fb")
	if kind == "chaser" and prefix == "st":
		kind = "mama"
	var id := "%s_%s" % [prefix, kind]
	if not DEFS.has(id):
		push_warning("EnemyFactory: no def for '%s', falling back to chaser" % id)
		id = "st_mama" if prefix == "st" else "%s_chaser" % prefix
	return spawn(parent, id, pos)


static func spawn_system_boss(parent: Node, faction: int, pos: Vector2) -> Node:
	return spawn(parent, FACTION_BOSS.get(faction, "boss_flaschbourn"), pos)


static func _build_data(id: String) -> EnemyData:
	if _data_cache.has(id):
		return _data_cache[id]

	var def: Dictionary = DEFS[id]
	var d := EnemyData.new()

	d.sprite_sheet = load(def["sheet"])
	d.frame_width  = def["fw"]
	d.frame_height = def["fh"]
	d.frame_count  = def["count"]
	d.fps          = def["fps"]

	d.contact_damage    = def["dmg"]
	d.experience_value  = def["xp"]
	d.speed             = def["speed"]
	d.turn_rate         = def.get("turn", 5.0)
	d.is_boss           = def.get("boss", false)
	d.immune_to_status  = d.is_boss
	d.fires_projectiles = def.get("shoots", def["arch"] == Archetype.SHOOTER)
	d.physics_group     = def["group"]

	# `shoot_rate` is a multiple of how fast an ordinary shooter fires, so 1.5
	# means one and a half times the rate — a shorter gap between rounds, not a
	# longer one. `proj_scale` sizes both the sprite and its hitbox.
	d.shoot_interval    = d.shoot_interval / maxf(float(def.get("shoot_rate", 1.0)), 0.01)
	d.projectile_scale  = float(def.get("proj_scale", 1.0))

	# Base health only. The hero-level bonus and the difficulty multiplier are
	# applied per-instance at spawn (EnemyUnit), because this resource is
	# cached and shared — enemies spawned later in a run have to be tougher
	# than the ones that came before.
	if d.is_boss:
		d.max_hp = 1000 if id == "boss_strogghold" else 800
		d.hp_per_hero_level = 140
	elif def.get("mama", false):
		d.max_hp = 100
	elif def.get("baby", false):
		d.max_hp = 25
		d.hp_per_hero_level = 4
		d.drops_loot = false   # the mama already paid out for these
	else:
		d.max_hp = 50

	# Size: bosses fixed 2x, baby fixed 1x (its sheet is already 2x the raw
	# pixel size of the mama's), mama/normal random 2–3x.
	if d.is_boss:
		d.fixed_scale = 2.0
	elif def.get("baby", false):
		d.fixed_scale = 1.0
	else:
		d.scale_min = 2.0
		d.scale_max = 3.0

	if def.get("mama", false):
		d.death_spawn_data = _build_data("baby_slime")
		d.death_spawn_count = 3

	if def.get("split", false):
		d.self_split_count = 2
		d.self_split_max_depth = 2
		d.self_split_scale_mult = 0.6
		d.self_split_hp_mult = 0.5

	_data_cache[id] = d
	return d
