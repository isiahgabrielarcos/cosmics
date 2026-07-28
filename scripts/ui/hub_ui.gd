extends CanvasLayer
class_name HubUI

# Hub menus built from the original Solar2D UI art:
#   cosmicGameMode.png backdrop · gamemodeMenu.png card buttons · close.png ·
#   acceptCard/rejectCard · weaponArray/skillArray/enemySystems icon sheets ·
#   chatBox.png dialogue box (dialogue.lua layout).
# Press I anywhere in the hub to open the inventory (blacksmith equip screen).

const RETRO_FONT := preload("res://assets/fonts/RetroGaming.ttf")

const BACKDROP_TEX := preload("res://assets/art/ui/cosmicGameMode.png")
const CARD_TEX     := preload("res://assets/art/ui/gamemodeMenu.png")
const CLOSE_TEX    := preload("res://assets/art/ui/close.png")
const ACCEPT_TEX   := preload("res://assets/art/ui/acceptCard.png")
const REJECT_TEX   := preload("res://assets/art/ui/rejectCard.png")
const CHATBOX_TEX  := preload("res://assets/art/ui/chatBox.png")
const WEAPON_SHEET := preload("res://assets/art/ui/weaponArray.png")
const SKILL_SHEET  := preload("res://assets/art/ui/skillArray.png")
const SYSTEM_SHEET := preload("res://assets/art/ui/enemySystems.png")
const TRADER_SHEET := preload("res://assets/art/ui/traderBuyAndSell.png")

