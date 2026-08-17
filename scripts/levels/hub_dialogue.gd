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
			{ "speaker": "receptionist", "text": "Welcome back, Toby. It's been a while since your last commission." },
			{ "speaker": "toby",         "text": "Yeah, I took quite a long break. Is there anything I can help with?" },
			{ "speaker": "receptionist", "text": "Yeah. We are in dire need of help since four solar systems, and including the citadel, are under attack." },
			{ "speaker": "toby",         "text": "What? I only heard it was the Flaschbourne System, I didn't know the attack has spread through the CCC" },
			{ "speaker": "receptionist", "text": "Yeah, it was quite the ambush." },
			{ "speaker": "receptionist", "text": "But uhm, between you and me, Toby. There's something fishy about this whole thing. Be careful out there, okay?" },
		],
		"The Commission thanks you for your continued service.\nThat's the official line. Personally? Nice work out there.",
		[
			{ "speaker": "receptionist", "text": "Sign here. And here. And... here." },
			{ "speaker": "toby",         "text": "What's the third one?" },
			{ "speaker": "receptionist", "text": "Waiver. Don't read it." },
		],
	],

	# Lorraine — Cosmic Polaroid Head. She documents the sector, so her interest
	# in fiends is professional rather than tactical.
	"polaroid": [
		[
			{ "speaker": "polaroid", "text": "My! My! If it isn't the great space cowboy themself! How have you been, Toby? It's good to see you!" },
			{ "speaker": "toby",     "text": "Lorraine! I've been doing good! I recently got attack in the Flaschbourne system though, but you know me! I got off there without a scratch... Except my ship." },
			{ "speaker": "polaroid", "text": "Oh my! I'm glad you made it out safely. Gabriel can easily buff that out, but don't be afraid of talking to Mary about your condition, okay?" },
			{ "speaker": "polaroid", "text": "Hehe, since the great space cowboy is here... I take it you're back to accepting commissions again?" },
			{ "speaker": "toby",     "text": "Oh you betcha!\nDon't worry, I'll be accepting your commissions again." },
			{ "speaker": "polaroid", "text": "Hehe. You know me so well. Talk to you later Toby!" },
		],
		[
			{ "speaker": "polaroid", "text": "Hold still, the light out here is awful." },
			{ "speaker": "toby",     "text": "There is no light out here." },
			{ "speaker": "polaroid", "text": "Exactly. It's very difficult work." },
		],
		"Nobody photographs the fiends up close. Nobody living, anyway.\nI'd like to change the second part.",
		[
			{ "speaker": "polaroid", "text": "I have four plates of a Squilltrant mid-split." },
			{ "speaker": "toby",     "text": "How close were you?" },
			{ "speaker": "polaroid", "text": "Close enough that there are only four." },
		],
		"The archive says the outer ring is empty.\nThe archive has never been to the outer ring.",
	],

	# Mary Jane — CCC First Responder Head. She runs the people who go in after
	# the shooting stops, so her lines are about the cost rather than the fight.
	"nurse": [
		"Sit. You're bleeding on my floor again.\nNo, don't apologise, just sit.",
		[
			{ "speaker": "nurse", "text": "Third patch job this week, pilot." },
			{ "speaker": "toby",  "text": "Fourth. You missed one." },
			{ "speaker": "nurse", "text": "I did not miss it. I chose not to write it down." },
		],
		"My teams go out after you lot are done.\nWe come back with fewer people than we left with, most days.",
		[
			{ "speaker": "nurse", "text": "You know what kills mercenaries? Not fiends." },
			{ "speaker": "toby",  "text": "Enlighten me." },
			{ "speaker": "nurse", "text": "Deciding they're fine. Every single time." },
		],
		"If the shield bar is empty, you are the shield.\nPlease stop being the shield.",
		[
			{ "speaker": "nurse", "text": "First Responders lost a shuttle at the ring." },
			{ "speaker": "toby",  "text": "...Anyone I know?" },
			{ "speaker": "nurse", "text": "Everyone knows everyone out here. That's the problem." },
		],
	],

	# Cody — Mercenary Guild Leader. He hands out the dangerous end of the
	# board and has been doing it long enough to be blunt about it.
	"guildmerc": [
		"Guild takes its cut whether you come back or not.\nCome back. It's better value.",
		[
			{ "speaker": "guildmerc", "text": "You're getting a reputation." },
			{ "speaker": "toby",      "text": "Good one?" },
			{ "speaker": "guildmerc", "text": "A loud one. Those pay the same." },
		],
		"Bosses aren't tougher than the swarm. They're just patient.\nThat's worse.",
		[
			{ "speaker": "guildmerc", "text": "I ran the Squilltrant line for nine years." },
			{ "speaker": "toby",      "text": "And now you run a desk." },
			{ "speaker": "guildmerc", "text": "And now I'm alive. Draw the line yourself." },
		],
		"Citadel says the perimeter is holding.\nCitadel says a lot of things from behind the perimeter.",
		[
			{ "speaker": "guildmerc", "text": "Turn down enough work and the board stops offering." },
			{ "speaker": "toby",      "text": "Is that a threat?" },
			{ "speaker": "guildmerc", "text": "It's arithmetic. Threats cost extra." },
		],
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
