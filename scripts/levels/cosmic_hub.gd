extends Node2D

# The cosmic base village (stage 100) — tilemap-built hub level. Plays the
# village music, adds the pause menu, and wires each already-placed NPC's
# `interacted` signal to its hub menu or a chat popup.

const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")

@onready var _ui: HubUI = $HubUI


func _ready() -> void:
	GameManager.start_session(100)
	AudioManager.play_music("cosmicVillage")

	add_child(PauseMenuScene.instantiate())

	# Receptionist — a short Chesca/Toby exchange, then the CCC level selection
	$Receptionist.interacted.connect(_on_receptionist_interact)

	$Guard1.interacted.connect(func(): _ui.open_dialogue("guard1",
		"The Commission desk is right up there.\nStay out of trouble, pilot."))

	$Guard2.interacted.connect(func(): _ui.open_dialogue("guard2",
		"Heard the fiends are getting bolder out there.\nGood thing you're on our side."))

	# Cosmic Trader — trade board
	$Trader.interacted.connect(func(): _ui.open_merchant())

	# Blacksmith Gabriel — ship status / loadout
	$Blacksmith.interacted.connect(func(): _ui.open_blacksmith())

	$Polaroid.interacted.connect(func(): _ui.open_dialogue("polaroid",
		"Say cheese! One day I'll photograph every corner of the cosmos.\nEven the scary ones."))

	# Nurse Mary Jane — infirmary (heals, then chats)
	$Nurse.interacted.connect(func(): _ui.open_infirmary())

	$GuildMerc.interacted.connect(func(): _ui.open_dialogue("guildmerc",
		"The guild board's empty today.\nCheck back later — bounties are coming."))


func _on_receptionist_interact() -> void:
	var dlg: DialoguePanel = _ui.open_sequence([
		{ "speaker": "receptionist", "text": "Looking for work, pilot?" },
		{ "speaker": "toby",         "text": "Always. What's on the board?" },
		{ "speaker": "receptionist", "text": "Pulling up the cluster map now.\nPick your system and I'll file the contract." },
	])
	dlg.closed.connect(func(): GameManager.goto_level_select(), CONNECT_ONE_SHOT)
