extends CanvasLayer
class_name BlacksmithPanel

# Ship Status — equip weapons & skills. Chrome (backdrop, close button,
# title, two scrolling columns) lives in scenes/ui/panels/blacksmith_panel.tscn;
# this script duplicates the row templates per owned/locked item.

signal closed

const WEAPON_SHEET := preload("res://assets/art/ui/weaponArray.png")
const SKILL_SHEET  := preload("res://assets/art/ui/skillArray.png")

const WEAPONS := {
	1: { "name": "Laser",            "desc": "Your typical laser cannon" },
	2: { "name": "Plasma Ball",      "desc": "Big scorching plasma ball" },
	3: { "name": "Comet",            "desc": "Icey comet" },
	4: { "name": "Light Wave",       "desc": "Releases a crescent-shaped wave" },
	5: { "name": "Halfmoon Slash",   "desc": "Close combat slash" },
	6: { "name": "Dash Slash",       "desc": "Your ship is the blade" },
	7: { "name": "Shield Generator", "desc": "Tanks 1 Hit" },
}

const SKILLS := {
	1: { "name": "Burst Projectile",  "desc": "Release Outbursts of Projectiles" },
	2: { "name": "Shockwave",         "desc": "Releases a huge shockwave that covers the screen" },
	3: { "name": "Energy Overdrive",  "desc": "Overdrive your cannons" },
	4: { "name": "Electric Shock",    "desc": "Releases a huge electric wave that covers the screen" },
	5: { "name": "Purple",            "desc": "Purple plasma across the screen" },
	6: { "name": "Giant Beam",        "desc": "Huge beam laser" },
	7: { "name": "Invincible Frames", "desc": "Ignore any damage for a few seconds" },
}

@onready var _close_btn: TextureButton   = $Root/Frame/CloseButton
@onready var _weapon_list: VBoxContainer = $Root/Frame/Margin/Content/Scroll/Columns/WeaponsCol/List
@onready var _skill_list: VBoxContainer  = $Root/Frame/Margin/Content/Scroll/Columns/SkillsCol/List
@onready var _weapon_row_t: PanelContainer = $Root/Frame/Margin/Content/Scroll/Columns/WeaponsCol/List/RowTemplate
@onready var _skill_row_t: PanelContainer  = $Root/Frame/Margin/Content/Scroll/Columns/SkillsCol/List/RowTemplate


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	visible = false
	_weapon_row_t.visible = false
	_skill_row_t.visible = false
	_close_btn.pressed.connect(close)


func open() -> void:
	visible = true
	AudioManager.play_sfx("pickedMode1")
	_rebuild()


func close() -> void:
	visible = false
	closed.emit()


func _rebuild() -> void:
	for c in _weapon_list.get_children():
		if c != _weapon_row_t:
			c.queue_free()
	for c in _skill_list.get_children():
		if c != _skill_row_t:
			c.queue_free()

	var eq: Dictionary = SaveManager.equipped_data

	for id in WEAPONS:
		var owned: bool = SaveManager.weapon_data.get("w%dvalue" % id, false)
		var tag := ""
		if int(eq.get("weapon1Slot", 1)) == id:
			tag += " [W1]"
		if int(eq.get("weapon2Slot", 1)) == id:
			tag += " [W2]"

		var row: PanelContainer = _weapon_row_t.duplicate()
		row.visible = true
		_weapon_list.add_child(row)

		var icon: TextureRect = row.get_node("HBox/Icon")
		var atlas := AtlasTexture.new()
		atlas.atlas = WEAPON_SHEET
		@warning_ignore("integer_division")
		atlas.region = Rect2(((id - 1) % 3) * 128, ((id - 1) / 3) * 128, 128, 128)
		icon.texture = atlas

		row.get_node("HBox/TextCol/NameLabel").text = "%s [%d/7]%s" % [WEAPONS[id]["name"], id, tag]
		row.get_node("HBox/TextCol/DescLabel").text = WEAPONS[id]["desc"]

		var w1: Button = row.get_node("HBox/W1Button")
		var w2: Button = row.get_node("HBox/W2Button")
		var locked: Label = row.get_node("HBox/LockedLabel")
		if owned:
			w1.visible = true
			w2.visible = true
			locked.visible = false
			w1.pressed.connect(_equip_weapon.bind(id, true))
			w2.pressed.connect(_equip_weapon.bind(id, false))
		else:
			w1.visible = false
			w2.visible = false
			locked.visible = true
			row.get_node("HBox/TextCol/NameLabel").modulate = Color(0.45, 0.45, 0.45)
			row.get_node("HBox/TextCol/DescLabel").modulate = Color(0.4, 0.4, 0.45)

	for id in SKILLS:
		var owned: bool = SaveManager.skill_data.get("s%dvalue" % id, false)
		var tag := "  [EQUIPPED]" if int(eq.get("skillSlot", 1)) == id else ""

		var row: PanelContainer = _skill_row_t.duplicate()
		row.visible = true
		_skill_list.add_child(row)

		var icon: TextureRect = row.get_node("HBox/Icon")
		var atlas := AtlasTexture.new()
		atlas.atlas = SKILL_SHEET
		@warning_ignore("integer_division")
		atlas.region = Rect2(((id - 1) % 3) * 128, ((id - 1) / 3) * 128, 128, 128)
		icon.texture = atlas

		row.get_node("HBox/TextCol/NameLabel").text = "%s [%d/7]%s" % [SKILLS[id]["name"], id, tag]
		row.get_node("HBox/TextCol/DescLabel").text = SKILLS[id]["desc"]

		var equip_btn: Button = row.get_node("HBox/EquipButton")
		var locked: Label = row.get_node("HBox/LockedLabel")
		if owned:
			equip_btn.visible = true
			locked.visible = false
			equip_btn.pressed.connect(_equip_skill.bind(id))
		else:
			equip_btn.visible = false
			locked.visible = true
			row.get_node("HBox/TextCol/NameLabel").modulate = Color(0.45, 0.45, 0.45)
			row.get_node("HBox/TextCol/DescLabel").modulate = Color(0.4, 0.4, 0.45)


func _equip_weapon(id: int, primary: bool) -> void:
	if primary:
		SaveManager.equipped_data["weapon1Slot"] = id
	else:
		SaveManager.equipped_data["weapon2Slot"] = id
	SaveManager.save_equipped_data()
	AudioManager.play_sfx("switchWeapon")
	_refresh_player_loadout()
	_rebuild()


func _equip_skill(id: int) -> void:
	SaveManager.equipped_data["skillSlot"] = id
	SaveManager.save_equipped_data()
	AudioManager.play_sfx("switchWeapon")
	_refresh_player_loadout()
	_rebuild()


func _refresh_player_loadout() -> void:
	var players := get_tree().get_nodes_in_group("friendlies")
	if players.is_empty():
		return
	var player = players[0]
	var ws = player.get_node_or_null("WeaponSystem")
	if ws:
		ws.primary_weapon = int(SaveManager.equipped_data.get("weapon1Slot", 1))
		ws.secondary_weapon = int(SaveManager.equipped_data.get("weapon2Slot", 1))
	var ms = player.get_node_or_null("ModuleSystem")
	if ms:
		ms.skill_slot = int(SaveManager.equipped_data.get("skillSlot", 1))
