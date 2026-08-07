extends Node

# Ports savingData.lua — same JSON files, same fields, stored in user://
# (C:\Users\<name>\AppData\Roaming\Godot\app_userdata\Cosmics\ on Windows)

var system_data: Dictionary = {}
var player_data: Dictionary = {}    # gems / shards / centralCurrency
var weapon_data: Dictionary = {}    # w1value..w7value (owned weapons)
var equipped_data: Dictionary = {}  # weapon1Slot / weapon2Slot / skillSlot / heroSkin
var skill_data: Dictionary = {}     # s1value..s7value (owned skills)
var stats_data: Dictionary = {}     # ship base stats (roguelite upgrades)
var story_data: Dictionary = {}


func _ready() -> void:
	_load_all()
	if not system_data.has("firstTimePlaying"):
		_create_first_time_data()
	_unlock_everything_for_playtesting()


# ── First-time defaults (exact values from savingData.lua) ─────────────────────

func _create_first_time_data() -> void:
	print("Actual First Game")
	system_data = { "firstTimePlaying": true }

	player_data = {
		"gems": 150,
		"shards": 500,
		"centralCurrency": 14000,
	}

	weapon_data = {
		"w1value": true,  "w2value": true, "w3value": false, "w4value": false,
		"w5value": false, "w6value": false, "w7value": false,
	}

	equipped_data = {
		"weapon1Slot": 1,   # Laser
		"weapon2Slot": 2,   # Plasma Ball
		"skillSlot": 1,
		"heroSkin": 1,
	}

	skill_data = {
		"s1value": true,  "s2value": false, "s3value": false, "s4value": false,
		"s5value": false, "s6value": false, "s7value": false,
	}

	stats_data = {
		"baseHealth": 100,
		"baseShield": 50,
		"is1stHalfUnlocked": 0,
		"baseSpeed": 5,
		"baseRange": 200,
		"baseHeroLevel": 1,

		"is2ndBaseUnlocked": 0,
		"baseShieldRegen": 1,
		"baseHealthRegen": 5,
		"is2ndBase1stHalfUnlocked": 0,
		"baseInitialShield": 0,
		"baseDamage": 20,
		"baseAmmoCapacity": 18,

		"cccSponsor": 0,
		"guildSponsor": 0,
		"traderUnionSponsor": 0,
		"cosmicSponsor": 0,

		"is2ndBaseUnlockedSponsor": 0,
		"increaseRare": 0,
		"increaseEpic": 0,
		"increaseLegendary": 0,
		"increaseHero": 0,
	}

	story_data = {
		"lobbyStory": 1,
		"characterQuest": 0,
		"OuterStory": 0,
	}

	save_all()


## Weapons/skills pulled from the loadout while their balance/kit is reworked
## (Comet, Shield Generator, Electric Shock, Giant Beam) — kept locked even
## during playtesting so they can't be equipped through a stale save.
const DISABLED_WEAPONS := [3, 7]
const DISABLED_SKILLS  := [4, 6]


## Playtest helper — unlocks every weapon/skill and stat gate so the whole
## game is reachable without grinding. Remove this call in _ready() once
## real progression/unlocks are wired up.
func _unlock_everything_for_playtesting() -> void:
	for i in range(1, 8):
		if not (i in DISABLED_WEAPONS):
			weapon_data["w%dvalue" % i] = true
		if not (i in DISABLED_SKILLS):
			skill_data["s%dvalue" % i] = true

	player_data["gems"] = maxi(int(player_data.get("gems", 0)), 99999)
	player_data["shards"] = maxi(int(player_data.get("shards", 0)), 99999)
	player_data["centralCurrency"] = maxi(int(player_data.get("centralCurrency", 0)), 99999)

	stats_data["is1stHalfUnlocked"] = 1
	stats_data["is2ndBaseUnlocked"] = 1
	stats_data["is2ndBase1stHalfUnlocked"] = 1
	stats_data["is2ndBaseUnlockedSponsor"] = 1

	save_all()


# ── File IO ────────────────────────────────────────────────────────────────────

func _save_file(file_name: String, data: Dictionary) -> void:
	var f := FileAccess.open("user://%s" % file_name, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func _load_file(file_name: String) -> Dictionary:
	if not FileAccess.file_exists("user://%s" % file_name):
		return {}
	var f := FileAccess.open("user://%s" % file_name, FileAccess.READ)
	if not f:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


func _load_all() -> void:
	system_data   = _load_file("systemData.json")
	player_data   = _load_file("playerData.json")
	weapon_data   = _load_file("weaponData.json")
	equipped_data = _load_file("equippedData.json")
	skill_data    = _load_file("skillData.json")
	stats_data    = _load_file("baseStatData.json")
	story_data    = _load_file("storyData.json")


func save_all() -> void:
	_save_file("systemData.json", system_data)
	save_player_data()
	_save_file("weaponData.json", weapon_data)
	_save_file("equippedData.json", equipped_data)
	_save_file("skillData.json", skill_data)
	_save_file("baseStatData.json", stats_data)
	_save_file("storyData.json", story_data)


func save_player_data() -> void:
	_save_file("playerData.json", player_data)


func save_stats_data() -> void:
	_save_file("baseStatData.json", stats_data)


func save_equipped_data() -> void:
	_save_file("equippedData.json", equipped_data)
