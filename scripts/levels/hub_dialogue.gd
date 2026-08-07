extends Node
class_name HubDialogue

# Dialogue banks for the hub NPCs, so talking to someone twice doesn't replay
# the same line. Each character has a list of entries; an entry is either a
# single line (String) or a back-and-forth sequence (Array of
# { speaker, text }) for the ones who talk with Toby.
#
# Entries are handed out in order and wrap around, so a player who keeps
# talking hears the whole bank before anything repeats. The cursor lives on
# GameManager, which means it resets with the save session rather than every
# time the hub scene reloads after a mission.

const BANKS := {
	"blacksmith": [
		"Ship Status is through here. Bring me shards and I'll bolt on\nsomething that keeps you breathing.",
		"Every weapon in that rack has killed something.\nMost of them have killed someone who owned it first.",
		[
			{ "speaker": "blacksmith", "text": "You keep bringing that hull back scratched." },
			{ "speaker": "toby",       "text": "Better scratched than scattered." },
			{ "speaker": "blacksmith", "text": "...Fair. Sit down, I'll buff it out." },
		],
		"Word of advice: a bigger gun won't save you from bad positioning.\nBut it does help.",
		[
			{ "speaker": "blacksmith", "text": "The Commission rates my work 'adequate'." },
			{ "speaker": "toby",       "text": "That's the highest rating they give." },
			{ "speaker": "blacksmith", "text": "I know. I framed it." },
		],
	],

	"guard1": [
		"The Commission desk is right up there.\nStay out of trouble, pilot.",
		"Quiet shift. I'd like to keep it that way,\nso don't go starting anything in my station.",
		"You know how many mercs walk back through that door?\nFewer than walk out. Mind yourself.",
		[
			{ "speaker": "guard1", "text": "You're the one who took the Frokenvinter contract." },
			{ "speaker": "toby",   "text": "Somebody had to." },
			{ "speaker": "guard1", "text": "Somebody did. Three somebodies, actually.\nYou're the one who came back." },
		],
		"Eveland says you're reckless. I said you're employed.\nBoth can be true.",
	],

	"guard2": [
		"Heard the fiends are getting bolder out there.\nGood thing you're on our side.",
		"They moved the perimeter beacons in again last night.\nThat's twice this month. Draw your own conclusions.",
		"Julie thinks I worry too much.\nJulie has never been outside the ring.",
		[
			{ "speaker": "guard2", "text": "Do you ever get used to it? The black?" },
			{ "speaker": "toby",   "text": "No. You just stop flinching." },
			{ "speaker": "guard2", "text": "...I'll stick to the door, thanks." },
		],
		"If the alarms go off, get behind me.\nI've been practising looking brave.",
	],

	# Chesca — the receptionist. Her bank is the pre-contract chatter; the
	# scripted "pull up the cluster map" exchange stays in cosmic_hub.gd.
	"receptionist": [
		[
			{ "speaker": "receptionist", "text": "Back already? The paperwork isn't even dry." },
			{ "speaker": "toby",         "text": "I work fast." },
			{ "speaker": "receptionist", "text": "You work *loud*. There's a difference,\nand I file complaints about one of them." },
		],
		"The Commission thanks you for your continued service.\nThat's the official line. Personally? Nice work out there.",
		[
			{ "speaker": "receptionist", "text": "Sign here. And here. And... here." },
			{ "speaker": "toby",         "text": "What's the third one?" },
			{ "speaker": "receptionist", "text": "Waiver. Don't read it." },
		],
		"Between us — the good contracts never make it to the board.\nKeep asking anyway.",
		"You still owe the guild for that station you found her in.\nSalvage rules are salvage rules.",
	],

	# Princess — the Central Trader Associate at the trade board.
	"trader": [
		"Everything's for sale. Some of it's even mine.",
		[
			{ "speaker": "trader", "text": "Gems up front, no credit, no exceptions." },
			{ "speaker": "toby",   "text": "You said that last time." },
			{ "speaker": "trader", "text": "And you paid last time. See how well it works?" },
		],
		"The Union sets the prices. I just smile while I read them out.",
		"Buy the skill before the weapon. Weapons run out of ammo.\nSkills run out of patience, which is slower.",
		[
			{ "speaker": "trader", "text": "You've been eyeing that one for three visits." },
			{ "speaker": "toby",   "text": "I'm building up to it." },
			{ "speaker": "trader", "text": "Build faster. Someone else is eyeing it too." },
		],
	],
}


## True while `speaker` still has something new to say this gameplay loop.
static func has_fresh_line(speaker: String) -> bool:
	return BANKS.has(speaker) and not GameManager.dialogue_spent.get(speaker, false)


## Next entry for `speaker`, as a sequence ready for DialoguePanel — and marks
## them spoken-to for this loop. One conversation per contract: the bank only
## advances when a run actually reaches an end screen, so backing out of a
## mission can't be used to farm through everyone's lines.
##
## Returns an empty Array if they have no bank or nothing new this loop; call
## has_fresh_line() first if you need to branch on that.
static func next_lines(speaker: String) -> Array:
	if not has_fresh_line(speaker):
		return []
	var bank: Array = BANKS[speaker]
	if bank.is_empty():
		return []

	var index: int = int(GameManager.dialogue_cursor.get(speaker, 0))
	GameManager.dialogue_cursor[speaker] = (index + 1) % bank.size()
	GameManager.dialogue_spent[speaker] = true

	var entry = bank[index]
	if entry is String:
		return [{ "speaker": speaker, "text": entry }]
	return entry


## What a non-essential NPC says once they've already had their say.
static func exhausted_line(speaker: String) -> Array:
	return [{ "speaker": speaker, "text": ". . ." }]
