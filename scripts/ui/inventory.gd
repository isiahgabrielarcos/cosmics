extends Control

# The in-run inventory: a panel that slides in from the left edge, plus a
# sidebar of ability icons down its right side that stays on screen when the
# panel is closed.
#
# Everything visible is authored in scenes/ui/inventory.tscn (and the small
# component scenes under scenes/ui/components/) — this script only fills those
# nodes in. Adjust the look in the editor, not here.
#
# Having the panel open does NOT stop you shooting. Only a click that lands on
# the tab or an icon is swallowed, and only until the button comes back up.

const CLOSED_X := -531.0
const OPEN_X := -20.0
const PANEL_Y := 219.0
const SLIDE_TIME := 0.3

## Placeholder art until real icons exist — the weapon and skill sheets
## already have a frame per id, so those are reused; passives get a flat tint.
const WEAPON_SHEET := preload("res://assets/art/ui/weaponArray.png")
const SKILL_SHEET := preload("res://assets/art/ui/skillArray.png")

## Passives that claim a sidebar slot once owned, in slot order. `flag` is the
## ModuleSystem property that turns them on, `timer` the key its cooldown
## Timer lives under.
const COOLDOWN_PASSIVES := [
	{ "flag": "got_comet_module", "timer": "comet",
	  "name": "Comet Shower", "tint": Color(0.55, 0.75, 1.0) },
	{ "flag": "got_shockwave_module", "timer": "shockwave",
	  "name": "Shock Wave", "tint": Color(1.0, 0.9, 0.4) },
	{ "flag": "got_electro_bubbles_module", "timer": "electro_bubbles",
	  "name": "Electro Bubbles", "tint": Color(0.6, 1.0, 0.85) },
	{ "flag": "got_energy_outburst_module", "timer": "energy_outburst",
	  "name": "Energy Outburst", "tint": Color(1.0, 0.6, 0.45) },
	{ "flag": "got_force_field_module", "timer": "force_field",
	  "name": "Force Field", "tint": Color(0.8, 0.8, 1.0) },
	{ "flag": "got_super_shield_module", "timer": "super_shield",
	  "name": "Super Shield", "tint": Color(1.0, 0.5, 0.55) },
]

const RARITY_ORDER := ["common", "rare", "epic", "legendary", "godly"]

## Order matters — _refresh_stats writes each row by index.
const STAT_LABELS := [
	"Health", "Shield", "Damage", "Ammo", "Pierce", "Speed", "Fire Rate", "Reload",
]

const MODULE_ROW := preload("res://scenes/ui/components/module_row.tscn")

@onready var panel: Control = $Inventory
@onready var _stats_box: VBoxContainer = $Inventory/Content/Stats
@onready var _currencies: HBoxContainer = $Inventory/Content/Currencies
@onready var _rarity_counts: HBoxContainer = $Inventory/Content/RarityCounts
@onready var _surrender: Label = $Inventory/Content/SurrenderValue
@onready var _module_list: VBoxContainer = $Inventory/Content/ModuleScroll/ModuleList
@onready var _sidebar: VBoxContainer = $Inventory/Sidebar
@onready var _tooltip: PanelContainer = $Inventory/TooltipPanel
@onready var _tooltip_name: Label = $Inventory/TooltipPanel/MarginContainer/Box/ModuleName
@onready var _tooltip_desc: Label = $Inventory/TooltipPanel/MarginContainer/Box/ModuleDesc

var is_open: bool = false

var _player: Node = null
var _weapon_system: Node = null
var _module_system: Node = null

var _slots: Array = []
var _stat_rows: Array = []
var _slide: Tween = null
var _icon_cache: Dictionary = {}


func _ready() -> void:
	panel.position = Vector2(CLOSED_X, PANEL_Y)
	_tooltip.visible = false
	_bind_slots()
	_build_stat_rows()
	call_deferred("_connect_to_player")
	GameManager.modules_changed.connect(_refresh_modules)
	_refresh_modules()


func _process(_delta: float) -> void:
	_update_slots()
	if is_open:
		_refresh_stats()


# ── Open / close ──────────────────────────────────────────────────────────────

func _on_open_close_pressed() -> void:
	# Pressing the tab is a UI action, not a trigger pull
	GameManager.ui_click_swallowed = true
	toggle()


func toggle() -> void:
	is_open = not is_open
	if _slide and _slide.is_valid():
		_slide.kill()
	_slide = create_tween()
	_slide.tween_property(panel, "position:x", OPEN_X if is_open else CLOSED_X, SLIDE_TIME)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	if is_open:
		_refresh_stats()
		_refresh_modules()
	else:
		_tooltip.visible = false
	AudioManager.play_sfx("switchMode")


