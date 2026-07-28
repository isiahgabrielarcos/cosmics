extends Node
class_name EnemyFactory

# Ports the enemy roster of enemiesMap.lua:
#   4 factions × 5 archetypes (chaser / shooter / bomber / ship slasher / ship dasher),
#   mama + baby slimes, and the 4 bosses — with the Lua spawn weights.
#
# Faction per stage (randomSpawner): 1 FlaschBourn · 2 Strogghold ·
# 3 Frokenvinter · 4 Squilltrant · missions 31–39 / complex: any faction.

const B := EnemyBase.Behavior

# sheet, frame w/h, frame count, fps (from the Lua sequence times),
# behavior, damage, xp, speed (Lua speed1 scaled to px/s)
const DEFS := {
	# ── FlaschBourn (stage 1) ──
	"fb_chaser":  { "sheet": "res://assets/art/characters/flaschBournChaser.png",  "fw": 32, "fh": 32, "count": 3, "fps": 3.0,  "behavior": B.CHASER,             "damage": 5,  "xp": 5,  "speed": 400.0 },
	"fb_shooter": { "sheet": "res://assets/art/characters/flaschBournShooter.png", "fw": 32, "fh": 32, "count": 3, "fps": 6.0,  "behavior": B.STATIONARY_SHOOTER, "damage": 10, "xp": 4,  "speed": 0.0 },
	"fb_bomber":  { "sheet": "res://assets/art/characters/flaschBournBomber.png",  "fw": 32, "fh": 32, "count": 5, "fps": 6.7,  "behavior": B.BOMBER,             "damage": 10, "xp": 5,  "speed": 225.0 },
	"fb_slasher": { "sheet": "res://assets/art/characters/flaschBournSlasher.png", "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "behavior": B.SHIP_SLASHER,       "damage": 2,  "xp": 10, "speed": 400.0 },
	"fb_ship":    { "sheet": "res://assets/art/characters/flaschBournShip.png",    "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "behavior": B.SHIP_DASHER,        "damage": 10, "xp": 10, "speed": 400.0 },
	# ── Strogghold (stage 2) ──
	"sh_chaser":  { "sheet": "res://assets/art/characters/red.png",                "fw": 32, "fh": 32, "count": 8, "fps": 8.0,  "behavior": B.CHASER,             "damage": 5,  "xp": 5,  "speed": 400.0 },
	"sh_shooter": { "sheet": "res://assets/art/characters/squidAlien.png",         "fw": 32, "fh": 32, "count": 7, "fps": 7.0,  "behavior": B.STATIONARY_SHOOTER, "damage": 10, "xp": 4,  "speed": 0.0 },
	"sh_bomber":  { "sheet": "res://assets/art/characters/bomber.png",             "fw": 32, "fh": 32, "count": 9, "fps": 12.0, "behavior": B.BOMBER,             "damage": 10, "xp": 5,  "speed": 225.0 },
	"sh_slasher": { "sheet": "res://assets/art/characters/stroggholdSlasher.png",  "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "behavior": B.SHIP_SLASHER,       "damage": 2,  "xp": 10, "speed": 400.0 },
	"sh_ship":    { "sheet": "res://assets/art/characters/stroggholdEnemyShip.png","fw": 32, "fh": 32, "count": 3, "fps": 12.0, "behavior": B.SHIP_DASHER,        "damage": 10, "xp": 10, "speed": 400.0 },
	# ── Frokenvinter (stage 3) ──
	"fv_chaser":  { "sheet": "res://assets/art/characters/frokenvinterChaser.png", "fw": 32, "fh": 32, "count": 3, "fps": 6.0,  "behavior": B.CHASER,             "damage": 5,  "xp": 5,  "speed": 400.0 },
	"fv_shooter": { "sheet": "res://assets/art/characters/octo.png",               "fw": 32, "fh": 32, "count": 6, "fps": 12.0, "behavior": B.STATIONARY_SHOOTER, "damage": 10, "xp": 4,  "speed": 0.0 },
	"fv_bomber":  { "sheet": "res://assets/art/characters/frokenvinterBomber.png", "fw": 32, "fh": 32, "count": 5, "fps": 6.7,  "behavior": B.BOMBER,             "damage": 10, "xp": 5,  "speed": 225.0 },
	"fv_slasher": { "sheet": "res://assets/art/characters/enemyShipFrokenVinter.png", "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "behavior": B.SHIP_SLASHER,    "damage": 2,  "xp": 10, "speed": 400.0 },
	"fv_ship":    { "sheet": "res://assets/art/characters/frokenvinterShip.png",   "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "behavior": B.SHIP_DASHER,        "damage": 10, "xp": 10, "speed": 400.0 },
	# ── Squilltrant (stage 4) ──
	"st_mama":    { "sheet": "res://assets/art/characters/slime1.png",             "fw": 64, "fh": 64, "count": 5, "fps": 10.0, "behavior": B.CHASER,             "damage": 5,  "xp": 5,  "speed": 150.0, "mama": true },
	"st_shooter": { "sheet": "res://assets/art/characters/squilltrantShooter.png", "fw": 32, "fh": 32, "count": 4, "fps": 8.0,  "behavior": B.STATIONARY_SHOOTER, "damage": 10, "xp": 4,  "speed": 0.0 },
	"st_bomber":  { "sheet": "res://assets/art/characters/squilltrantBomber.png",  "fw": 32, "fh": 32, "count": 5, "fps": 6.7,  "behavior": B.BOMBER,             "damage": 10, "xp": 5,  "speed": 225.0 },
	"st_slasher": { "sheet": "res://assets/art/characters/squilltrantSlasher.png", "fw": 32, "fh": 32, "count": 3, "fps": 12.0, "behavior": B.SHIP_SLASHER,       "damage": 2,  "xp": 10, "speed": 400.0 },
	"st_ship":    { "sheet": "res://assets/art/characters/enemyShipSqiulltrant.png","fw": 32, "fh": 32, "count": 3, "fps": 12.0, "behavior": B.SHIP_DASHER,       "damage": 10, "xp": 10, "speed": 400.0 },
	# ── Baby slime (enemy6 — spawned when mama dies) ──
	"baby_slime": { "sheet": "res://assets/art/characters/slime.png",              "fw": 32, "fh": 32, "count": 5, "fps": 10.0, "behavior": B.CHASER,             "damage": 2,  "xp": 3,  "speed": 325.0, "baby": true },
	# ── Bosses (every 50 spawns) ──
	"boss1":      { "sheet": "res://assets/art/characters/cosmicBoss2.png",        "fw": 128, "fh": 128, "count": 3, "fps": 6.0, "behavior": B.BOSS_SLASHER,      "damage": 30, "xp": 100, "speed": 400.0, "boss": true },
	"boss2":      { "sheet": "res://assets/art/characters/cosmicBoss1.png",        "fw": 128, "fh": 128, "count": 7, "fps": 8.75,"behavior": B.BOSS_CHASER,       "damage": 30, "xp": 100, "speed": 350.0, "boss": true },
	"boss3":      { "sheet": "res://assets/art/characters/cosmicBoss3.png",        "fw": 128, "fh": 128, "count": 3, "fps": 6.0, "behavior": B.BOSS_SLASHER,      "damage": 30, "xp": 100, "speed": 400.0, "boss": true },
	"boss4":      { "sheet": "res://assets/art/characters/cosmicBoss4.png",        "fw": 128, "fh": 128, "count": 3, "fps": 6.0, "behavior": B.BOSS_SLASHER,      "damage": 30, "xp": 100, "speed": 400.0, "boss": true },
}

const FACTION_PREFIX := { 1: "fb", 2: "sh", 3: "fv", 4: "st" }

static var _frames_cache: Dictionary = {}


static func spawn(parent: Node, id: String, pos: Vector2) -> EnemyBase:
	var def: Dictionary = DEFS[id]
	var enemy := EnemyBase.new()

	enemy.behavior = def["behavior"]
	enemy.contact_damage = def["damage"]
	enemy.experience_value = def["xp"]
	enemy.speed = def["speed"]
	enemy.is_boss = def.get("boss", false)
	enemy.is_mama_slime = def.get("mama", false)

	# Health rules from whereSpawn(): enemyLevel = heroLevel * 30
	var enemy_level: int = int(SaveManager.stats_data.get("baseHeroLevel", 1)) * 30
	if enemy.is_boss:
		enemy.max_hp = (1000 if def["behavior"] == B.BOSS_CHASER else 800) + enemy_level * 10
	elif enemy.is_mama_slime:
		enemy.max_hp = 100 + enemy_level
	elif def.get("baby", false):
		enemy.max_hp = 25
	else:
		enemy.max_hp = 50 + enemy_level

	# Size rules: bosses 2×, mama 2–3×, baby 1.5×, normal 2–3× random
	var visual_scale: float
	if enemy.is_boss:
		visual_scale = 2.0
	elif def.get("baby", false):
		visual_scale = 1.5
	else:
		visual_scale = randf_range(2.0, 3.0)

	enemy.setup_visual(_get_frames(def), visual_scale)
	enemy.global_position = pos
	parent.add_child(enemy)

	if enemy.is_boss:
		AudioManager.play_sfx("bossSpawnSound")
	return enemy


static func spawn_baby_slime(parent: Node, pos: Vector2) -> EnemyBase:
	return spawn(parent, "baby_slime", pos)


## Ports the faction spawn weights (roll 1..30):
##   1–10 chaser · 11–15 shooter · 16–20 bomber · 21–25 slasher · 26–30 ship
static func spawn_from_roll(parent: Node, faction: int, roll: int, pos: Vector2) -> EnemyBase:
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


static func spawn_random_boss(parent: Node, pos: Vector2) -> EnemyBase:
	return spawn(parent, "boss%d" % randi_range(1, 4), pos)


static func _get_frames(def: Dictionary) -> SpriteFrames:
	var key: String = def["sheet"]
	if _frames_cache.has(key):
		return _frames_cache[key]

	var tex: Texture2D = load(def["sheet"])
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", def["fps"])
	frames.set_animation_loop("idle", true)

	var fw: int = def["fw"]
	var fh: int = def["fh"]
	var cols := maxi(1, int(tex.get_width() / fw))
	for i in int(def["count"]):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		@warning_ignore("integer_division")
		atlas.region = Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)
		frames.add_frame("idle", atlas)

	_frames_cache[key] = frames
	return frames
