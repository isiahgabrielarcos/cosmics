extends RefCounted

# Who calls Toby mid-run, what they ask for, and what they pay.
#
# This file is data only. It rolls a contract offer and hands back a plain
# dictionary; nothing here knows about panels, timers or the run itself. That
# keeps the writing in one place, so adding a new job for someone is a new row
# in their `tasks` list and nothing else.
#
# Each caller owns a lane so the offers stay in character:
#   Chesca   (Reception)  hands out the guild's routine work, mostly culling
#                         fiends and running supplies.
#   Gabriel  (Blacksmith) wants materials, so shards, gems and salvaged modules.
#   Mary Jane(First Resp.) sends you to keep other people alive.
#   Lorraine (Polaroid)   documents the sector, so her work is about observing
#                         fiends rather than only killing them.
#   Cody     (Merc Guild) takes the dangerous end: bosses, citadel defence, and
#                         named enemy types.
#
# Every task carries a `pay` weight. The reward roll multiplies its currency
# bands by that weight, so a job that asks for more is worth more without
# anybody hand-tuning a number per line.
#
# `id` on each task is what the future objective tracking will hook into. The
# calls do nothing but offer and record for now, which is deliberate; the
# scenarios come later.

## Deliberately NOT a class_name global. Godot only registers those after the
## editor rescans, so a brand new one fails to resolve for anyone running the
## project before opening it, and that parse error takes every script that
## references it down too. Callers preload this instead.

## `id` is what the objective tracking keys off. Everything with a `kill_*`,
## `collect_*` or `gauge_*` id is counted by GameManager as the run goes; the
## `haul_*` ids put a physical cargo on the ship and a citadel to fly it to.
const CALLERS := {
	"receptionist": {
		"name": "Chesca",
		"role": "CCC Guild Receptionist",
		"avatar": "res://assets/art/ui/receptionistAvatar.png",
		"tasks": [
			{ "id": "kill_any",     "text": "Cull %d fiends anywhere in the sector", "min": 50, "max": 250, "pay": 1.0 },
			{ "id": "kill_any",     "text": "Thin the swarm: %d confirmed kills",    "min": 80, "max": 250, "pay": 1.1 },
			{ "id": "haul_supply",  "text": "Run the supply crate out to the citadel", "min": 1, "max": 1,  "pay": 1.6 },
		],
	},
	"blacksmith": {
		"name": "Gabriel",
		"role": "Cosmic Blacksmith",
		"avatar": "res://assets/art/ui/cosmicTalyerAvatar.png",
		"tasks": [
			{ "id": "collect_gems",    "text": "Salvage %d gems out of the wrecks", "min": 20, "max": 50,  "pay": 1.2 },
			{ "id": "collect_shards",  "text": "Bring me %d cosmic shards",         "min": 50, "max": 100, "pay": 1.0 },
			{ "id": "collect_modules", "text": "Fit %d modules so I can see how they hold up", "min": 10, "max": 25, "pay": 1.4 },
		],
	},
	"nurse": {
		"name": "Mary Jane",
		"role": "CCC First Responder Head",
		"avatar": "res://assets/art/ui/nurseAvatar.png",
		"tasks": [
			{ "id": "haul_ship", "text": "Tow the medical ship back to the citadel", "min": 1, "max": 1, "pay": 1.7 },
		],
	},
	"polaroid": {
		"name": "Lorraine",
		"role": "Cosmic Polaroid Head",
		"avatar": "res://assets/art/ui/cosmicPolaroidAvatar.png",
		"tasks": [
			{ "id": "gauge_onscreen", "text": "Draw %d fiends on screen at once so I can shoot it", "min": 8, "max": 15, "pay": 1.5 },
		],
	},
	"guildmerc": {
		"name": "Cody",
		"role": "Mercenary Guild Leader",
		"avatar": "res://assets/art/ui/arthurAvatar.png",
		"tasks": [
			{ "id": "kill_boss",    "text": "Put down %d system bosses",                      "min": 1,  "max": 3,   "pay": 2.2 },
			{ "id": "kill_bomber",  "text": "Take out %d bombers before they reach the ring", "min": 20, "max": 60,  "pay": 1.4 },
			{ "id": "kill_slasher", "text": "Kill %d slashers, they are gutting our scouts",  "min": 20, "max": 60,  "pay": 1.4 },
			{ "id": "kill_chaser",  "text": "Run down %d chasers",                            "min": 40, "max": 120, "pay": 1.3 },
			{ "id": "kill_shooter", "text": "Silence %d shooters holding the corridor",       "min": 25, "max": 70,  "pay": 1.3 },
		],
	},
}

## Base payout bands, before the task's `pay` weight is applied. A contract
## pays in one or two of these, never all three, so the rewards read as
## distinct offers rather than one flat lump.
const REWARDS := {
	"cc":     { "label": "CC",     "min": 60, "max": 180 },
	"shards": { "label": "Shards", "min": 20, "max": 70  },
	"gems":   { "label": "Gems",   "min": 3,  "max": 14  },
}

## Chance a contract pays in two currencies rather than one.
const DOUBLE_REWARD_CHANCE := 0.35


## Rolls one offer. Returns a dictionary the panels can render directly:
## caller key, display name, role, avatar path, the goal line, a formatted
## reward line, and the machine readable parts the payout will eventually use.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var keys := CALLERS.keys()
	var caller_key: String = keys[rng.randi_range(0, keys.size() - 1)]
	return roll_for(caller_key, rng)


## Same, but from a named caller. Useful for scripted beats later on, and for
## testing one character's lane on its own.
static func roll_for(caller_key: String, rng: RandomNumberGenerator) -> Dictionary:
	var caller: Dictionary = CALLERS[caller_key]
	var tasks: Array = caller["tasks"]
	var task: Dictionary = tasks[rng.randi_range(0, tasks.size() - 1)]

	var amount := rng.randi_range(int(task["min"]), int(task["max"]))
	var goal: String = task["text"]
	# Tasks that are a single objective rather than a count carry no
	# placeholder, so only substitute when there is one to fill.
	if goal.contains("%d"):
		goal = goal % amount

	var parts := _roll_rewards(float(task["pay"]), rng)

	return {
		"caller": caller_key,
		"name": caller["name"],
		"role": caller["role"],
		"avatar": caller["avatar"],
		"task_id": task["id"],
		"amount": amount,
		"target": amount,     # what progress is measured against
		"progress": 0,
		"complete": false,
		"goal": goal,
		"reward": format_reward(parts),
		"reward_parts": parts,
	}


static func _roll_rewards(pay: float, rng: RandomNumberGenerator) -> Array:
	var kinds := REWARDS.keys()
	kinds.shuffle()
	var count := 2 if rng.randf() < DOUBLE_REWARD_CHANCE else 1

	var parts: Array = []
	for i in mini(count, kinds.size()):
		var kind: String = kinds[i]
		var band: Dictionary = REWARDS[kind]
		var value := rng.randi_range(int(band["min"]), int(band["max"])) * pay
		parts.append({ "kind": kind, "amount": maxi(1, int(round(value))) })
	return parts


## "180 CC + 40 Shards"
static func format_reward(parts: Array) -> String:
	var chunks: PackedStringArray = []
	for part in parts:
		var label: String = REWARDS.get(part["kind"], {}).get("label", part["kind"])
		chunks.append("%d %s" % [int(part["amount"]), label])
	return " + ".join(chunks)