func _connect_to_player() -> void:
	var players := get_tree().get_nodes_in_group("friendlies")
	if players.is_empty():
		return
	_player = players[0]
	_weapon_system = _player.get_node_or_null("WeaponSystem")
	_module_system = _player.get_node_or_null("ModuleSystem")
	_refresh_stats()
	_refresh_modules()


# ── Sidebar ───────────────────────────────────────────────────────────────────

func _bind_slots() -> void:
	_slots.clear()
	for child in _sidebar.get_children():
		if child is IconSlot:
			_slots.append(child)
	if _slots.size() < 2:
		return

	_slots[0].kind = "weapon"
	_slots[0].title = "Weapon"
	_slots[1].kind = "skill"
	_slots[1].title = "Special"

	for i in COOLDOWN_PASSIVES.size():
		var index := 2 + i
		if index >= _slots.size():
			break
		var passive: Dictionary = COOLDOWN_PASSIVES[i]
		var slot: IconSlot = _slots[index]
		slot.kind = "passive"
		slot.flag = passive["flag"]
		slot.timer_key = passive["timer"]
		slot.title = passive["name"]
		slot.icon.modulate = passive["tint"]

	for slot in _slots:
		slot.clicked.connect(_on_slot_clicked)


func _on_slot_clicked(slot: IconSlot) -> void:
	_show_tooltip(slot.title, slot.description)


func _update_slots() -> void:
	if _weapon_system == null or _module_system == null or _slots.size() < 2:
		return

	_slot_weapon(_slots[0])
	_slot_skill(_slots[1])
	for i in COOLDOWN_PASSIVES.size():
		var index := 2 + i
		if index < _slots.size():
			_slot_passive(_slots[index])


func _slot_weapon(slot: IconSlot) -> void:
	var id: int = _weapon_system.primary_weapon if _weapon_system.is_primary_selected \
		else _weapon_system.secondary_weapon
	# Swapping weapons swaps the icon
	if slot.content_id != id:
		slot.content_id = id
		slot.icon.texture = _sheet_icon(WEAPON_SHEET, id)
		slot.title = "Weapon %d" % id
	slot.description = "Ammo %d / %d" % [_weapon_system.current_ammo, _weapon_system.ammo_capacity]

	if _weapon_system.reloading:
		var timer: Timer = _weapon_system._reload_timer
		slot.set_cooldown(timer.time_left / maxf(timer.wait_time, 0.01), "%.1f" % timer.time_left)
	else:
		slot.set_cooldown(0.0, str(_weapon_system.current_ammo))


func _slot_skill(slot: IconSlot) -> void:
	var id: int = _module_system.skill_slot
	if slot.content_id != id:
		slot.content_id = id
		slot.icon.texture = _sheet_icon(SKILL_SHEET, id)
		slot.title = "Special %d" % id
	slot.description = "Your equipped special. Press Space to use."

	if _module_system.skill_ready:
		slot.set_cooldown(0.0, "")
	else:
		var left: float = _module_system._skill_cd_left
		var total: float = maxf(_module_system._skill_cd_total, 0.01)
		slot.set_cooldown(left / total, str(ceili(left)))


func _slot_passive(slot: IconSlot) -> void:
	var owned: bool = _module_system.get(slot.flag)
	slot.set_owned(owned)

	if not owned:
		# Empty but visible, so you can see what there's room for
		slot.set_cooldown(0.0, "")
		slot.description = "Empty slot — fit a %s module." % slot.title
		return

	slot.description = "%s is fitted and cycling automatically." % slot.title
	var timer: Timer = _module_system._timers.get(slot.timer_key)
	if timer == null:
		slot.set_cooldown(0.0, "")
		return
	slot.set_cooldown(timer.time_left / maxf(timer.wait_time, 0.01), str(ceili(timer.time_left)))


func _sheet_icon(sheet: Texture2D, id: int) -> AtlasTexture:
	var key := "%s_%d" % [sheet.resource_path, id]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	@warning_ignore("integer_division")
	atlas.region = Rect2(((id - 1) % 3) * 128, ((id - 1) / 3) * 128, 128, 128)
	_icon_cache[key] = atlas
	return atlas


# ── Tooltip ───────────────────────────────────────────────────────────────────

