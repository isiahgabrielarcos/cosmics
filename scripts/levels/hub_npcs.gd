extends Node2D

# Wires each hub NPC's `interacted` signal to its hub menu or a chat popup.
# The NPCs themselves are scene instances under this node (scenes/npcs/*.tscn)
# — drag them in the editor to reposition, no code changes needed.

@export var hub_ui_path: NodePath

var _ui: HubUI


func _ready() -> void:
	_ui = get_node_or_null(hub_ui_path) as HubUI
	if _ui == null:
		push_error("HubNPCs: hub_ui_path not assigned")
		return

	# Central Cosmic Commission receptionist — mission board
	$Receptionist.interacted.connect(func(): _ui.open_ccc())

	# Guards flanking the CCC desk
	$Guard1.interacted.connect(func(): _ui.open_dialogue("guard1",
		"The Commission desk is right up there.\nStay out of trouble, pilot."))

	$Guard2.interacted.connect(func(): _ui.open_dialogue("guard2",
		"Heard the fiends are getting bolder out there.\nGood thing you're on our side."))

	# Cosmic Trader — merchant shop
	$Trader.interacted.connect(func(): _ui.open_merchant())

	# Blacksmith Talyer — equipment
	$Blacksmith.interacted.connect(func(): _ui.open_blacksmith())

	# Polaroid — flavor
	$Polaroid.interacted.connect(func(): _ui.open_dialogue("polaroid",
		"Say cheese! One day I'll photograph every corner of the cosmos.\nEven the scary ones."))

	# Nurse — infirmary
	$Nurse.interacted.connect(func(): _ui.open_infirmary())

	# Guild Merc — quests (coming later)
	$GuildMerc.interacted.connect(func(): _ui.open_dialogue("guildmerc",
		"The guild board's empty today.\nCheck back later — bounties are coming."))
