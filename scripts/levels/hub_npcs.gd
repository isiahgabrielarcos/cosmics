extends Node2D

# Ports cosmicNPCs() — spawns the village NPCs at their original positions
# (g = 64) and wires each one to its hub menu or a chat popup.
# allNPCSprite.png frame starts (0-based): receptionist 0 · guard1 4 · guard2 8 ·
# blacksmith 16 · trader 20 · polaroid 24 · nurse 28 · merc 32

const G := 64.0

@export var hub_ui_path: NodePath

var _ui: HubUI


func _ready() -> void:
	_ui = get_node_or_null(hub_ui_path) as HubUI
	if _ui == null:
		push_error("HubNPCs: hub_ui_path not assigned")
		return

	# Central Cosmic Commission receptionist — mission board (top middle)
	_npc({ "name": "Receptionist", "start_frame": 0, "position": Vector2(0, -12 * G),
		"interact_radius": 195.0 },
		func(): _ui.open_ccc())

	# Guards flanking the CCC desk
	_npc({ "name": "Guard1", "start_frame": 4, "fps": 3.0, "position": Vector2(7 * G, -9 * G),
		"solid": true },
		func(): _ui.open_dialogue("CCC Guard", "guard1",
			"The Commission desk is right up there.\nStay out of trouble, pilot."))

	_npc({ "name": "Guard2", "start_frame": 8, "fps": 3.75, "position": Vector2(-7 * G, -9 * G),
		"solid": true },
		func(): _ui.open_dialogue("CCC Guard", "guard2",
			"Heard the fiends are getting bolder out there.\nGood thing you're on our side."))

	# Cosmic Trader — merchant shop (top left)
	_npc({ "name": "Trader", "start_frame": 20, "position": Vector2(-13 * G, -14 * G),
		"solid": true },
		func(): _ui.open_merchant())

	# Blacksmith Talyer — equipment (top right)
	_npc({ "name": "Blacksmith", "start_frame": 16, "position": Vector2(13 * G, -14 * G),
		"solid": true },
		func(): _ui.open_blacksmith())

	# Polaroid — flavor
	_npc({ "name": "Polaroid", "start_frame": 24, "position": Vector2(4 * G, -3 * G),
		"solid": true },
		func(): _ui.open_dialogue("Cosmic Polaroid", "polaroid",
			"Say cheese! One day I'll photograph every corner of the cosmos.\nEven the scary ones."))

	# Nurse — infirmary (left wing)
	_npc({ "name": "Nurse", "start_frame": 28, "position": Vector2(-24 * G, -8 * G) },
		func(): _ui.open_infirmary())

	# Guild Merc — quests (right wing, coming later)
	_npc({ "name": "GuildMerc", "start_frame": 32, "position": Vector2(23.75 * G, -8 * G) },
		func(): _ui.open_dialogue("Guild Mercenary", "girl",
			"The guild board's empty today.\nCheck back later — bounties are coming."))


func _npc(cfg: Dictionary, on_interact: Callable) -> void:
	var npc := NpcBase.create(cfg)
	add_child(npc)
	npc.interacted.connect(on_interact)
