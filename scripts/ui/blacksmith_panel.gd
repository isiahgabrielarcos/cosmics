extends CanvasLayer
class_name BlacksmithPanel

# Ship Status — the module-grid loadout screen. Chrome and the 10 module
# controls live in scenes/ui/panels/blacksmith_panel.tscn; this script fills
# each module in from WEAPONS/SKILLS, drives the buy → equip → equipped
# button states, and slides the detail panels in and out.
#
# Comet (3) / Shield Generator (7) and Electric Shock (4) / Giant Beam (6)
# are excluded, leaving exactly 5 weapons and 5 skills for the 5 slots.

signal closed

const WEAPON_SHEET := preload("res://assets/art/ui/weaponArray.png")
const SKILL_SHEET  := preload("res://assets/art/ui/skillArray.png")

# Weapons are bought with Cosmic Shards, skills with Cosmic Gems (matches
# the trade board). Weapon 1 and skill 1 are the free starting kit.
const WEAPONS := {
	1: { "name": "Laser",          "price": 0,    "scene": "res://scenes/weapons/laser_beam.tscn",
		 "story": "Standard-issue CCC cannon. Never the best, never the reason you died." },
	2: { "name": "Plasma Ball",    "price": 300,  "scene": "res://scenes/weapons/laser_plasma.tscn",
		 "story": "Superheated slug that punches a hole and keeps going." },
	4: { "name": "Light Wave",     "price": 800,  "scene": "res://scenes/weapons/wide_slash.tscn",
		 "story": "A crescent of hard light. Wide enough to clear a lane on its own." },
	5: { "name": "Halfmoon Slash", "price": 1200, "scene": "res://scenes/weapons/slash.tscn",
		 "story": "Close work. Spins the blade around the hull and cuts everything touching you." },
	6: { "name": "Dash Slash",     "price": 1600, "scene": "res://scenes/weapons/pierce.tscn",
		 "story": "The ship is the blade. Line it up, commit, and go straight through." },
}

const SKILLS := {
	1: { "name": "Burst Projectile", "price": 0,   "cd": 10.0,
		 "story": "Dump the capacitors into every barrel at once.",
		 "stats": "12 bolts in a full circle\n25 damage each · 3 pierce" },
	2: { "name": "Shockwave",        "price": 50,  "cd": 5.0,
		 "story": "Slam the drive core and let the pressure wave do the work.",
		 "stats": "700 radius blast\n40 damage · heavy knockback" },
	3: { "name": "Energy Overdrive", "price": 75,  "cd": 20.0,
		 "story": "Redline the cannons and hope the coolant holds.",
		 "stats": "Fire rate x2.5 for 6 s" },
	5: { "name": "Purple",           "price": 150, "cd": 20.0,
		 "story": "Nobody at the Commission will tell you what this actually is.",
		 "stats": "450 radius blast\n60 damage · knockback" },
	7: { "name": "Invincible Frames","price": 300, "cd": 10.0,
		 "story": "Phase the hull out of sync with everything trying to hit it.",
		 "stats": "Ignore all damage for 5 s" },
}

const SLIDE_DISTANCE := 1100.0
const SLIDE_TIME := 0.32

@onready var _root: Control          = $Root
@onready var _dim: ColorRect         = $Root/Dim
@onready var _close_btn: TextureButton = $Root/Frame/CloseButton
@onready var _weapons_root: Control  = $Root/Weapons
@onready var _skills_root: Control   = $Root/Skills

@onready var _wpanel: Control        = $"Root/Weapons Panel"
@onready var _wpanel_art: NinePatchRect = $"Root/Weapons Panel/TextureRect"
@onready var _wp_icon: AnimatedSprite2D = $"Root/Weapons Panel/AnimatedSprite2D"
@onready var _wp_name: Label         = $"Root/Weapons Panel/Weapon Name"
@onready var _wp_price: Label        = $"Root/Weapons Panel/Weapon Price"
@onready var _wp_story: Label        = $"Root/Weapons Panel/NarrativeDescription"
@onready var _wp_stats: Label        = $"Root/Weapons Panel/GameplayDescription"
@onready var _wp_btn1: Button        = $"Root/Weapons Panel/Slot1-Buy-Equip-Equipped"
@onready var _wp_btn2: Button        = $"Root/Weapons Panel/Slot2-Buy-Equip-Equipped2"

