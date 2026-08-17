extends Control

# The incoming call that interrupts a run. Slides in from the right edge,
# shows who is calling, what they want and what it pays, and waits for Accept
# or Decline. Ignore it and it hangs up on its own, which counts as a decline.
#
# The root is a plain Control rather than its own CanvasLayer, so this drops
# straight into the player HUD next to everything else on screen instead of
# fighting it for a layer number.
#
# It deliberately does NOT pause the game or set GameManager.ui_open. A call
# arrives while you are flying and shooting, and freezing the run for it would
# turn a piece of texture into an interruption. The only concession is that
# pressing either button marks the click as UI so the same press does not also
# come out of the cannon, the same guard the HUD buttons use.
#
# Everything visual lives in scenes/ui/panels/contract_call_panel.tscn. This
# script only fills the labels in and runs the slide.

signal accepted(contract: Dictionary)
signal declined(contract: Dictionary)

## How long the slide takes, and how far past its resting spot the panel waits
## while hidden so no sliver of frame is left showing.
@export var slide_time := 0.45
@export var hidden_margin := 40.0

## Seconds a call stays on screen before it gives up and counts as declined.
## Zero disables the timeout and the call sits there until answered.
@export var auto_decline_after := 30.0

## Overrides the Padding node's margins when above zero. Left at zero the
## values authored on that node in the scene are used as they are.
@export var content_padding := 0

@onready var _panel: Control        = $Panel
@onready var _padding: MarginContainer = $Panel/Padding
@onready var _timer_label: Label    = $Panel/Padding/Body/TopRow/TimerLabel
@onready var _avatar: TextureRect   = $Panel/Padding/Body/AvatarRow/AvatarFrame/Avatar
@onready var _avatar_frame: Control = $Panel/Padding/Body/AvatarRow/AvatarFrame
@onready var _name: Label           = $Panel/Padding/Body/NameLabel
@onready var _role: Label           = $Panel/Padding/Body/RoleLabel
@onready var _goal: Label           = $Panel/Padding/Body/GoalValue
@onready var _reward: Label         = $Panel/Padding/Body/RewardValue
@onready var _accept: Button        = $Panel/Padding/Body/Buttons/AcceptButton
@onready var _decline: Button       = $Panel/Padding/Body/Buttons/DeclineButton

var _contract: Dictionary = {}
var _slide: Tween = null
var _open := false
var _timeout_left := 0.0

## Where the panel sits when shown, taken from wherever it is placed in the
## scene, so nudging it in the editor moves the resting spot.
var _rest_x := 0.0


func _ready() -> void:
	add_to_group("contract_call_panel")
	visible = false
	_apply_padding()
	_rest_x = _panel.position.x
	_panel.position.x = _hidden_x()

	_accept.pressed.connect(_on_accept)
	_decline.pressed.connect(_on_decline)


func _apply_padding() -> void:
	if content_padding <= 0:
		return
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_padding.add_theme_constant_override(side, content_padding)


func _process(delta: float) -> void:
	if not _open:
		return
	if auto_decline_after <= 0.0:
		_timer_label.visible = false
		return

	_timeout_left -= delta
	_timer_label.visible = true
	_timer_label.text = str(maxi(0, ceili(_timeout_left)))
	if _timeout_left <= 0.0:
		# Nobody answered. The guild takes that as a no.
		_on_decline()


func _hidden_x() -> float:
	return _rest_x + _panel.size.x + hidden_margin


## Shows an offer produced by ContractRegistry.roll().
func present(contract: Dictionary) -> void:
	_contract = contract

	_name.text = str(contract.get("name", ""))
	_role.text = str(contract.get("role", ""))
	_goal.text = str(contract.get("goal", ""))
	_reward.text = str(contract.get("reward", ""))

	var avatar_path := str(contract.get("avatar", ""))
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		_avatar.texture = load(avatar_path)
		_avatar_frame.visible = true
	else:
		_avatar_frame.visible = false

	visible = true
	_open = true
	_timeout_left = auto_decline_after
	_timer_label.visible = auto_decline_after > 0.0
	_timer_label.text = str(int(auto_decline_after))
	AudioManager.play_sfx("interacting")
	_slide_to(_rest_x)


func _slide_to(target_x: float) -> void:
	if _slide and _slide.is_valid():
		_slide.kill()
	_slide = create_tween()
	_slide.tween_property(_panel, "position:x", target_x, slide_time)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _dismiss() -> void:
	_open = false
	if _slide and _slide.is_valid():
		_slide.kill()
	_slide = create_tween()
	_slide.tween_property(_panel, "position:x", _hidden_x(), slide_time)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_slide.tween_callback(func(): visible = false)


func _on_accept() -> void:
	if not _open:
		return
	# This click operated the UI, so it must not also fire the guns.
	GameManager.ui_click_swallowed = true
	AudioManager.play_sfx("pickedMode1")
	var taken := _contract
	_dismiss()
	accepted.emit(taken)


func _on_decline() -> void:
	if not _open:
		return
	GameManager.ui_click_swallowed = true
	AudioManager.play_sfx("switchMode")
	var refused := _contract
	_dismiss()
	declined.emit(refused)
