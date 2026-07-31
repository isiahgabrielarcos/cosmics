extends CanvasLayer
class_name MerchantPanel

# Cosmic Trade Board — buy weapons with shards, skills with gems. Chrome
# lives in scenes/ui/panels/merchant_panel.tscn; this script duplicates the
# row templates per item and wires the buy buttons.

signal closed

const WEAPON_SHEET := preload("res://assets/art/ui/weaponArray.png")
const SKILL_SHEET  := preload("res://assets/art/ui/skillArray.png")

const WEAPON_NAMES := {
	1: "Laser", 2: "Plasma Ball", 3: "Comet", 4: "Light Wave",
	5: "Halfmoon Slash", 6: "Dash Slash", 7: "Shield Generator",
}
const SKILL_NAMES := {
	1: "Burst Projectile", 2: "Shockwave", 3: "Energy Overdrive",
	4: "Electric Shock", 5: "Purple", 6: "Giant Beam", 7: "Invincible Frames",
}

const WEAPON_PRICES := { 2: 300, 3: 500, 4: 800, 5: 1200, 6: 1600, 7: 2000 }
const SKILL_PRICES  := { 2: 50, 3: 75, 4: 100, 5: 150, 6: 200, 7: 300 }

@onready var _close_btn: TextureButton   = $Root/Frame/CloseButton
@onready var _wallet: Label              = $Root/Frame/Margin/Content/Wallet
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
	var pd: Dictionary = SaveManager.player_data
	_wallet.text = "Gems: %d    Shards: %d    CC: %d" % [
		int(pd.get("gems", 0)), int(pd.get("shards", 0)), int(pd.get("centralCurrency", 0))]

	for c in _weapon_list.get_children():
		if c != _weapon_row_t:
			c.queue_free()
	for c in _skill_list.get_children():
		if c != _skill_row_t:
			c.queue_free()

	for id in WEAPON_PRICES:
		var owned: bool = SaveManager.weapon_data.get("w%dvalue" % id, false)
		var row: PanelContainer = _weapon_row_t.duplicate()
		row.visible = true
		_weapon_list.add_child(row)

		var icon: TextureRect = row.get_node("HBox/Icon")
		var atlas := AtlasTexture.new()
		atlas.atlas = WEAPON_SHEET
		@warning_ignore("integer_division")
		atlas.region = Rect2(((id - 1) % 3) * 128, ((id - 1) / 3) * 128, 128, 128)
		icon.texture = atlas

		var label: Label = row.get_node("HBox/PriceLabel")
		var buy_btn: TextureButton = row.get_node("HBox/BuyButton")
		if owned:
			label.text = "%s — owned" % WEAPON_NAMES[id]
			label.modulate = Color(0.5, 1.0, 0.6)
			buy_btn.visible = false
		else:
			label.text = "%s — %d shards" % [WEAPON_NAMES[id], WEAPON_PRICES[id]]
			buy_btn.visible = true
			buy_btn.pressed.connect(_buy_weapon.bind(id))

	for id in SKILL_PRICES:
		var owned: bool = SaveManager.skill_data.get("s%dvalue" % id, false)
		var row: PanelContainer = _skill_row_t.duplicate()
		row.visible = true
		_skill_list.add_child(row)

		var icon: TextureRect = row.get_node("HBox/Icon")
		var atlas := AtlasTexture.new()
		atlas.atlas = SKILL_SHEET
		@warning_ignore("integer_division")
		atlas.region = Rect2(((id - 1) % 3) * 128, ((id - 1) / 3) * 128, 128, 128)
		icon.texture = atlas

		var label: Label = row.get_node("HBox/PriceLabel")
		var buy_btn: TextureButton = row.get_node("HBox/BuyButton")
		if owned:
			label.text = "%s — owned" % SKILL_NAMES[id]
			label.modulate = Color(0.5, 1.0, 0.6)
			buy_btn.visible = false
		else:
			label.text = "%s — %d gems" % [SKILL_NAMES[id], SKILL_PRICES[id]]
			buy_btn.visible = true
			buy_btn.pressed.connect(_buy_skill.bind(id))


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
	_rebuild()


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
	_rebuild()