# Original names + descriptions from showBlacksmithTable / whatMode
const WEAPONS := {
	1: { "name": "Laser",           "desc": "Your typical laser cannon" },
	2: { "name": "Plasma Ball",     "desc": "Big scorching plasma ball" },
	3: { "name": "Comet",           "desc": "Icey comet" },
	4: { "name": "Light Wave",      "desc": "Releases a crescent-shaped wave" },
	5: { "name": "Halfmoon Slash",  "desc": "Close combat slash" },
	6: { "name": "Dash Slash",      "desc": "Your ship is the blade" },
	7: { "name": "Shield Generator","desc": "Tanks 1 Hit" },
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

# Mission list from showGameMode (createAttackGroup systems table)
const MISSIONS := [
	{ "stage": 0,  "icon": 4, "name": "Random Solar System",
		"desc": "Randomly picks a solar system for you to invade" },
	{ "stage": 1,  "icon": 0, "name": "FlaschBourn Feiry Solar System",
		"desc": "A fairly normal solar system filled with space soaring aliens" },
	{ "stage": 2,  "icon": 1, "name": "Stroggholl C137 Solar System",
		"desc": "An abandoned dyson sphere. Rogue aliens, high bounty criminals. Pure anarchy" },
	{ "stage": 3,  "icon": 2, "name": "Frokenvinter Glazing Solar System",
		"desc": "A blazing solar system filled with rogue comets and heavy aliens" },
	{ "stage": 4,  "icon": 3, "name": "Squilltrant Slime Solar System",
		"desc": "A dwarf solar system filled with both heavy and fast aliens" },
	{ "stage": 21, "icon": 5, "name": "The Endless Void",
		"desc": "Survive as long as you can. The fiends never stop coming" },
]

const WEAPON_PRICES := { 2: 300, 3: 500, 4: 800, 5: 1200, 6: 1600, 7: 2000 }
const SKILL_PRICES  := { 2: 50, 3: 75, 4: 100, 5: 150, 6: 200, 7: 300 }

const AVATARS := {
	"receptionist": "res://assets/art/ui/receptionistAvatar.png",
	"guard1":       "res://assets/art/ui/guard1Avatar.png",
	"guard2":       "res://assets/art/ui/guard2Avatar.png",
	"trader":       "res://assets/art/ui/cosmicTraderAvatar.png",
	"blacksmith":   "res://assets/art/ui/cosmicTalyerAvatar.png",
	"polaroid":     "res://assets/art/ui/cosmicPolaroidAvatar.png",
	"nurse":        "res://assets/art/ui/nurseAvatar.png",
	"girl":         "res://assets/art/ui/mysteriousGirlAvatar.png",
}

var _root: Control = null
var _selected_stage: int = 1
var _selected_difficulty: String = "normal"


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.ui_open and _root:
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			close_panel()
	elif event.is_action_pressed("inventory") and not GameManager.game_paused:
		open_blacksmith()


# ── Panel plumbing (cosmicGameMode backdrop + close button) ────────────────────

func _open_panel(title_text: String) -> VBoxContainer:
	close_panel()
	GameManager.ui_open = true
	GameManager.pause_game()
	AudioManager.play_sfx("pickedMode1")

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	# the big game-mode plan backdrop, near-fullscreen like the original
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.custom_minimum_size = Vector2(1800, 1012)
	frame.position = Vector2(-900, -506)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(frame)

	var backdrop := TextureRect.new()
	backdrop.texture = BACKDROP_TEX
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(backdrop)

	# close.png button, top-right of the plan
	var close_btn := TextureButton.new()
	close_btn.texture_normal = CLOSE_TEX
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_SCALE
	close_btn.custom_minimum_size = Vector2(64, 64)
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.position = Vector2(-110, 46)
	close_btn.pressed.connect(close_panel)
	frame.add_child(close_btn)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 130)
	margin.add_theme_constant_override("margin_right", 130)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 80)
	frame.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var title := _label("• %s •" % title_text, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	return content


func close_panel() -> void:
	if _root:
		_root.queue_free()
		_root = null
	if GameManager.ui_open:
		GameManager.ui_open = false
		GameManager.resume_game()


# ── Icon helper (128px sheets, 3 columns) ─────────────────────────────────────

func _icon(sheet: Texture2D, idx: int, size: float = 96.0) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	@warning_ignore("integer_division")
	atlas.region = Rect2((idx % 3) * 128, (idx / 3) * 128, 128, 128)
	var rect := TextureRect.new()
	rect.texture = atlas
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


# ── Inventory / Blacksmith (Ship Status — equip weapons & skills) ──────────────

func open_blacksmith() -> void:
	var content := _open_panel("Ship Status")

	var eq: Dictionary = SaveManager.equipped_data
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 50)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)

	# ── Weapons column ──
	var weapons_col := VBoxContainer.new()
	weapons_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons_col.add_theme_constant_override("separation", 8)
	columns.add_child(weapons_col)
	weapons_col.add_child(_label("Weapon Slots", 24))

	for id in WEAPONS:
		var owned: bool = SaveManager.weapon_data.get("w%dvalue" % id, false)
		var tag := ""
		if int(eq.get("weapon1Slot", 1)) == id:
			tag += " [W1]"
		if int(eq.get("weapon2Slot", 1)) == id:
			tag += " [W2]"

		var row := _card_row(weapons_col)
		row.add_child(_icon(WEAPON_SHEET, id - 1, 72.0))

		var text_col := VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_col)
		var name_lbl := _label("%s [%d/7]%s" % [WEAPONS[id]["name"], id, tag], 18)
		var desc_lbl := _label(WEAPONS[id]["desc"], 13)
		desc_lbl.modulate = Color(0.8, 0.8, 0.9)
		text_col.add_child(name_lbl)
		text_col.add_child(desc_lbl)

		if owned:
			row.add_child(_card_button("W1", 16, _equip_weapon.bind(id, true)))
			row.add_child(_card_button("W2", 16, _equip_weapon.bind(id, false)))
		else:
			name_lbl.modulate = Color(0.45, 0.45, 0.45)
			desc_lbl.modulate = Color(0.4, 0.4, 0.45)
			row.add_child(_label("LOCKED", 14))

	# ── Skills column ──
	var skills_col := VBoxContainer.new()
	skills_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_col.add_theme_constant_override("separation", 8)
	columns.add_child(skills_col)
	skills_col.add_child(_label("Skill Slot", 24))

	for id in SKILLS:
		var owned: bool = SaveManager.skill_data.get("s%dvalue" % id, false)
		var tag := "  [EQUIPPED]" if int(eq.get("skillSlot", 1)) == id else ""

		var row := _card_row(skills_col)
		row.add_child(_icon(SKILL_SHEET, id - 1, 72.0))

		var text_col := VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_col)
		var name_lbl := _label("%s [%d/7]%s" % [SKILLS[id]["name"], id, tag], 18)
		var desc_lbl := _label(SKILLS[id]["desc"], 13)
		desc_lbl.modulate = Color(0.8, 0.8, 0.9)
		text_col.add_child(name_lbl)
		text_col.add_child(desc_lbl)

		if owned:
			row.add_child(_card_button("Equip", 16, _equip_skill.bind(id)))
		else:
			name_lbl.modulate = Color(0.45, 0.45, 0.45)
			desc_lbl.modulate = Color(0.4, 0.4, 0.45)
			row.add_child(_label("LOCKED", 14))

	var hint := _label("Q swaps W1/W2 in battle · Space uses your skill · I opens this menu", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


func _equip_weapon(id: int, primary: bool) -> void:
	if primary:
		SaveManager.equipped_data["weapon1Slot"] = id
	else:
		SaveManager.equipped_data["weapon2Slot"] = id
	SaveManager.save_equipped_data()
	AudioManager.play_sfx("switchWeapon")
	_refresh_player_loadout()
	open_blacksmith()


func _equip_skill(id: int) -> void:
	SaveManager.equipped_data["skillSlot"] = id
	SaveManager.save_equipped_data()
	AudioManager.play_sfx("switchWeapon")
	_refresh_player_loadout()
	open_blacksmith()


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


# ── Merchant (Trade Board) ─────────────────────────────────────────────────────

func open_merchant() -> void:
	var content := _open_panel("Cosmic Trade Board")

	var pd: Dictionary = SaveManager.player_data
	var wallet := _label("Gems: %d    Shards: %d    CC: %d" %
		[int(pd.get("gems", 0)), int(pd.get("shards", 0)), int(pd.get("centralCurrency", 0))], 20)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(wallet)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 50)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)

	var weapons_col := VBoxContainer.new()
	weapons_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons_col.add_theme_constant_override("separation", 8)
	columns.add_child(weapons_col)
	weapons_col.add_child(_label("Weapons — Cosmic Shards", 22))

	for id in WEAPON_PRICES:
		var owned: bool = SaveManager.weapon_data.get("w%dvalue" % id, false)
		var row := _card_row(weapons_col)
		row.add_child(_icon(WEAPON_SHEET, id - 1, 72.0))
		var lbl := _label("%s — %d shards" % [WEAPONS[id]["name"], WEAPON_PRICES[id]], 18)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		if owned:
			lbl.text = "%s — owned" % WEAPONS[id]["name"]
			lbl.modulate = Color(0.5, 1.0, 0.6)
		else:
			row.add_child(_accept_button(_buy_weapon.bind(id)))

	var skills_col := VBoxContainer.new()
	skills_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_col.add_theme_constant_override("separation", 8)
	columns.add_child(skills_col)
	skills_col.add_child(_label("Skills — Cosmic Gems", 22))

	for id in SKILL_PRICES:
		var owned: bool = SaveManager.skill_data.get("s%dvalue" % id, false)
		var row := _card_row(skills_col)
		row.add_child(_icon(SKILL_SHEET, id - 1, 72.0))
		var lbl := _label("%s — %d gems" % [SKILLS[id]["name"], SKILL_PRICES[id]], 18)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		if owned:
			lbl.text = "%s — owned" % SKILLS[id]["name"]
			lbl.modulate = Color(0.5, 1.0, 0.6)
		else:
			row.add_child(_accept_button(_buy_skill.bind(id)))