func _show_tooltip(title: String, desc: String) -> void:
	if desc == "":
		return
	_tooltip_name.text = title
	_tooltip_desc.text = desc
	_tooltip.visible = true


# ── Stats ─────────────────────────────────────────────────────────────────────

func _build_stat_rows() -> void:
	for i in STAT_LABELS.size():
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 15)
		_stats_box.add_child(row)
		_stat_rows.append(row)


## Rows are written in place. This runs every frame while the panel is open,
## so rebuilding the labels here would both churn nodes and double them up —
## queue_free() only takes effect at the end of the frame.
func _refresh_stats() -> void:
	if _player == null or _weapon_system == null:
		return
	var st: Dictionary = SaveManager.stats_data
	_stat_int(0, _player.max_hp, int(st.get("baseHealth", 100)))
	_stat_int(1, _player.max_shield, int(st.get("baseShield", 50)))
	_stat_int(2, _weapon_system.base_damage, _weapon_system.starting_damage)
	_stat_int(3, _weapon_system.ammo_capacity,
		_weapon_system.ammo_capacity - _weapon_system.bonus_ammo)
	_stat_int(4, 2 + _weapon_system.bonus_pierce, 2)
	_stat_float(5, 1.0 + _player.speed_bonus, 1.0)
	_stat_float(6, _weapon_system.attack_speed, 0.25, true)
	_stat_float(7, _weapon_system.reload_time, 2.0, true)


## "Health   140 (100 + 40)" — the summed value first, then where it came from.
func _stat_int(index: int, total: int, base: int) -> void:
	var row: Label = _stat_rows[index]
	var added := total - base
	row.text = "%-11s %d  (%d + %d)" % [STAT_LABELS[index], total, base, added]
	row.add_theme_color_override("font_color",
		Color(0.72, 0.75, 0.8) if added == 0 else Color(0.6, 1.0, 0.7))


func _stat_float(index: int, total: float, base: float, lower_is_better := false) -> void:
	var row: Label = _stat_rows[index]
	var delta := total - base
	row.text = "%-11s %.2f  (%.2f %s %.2f)" % [
		STAT_LABELS[index], total, base, "-" if delta < 0.0 else "+", absf(delta)]
	var tint := Color(0.72, 0.75, 0.8)
	if not is_zero_approx(delta):
		tint = Color(0.6, 1.0, 0.7) if (delta < 0.0) == lower_is_better else Color(1.0, 0.7, 0.6)
	row.add_theme_color_override("font_color", tint)


# ── Hold / modules ────────────────────────────────────────────────────────────

func _refresh_modules() -> void:
	if _currencies == null:
		return

	# Currency icons are placeholder ColorRects until the real art exists
	var pd: Dictionary = SaveManager.player_data
	_set_chip(_currencies.get_node("Gems"), Color(0.6, 1.0, 0.85), int(pd.get("gems", 0)))
	_set_chip(_currencies.get_node("Shards"), Color(0.75, 0.6, 1.0), int(pd.get("shards", 0)))
	_set_chip(_currencies.get_node("Central"), Color(1.0, 0.85, 0.4),
		int(pd.get("centralCurrency", 0)))

	for i in RARITY_ORDER.size():
		var rarity: String = RARITY_ORDER[i]
		var label := _rarity_counts.get_child(i) as Label
		label.text = "%s %d" % [rarity.substr(0, 3).to_upper(),
			int(GameManager.modules_taken.get(rarity, 0))]
		label.add_theme_color_override("font_color", ModuleRegistry.RARITY_COLORS[rarity])

	_surrender.text = "Surrender value: %d CC  (%d on failure)" % [
		GameManager.modules_payout(true), GameManager.modules_payout(false)]

	_clear(_module_list)
	for i in range(GameManager.module_log.size() - 1, -1, -1):
		_module_row(GameManager.module_log[i])


func _set_chip(chip: Node, tint: Color, amount: int) -> void:
	(chip.get_node("Icon") as ColorRect).color = tint
	(chip.get_node("Amount") as Label).text = str(amount)


func _module_row(entry: Dictionary) -> void:
	var row: Button = MODULE_ROW.instantiate()
	row.text = entry["name"]
	row.add_theme_color_override("font_color", ModuleRegistry.RARITY_COLORS[entry["rarity"]])
	row.pressed.connect(func():
		GameManager.ui_click_swallowed = true
		_show_tooltip(entry["name"], entry["desc"]))
	_module_list.add_child(row)


## Detaches before freeing. queue_free() alone leaves the node in the tree
## until the end of the frame, so a rebuild in the same frame doubles the list.
func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
