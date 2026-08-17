extends Node2D

# The cosmic base village (stage 100) — tilemap-built hub level. Plays the
# village music, adds the pause menu, and wires each already-placed NPC's
# `interacted` signal to its hub menu or a chat popup.

const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")

@onready var _ui: HubUI = $HubUI
@onready var toby: CharacterBody2D = $Toby

func _ready() -> void:
	GameManager.start_session(100)
	AudioManager.play_music("cosmicLobby2Music")

	add_child(PauseMenuScene.instantiate())

	# Receptionist — a short Chesca/Toby exchange, then the CCC level selection
	$Receptionist.interacted.connect(_on_receptionist_interact)

	_wire_npcs()
	_seed_objectives()

	if GameManager.last_talked_to == "receptionist":
		toby.position = Vector2(0, -390)
		GameManager.last_talked_to == ""

## The narrative steps the hub asks of you, in the order they should be worked
## through. Seeded every time the hub loads; GameManager ignores ones already
## listed, so a step ticked off before a mission stays ticked off after it.
##
## Placeholder content for now: the story beats slot in here later, and the
## panel picks them up with no further wiring.
const HUB_OBJECTIVES := [
	{ "id": "talk_chesca", "text": "Report in to Chesca at the reception desk" },
	{ "id": "talk_guildmerc", "text": "Ask Cody what the guild board is paying" },
	{ "id": "talk_blacksmith", "text": "Have Gabriel look over the hull" },
	{ "id": "talk_nurse", "text": "Get patched up by Mary Jane" },
	{ "id": "talk_polaroid", "text": "See what Lorraine has been photographing" },
	{ "id": "talk_trader", "text": "Check Princess's stock at the trade board" },
]

## Talking to someone ticks their step off. Keyed by dialogue bank name so it
## lines up with SPEAKER_PREFIXES below.
const OBJECTIVE_FOR_SPEAKER := {
	"receptionist": "talk_chesca",
	"guildmerc": "talk_guildmerc",
	"blacksmith": "talk_blacksmith",
	"nurse": "talk_nurse",
	"polaroid": "talk_polaroid",
	"trader": "talk_trader",
}


func _seed_objectives() -> void:
	for step in HUB_OBJECTIVES:
		GameManager.add_objective(str(step["id"]), str(step["text"]))


## NPC name prefix -> which dialogue bank they speak from. Matched by PREFIX,
## not by exact node name, so a second copy of someone placed in the hub
## ("Nurse2", "GuildMerc3") is wired up automatically. Wiring by exact name is
## what left the newly added Nurse2 and GuildMerc2 standing there mute.
const SPEAKER_PREFIXES := {
	"Guard1": "guard1",
	"Guard2": "guard2",
	"Trader": "trader",
	"Blacksmith": "blacksmith",
	"Polaroid": "polaroid",
	"Nurse": "nurse",
	"GuildMerc": "guildmerc",
}

## The two who open a shop panel after their line. Everyone else just talks.
const SHOPKEEPERS := { "trader": "open_merchant", "blacksmith": "open_blacksmith" }


func _wire_npcs() -> void:
	for child in get_children():
		if not child is NpcBase:
			continue
		var speaker := _speaker_for(str(child.name))
		if speaker == "":
			continue

		if SHOPKEEPERS.has(speaker):
			var opener := Callable(_ui, SHOPKEEPERS[speaker])
			child.interacted.connect(func():
				_touch_objective(speaker)
				_say_then(speaker, opener))
		elif speaker == "nurse":
			# Mary Jane patches the ship up, then talks. The heal is
			# unconditional; the conversation rotates like everyone else's.
			child.interacted.connect(func():
				_touch_objective("nurse")
				_ui.heal_player()
				_say("nurse"))
		else:
			child.interacted.connect(func():
				_touch_objective(speaker)
				_say(speaker))


## Ticks a character's narrative step off. Called from the interaction itself
## rather than from _say, because a shopkeeper with nothing new to say skips
## the dialogue entirely and goes straight to their panel.
func _touch_objective(speaker: String) -> void:
	if OBJECTIVE_FOR_SPEAKER.has(speaker):
		GameManager.complete_objective(str(OBJECTIVE_FOR_SPEAKER[speaker]))


## Longest prefix wins, so "Guard1" is never mistaken for a "Guard" bank.
func _speaker_for(node_name: String) -> String:
	var best := ""
	var best_len := 0
	for prefix in SPEAKER_PREFIXES:
		if node_name.begins_with(prefix) and prefix.length() > best_len:
			best = SPEAKER_PREFIXES[prefix]
			best_len = prefix.length()
	return best


## Flavour NPCs: one conversation per contract. Once they've had their say
## they've got nothing left until you've been out and finished a run.
func _say(speaker: String) -> DialoguePanel:
	var lines := HubDialogue.next_lines(speaker)
	if lines.is_empty():
		lines = HubDialogue.exhausted_line(speaker)
	return _ui.open_sequence(lines)


## Shopkeepers: a line the first time each contract, straight to business
## after that. Never a dead end — the panel always opens either way.
func _say_then(speaker: String, open_panel: Callable) -> void:
	if not HubDialogue.has_fresh_line(speaker):
		open_panel.call()
		return
	var dlg := _say(speaker)
	dlg.closed.connect(func(): open_panel.call(), CONNECT_ONE_SHOT)


## Chesca opens with her line for this contract if she still has one, then
## always ends on the pitch that sends the player to the cluster map.
func _on_receptionist_interact() -> void:
	_touch_objective("receptionist")
	var lines := HubDialogue.next_lines("receptionist")
	lines.append_array([
		{ "speaker": "receptionist", "text": "Looking for work, pilot?" },
		{ "speaker": "toby",         "text": "Always. What's on the board?" },
		{ "speaker": "receptionist", "text": "Pulling up the cluster map now.\nPick your system and I'll file the contract." },
	])
	var dlg: DialoguePanel = _ui.open_sequence(lines)
	dlg.closed.connect(func(): GameManager.goto_level_select(), CONNECT_ONE_SHOT)
