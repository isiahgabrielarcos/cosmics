extends Node

# Drives the mid-run contract calls.
#
# Toby gets a call on a timer. Take the job and the next one is a full
# interval away; turn it down and they call back sooner, because a refusal
# means the guild still has work sitting on the board. That asymmetry is the
# whole rule: declining is not free time, it just moves the interruption
# closer. Letting a call time out on screen counts as a refusal too.
#
# The system owns the timing and the roll. The two panels own the
# presentation, and GameManager owns the list of what has been taken, so the
# accepted contracts survive the UI being rebuilt.
#
# The panels are found by group rather than held as children, because they
# live in the player HUD where the rest of the on-screen furniture is. That
# also means moving them around in the HUD scene cannot quietly unhook them,
# which an exported NodePath very much can.
#
# Accepting currently records the contract and nothing more. The objectives
# and payouts come later; this is the offer loop on its own.

const ContractRegistry := preload("res://scripts/systems/contract_registry.gd")
const EscortCargoScene := preload("res://scenes/environment/escort_cargo.tscn")
const CitadelScene := preload("res://scenes/environment/cosmic_citadel.tscn")

const CALL_PANEL_GROUP := "contract_call_panel"
const LIST_PANEL_GROUP := "contracts_panel"

# ── Objectives ────────────────────────────────────────────────────────────────
# Kill and collect contracts are counted by GameManager wherever the thing
# already happens, so they need nothing here. Two kinds do need this node:
#
#   haul_*         puts a physical cargo on the ship and a citadel to fly it
#                  to, and completes on arrival.
#   gauge_onscreen is a live reading of how many fiends are in view, so it has
#                  to be sampled rather than counted.

## escortAssets.png frames per haul. The sheet's top row is a 3x3 grid of
## 48x48: 0 and 2 are supply crates, 1 is the medical ship.
const HAUL_FRAMES := {
	"haul_supply": [0, 2],
	"haul_ship": [1],
}

## How far out the citadel is placed. A long way, deliberately: the haul is
## paid for the whole trip at reduced speed.
@export var citadel_distance_min := 10000.0
@export var citadel_distance_max := 30000.0

## How often the on-screen fiend count is sampled. Every frame would be waste
## for a number that only has to be roughly right.
@export var gauge_interval := 0.4

## Extra margin around the camera view counted as "on screen", so a fiend
## clipping the edge still counts.
@export var gauge_margin := 120.0

## Seconds until the next call. Accepting pays the full wait; declining, or
## ignoring a call until it hangs up, brings the next one forward.
@export var interval_accepted := 120.0
@export var interval_declined := 60.0

## Wait before the very first call of a run. Short on purpose: a job offered
## early gives the run a shape from the outset rather than two silent minutes.
@export var first_call_delay := 30.0

## Stop offering once this many are open. Zero means no limit.
@export var max_active := 0

## Calls only happen in a real mission. The hub has the NPCs themselves.
@export var skip_in_hub := true

var _rng := RandomNumberGenerator.new()
var _timer: Timer
var _pending := false
var _call_panel: Node = null
var _contracts_panel: Node = null
var _gauge_clock := 0.0
var _caller_bag: Array = []


func _ready() -> void:
	_rng.randomize()

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_call_due)
	add_child(_timer)

	if skip_in_hub and GameManager.is_hub():
		return
	# Deferred: the HUD that owns the panels is a sibling and may not have
	# readied yet when this does.
	call_deferred("_begin")


func _begin() -> void:
	if not _bind_panels():
		push_warning("ContractSystem: no contract panels found in the tree; calls disabled.")
		return
	_timer.start(first_call_delay)


func _bind_panels() -> bool:
	_call_panel = get_tree().get_first_node_in_group(CALL_PANEL_GROUP)
	_contracts_panel = get_tree().get_first_node_in_group(LIST_PANEL_GROUP)
	if _call_panel == null:
		return false
	_call_panel.accepted.connect(_on_accepted)
	_call_panel.declined.connect(_on_declined)
	return true


