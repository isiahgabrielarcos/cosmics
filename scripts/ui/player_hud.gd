extends CanvasLayer

@onready var battle_hud: Control = $Battle_HUD
@onready var hub_hud: Control = $Hub_HUD

@onready var health_bar: TextureProgressBar  = $Battle_HUD/HealthBar
@onready var shield_bar: TextureProgressBar  = $Battle_HUD/ShieldBar
@onready var exp_bar: TextureProgressBar     = $Battle_HUD/ExpBar
@onready var level_label: Label              = $Battle_HUD/LevelLabel
@onready var ammo_label: Label               = $Battle_HUD/AmmoLabel
@onready var reload_label: Label             = $Battle_HUD/ReloadLabel
@onready var weapon_label: Label             = $Battle_HUD/WeaponLabel
@onready var skill_label: Label              = $Battle_HUD/SkillLabel
@onready var timer_label: Label              = $Battle_HUD/TimerLabel
@onready var kills_label: Label              = $Battle_HUD/KillsLabel
@onready var currency_label: Label           = $Battle_HUD/CurrencyLabel

var _player: Node = null
var _weapon_system: Node = null


func _ready() -> void:
	
	
	if GameManager.is_hub():
		battle_hud.visible = false
		hub_hud.visible = true
	else:
		
		battle_hud.visible = true
		hub_hud.visible = false
		GameManager.mission_timer_updated.connect(_on_mission_timer)
		GameManager.enemy_killed_signal.connect(_on_enemy_killed)
		GameManager.currency_changed.connect(_on_currency_changed)
		_refresh_currency()

	call_deferred("_connect_to_player")


func _process(_delta: float) -> void:
	if _weapon_system:
		var slot: int = _weapon_system.primary_weapon if _weapon_system.is_primary_selected \
			else _weapon_system.secondary_weapon
		var tag := "PRI" if _weapon_system.is_primary_selected else "SEC"
		weapon_label.text = "%s W%d" % [tag, slot]


# ── Connect to the player node ─────────────────────────────────────────────────

func _connect_to_player() -> void:
	var players := get_tree().get_nodes_in_group("friendlies")
	if players.is_empty():
		push_warning("PlayerHUD: no node in group 'friendlies' found.")
		return

	_player = players[0]

	if _player.has_signal("hp_changed"):
		_player.hp_changed.connect(_on_hp_changed)
		_on_hp_changed(_player.hp, _player.max_hp)
	if _player.has_signal("shield_changed"):
		_player.shield_changed.connect(_on_shield_changed)
		_on_shield_changed(_player.shield, _player.max_shield)
	if _player.has_signal("ammo_changed"):
		_player.ammo_changed.connect(_on_ammo_changed)
	if _player.has_signal("xp_changed"):
		_player.xp_changed.connect(_on_xp_changed)
		_on_xp_changed(_player.current_exp, _player.exp_to_next_level, _player.level)

	_weapon_system = _player.get_node_or_null("WeaponSystem")
	if _weapon_system:
		_on_ammo_changed(_weapon_system.current_ammo, _weapon_system.ammo_capacity, false)

	var module_system = _player.get_node_or_null("ModuleSystem")
	if module_system and module_system.has_signal("skill_cooldown_changed"):
		module_system.skill_cooldown_changed.connect(_on_skill_cooldown)


# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_hp_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_shield_changed(current: float, maximum: int) -> void:
	shield_bar.max_value = maximum
	shield_bar.value = current


func _on_ammo_changed(current: int, maximum: int, reloading: bool) -> void:
	ammo_label.text = "%d / %d" % [current, maximum]
	reload_label.visible = reloading


func _on_xp_changed(current: int, required: int, lv: int) -> void:
	exp_bar.max_value = required
	exp_bar.value = current
	level_label.text = "LVL %d" % lv


func _on_skill_cooldown(remaining: float, _total: float) -> void:
	if remaining <= 0.0:
		skill_label.text = "SKILL READY"
		skill_label.modulate = Color(0.5, 1.0, 0.6)
	else:
		skill_label.text = "SKILL %ds" % ceili(remaining)
		skill_label.modulate = Color(1.0, 0.7, 0.3)


func _on_mission_timer(display_seconds: float, _count_up: bool) -> void:
	var total := int(display_seconds)
	@warning_ignore("integer_division")
	timer_label.text = "%02d:%02d" % [total / 60, total % 60]


func _on_enemy_killed(_experience: int) -> void:
	kills_label.text = "Kills: %d" % GameManager.enemies_killed


func _on_currency_changed(gems: int, shards: int, central: int) -> void:
	currency_label.text = "Gems: %d   Shards: %d   CC: %d" % [gems, shards, central]


func _refresh_currency() -> void:
	var pd: Dictionary = SaveManager.player_data
	_on_currency_changed(
		int(pd.get("gems", 0)),
		int(pd.get("shards", 0)),
		int(pd.get("centralCurrency", 0)))
