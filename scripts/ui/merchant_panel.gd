extends CanvasLayer
class_name MerchantPanel

# The Cosmic Trader's board. Princess sells consumable-style *items* now, not
# weapons and skills — those live at the blacksmith, where you can buy and
# equip in one place.
#
# Stock is rolled once per gameplay loop and then frozen: prices, which slots
# carry what, and what's already been bought all survive leaving and re-
# entering the hub. It only rerolls when a run reaches an end screen, so you
# can't shop-scum by walking in and out.
#
# Layout comes straight from scenes/ui/panels/merchant_panel.tscn and is not
# touched here: two clusters of five tiles side by side (the "Weapons" group
# on the left, "Skills" on the right — names left over from when this sold
# weapons and skills), and the detail panel on the left of the board.

signal closed

const ITEM_SHEET := preload("res://assets/art/ui/weaponArray.png")

## Currencies an item can be priced in, with the range each rolls within.
## Keys match SaveManager.player_data.
const CURRENCIES := {
	"shards":         { "label": "shards", "min": 40,  "max": 220 },
	"gems":           { "label": "gems",   "min": 10,  "max": 70 },
	"centralCurrency":{ "label": "CC",     "min": 150, "max": 900 },
}

## The catalogue Princess draws from. `icon` indexes the shared sheet.
## Effects aren't wired yet — these are the shelf, with templated copy.
const CATALOGUE := [
	{ "name": "Hull Sealant", "icon": 1,
	  "story": "Industrial foam that sets in vacuum. Smells appalling.",
	  "stats": "Repairs the hull between contracts." },
	{ "name": "Coolant Flask", "icon": 2,
	  "story": "Keeps a cannon from cooking itself on a long engagement.",
	  "stats": "Reduces heat build-up on sustained fire." },
	{ "name": "Shield Cell", "icon": 3,
	  "story": "One charge, one good decision. Spend it well.",
	  "stats": "Restores the dash meter on use." },
	{ "name": "Targeting Chip", "icon": 4,
	  "story": "Salvaged Commission hardware. Mostly legal.",
	  "stats": "Improves projectile accuracy." },
	{ "name": "Scrap Magnet", "icon": 5,
	  "story": "Pulls loose salvage in from further out.",
	  "stats": "Widens shard pickup range." },
	{ "name": "Emergency Beacon", "icon": 6,
	  "story": "The guild says they always answer. The guild says a lot.",
	  "stats": "Marks your wreck for recovery." },
	{ "name": "Ration Pack", "icon": 7,
	  "story": "Eleven flavours. All of them are 'grey'.",
	  "stats": "Small health restore between contracts." },
	{ "name": "Nav Charts", "icon": 8,
	  "story": "Hand-annotated by someone who did not come back.",
	  "stats": "Reveals more of the contract board." },
	{ "name": "Signal Jammer", "icon": 9,
	  "story": "Makes you boring to look at, electronically speaking.",
	  "stats": "Enemies notice you later." },
	{ "name": "Spare Capacitor", "icon": 1,
	  "story": "Third-hand, but it holds a charge.",
	  "stats": "Shortens special cooldown slightly." },
	{ "name": "Plating Offcuts", "icon": 2,
	  "story": "Gabriel's rejects. Still better than nothing.",
	  "stats": "Small permanent hull bonus." },
	{ "name": "Black Box", "icon": 3,
	  "story": "Someone else's last flight. Princess won't say whose.",
	  "stats": "Unknown. Sold as seen." },
]

const SLOT_COUNT := 10

## Negative — the detail panel lives on the left of the board, so it enters
## and leaves off the left edge rather than crossing the tiles.
const SLIDE_DISTANCE := -1100.0
const SLIDE_TIME := 0.32

@onready var _root: Control          = $Root
@onready var _close_btn: Button      = $Root/Frame/BackButton
@onready var _wallet: Label          = $Root/Wallet
@onready var _weapons_root: Control  = $Root/Weapons
@onready var _skills_root: Control   = $Root/Skills

# The item detail panel is the node authored on the left of the board. Its
# name is historical — it used to show skills.
@onready var _panel: Control             = $"Root/Skill Panel"
@onready var _panel_art: NinePatchRect   = $"Root/Skill Panel/TextureRect"
@onready var _p_icon: AnimatedSprite2D   = $"Root/Skill Panel/AnimatedSprite2D"
@onready var _p_name: Label              = $"Root/Skill Panel/Skill Name"
@onready var _p_price: Label             = $"Root/Skill Panel/Skill Price"
@onready var _p_story: Label             = $"Root/Skill Panel/NarrativeDescription"
@onready var _p_stats: Label             = $"Root/Skill Panel/GameplayDescription"
@onready var _p_buy: Button              = $"Root/Skill Panel/BuyButton"

var _panel_rest: Vector2
var _open_slot: int = -1
var _slide_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	visible = false

	_panel_rest = _panel.position
	_panel.visible = false

	# The right-hand detail panel has no job now — one item panel is enough
	var legacy := get_node_or_null("Root/Weapons Panel")
	if legacy:
		legacy.visible = false

	_close_btn.pressed.connect(close)

	for i in SLOT_COUNT:
		var tile := _slot_tile(i)
		if tile == null:
			continue
		var btn := tile.get_node_or_null("Button") as TextureButton
		if btn:
			btn.pressed.connect(_show_item.bind(i))

	_p_buy.pressed.connect(_buy_open_item)
	GameManager.run_loop_advanced.connect(func(_loop: int): TraderStock.reroll())