func _on_call_due() -> void:
	# A run that has already ended should not ring. Nor should a second call
	# stack on top of one still waiting to be answered.
	if GameManager.game_done or _pending or _call_panel == null:
		return
	if max_active > 0 and GameManager.active_contracts.size() >= max_active:
		# Full book: check back on the shorter interval rather than going quiet
		# for the rest of the run.
		_timer.start(interval_declined)
		return

	_pending = true
	_call_panel.present(ContractRegistry.roll_for(_next_caller(), _rng))


## Callers are dealt from a shuffled bag rather than rolled independently.
##
## A plain uniform roll already gives each of the five an equal 20% chance, and
## measuring it confirms that — but independent draws clump, so a run can
## genuinely hand you the same person four times in eight calls and it reads as
## favouritism. Dealing the whole cast before reshuffling keeps the same average
## while guaranteeing you hear from everyone once per five calls.
func _next_caller() -> String:
	if _caller_bag.is_empty():
		_caller_bag = ContractRegistry.CALLERS.keys()
		_caller_bag.shuffle()
	return _caller_bag.pop_back()


func _on_accepted(contract: Dictionary) -> void:
	_pending = false
	GameManager.add_contract(contract)
	if HAUL_FRAMES.has(str(contract.get("task_id", ""))):
		_begin_haul(contract)
	_timer.start(interval_accepted)


# ── Haul contracts ────────────────────────────────────────────────────────────

## Drops a citadel a long way off in a random direction and ropes the cargo to
## the ship. Only one haul runs at a time: a second crate on the same rope
## would stack the speed penalty and read as a bug rather than a challenge.
func _begin_haul(contract: Dictionary) -> void:
	var player := _find_player()
	if player == null:
		return
	if not get_tree().get_nodes_in_group("escort_cargo").is_empty():
		return

	var scene_root := get_tree().current_scene

	var citadel := CitadelScene.instantiate()
	var bearing := randf() * TAU
	var distance := randf_range(citadel_distance_min, citadel_distance_max)
	scene_root.add_child(citadel)
	citadel.global_position = player.global_position + Vector2.RIGHT.rotated(bearing) * distance

	var frames: Array = HAUL_FRAMES[str(contract["task_id"])]
	var cargo := EscortCargoScene.instantiate()
	cargo.frame = int(frames[randi() % frames.size()])
	scene_root.add_child(cargo)
	cargo.attach(player, citadel)

	# Arrival is the citadel's call; it owns the distance check.
	citadel.reached.connect(func():
		if is_instance_valid(cargo):
			cargo.complete()
		if is_instance_valid(citadel):
			citadel.mark_delivered()
		GameManager.advance_contracts(str(contract["task_id"]),
			int(contract.get("target", 1))), CONNECT_ONE_SHOT)


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("friendlies")
	return players[0] if not players.is_empty() else null


# ── On-screen fiend gauge ─────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if GameManager.game_done:
		return
	_gauge_clock -= delta
	if _gauge_clock > 0.0:
		return
	_gauge_clock = gauge_interval

	if GameManager.contracts_for("gauge_onscreen").is_empty():
		return
	GameManager.report_contract_gauge("gauge_onscreen", _count_enemies_on_screen())


func _count_enemies_on_screen() -> int:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return 0
	var view := get_viewport().get_visible_rect().size
	var rect := Rect2(camera.get_screen_center_position() - view * 0.5, view)\
		.grow(gauge_margin)

	var seen := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node2D and rect.has_point((enemy as Node2D).global_position):
			seen += 1
	return seen


func _on_declined(_contract: Dictionary) -> void:
	_pending = false
	_timer.start(interval_declined)


## Opens the list from outside, for a HUD button to call.
func toggle_contracts() -> void:
	if _contracts_panel != null:
		_contracts_panel.toggle()