func _buy_weapon(id: int) -> void:
	var price: int = WEAPON_PRICES[id]
	if int(SaveManager.player_data.get("shards", 0)) < price:
		AudioManager.play_sfx("demoWarning")
		return
	SaveManager.player_data["shards"] = int(SaveManager.player_data["shards"]) - price
	SaveManager.weapon_data["w%dvalue" % id] = true
	SaveManager.save_all()
	GameManager._emit_currency()
	AudioManager.play_sfx("moduleChest")
	open_merchant()


func _buy_skill(id: int) -> void:
	var price: int = SKILL_PRICES[id]
	if int(SaveManager.player_data.get("gems", 0)) < price:
		AudioManager.play_sfx("demoWarning")
		return
	SaveManager.player_data["gems"] = int(SaveManager.player_data["gems"]) - price
	SaveManager.skill_data["s%dvalue" % id] = true
	SaveManager.save_all()
	GameManager._emit_currency()
	AudioManager.play_sfx("moduleChest")
	open_merchant()


# ── Central Cosmic Commission (mission board with enemySystems icons) ──────────

func open_ccc() -> void:
	var content := _open_panel("Central Cosmic Commission")

	content.add_child(_label("Pick a solar system to invade:", 20))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for m in MISSIONS:
		var row := _card_row(list)
		row.add_child(_icon(SYSTEM_SHEET, m["icon"], 84.0))

		var text_col := VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_col)
		var name_lbl := _label(m["name"], 20)
		var desc_lbl := _label(m["desc"], 13)
		desc_lbl.modulate = Color(0.8, 0.8, 0.9)
		text_col.add_child(name_lbl)
		text_col.add_child(desc_lbl)

		var pick := _card_button("Select", 16, _select_stage.bind(int(m["stage"])))
		pick.name = "stage_%d" % m["stage"]
		if _selected_stage == int(m["stage"]):
			pick.text = "* Picked *"
		row.add_child(pick)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 40)
	content.add_child(bottom)

	bottom.add_child(_label("Difficulty:", 20))
	var diff_btn := _card_button(_selected_difficulty.to_upper(), 18, Callable())
	diff_btn.pressed.connect(func():
		_selected_difficulty = "expert" if _selected_difficulty == "normal" else "normal"
		diff_btn.text = _selected_difficulty.to_upper()
		AudioManager.play_sfx("switchMode"))
	bottom.add_child(diff_btn)

	# accept / reject cards to launch or bail, like the original confirm cards
	bottom.add_child(_accept_button(func():
		var stage := _selected_stage
		if stage == 0:
			stage = randi_range(1, 4)   # Random Solar System
		GameManager.queue_battle(stage, _selected_difficulty)))
	var reject := TextureButton.new()
	reject.texture_normal = REJECT_TEX
	reject.ignore_texture_size = true
	reject.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	reject.custom_minimum_size = Vector2(48, 144)
	reject.pressed.connect(close_panel)
	bottom.add_child(reject)


