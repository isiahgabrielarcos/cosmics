extends TextureRect
class_name ModuleCard

# One of the three cards on the module pick screen. Layout lives in
# scenes/ui/components/module_card.tscn — edit it there and all three follow.
#
# The card owns its own idle bob. The pick panel deals the cards a fixed
# interval apart and hands each one a phase matching its place in that deal,
# which is what makes the row read as a travelling wave instead of three
# things moving together.

signal chosen(card: ModuleCard)

@onready var rarity_label: Label = $Body/Rarity
@onready var name_label: Label = $Body/ModuleName
@onready var desc_label: Label = $Body/Description

## Pixels the card drifts, and how long one full cycle takes.
@export var bob_height: float = 14.0
@export var bob_period: float = 2.0

var rarity: String = "common"
var option: Dictionary = {}

var _base_y: float = 0.0
var _phase: float = 0.0
var _time: float = 0.0
var _live: bool = false


func _ready() -> void:
	gui_input.connect(_on_gui_input)


func _process(delta: float) -> void:
	if not _live:
		return
	_time += delta
	position.y = _base_y + sin(_time * TAU / bob_period - _phase) * bob_height


## Fills the card in and starts it bobbing. `phase` offsets the idle so a row
## of cards ripples rather than moving as one.
func setup(card_rarity: String, card_option: Dictionary, phase: float) -> void:
	rarity = card_rarity
	option = card_option
	_phase = phase
	_base_y = position.y
	_time = 0.0
	_live = true

	texture = ModuleRegistry.RARITY_ART[card_rarity]
	rarity_label.text = card_rarity.to_upper()
	rarity_label.add_theme_color_override("font_color",
		ModuleRegistry.RARITY_COLORS[card_rarity])
	name_label.text = card_option.get("name", "")
	desc_label.text = card_option.get("desc", "")


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(self)
