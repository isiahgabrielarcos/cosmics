extends CanvasLayer

@onready var battle_hud: Control = $Battle_HUD

@onready var health_bar: TextureProgressBar  = $Battle_HUD/HealthBar
@onready var shield_bar: TextureProgressBar  = $Battle_HUD/ShieldBar
@onready var exp_bar: TextureProgressBar     = $Battle_HUD/ExpBar
@onready var level_label: Label              = $Battle_HUD/LevelLabel
@onready var ammo_label: Label               = $Battle_HUD/AmmoLabel
@onready var reload_label: Label             = $Battle_HUD/ReloadLabel
@onready var health_label: Label             = $Battle_HUD/HealthLabel
@onready var dash_label: Label               = $Battle_HUD/DashLabel
@onready var exp_label: Label                = $Battle_HUD/ExpLabel
@onready var timer_label: Label              = $Battle_HUD/TimerLabel
@onready var kills_label: Label              = $Battle_HUD/KillsLabel
@onready var currency_label: Label           = $Battle_HUD/CurrencyLabel
@onready var pause_button: TextureButton     = $Battle_HUD/PauseButton

var _player: Node = null
var _weapon_system: Node = null

# Ammo readout counts up over the reload instead of snapping, so a weapon
# swap reads as "refilling to the new magazine" rather than a number jump.
var _ammo_tween: Tween = null
var _ammo_max: int = 0

# Health and dash both refill in discrete ticks. Driving the bars straight
# from those values makes them jump a chunk at a time; the bars instead chase
# the real value every frame so a refill reads as a slow creep. The numeric
# labels stay exact — only the fill is smoothed.
const BAR_CREEP_SPEED := 6.0
var _hp_display: float = -1.0
var _dash_display: float = -1.0


func _ready() -> void:
	
	
	if GameManager.is_hub():
		battle_hud.visible = true
		$Battle_HUD/Inventory2.hide()
	else:
		
		battle_hud.visible = true
		GameManager.mission_timer_updated.connect(_on_mission_timer)
		GameManager.enemy_killed_signal.connect(_on_enemy_killed)
		GameManager.currency_changed.connect(_on_currency_changed)
		_refresh_currency()

	get_viewport().size_changed.connect(_layout_for_viewport)
	_layout_for_viewport()

	pause_button.pressed.connect(_on_pause_button_pressed)

	call_deferred("_connect_to_player")


## Same effect as pressing Esc — routed through PauseMenu.toggle_pause() so
## the button can't drift out of sync with the key binding's own rules about
## when pausing is (and isn't) allowed (mid module-pick, already game-over...).
func _on_pause_button_pressed() -> void:
	# Pressing the on-screen button is a UI action, not a trigger pull.
	GameManager.ui_click_swallowed = true

	# Searched from the tree root rather than assumed to be a direct child of
	# current_scene: battle_scene.gd/cosmic_hub.gd instantiate it at runtime
	# and add_child() it, which never sets `owner` — so find_child's default
	# owned-only search would silently miss it. owned=false covers that.
	var pause_menu := get_tree().root.find_child("PauseMenu", true, false)
	if pause_menu and pause_menu.has_method("toggle_pause"):
		pause_menu.toggle_pause()
	else:
		push_warning("PlayerHUD: pause button pressed but no PauseMenu found in the tree.")


## Re-places any nodes that can't anchor themselves (Sprite2D, etc.) whenever
## the window is resized. Nothing currently needs it — kept as the hook to
## use if a node like that gets added back to Battle_HUD.
func _layout_for_viewport() -> void:
	pass


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



func _process(delta: float) -> void:
	# The hub's Toby is a different character script with no hp/shield — the
	# battle bars only exist to be driven when the battle HUD is up.
	if _player == null or not battle_hud.visible:
		return
	if _hp_display < 0.0 or _dash_display < 0.0:
		return
	# Eased toward the true value rather than set to it, so a regen tick
	# fills the bar smoothly instead of snapping a block into place.
	var weight := clampf(BAR_CREEP_SPEED * delta, 0.0, 1.0)
	_hp_display = lerpf(_hp_display, float(_player.hp), weight)
	_dash_display = lerpf(_dash_display, _player.shield, weight)
	health_bar.value = _hp_display
	shield_bar.value = _dash_display


# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_hp_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	if _hp_display < 0.0:
		_hp_display = float(current)     # first read snaps, later ones creep
		health_bar.value = current
	health_label.text = "%d / %d" % [maxi(0, current), maximum]


## The shield bar doubles as dash fuel, so it's labelled as the dash meter.
func _on_shield_changed(current: float, maximum: int) -> void:
	shield_bar.max_value = maximum
	if _dash_display < 0.0:
		_dash_display = current
		shield_bar.value = current
	dash_label.text = "DASH %d / %d" % [int(floor(current)), maximum]


func _on_ammo_changed(current: int, maximum: int, reloading: bool) -> void:
	if _ammo_tween and _ammo_tween.is_valid():
		_ammo_tween.kill()
		_ammo_tween = null

	_ammo_max = maximum
	reload_label.visible = reloading

	if not reloading:
		_set_ammo_display(float(current))
		return

	var duration: float = 2.0
	if _weapon_system:
		duration = _weapon_system.reload_time
	_ammo_tween = create_tween()
	_ammo_tween.tween_method(_set_ammo_display, float(current), float(maximum), duration)


func _set_ammo_display(value: float) -> void:
	ammo_label.text = "%d / %d" % [int(round(value)), _ammo_max]


func _on_xp_changed(current: int, required: int, lv: int) -> void:
	exp_bar.max_value = required
	exp_bar.value = current
	level_label.text = "LVL %d" % lv
	exp_label.text = "XP %d / %d" % [current, required]


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
