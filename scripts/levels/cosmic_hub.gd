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

	# Receptionist — sends the player straight to the testing area on close
	$Receptionist.interacted.connect(_on_receptionist_interact)

	$Guard1.interacted.connect(func(): _ui.open_dialogue("CCC Guard", "guard1",
		"The Commission desk is right up there.\nStay out of trouble, pilot."))

	$Guard2.interacted.connect(func(): _ui.open_dialogue("CCC Guard", "guard2",
		"Heard the fiends are getting bolder out there.\nGood thing you're on our side."))

	$Trader.interacted.connect(func(): _ui.open_dialogue("Cosmic Trader", "trader",
		"Welcome to the Trade Board!\nCome back soon — I'll have wares ready for you."))

	$Blacksmith.interacted.connect(func(): _ui.open_dialogue("Blacksmith Talyer", "blacksmith",
		"The forge is hot and ready.\nBring me some shards and we'll see what we can do."))

	$Polaroid.interacted.connect(func(): _ui.open_dialogue("Cosmic Polaroid", "polaroid",
		"Say cheese! One day I'll photograph every corner of the cosmos.\nEven the scary ones."))

	$Nurse.interacted.connect(func(): _ui.open_dialogue("Nurse", "nurse",
		"Rest up, pilot. The infirmary is open whenever you need it.\nDon't push yourself too hard out there."))

	$GuildMerc.interacted.connect(func(): _ui.open_dialogue("Guild Mercenary", "girl",
		"The guild board's empty today.\nCheck back later — bounties are coming."))


func _on_receptionist_interact() -> void:
	var dlg: DialoguePanel = _ui.open_dialogue("Receptionist", "receptionist",
		"Ready to head out, pilot?\nI'll patch you through to the testing area now.")
	dlg.closed.connect(func(): GameManager.goto_battle(), CONNECT_ONE_SHOT)
