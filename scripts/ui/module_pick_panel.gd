extends CanvasLayer
class_name ModulePickPanel

# The level-up / module-chest reward screen. Freeze the run, deal three cards,
# let the player take one.
#
# Layout is authored in scenes/ui/panels/module_pick_panel.tscn — three
# ModuleCard instances under Root/Cards, plus the dim and the title. Nothing
# here builds UI; it only fills the cards in and runs the deal.
#
# The cards are revealed SPAWN_STAGGER apart and each starts bobbing with a
# phase matching its place in that order, so the row reads as a travelling
# wave rather than three things moving as one. That's the whole reason the
# deal is staggered.
#
# Runs on PROCESS_MODE_ALWAYS so it keeps animating while the tree is paused.

signal picked

const SPAWN_STAGGER := 0.2     # delay between cards being revealed
const FADE_TIME := 0.35        # alpha 0 -> 1 as each lands
const DIM_ALPHA := 0.72

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _cards_root: Control = $Root/Cards
@onready var picking_timer: Timer = $PickingTimer

var _cards: Array = []
var _resolved: bool = false
var pickingTimerDone: bool = false

var _player: Node = null
var _weapon_system: Node = null
var _module_system: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	for child in _cards_root.get_children():
		if child is ModuleCard:
			_cards.append(child)
			(child as ModuleCard).chosen.connect(_on_card_chosen)
	print(pickingTimerDone)

# ── Opening ───────────────────────────────────────────────────────────────────

func open() -> void:
	var players := get_tree().get_nodes_in_group("friendlies")
	if players.is_empty():
		return
	_player = players[0]
	_weapon_system = _player.get_node_or_null("WeaponSystem")
	_module_system = _player.get_node_or_null("ModuleSystem")
	if _weapon_system == null or _module_system == null:
		return

	_resolved = false
	visible = true
	GameManager.ui_open = true
	get_tree().paused = true

	_root.modulate.a = 1.0
	_dim.color.a = 0.0
	create_tween().tween_property(_dim, "color:a", DIM_ALPHA, FADE_TIME)

	pickingTimerDone = false
	picking_timer.start()

	_deal_cards()


func _deal_cards() -> void:
	for i in _cards.size():
		var card: ModuleCard = _cards[i]
		card.modulate.a = 0.0
		card.visible = true

		var rarity := ModuleRegistry.roll_rarity()
		var option: Dictionary = ModuleRegistry.roll_option(
			rarity, _player, _weapon_system, _module_system)
		# The phase offset mirrors the deal delay, which is what turns three
		# independent bobs into one wave down the row.
		card.setup(rarity, option, float(i) * SPAWN_STAGGER * TAU / card.bob_period)

		get_tree().create_timer(i * SPAWN_STAGGER, true, false, true)\
			.timeout.connect(_reveal_card.bind(card))


func _reveal_card(card: ModuleCard) -> void:
	if not visible or not is_instance_valid(card):
		return
	AudioManager.play_sfx("pickedMode1")
	create_tween().tween_property(card, "modulate:a", 1.0, FADE_TIME)


# ── Choosing ──────────────────────────────────────────────────────────────────

func _on_card_chosen(card: ModuleCard) -> void:
	# The cards are still fading in and bobbing when the first click lands —
	# without this guard a fast double-click banks two upgrades.
	if _resolved:
		return
	_resolved = true

	var option: Dictionary = card.option
	if option.has("apply"):
		(option["apply"] as Callable).call()
		# A scrap payout isn't a module, so it doesn't go on the guild ledger
		GameManager.record_module(card.rarity, option["name"], option["desc"])
	elif option.has("scrap"):
		ModuleRegistry.grant_scrap(option["scrap"])

	AudioManager.play_sfx("moduleChest")
	picked.emit()

	# A chest can owe several rounds in a row — deal the next hand rather than
	# handing control back.
	if GameManager.pending_module_picks > 0:
		GameManager.pending_module_picks -= 1
		_fade_out(open)
	else:
		_fade_out(_close)


func _fade_out(on_done: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.25)
	tw.tween_callback(on_done)


func _close() -> void:
	visible = false
	GameManager.ui_open = false
	get_tree().paused = false
	for card in _cards:
		card.modulate.a = 0.0


func _on_picking_timer_timeout() -> void:
	pickingTimerDone = true
	print("THen True")
