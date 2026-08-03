extends CanvasLayer
class_name MerchantPanel

# Cosmic Trade Board — DRAFT, built on the same module-grid pattern as the
# blacksmith so the two screens read as a matched pair. Where the blacksmith
# equips what you already own, the trader is where you buy it and where you
# convert one currency into another.
#
# Chrome lives in scenes/ui/panels/merchant_panel.tscn. The layout mirrors
# blacksmith_panel.tscn one-for-one: a Weapons column of 5 modules, a Skills
# column of 5, and two slide-in detail panels.
#
# Comet (3) / Shield Generator (7) and Electric Shock (4) / Giant Beam (6) are
# excluded, so the 5 modules per column line up exactly with the blacksmith.

signal closed

const WEAPON_SHEET := preload("res://assets/art/ui/weaponArray.png")
const SKILL_SHEET  := preload("res://assets/art/ui/skillArray.png")

## Weapons cost Cosmic Shards. Prices match blacksmith_panel.WEAPONS.
const WEAPONS := {
	1: { "name": "Laser",          "price": 0,
		 "story": "Standard-issue CCC cannon. Comes with the licence." },
	2: { "name": "Plasma Ball",    "price": 300,
		 "story": "Superheated slug that punches a hole and keeps going." },
	4: { "name": "Light Wave",     "price": 800,
		 "story": "A crescent of hard light. Wide enough to clear a lane on its own." },
	5: { "name": "Halfmoon Slash", "price": 1200,
		 "story": "Close work. Spins the blade around the hull." },
	6: { "name": "Dash Slash",     "price": 1600,
		 "story": "The ship is the blade. Line it up and commit." },
}

## Skills cost Cosmic Gems. Prices match blacksmith_panel.SKILLS.
const SKILLS := {
	1: { "name": "Burst Projectile", "price": 0,
		 "story": "Dump the capacitors into every barrel at once." },
	2: { "name": "Shockwave",        "price": 50,
		 "story": "Slam the drive core and let the pressure wave do the work." },
	3: { "name": "Energy Overdrive", "price": 75,
		 "story": "Redline the cannons and hope the coolant holds." },
	5: { "name": "Purple",           "price": 150,
		 "story": "Nobody at the Commission will tell you what this actually is." },
	7: { "name": "Invincible Frames","price": 300,
		 "story": "Phase the hull out of sync with everything trying to hit it." },
}

## Currency conversion offered by the trader (from the GDD economy section).
const EXCHANGES := [
	{ "give": "centralCurrency", "give_amount": 120, "get": "shards", "get_amount": 50 },
	{ "give": "centralCurrency", "give_amount": 120, "get": "gems",   "get_amount": 15 },
]

const SLIDE_DISTANCE := 1100.0
const SLIDE_TIME := 0.32

@onready var _root: Control          = $Root
@onready var _close_btn: TextureButton = $Root/Frame/CloseButton
@onready var _wallet: Label          = $Root/Wallet
@onready var _weapons_root: Control  = $Root/Weapons
@onready var _skills_root: Control   = $Root/Skills

@onready var _wpanel: Control        = $"Root/Weapons Panel"
@onready var _wpanel_art: NinePatchRect = $"Root/Weapons Panel/TextureRect"
@onready var _wp_icon: AnimatedSprite2D = $"Root/Weapons Panel/AnimatedSprite2D"
@onready var _wp_name: Label         = $"Root/Weapons Panel/Weapon Name"
@onready var _wp_price: Label        = $"Root/Weapons Panel/Weapon Price"
@onready var _wp_story: Label        = $"Root/Weapons Panel/NarrativeDescription"
@onready var _wp_stats: Label        = $"Root/Weapons Panel/GameplayDescription"
@onready var _wp_buy: Button         = $"Root/Weapons Panel/BuyButton"

@onready var _spanel: Control        = $"Root/Skill Panel"
@onready var _spanel_art: NinePatchRect = $"Root/Skill Panel/TextureRect"
@onready var _sp_icon: AnimatedSprite2D = $"Root/Skill Panel/AnimatedSprite2D"
@onready var _sp_name: Label         = $"Root/Skill Panel/Skill Name"
@onready var _sp_price: Label        = $"Root/Skill Panel/Skill Price"
@onready var _sp_story: Label        = $"Root/Skill Panel/NarrativeDescription"
@onready var _sp_stats: Label        = $"Root/Skill Panel/GameplayDescription"
@onready var _sp_buy: Button         = $"Root/Skill Panel/BuyButton"