func _select_stage(stage: int) -> void:
	_selected_stage = stage
	AudioManager.play_sfx("pickedMode2")
	if _root:
		for btn in _root.find_children("stage_*", "Button", true, false):
			btn.text = "* Picked *" if btn.name == "stage_%d" % stage else "Select"


# ── NPC dialogue — chatBox.png layout from dialogue.lua ────────────────────────

func open_dialogue(npc_name: String, avatar_key: String, text: String) -> void:
	close_panel()
	GameManager.ui_open = true
	GameManager.pause_game()

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	# speaking character rises from the bottom-left (dialogue.lua avatar)
	if AVATARS.has(avatar_key) and ResourceLoader.exists(AVATARS[avatar_key]):
		var avatar := TextureRect.new()
		avatar.texture = load(AVATARS[avatar_key])
		avatar.custom_minimum_size = Vector2(560, 560)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		avatar.position = Vector2(60, -560)
		avatar.modulate.a = 0.0
		_root.add_child(avatar)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(avatar, "modulate:a", 1.0, 0.4)
		tw.tween_property(avatar, "position:x", 100.0, 0.4)

	# chatBox.png stretched wide on the right, like textBox in dialogue.lua
	var box := TextureRect.new()
	box.texture = CHATBOX_TEX
	box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.stretch_mode = TextureRect.STRETCH_SCALE
	box.custom_minimum_size = Vector2(1380, 520)
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.position = Vector2(-1440, -540)
	box.modulate.a = 0.0
	_root.add_child(box)
	create_tween().tween_property(box, "modulate:a", 1.0, 0.15)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	box.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	col.add_child(_label(npc_name, 26))
	var body := _label(text, 22)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	var hint := _label("click or press Esc to close", 14)
	hint.modulate = Color(0.7, 0.7, 0.8)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(hint)

	# click anywhere to close
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close_panel())
	box.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close_panel())


## Nurse — heals the ship and chats
func open_infirmary() -> void:
	var players := get_tree().get_nodes_in_group("friendlies")
	if not players.is_empty():
		var player = players[0]
		player.hp = player.max_hp
		player.shield = player.max_shield
		player.hp_changed.emit(player.hp, player.max_hp)
		player.shield_changed.emit(player.shield, player.max_shield)
	open_dialogue("Cosmic Nurse", "nurse",
		"There you go — patched up and good as new!\nTry not to get shot so much out there, okay?")


# ── Widget helpers ─────────────────────────────────────────────────────────────

func _label(text: String, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", RETRO_FONT)
	lbl.add_theme_font_size_override("font_size", size)
	return lbl


func _card_row(parent: Node) -> HBoxContainer:
	# an item row backed by the gamemodeMenu card art; returns the inner HBox
	var style := StyleBoxTexture.new()
	style.texture = CARD_TEX
	style.modulate_color = Color(1, 1, 1, 0.35)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 10)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	return row


func _card_button(text: String, size: int, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_override("font", RETRO_FONT)
	btn.add_theme_font_size_override("font_size", size)

	var normal := StyleBoxTexture.new()
	normal.texture = CARD_TEX
	for side in ["left", "right", "top", "bottom"]:
		normal.set("content_margin_" + side, 10)
	var hover := normal.duplicate()
	hover.modulate_color = Color(1.3, 1.3, 1.4)
	var pressed := normal.duplicate()
	pressed.modulate_color = Color(0.8, 0.8, 0.9)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	if callback.is_valid():
		btn.pressed.connect(callback)
	return btn


func _accept_button(callback: Callable) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = ACCEPT_TEX
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = Vector2(48, 96)
	btn.pressed.connect(callback)
	return btn