## Slots run left cluster first, then right, so slot order matches reading
## order on screen. The "Weapons"/"Skills" node names are historical.
func _slot_tile(index: int) -> Control:
	if index < 5:
		return _weapons_root.get_node_or_null("Weapons%d" % (index + 1)) as Control
	var skill_index := index - 5
	var skill_name := "Skill" if skill_index == 0 else "Skill%d" % (skill_index + 1)
	return _skills_root.get_node_or_null(skill_name) as Control


func open() -> void:
	visible = true
	AudioManager.play_sfx("pickedMode1")
	TraderStock.ensure_stocked()
	_hide_panel(false)
	_rebuild()
	# Princess rises into frame with the board
	var portrait := get_node_or_null("Root/Frame/TextureRect")
	if portrait is AvatarFloat:
		(portrait as AvatarFloat).play_intro()


func close() -> void:
	visible = false
	_hide_panel(false)
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	var at: Vector2 = (event as InputEventMouseButton).global_position
	if _panel.visible and not _panel_art.get_global_rect().has_point(at):
		_hide_panel()


# ── Board ─────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	_refresh_wallet()

	for i in SLOT_COUNT:
		var tile := _slot_tile(i)
		if tile == null:
			continue
		var item: Dictionary = TraderStock.item(i)
		var sold: bool = TraderStock.is_sold(i)

		_set_icon(tile.get_node("AnimatedSprite2D"), int(item["icon"]))
		_tile_label(tile, ["Skill Name", "Weapon Name"]).text = item["name"]
		_tile_label(tile, ["Skill Price", "Weapon Price"]).text = \
			"SOLD" if sold else TraderStock.price_text(i)
		tile.get_node("EquippedLabel").text = "PURCHASED" if sold else ""

		# Bought stock stays on the shelf, greyed out, so the board doesn't
		# reshuffle under the player mid-visit.
		tile.modulate = Color(0.45, 0.45, 0.5) if sold else Color.WHITE

	if _panel.visible and _open_slot >= 0:
		_fill_panel(_open_slot)


## The two rows label their children differently ("Skill Name" vs "Weapon
## Name"); this finds whichever the tile actually has.
func _tile_label(tile: Control, names: Array) -> Label:
	for n in names:
		var node := tile.get_node_or_null(n) as Label
		if node:
			return node
	return null


func _set_icon(spr: AnimatedSprite2D, icon_index: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = ITEM_SHEET
	@warning_ignore("integer_division")
	atlas.region = Rect2(((icon_index - 1) % 3) * 128, ((icon_index - 1) / 3) * 128, 128, 128)
	var frames := SpriteFrames.new()
	frames.add_frame("default", atlas)
	spr.sprite_frames = frames
	spr.play("default")


func _refresh_wallet() -> void:
	var pd: Dictionary = SaveManager.player_data
	_wallet.text = "Gems: %d   Shards: %d   CC: %d" % [
		int(pd.get("gems", 0)), int(pd.get("shards", 0)),
		int(pd.get("centralCurrency", 0))]


# ── Detail panel ──────────────────────────────────────────────────────────────

func _show_item(slot: int) -> void:
	_open_slot = slot
	_fill_panel(slot)
	AudioManager.play_sfx("switchMode")
	_slide_in()


func _fill_panel(slot: int) -> void:
	var item: Dictionary = TraderStock.item(slot)
	var sold: bool = TraderStock.is_sold(slot)

	_set_icon(_p_icon, int(item["icon"]))
	_p_name.text = item["name"]
	_p_price.text = "PURCHASED" if sold else TraderStock.price_text(slot)
	_p_story.text = item["story"]
	_p_stats.text = item["stats"]

	if sold:
		_p_buy.text = "PURCHASED"
		_p_buy.disabled = true
	else:
		_p_buy.text = "BUY"
		_p_buy.disabled = not TraderStock.can_afford(slot)


func _buy_open_item() -> void:
	if _open_slot < 0 or TraderStock.is_sold(_open_slot):
		return
	if not TraderStock.can_afford(_open_slot):
		AudioManager.play_sfx("demoWarning")
		return

	TraderStock.purchase(_open_slot)
	AudioManager.play_sfx("moduleChest")
	GameManager._emit_currency()
	_rebuild()


# ── Slide ─────────────────────────────────────────────────────────────────────

func _kill_slide() -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = null


func _slide_in() -> void:
	_kill_slide()
	_panel.visible = true
	_panel.position = _panel_rest + Vector2(SLIDE_DISTANCE, 0.0)
	_slide_tween = create_tween()
	_slide_tween.tween_property(_panel, "position", _panel_rest, SLIDE_TIME)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _hide_panel(animated: bool = true) -> void:
	_open_slot = -1
	_kill_slide()

	if not animated or not _panel.visible:
		_panel.visible = false
		_panel.position = _panel_rest
		return

	_slide_tween = create_tween()
	_slide_tween.tween_property(_panel, "position",
		_panel_rest + Vector2(SLIDE_DISTANCE, 0.0), SLIDE_TIME)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_slide_tween.tween_callback(func():
		_panel.visible = false
		_panel.position = _panel_rest)


func is_open() -> bool:
	return visible


func contains_point(at: Vector2) -> bool:
	return visible and _panel.visible and _panel_art.get_global_rect().has_point(at)