@onready var _spanel: Control        = $"Root/Skill Panel"
@onready var _spanel_art: NinePatchRect = $"Root/Skill Panel/TextureRect"
@onready var _sp_icon: AnimatedSprite2D = $"Root/Skill Panel/AnimatedSprite2D"
@onready var _sp_name: Label         = $"Root/Skill Panel/Skill Name"
@onready var _sp_price: Label        = $"Root/Skill Panel/Skill Price"
@onready var _sp_story: Label        = $"Root/Skill Panel/NarrativeDescription"
@onready var _sp_stats: Label        = $"Root/Skill Panel/GameplayDescription"
@onready var _sp_btn: Button         = $"Root/Skill Panel/Buy-Equip-Equipped"

var _weapon_ids: Array = []
var _skill_ids: Array = []
var _wpanel_rest: Vector2
var _spanel_rest: Vector2
var _open_weapon: int = -1
var _open_skill: int = -1
var _weapon_stats_cache: Dictionary = {}
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

	# module buttons -> open the matching detail panel
	for i in _weapon_ids.size():
		var btn: TextureButton = _weapons_root.get_node("Weapons%d/Button" % (i + 1))
		btn.pressed.connect(_show_weapon_panel.bind(_weapon_ids[i]))
	for i in _skill_ids.size():
		var btn: TextureButton = _skills_root.get_node("%s/Button" % _skill_node(i))
		btn.pressed.connect(_show_skill_panel.bind(_skill_ids[i]))

	_wp_btn1.pressed.connect(func(): _weapon_action(1))
	_wp_btn2.pressed.connect(func(): _weapon_action(2))
	_sp_btn.pressed.connect(_skill_action)


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


# ── Click-outside closes an open detail panel ─────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	# Note: the click is deliberately NOT marked handled, so clicking straight
	# from one module onto another still reaches that module's button — the
	# open panel closes and the new one opens in the same click.
	var at: Vector2 = (event as InputEventMouseButton).global_position
	if _wpanel.visible and not _wpanel_art.get_global_rect().has_point(at):
		_hide_panels()
	elif _spanel.visible and not _spanel_art.get_global_rect().has_point(at):
		_hide_panels()


# ── Module grid ───────────────────────────────────────────────────────────────

func _rebuild() -> void:
	var eq: Dictionary = SaveManager.equipped_data
	var w1: int = int(eq.get("weapon1Slot", 1))
	var w2: int = int(eq.get("weapon2Slot", 1))
	var sk: int = int(eq.get("skillSlot", 1))

	for i in _weapon_ids.size():
		var id: int = _weapon_ids[i]
		var m: Control = _weapons_root.get_node("Weapons%d" % (i + 1))
		var owned: bool = _owns_weapon(id)

		_set_icon(m.get_node("AnimatedSprite2D"), WEAPON_SHEET, id)
		m.get_node("Weapon Name").text = WEAPONS[id]["name"]
		m.get_node("Weapon Price").text = _price_text(id, owned, true)

		var tag := ""
		if w1 == id:
			tag = "SLOT 1"
		if w2 == id:
			tag = "SLOT 2" if tag == "" else "SLOT 1 & 2"
		m.get_node("EquippedLabel").text = tag

		m.modulate = Color.WHITE if owned else Color(0.55, 0.55, 0.6)

	for i in _skill_ids.size():
		var id: int = _skill_ids[i]
		var m: Control = _skills_root.get_node(_skill_node(i))
		var owned: bool = _owns_skill(id)

		_set_icon(m.get_node("AnimatedSprite2D"), SKILL_SHEET, id)
		m.get_node("Skill Name").text = SKILLS[id]["name"]
		m.get_node("Skill Price").text = _price_text(id, owned, false)
		m.get_node("EquippedLabel").text = "EQUIPPED" if sk == id else ""

		m.modulate = Color.WHITE if owned else Color(0.55, 0.55, 0.6)

	if _wpanel.visible and _open_weapon > 0:
		_fill_weapon_panel(_open_weapon)
	if _spanel.visible and _open_skill > 0:
		_fill_skill_panel(_open_skill)


func _price_text(id: int, owned: bool, is_weapon: bool) -> String:
	if owned:
		return "OWNED"
	var src: Dictionary = WEAPONS if is_weapon else SKILLS
	return "%d %s" % [src[id]["price"], "shards" if is_weapon else "gems"]


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
	# slides in from off-screen right, moving leftward to rest
	_slide_in(_wpanel, _wpanel_rest, SLIDE_DISTANCE)


