extends Node2D

# The cosmic base village (stage 100) — tilemap-built hub level. Plays the
# village music, adds the pause menu, and wires each already-placed NPC's
# `interacted` signal to its hub menu or a chat popup.

const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")

@onready var _ui: HubUI = $HubUI
@onready var toby: CharacterBody2D = $Toby

func _ready() -> void:
	GameManager.start_session(100)
	AudioManager.play_music("cosmicVillage")

	add_child(PauseMenuScene.instantiate())

	# Receptionist — a short Chesca/Toby exchange, then the CCC level selection
	$Receptionist.interacted.connect(_on_receptionist_interact)

	# Guards rotate through their dialogue banks (HubDialogue) so a second
	# visit isn't the same line back at you.
	$Guard1.interacted.connect(func(): _say("guard1"))
	$Guard2.interacted.connect(func(): _say("guard2"))

	# Cosmic Trader — a word from Princess, then the trade board
	$Trader.interacted.connect(func(): _say_then("trader", _ui.open_merchant))

	# Blacksmith Gabriel — a word from him, then ship status / loadout
	$Blacksmith.interacted.connect(func(): _say_then("blacksmith", _ui.open_blacksmith))

	$Polaroid.interacted.connect(func(): _ui.open_dialogue("polaroid",
		"Say cheese! One day I'll photograph every corner of the cosmos.\nEven the scary ones."))

	# Nurse Mary Jane — infirmary (heals, then chats)
	$Nurse.interacted.connect(func(): _ui.open_infirmary())

	$GuildMerc.interacted.connect(func(): _ui.open_dialogue("guildmerc",
		"The guild board's empty today.\nCheck back later, bounties are coming."))

	if GameManager.last_talked_to == "receptionist":
		toby.position = Vector2(0, -390)
		GameManager.last_talked_to == ""

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
	var lines := HubDialogue.next_lines("receptionist")
	lines.append_array([
		{ "speaker": "receptionist", "text": "Looking for work, pilot?" },
		{ "speaker": "toby",         "text": "Always. What's on the board?" },
		{ "speaker": "receptionist", "text": "Pulling up the cluster map now.\nPick your system and I'll file the contract." },
	])
	var dlg: DialoguePanel = _ui.open_sequence(lines)
	dlg.closed.connect(func(): GameManager.goto_level_select(), CONNECT_ONE_SHOT)