var _weapon_ids: Array = []
var _skill_ids: Array = []
var _wpanel_rest: Vector2
var _spanel_rest: Vector2
var _open_weapon: int = -1
var _open_skill: int = -1
var _slide_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	visible = false

	_weapon_ids = WEAPONS.keys()
	_skill_ids = SKILLS.keys()
	_weapon_ids.sort()
	_skill_ids.sort()

	_wpanel_rest = _wpanel.position
	_spanel_rest = _spanel.position
	_wpanel.visible = false
	_spanel.visible = false

	_close_btn.pressed.connect(close)

	for i in _weapon_ids.size():
		var btn: TextureButton = _weapons_root.get_node("Weapons%d/Button" % (i + 1))
		btn.pressed.connect(_show_weapon_panel.bind(_weapon_ids[i]))
	for i in _skill_ids.size():
		var btn: TextureButton = _skills_root.get_node("%s/Button" % _skill_node(i))
		btn.pressed.connect(_show_skill_panel.bind(_skill_ids[i]))

	_wp_buy.pressed.connect(_buy_weapon)
	_sp_buy.pressed.connect(_buy_skill)


func _skill_node(i: int) -> String:
	return "Skill" if i == 0 else "Skill%d" % (i + 1)


func open() -> void:
	visible = true
	AudioManager.play_sfx("pickedMode1")
	_hide_panels(false)
	_rebuild()


func close() -> void:
	visible = false
	_hide_panels(false)
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	var at: Vector2 = (event as InputEventMouseButton).global_position
	if _wpanel.visible and not _wpanel_art.get_global_rect().has_point(at):
		_hide_panels()
	elif _spanel.visible and not _spanel_art.get_global_rect().has_point(at):
		_hide_panels()


# ── Module grid ───────────────────────────────────────────────────────────────

func _rebuild() -> void:
	var pd: Dictionary = SaveManager.player_data
	_wallet.text = "GEMS %d      SHARDS %d      CC %d" % [
		int(pd.get("gems", 0)), int(pd.get("shards", 0)), int(pd.get("centralCurrency", 0))]

	for i in _weapon_ids.size():
		var id: int = _weapon_ids[i]
		var m: Control = _weapons_root.get_node("Weapons%d" % (i + 1))
		var owned: bool = _owns_weapon(id)

		_set_icon(m.get_node("AnimatedSprite2D"), WEAPON_SHEET, id)
		m.get_node("Weapon Name").text = WEAPONS[id]["name"]
		m.get_node("Weapon Price").text = "OWNED" if owned else "%d shards" % WEAPONS[id]["price"]
		m.get_node("EquippedLabel").text = "OWNED" if owned else ""
		m.modulate = Color(0.6, 0.62, 0.66) if owned else Color.WHITE

	for i in _skill_ids.size():
		var id: int = _skill_ids[i]
		var m: Control = _skills_root.get_node(_skill_node(i))
		var owned: bool = _owns_skill(id)

		_set_icon(m.get_node("AnimatedSprite2D"), SKILL_SHEET, id)
		m.get_node("Skill Name").text = SKILLS[id]["name"]
		m.get_node("Skill Price").text = "OWNED" if owned else "%d gems" % SKILLS[id]["price"]
		m.get_node("EquippedLabel").text = "OWNED" if owned else ""
		m.modulate = Color(0.6, 0.62, 0.66) if owned else Color.WHITE

	if _wpanel.visible and _open_weapon > 0:
		_fill_weapon_panel(_open_weapon)
	if _spanel.visible and _open_skill > 0:
		_fill_skill_panel(_open_skill)