func _show_skill_panel(id: int) -> void:
	_open_skill = id
	_open_weapon = -1
	_wpanel.visible = false
	_wpanel.position = _wpanel_rest
	_fill_skill_panel(id)
	AudioManager.play_sfx("switchMode")
	# slides in from off-screen left, moving rightward to rest
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

	# weapons panel exits left->right, skill panel exits right->left
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
	var eq: Dictionary = SaveManager.equipped_data

	_set_icon(_wp_icon, WEAPON_SHEET, id)
	_wp_name.text = d["name"]
	_wp_price.text = "OWNED" if owned else "%d shards" % d["price"]
	_wp_story.text = d["story"]
	_wp_stats.text = _weapon_stats(id)

	_style_slot_button(_wp_btn1, id, owned, int(eq.get("weapon1Slot", 1)), 1)
	_style_slot_button(_wp_btn2, id, owned, int(eq.get("weapon2Slot", 1)), 2)


func _style_slot_button(btn: Button, id: int, owned: bool, equipped_here: int, slot: int) -> void:
	if not owned:
		btn.text = "BUY"
		btn.disabled = int(SaveManager.player_data.get("shards", 0)) < int(WEAPONS[id]["price"])
		return
	if equipped_here == id:
		btn.text = "EQUIPPED"
		btn.disabled = true
		return
	btn.text = "EQUIP"
	# no duplicates across the two slots unless it's the only weapon owned
	var other: int = int(SaveManager.equipped_data.get(
		"weapon2Slot" if slot == 1 else "weapon1Slot", 1))
	btn.disabled = (other == id and _owned_weapon_count() >= 2)


func _fill_skill_panel(id: int) -> void:
	var d: Dictionary = SKILLS[id]
	var owned: bool = _owns_skill(id)
	var equipped: bool = int(SaveManager.equipped_data.get("skillSlot", 1)) == id

	_set_icon(_sp_icon, SKILL_SHEET, id)
	_sp_name.text = d["name"]
	_sp_price.text = "OWNED" if owned else "%d gems" % d["price"]
	_sp_story.text = d["story"]
	_sp_stats.text = "%s\n%.0f s cooldown" % [d["stats"], d["cd"]]

	if not owned:
		_sp_btn.text = "BUY"
		_sp_btn.disabled = int(SaveManager.player_data.get("gems", 0)) < int(d["price"])
	elif equipped:
		_sp_btn.text = "EQUIPPED"
		_sp_btn.disabled = true
	else:
		_sp_btn.text = "EQUIP"
		_sp_btn.disabled = false


func _owned_weapon_count() -> int:
	var n := 0
	for id in _weapon_ids:
		if _owns_weapon(id):
			n += 1
	return n


## Reads the real WeaponData off each weapon scene so the stat block always
## matches what the weapon actually does in-game.
func _weapon_stats(id: int) -> String:
	if _weapon_stats_cache.has(id):
		return _weapon_stats_cache[id]

	var scene: PackedScene = load(WEAPONS[id]["scene"])
	var probe: WeaponProjectile = scene.instantiate()
	var d: WeaponData = probe.data
	probe.free()

	var lines := ["%d damage · %.2f s per shot" % [d.base_damage, d.fire_rate]]
	match d.archetype:
		WeaponData.Archetype.BOLT:
			lines.append("%.0f speed · %d pierce" % [d.speed, d.pierce])
		WeaponData.Archetype.SWEEP:
			lines.append("Spins around the ship · %d pierce" % d.pierce)
		WeaponData.Archetype.THRUST:
			lines.append("Lunges %.0f units forward" % d.thrust_distance)
		WeaponData.Archetype.SHIELD:
			lines.append("%.0f knockback · %.1f s invuln" % [d.knockback_force, d.invuln_duration])

	var text := "\n".join(lines)
	_weapon_stats_cache[id] = text
	return text


# ── Buy / equip ───────────────────────────────────────────────────────────────

func _weapon_action(slot: int) -> void:
	var id := _open_weapon
	if id <= 0:
		return

	if not _owns_weapon(id):
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
		return

	var other_key := "weapon2Slot" if slot == 1 else "weapon1Slot"
	if int(SaveManager.equipped_data.get(other_key, 1)) == id and _owned_weapon_count() >= 2:
		AudioManager.play_sfx("demoWarning")
		return

	SaveManager.equipped_data["weapon%dSlot" % slot] = id
	SaveManager.save_equipped_data()
	AudioManager.play_sfx("switchWeapon")
	_refresh_player_loadout()
	_rebuild()


func _skill_action() -> void:
	var id := _open_skill
	if id <= 0:
		return

	if not _owns_skill(id):
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
		return

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
