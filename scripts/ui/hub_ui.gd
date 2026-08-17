extends CanvasLayer
class_name HubUI

# Hub menu orchestrator. Each panel's static layout is its own scene under
# scenes/ui/panels/ (ccc_panel.tscn, blacksmith_panel.tscn, merchant_panel.tscn,
# dialogue_panel.tscn) so they can be finetuned in the editor — this script
# only opens/closes them and keeps GameManager.ui_open / pause state in sync.
# Press I anywhere in the hub to open the inventory (blacksmith screen).

@onready var _ccc: CccPanel               = $CccPanel
@onready var _blacksmith: BlacksmithPanel = $BlacksmithPanel
@onready var _merchant: MerchantPanel     = $MerchantPanel
@onready var _dialogue: DialoguePanel     = $DialoguePanel

var _active: CanvasLayer = null


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS

	for panel in [_ccc, _blacksmith, _merchant, _dialogue]:
		panel.closed.connect(_on_panel_closed)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.ui_open and _active:
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			close_panel()
	elif event.is_action_pressed("inventory") and not GameManager.game_paused:
		open_blacksmith()


func close_panel() -> void:
	if _active:
		_active.close()
		_active = null
	if GameManager.ui_open:
		GameManager.ui_open = false
		GameManager.resume_game()


func _on_panel_closed() -> void:
	_active = null
	if GameManager.ui_open:
		GameManager.ui_open = false
		GameManager.resume_game()


func _begin(panel: CanvasLayer) -> void:
	close_panel()
	GameManager.ui_open = true
	GameManager.pause_game()
	_active = panel


func open_ccc() -> void:
	_begin(_ccc)
	_ccc.open()


func open_blacksmith() -> void:
	_begin(_blacksmith)
	_blacksmith.open()


func open_merchant() -> void:
	_begin(_merchant)
	_merchant.open()


## speaker must be a key in DialoguePanel.CHARACTERS (its name/role/avatar
## are looked up automatically, callers only ever pass the key and the line).
func open_dialogue(speaker: String, text: String) -> DialoguePanel:
	_begin(_dialogue)
	_dialogue.open(speaker, text)
	return _dialogue


## Multi-stage, multi-speaker conversation — see DialoguePanel.open_sequence.
func open_sequence(lines: Array) -> DialoguePanel:
	_begin(_dialogue)
	_dialogue.open_sequence(lines)
	return _dialogue


## Patches the ship back to full. Split out from open_infirmary so the nurse
## can heal and then run her normal rotating dialogue, rather than being stuck
## with one fixed line forever.
## The hub's Toby is toby_overworld.gd, which is a walking sprite with no
## health at all — only the ship carries hp and shield. Calling this in the
## hub used to throw on every single interaction because it assumed the ship.
## Guarded rather than removed: the heal still lands whenever a body that
## actually has those stats is the one in the friendlies group.
func heal_player() -> void:
	var players := get_tree().get_nodes_in_group("friendlies")
	if players.is_empty():
		return
	var player = players[0]
	if "max_hp" in player:
		player.hp = player.max_hp
		if player.has_signal("hp_changed"):
			player.hp_changed.emit(player.hp, player.max_hp)
	if "max_shield" in player:
		player.shield = player.max_shield
		if player.has_signal("shield_changed"):
			player.shield_changed.emit(player.shield, player.max_shield)


## Nurse — heals the ship and chats. Kept for hub_scene.gd, which still wires
## the nurse straight to it.
func open_infirmary() -> void:
	heal_player()
	open_dialogue("nurse",
		"There you go — patched up and good as new!\nTry not to get shot so much out there, okay?")
