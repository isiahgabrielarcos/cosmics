extends Control

# The hub's objectives list: what the story wants from you right now, as
# opposed to the contracts you pick up mid-run.
#
# Deliberately the same object as the contracts panel from the player's side —
# same right edge, same slide, same tab button, same Tab key. The two never
# appear together (contracts are battle only, objectives are hub only), so one
# key and one habit covers both.
#
# Steps live on GameManager so ticking one off before a mission is still ticked
# off when the hub reloads afterwards.

@export var slide_time := 0.35

## Extra gap past the panel's own width when closed.
@export var hidden_margin := 0.0

## How much of the screen edge the closed tab button keeps clear of, so it is
## always grabbable whatever the panel is positioned at.
@export var tab_visible_margin := 8.0

## Overrides the Padding node's margins when above zero.
@export var content_padding := 0

const ROW_SCENE := preload("res://scenes/ui/components/objective_row.tscn")

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
	add_to_group("objectives_panel")
	_apply_padding()
	# Hidden until parked. The open position is read from the scene, but a
	# Control inside a parent that starts invisible (the hub HUD does) has not
	# had its anchors resolved yet at _ready, so reading it here gave a raw
	# offset and parked the panel in the middle of the screen.
	_slider.visible = false
	call_deferred("_park_closed")

	_tab.pressed.connect(_on_tab_pressed)
	GameManager.objectives_changed.connect(_rebuild)
	_rebuild()


func _apply_padding() -> void:
	if content_padding <= 0:
		return
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_padding.add_theme_constant_override(side, content_padding)


## Clamped so the tab button always lands inside the viewport, however far
## right the panel itself is placed.
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
	if get_tree().paused or GameManager.ui_open:
		return
	get_viewport().set_input_as_handled()
	toggle()


func _on_tab_pressed() -> void:
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


## Open steps first, finished ones sunk to the bottom, each group keeping the
## order it was added in.
func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var open_steps: Array = []
	var done_steps: Array = []
	for objective in GameManager.narrative_objectives:
		if bool(objective.get("done", false)):
			done_steps.append(objective)
		else:
			open_steps.append(objective)

	for objective in open_steps + done_steps:
		var row := ROW_SCENE.instantiate()
		_list.add_child(row)
		row.fill(objective)

	_empty.visible = open_steps.is_empty() and done_steps.is_empty()
	_count.text = "%d / %d" % [done_steps.size(), open_steps.size() + done_steps.size()]
