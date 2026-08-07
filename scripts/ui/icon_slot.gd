extends Panel
class_name IconSlot

# One ability icon on the inventory sidebar.
#
# The cooldown readout is the Mask: a black overlay anchored to the BOTTOM of
# the slot, so shrinking it drains downward and uncovers the icon from the
# top. How much icon you can see is how ready the ability is — no separate
# bar to read. Edit the look in scenes/ui/components/icon_slot.tscn; this
# only drives it.

signal clicked(slot: IconSlot)

@onready var icon: TextureRect = $Icon
@onready var mask: ColorRect = $Mask
@onready var caption: Label = $Caption

## What the click-through panel shows for this slot.
var title: String = ""
var description: String = ""

## Which ability this slot is bound to — set by the inventory when it builds
## the sidebar. `kind` is "weapon", "skill" or "passive".
var kind: String = "passive"
var flag: String = ""
var timer_key: String = ""
var content_id: int = -1


func _ready() -> void:
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# Operating the HUD must not also fire the cannon
		GameManager.ui_click_swallowed = true
		clicked.emit(self)


## `ratio` 1.0 = just used (fully covered), 0.0 = ready (fully revealed).
func set_cooldown(ratio: float, text: String = "") -> void:
	mask.anchor_top = 1.0 - clampf(ratio, 0.0, 1.0)
	caption.text = text


## Dim an unowned slot so the space still reads as "something goes here".
func set_owned(owned: bool) -> void:
	modulate.a = 1.0 if owned else 0.25
