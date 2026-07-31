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
# (which of the 3 collision layers — see enemy_unit.gd), and stats.
const DEFS := {
	# ── FlaschBourn (stage 1) ──
	"fb_chaser":  { "sheet": "res://assets/art/enemies/flaschBournChaser.png",     "fw": 32, "fh": 32, "count": 3, "fps": 6.0,  "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 5,  "xp": 5,  "speed": 260.0, "turn": 4.0 },
	"fb_shooter": { "sheet": "res://assets/art/enemies/flaschBournShooter.png",    "fw": 32, "fh": 32, "count": 3, "fps": 6.0,  "arch": Archetype.SHOOTER, "group": GROUP.SHOOTERS, "dmg": 10, "xp": 4,  "speed": 50.0 },
	"fb_bomber":  { "sheet": "res://assets/art/enemies/flaschBournBomber.png",     "fw": 32, "fh": 32, "count": 5, "fps": 6.7,  "arch": Archetype.BOMBER,  "group": GROUP.CHASERS,  "dmg": 10, "xp": 5,  "speed": 200.0 },
	"fb_slasher": { "sheet": "res://assets/art/enemies/flaschBournSlasher.png",    "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.SLASHER, "group": GROUP.SHIPS,    "dmg": 12, "xp": 10, "speed": 220.0, "turn": 6.0 },
	"fb_ship":    { "sheet": "res://assets/art/enemies/flaschBournShip.png",       "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.CHASER,  "group": GROUP.SHIPS,    "dmg": 10, "xp": 10, "speed": 550.0, "turn": 10.0 },
	# ── Strogghold (stage 2) ──
	"sh_chaser":  { "sheet": "res://assets/art/enemies/red.png",                   "fw": 32, "fh": 32, "count": 9, "fps": 12.0, "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 5,  "xp": 5,  "speed": 260.0, "turn": 4.0 },
	"sh_shooter": { "sheet": "res://assets/art/enemies/squidAlien.png",            "fw": 32, "fh": 32, "count": 7, "fps": 7.0,  "arch": Archetype.SHOOTER, "group": GROUP.SHOOTERS, "dmg": 10, "xp": 4,  "speed": 50.0 },
	"sh_bomber":  { "sheet": "res://assets/art/enemies/bomber.png",                "fw": 32, "fh": 32, "count": 9, "fps": 12.0, "arch": Archetype.BOMBER,  "group": GROUP.CHASERS,  "dmg": 10, "xp": 5,  "speed": 200.0 },
	"sh_slasher": { "sheet": "res://assets/art/enemies/stroggholdSlasher.png",     "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.SLASHER, "group": GROUP.SHIPS,    "dmg": 12, "xp": 10, "speed": 220.0, "turn": 6.0 },
	"sh_ship":    { "sheet": "res://assets/art/enemies/stroggholdEnemyShip.png",   "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.CHASER,  "group": GROUP.SHIPS,    "dmg": 10, "xp": 10, "speed": 550.0, "turn": 10.0 },
	# ── Frokenvinter (stage 3) ──
	"fv_chaser":  { "sheet": "res://assets/art/enemies/frokenvinterChaser.png",    "fw": 32, "fh": 32, "count": 3, "fps": 6.0,  "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 5,  "xp": 5,  "speed": 260.0, "turn": 4.0 },
	"fv_shooter": { "sheet": "res://assets/art/enemies/octo.png",                  "fw": 32, "fh": 32, "count": 6, "fps": 12.0, "arch": Archetype.SHOOTER, "group": GROUP.SHOOTERS, "dmg": 10, "xp": 4,  "speed": 50.0 },
	"fv_bomber":  { "sheet": "res://assets/art/enemies/frokenvinterBomber.png",    "fw": 32, "fh": 32, "count": 5, "fps": 6.7,  "arch": Archetype.BOMBER,  "group": GROUP.CHASERS,  "dmg": 10, "xp": 5,  "speed": 200.0 },
	"fv_slasher": { "sheet": "res://assets/art/enemies/enemyShipFrokenVinter.png", "fw": 32, "fh": 32, "count": 4, "fps": 12.0, "arch": Archetype.SLASHER, "group": GROUP.SHIPS,    "dmg": 12, "xp": 10, "speed": 220.0, "turn": 6.0 },
	"fv_ship":    { "sheet": "res://assets/art/enemies/frokenvinterShip.png",      "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.CHASER,  "group": GROUP.SHIPS,    "dmg": 10, "xp": 10, "speed": 550.0, "turn": 10.0 },
	# ── Squilltrant (stage 4) ──
	"st_mama":    { "sheet": "res://assets/art/enemies/slime.png",                "fw": 32, "fh": 32, "count": 5, "fps": 10.0, "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 5,  "xp": 5,  "speed": 200.0, "turn": 4.0, "mama": true },
	"st_shooter": { "sheet": "res://assets/art/enemies/squilltrantShooter.png",    "fw": 32, "fh": 32, "count": 4, "fps": 8.0,  "arch": Archetype.SHOOTER, "group": GROUP.SHOOTERS, "dmg": 10, "xp": 4,  "speed": 50.0 },
	"st_bomber":  { "sheet": "res://assets/art/enemies/squilltrantBomber.png",     "fw": 32, "fh": 32, "count": 5, "fps": 6.7,  "arch": Archetype.BOMBER,  "group": GROUP.CHASERS,  "dmg": 10, "xp": 5,  "speed": 200.0 },
	"st_slasher": { "sheet": "res://assets/art/enemies/squilltrantSlasher.png",    "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.SLASHER, "group": GROUP.SHIPS,    "dmg": 12, "xp": 10, "speed": 220.0, "turn": 6.0 },
	"st_ship":    { "sheet": "res://assets/art/enemies/enemyShipSqiulltrant.png",  "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "arch": Archetype.CHASER,  "group": GROUP.SHIPS,    "dmg": 10, "xp": 10, "speed": 550.0, "turn": 10.0 },
	# ── Baby slime (spawned when a mama slime dies) ──
	"baby_slime": { "sheet": "res://assets/art/enemies/slime1.png",               "fw": 64, "fh": 64, "count": 5, "fps": 10.0, "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 2,  "xp": 3,  "speed": 340.0, "turn": 5.0, "baby": true },
	# ── Bosses (every 50th spawn) — all fundamentally chasers, each with a twist ──
	"boss_strogghold":   { "sheet": "res://assets/art/enemies/cosmicBoss1.png", "fw": 128, "fh": 128, "count": 7, "fps": 8.75, "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 30, "xp": 100, "speed": 200.0, "turn": 3.0, "boss": true },
	"boss_frokenvinter": { "sheet": "res://assets/art/enemies/cosmicBoss2.png", "fw": 128, "fh": 128, "count": 3, "fps": 6.0,  "arch": Archetype.SLASHER, "group": GROUP.SHIPS,    "dmg": 25, "xp": 100, "speed": 220.0, "turn": 6.0, "boss": true },
	"boss_flaschbourn":  { "sheet": "res://assets/art/enemies/cosmicBoss3.png", "fw": 128, "fh": 128, "count": 3, "fps": 6.0,  "arch": Archetype.CHASER,  "group": GROUP.SHOOTERS, "dmg": 20, "xp": 100, "speed": 160.0, "turn": 3.0, "boss": true, "shoots": true },
	"boss_squilltrant":  { "sheet": "res://assets/art/enemies/cosmicBoss4.png", "fw": 128, "fh": 128, "count": 3, "fps": 6.0,  "arch": Archetype.CHASER,  "group": GROUP.CHASERS,  "dmg": 20, "xp": 100, "speed": 220.0, "turn": 4.0, "boss": true, "split": true },
}

const FACTION_PREFIX := { 1: "fb", 2: "sh", 3: "fv", 4: "st" }
const BOSS_IDS := ["boss_strogghold", "boss_frokenvinter", "boss_flaschbourn", "boss_squilltrant"]

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


## Ports the faction spawn weights (roll 1..30):
##   1–10 chaser (mama for Squilltrant) · 11–15 shooter · 16–20 bomber ·
##   21–25 slasher · 26–30 ship
static func spawn_from_roll(parent: Node, faction: int, roll: int, pos: Vector2) -> Node:
	var prefix: String = FACTION_PREFIX.get(faction, "fb")
	var kind: String
	if roll <= 10:
		kind = "mama" if prefix == "st" else "chaser"
	elif roll <= 15:
		kind = "shooter"
	elif roll <= 20:
		kind = "bomber"
	elif roll <= 25:
		kind = "slasher"
	else:
		kind = "ship"
	return spawn(parent, "%s_%s" % [prefix, kind], pos)


static func spawn_random_boss(parent: Node, pos: Vector2) -> Node:
	return spawn(parent, BOSS_IDS[randi_range(0, BOSS_IDS.size() - 1)], pos)


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
	d.fires_projectiles = def.get("shoots", def["arch"] == Archetype.SHOOTER)
	d.physics_group     = def["group"]

	# Health rules from whereSpawn(): enemyLevel = heroLevel * 30
	var enemy_level: int = int(SaveManager.stats_data.get("baseHeroLevel", 1)) * 30
	if d.is_boss:
		d.max_hp = (1000 if id == "boss_strogghold" else 800) + enemy_level * 10
	elif def.get("mama", false):
		d.max_hp = 100 + enemy_level
	elif def.get("baby", false):
		d.max_hp = 25
	else:
		d.max_hp = 50 + enemy_level

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
