extends Control

# The running list of contracts Toby has taken. Slides in from the right on the
# "contracts" action (Tab) or on the tab button stuck to its left edge, and
# slides back out on the next press.
#
# The root is a plain Control rather than its own CanvasLayer, so this drops
# straight into the player HUD alongside the rest of the on-screen furniture.
#
# The tab button is what makes the panel discoverable. It rides along with the
# panel inside `Slider`, and the closed position is chosen so the panel clears
# the screen while the button does not, leaving a visible handle at the edge
# rather than a keybind nobody knows about.
#
# Like the call panel it never pauses the run. You can open the list mid fight,
# read it, and close it again without the game stopping, so checking your jobs
# costs you tempo rather than nothing.
#
# Rows are instanced from scenes/ui/components/contract_row.tscn and show only
# the goal and the reward, which is all that has been agreed so far. Progress
# tracking comes later, when the objectives themselves exist.

@export var slide_time := 0.35

## Extra gap past the panel's own width when closed. Raise it to tuck the tab
## button further off screen, lower it to leave more of the panel peeking.
@export var hidden_margin := 0.0

## How much of the screen edge the closed tab button keeps clear of. The closed
## position is clamped so the button always lands inside the viewport by at
## least this much, whatever the panel is positioned at.
@export var tab_visible_margin := 8.0

## Overrides the Padding node's margins when above zero. Left at zero the
## values authored on that node in the scene are used as they are.
@export var content_padding := 0

const ROW_SCENE := preload("res://scenes/ui/components/contract_row.tscn")

@onready var _slider: Control          = $Slider
@onready var _panel: Control           = $Slider/Panel
@onready var _tab: BaseButton          = $Slider/TabButton
@onready var _padding: MarginContainer = $Slider/Panel/Padding
@onready var _list: VBoxContainer      = $Slider/Panel/Padding/Body/Scroll/List
@onready var _empty: Label             = $Slider/Panel/Padding/Body/EmptyLabel
@onready var _count: Label             = $Slider/Panel/Padding/Body/Header/CountLabel

var _slide: Tween = null
var _rest_x := 0.0
## Measured closed position. INF until layout has settled.
var _closed_x := INF

var is_open := false


func _ready() -> void:
	add_to_group("contracts_panel")
	_apply_padding()
	# Hidden until parked. The open position is read from the scene, but a
	# Control inside a parent that starts invisible (the hub HUD does) has not
	# had its anchors resolved yet at _ready, so reading it here gave a raw
	# offset and parked the panel in the middle of the screen.
	_slider.visible = false
	# Sizes are not final until the containers have laid out, and the closed
	# position depends on both the panel's width and the tab's. Re-park once
	# they are, or the tab can start off screen on the very first frame.
	call_deferred("_park_closed")

	_tab.pressed.connect(_on_tab_pressed)
	GameManager.contracts_changed.connect(_rebuild)
	_rebuild()


func _apply_padding() -> void:
	if content_padding <= 0:
		return
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_padding.add_theme_constant_override(side, content_padding)


## Closed means the panel itself is off screen while the tab button stays on
## it. The button rides to the left of the panel inside the same slider, so
## sliding by exactly the panel's width would put it flush against the right
## edge — and any authored position further right pushed it clean off screen,
## which left the list openable only by a key nobody had been told about.
##
## The result is therefore clamped: whatever the panel is placed at, the closed
## position never moves the tab past the edge of the viewport.
func _hidden_x() -> float:
	# Measured once after layout; until then, fall back to the naive slide.
	if _closed_x != INF:
		return _closed_x
	return _rest_x + _panel.size.x + hidden_margin


## Parks the slider closed and then pulls it back by however much the tab
## button overshoots the right edge.
##
## Deriving this from the authored offsets did not work: a TextureButton's real
## width and position come from its minimum size after layout, not from the
## numbers in the scene, so the arithmetic was done against values that were
## still wrong. Measuring where the button actually landed cannot be.
func _park_closed() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_open:
		return

	_rest_x = _slider.position.x
	_slider.position.x = _rest_x + _panel.size.x + hidden_margin
	await get_tree().process_frame

	var edge := get_viewport_rect().size.x - tab_visible_margin
	var overshoot: float = (_tab.global_position.x + _tab.size.x) - edge
	if overshoot > 0.0:
		_slider.position.x -= overshoot
	_closed_x = _slider.position.x
	_slider.visible = true

	if not get_viewport().size_changed.is_connected(_recompute_closed):
		get_viewport().size_changed.connect(_recompute_closed)


## A resolution change moves the right edge, so the parked spot is remeasured.
func _recompute_closed() -> void:
	_closed_x = INF
	_park_closed()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("contracts"):
		return
	# Not while something modal is up, or Tab would slide the list in behind
	# the pause menu.
	if get_tree().paused or GameManager.ui_open or GameManager.game_done:
		return
	get_viewport().set_input_as_handled()
	toggle()


func _on_tab_pressed() -> void:
	# A click on the handle is a UI action, not a trigger pull.
	GameManager.ui_click_swallowed = true
	toggle()


func toggle() -> void:
	set_open(not is_open)


func set_open(open: bool) -> void:
	if is_open == open:
		return
	is_open = open
	AudioManager.play_sfx("switchMode")

	if _slide and _slide.is_valid():
		_slide.kill()
	_slide = create_tween()
	_slide.tween_property(_slider, "position:x", _rest_x if open else _hidden_x(), slide_time)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)


## Rebuilt wholesale rather than appended to, so the list can never drift out
## of step with what the run actually holds.
func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	# Open jobs first, finished ones sunk to the bottom, each group still in the
	# order it was taken. Completed contracts are kept rather than dropped: the
	# tail of the list is the run's receipt.
	var open_jobs: Array = []
	var done_jobs: Array = []
	for contract in GameManager.active_contracts:
		if bool(contract.get("complete", false)):
			done_jobs.append(contract)
		else:
			open_jobs.append(contract)

	for contract in open_jobs + done_jobs:
		var row := ROW_SCENE.instantiate()
		_list.add_child(row)
		row.fill(contract)

	_empty.visible = open_jobs.is_empty() and done_jobs.is_empty()
	# Reads as "what's still owed", which is the number that matters mid-run.
	_count.text = "%d / %d" % [done_jobs.size(), open_jobs.size() + done_jobs.size()]