func _set_icon(spr: AnimatedSprite2D, sheet: Texture2D, id: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	@warning_ignore("integer_division")
	atlas.region = Rect2(((id - 1) % 3) * 128, ((id - 1) / 3) * 128, 128, 128)
	var frames := SpriteFrames.new()
	frames.add_frame("default", atlas)
	spr.sprite_frames = frames
	spr.play("default")


func _owns_weapon(id: int) -> bool:
	return bool(SaveManager.weapon_data.get("w%dvalue" % id, false))


func _owns_skill(id: int) -> bool:
	return bool(SaveManager.skill_data.get("s%dvalue" % id, false))


# ── Detail panels ─────────────────────────────────────────────────────────────

func _show_weapon_panel(id: int) -> void:
	_open_weapon = id
	_open_skill = -1
	_spanel.visible = false
	_spanel.position = _spanel_rest
	_fill_weapon_panel(id)
	AudioManager.play_sfx("switchMode")
	_slide_in(_wpanel, _wpanel_rest, SLIDE_DISTANCE)


func _show_skill_panel(id: int) -> void:
	_open_skill = id
	_open_weapon = -1
	_wpanel.visible = false
	_wpanel.position = _wpanel_rest
	_fill_skill_panel(id)
	AudioManager.play_sfx("switchMode")
	_slide_in(_spanel, _spanel_rest, -SLIDE_DISTANCE)


func _kill_slide() -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = null


func _slide_in(panel: Control, rest: Vector2, from_offset: float) -> void:
	_kill_slide()
	panel.visible = true
	panel.position = rest + Vector2(from_offset, 0.0)
	_slide_tween = create_tween()
	_slide_tween.tween_property(panel, "position", rest, SLIDE_TIME)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _hide_panels(animated: bool = true) -> void:
	_open_weapon = -1
	_open_skill = -1
	_kill_slide()

	if not animated:
		_wpanel.visible = false
		_spanel.visible = false
		_wpanel.position = _wpanel_rest
		_spanel.position = _spanel_rest
		return

	if _wpanel.visible:
		_slide_out(_wpanel, _wpanel_rest, SLIDE_DISTANCE)
	elif _spanel.visible:
		_slide_out(_spanel, _spanel_rest, -SLIDE_DISTANCE)


func _slide_out(panel: Control, rest: Vector2, to_offset: float) -> void:
	_slide_tween = create_tween()
	_slide_tween.tween_property(panel, "position", rest + Vector2(to_offset, 0.0), SLIDE_TIME)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_slide_tween.tween_callback(func():
		panel.visible = false
		panel.position = rest)


func _fill_weapon_panel(id: int) -> void:
	var d: Dictionary = WEAPONS[id]
	var owned: bool = _owns_weapon(id)
	var price: int = int(d["price"])

	_set_icon(_wp_icon, WEAPON_SHEET, id)
	_wp_name.text = d["name"]
	_wp_price.text = "OWNED" if owned else "%d shards" % price
	_wp_story.text = d["story"]
	_wp_stats.text = "Equip it at the blacksmith once purchased."

	if owned:
		_wp_buy.text = "OWNED"
		_wp_buy.disabled = true
	else:
		_wp_buy.text = "BUY  %d" % price
		_wp_buy.disabled = int(SaveManager.player_data.get("shards", 0)) < price


func _fill_skill_panel(id: int) -> void:
	var d: Dictionary = SKILLS[id]
	var owned: bool = _owns_skill(id)
	var price: int = int(d["price"])

	_set_icon(_sp_icon, SKILL_SHEET, id)
	_sp_name.text = d["name"]
	_sp_price.text = "OWNED" if owned else "%d gems" % price
	_sp_story.text = d["story"]
	_sp_stats.text = "Equip it at the blacksmith once purchased."

	if owned:
		_sp_buy.text = "OWNED"
		_sp_buy.disabled = true
	else:
		_sp_buy.text = "BUY  %d" % price
		_sp_buy.disabled = int(SaveManager.player_data.get("gems", 0)) < price


# ── Purchases ─────────────────────────────────────────────────────────────────

func _buy_weapon() -> void:
	var id := _open_weapon
	if id <= 0 or _owns_weapon(id):
		return
	var price: int = int(WEAPONS[id]["price"])
	if int(SaveManager.player_data.get("shards", 0)) < price:
		AudioManager.play_sfx("demoWarning")
		return
	SaveManager.player_data["shards"] = int(SaveManager.player_data.get("shards", 0)) - price
	SaveManager.weapon_data["w%dvalue" % id] = true
	SaveManager.save_all()
	GameManager._emit_currency()
	AudioManager.play_sfx("moduleChest")
	_rebuild()


func _buy_skill() -> void:
	var id := _open_skill
	if id <= 0 or _owns_skill(id):
		return
	var price: int = int(SKILLS[id]["price"])
	if int(SaveManager.player_data.get("gems", 0)) < price:
		AudioManager.play_sfx("demoWarning")
		return
	SaveManager.player_data["gems"] = int(SaveManager.player_data.get("gems", 0)) - price
	SaveManager.skill_data["s%dvalue" % id] = true
	SaveManager.save_all()
	GameManager._emit_currency()
	AudioManager.play_sfx("moduleChest")
	_rebuild()
