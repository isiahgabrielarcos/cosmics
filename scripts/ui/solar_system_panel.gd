extends CanvasLayer
class_name SolarSystemPanel

# Detail panel for one solar system in the CCC level selection. Opens when a
# system is clicked in the 3D cluster and carries everything needed to launch
# a run: the inner difficulty selector (5 tiers) plus the two run modes.
#
# Layout lives in scenes/ui/panels/solar_system_panel.tscn.

signal closed
signal launch_requested(stage: int, tier: int, endless: bool)

const TIER_COUNT := 5

## Per-tier label + the enemy variety it unlocks (mirrors GameManager's
## TIER_VARIETY / the spawner's VARIETY_ROLLS bands).
const TIERS := [
	{ "name": "BEGINNER",     "color": Color(0.55, 1.0, 0.6),
	  "desc": "Chasers only. A clean run to learn the system." },
	{ "name": "EASY",         "color": Color(0.75, 1.0, 0.5),
	  "desc": "Chasers and ranged shooters." },
	{ "name": "MEDIUM",       "color": Color(1.0, 0.9, 0.4),
	  "desc": "Adds bombers that detonate on contact." },
	{ "name": "HARD",         "color": Color(1.0, 0.6, 0.3),
	  "desc": "Adds slashers that lunge once they close." },
	{ "name": "SPACE COWBOY", "color": Color(1.0, 0.35, 0.35),
	  "desc": "Full roster, fastest spawns, no mercy." },
]

## Every named system, keyed by its battle stage id. Endless uses stage+20
## (21-24) to match GameManager.is_endless_stage().
const SYSTEMS := {
	1: {
		"name": "FLASCHBOURN",
		"subtitle": "The Feiry Solar System",
		"story": "A settled, ordinary system of space-soaring aliens. Passive by nature, "
			+ "aggressive the moment you give them a reason. This is where the station died, "
			+ "and where you found her in the wreckage.",
		"gameplay": "Baseline enemy speed and health.\nRecommended for a first contract.",
	},
	2: {
		"name": "STROGGHOLD",
		"subtitle": "C137 · The Abandoned Dyson Sphere",
		"story": "A hollowed megastructure the Union stopped policing years ago. Rogue "
			+ "aliens and high-bounty criminals run it now. Pure anarchy, and the pay "
			+ "reflects it.",
		"gameplay": "Tougher chasers, denser waves.\nHigher shard yield per kill.",
	},
	3: {
		"name": "FROKENVINTER",
		"subtitle": "The Glazing Solar System",
		"story": "A blazing corridor of rogue comets and heavy, armoured aliens. Every "
			+ "structure here is wrapped in anti-radiation plating, and it still is not enough.",
		"gameplay": "Heavy, slow enemies with high health.\nPositioning matters more than damage.",
	},
	4: {
		"name": "SQUILLTRANT",
		"subtitle": "The Slime Solar System",
		"story": "A dwarf system of diplomats who would rather not fight you, and slimes "
			+ "that do not get a say. Kill the parent and you inherit the children.",
		"gameplay": "Mixed fast and heavy enemies.\nSlimes split into smaller copies on death.",
	},
}

@onready var _root: Control        = $Root
@onready var _art: NinePatchRect   = $Root/Frame
@onready var _name: Label          = $Root/Frame/SystemName
@onready var _subtitle: Label      = $Root/Frame/Subtitle
@onready var _image: TextureRect   = $Root/Frame/SystemImage
@onready var _story: Label         = $Root/Frame/NarrativeDescription
@onready var _gameplay: Label      = $Root/Frame/GameplayDescription
@onready var _tier_name: Label     = $Root/Frame/TierRow/TierName
@onready var _tier_btn: Button     = $Root/Frame/TierRow/TierButton
@onready var _tier_desc: Label     = $Root/Frame/TierRow/TierDesc
@onready var _run_btn: Button      = $Root/Frame/Buttons/RunButton
@onready var _endless_btn: Button  = $Root/Frame/Buttons/EndlessButton
@onready var _close_btn: Button    = $Root/Frame/CloseButton

var _stage: int = 1
var _tier: int = 1
var _rest_x: float = 0.0
var _tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	visible = false
	_rest_x = _root.position.x

	_tier_btn.pressed.connect(_cycle_tier)

	_close_btn.pressed.connect(close)
	_run_btn.pressed.connect(func(): _launch(false))
	_endless_btn.pressed.connect(func(): _launch(true))


func open(stage: int) -> void:
	if not SYSTEMS.has(stage):
		return
	_stage = stage
	var d: Dictionary = SYSTEMS[stage]

	_name.text = d["name"]
	_subtitle.text = d["subtitle"]
	_story.text = d["story"]
	_gameplay.text = d["gameplay"]
	_refresh_tier()

	visible = true
	AudioManager.play_sfx("pickedMode1")

	# slide in from off the right edge
	_kill_tween()
	_root.position.x = _rest_x + 900.0
	_tween = create_tween()
	_tween.tween_property(_root, "position:x", _rest_x, 0.3)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not visible:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_root, "position:x", _rest_x + 900.0, 0.26)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		visible = false
		_root.position.x = _rest_x
		closed.emit())


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


## True while the panel is on screen and should swallow clicks.
func is_open() -> bool:
	return visible


func contains_point(at: Vector2) -> bool:
	return visible and _art.get_global_rect().has_point(at)


## Steps to the next difficulty and wraps back to Beginner past the top.
func _cycle_tier() -> void:
	_tier = _tier % TIER_COUNT + 1
	AudioManager.play_sfx("pickedMode2")
	_refresh_tier()


func _refresh_tier() -> void:
	var info: Dictionary = TIERS[_tier - 1]
	_tier_name.text = "DIFFICULTY  %d/%d" % [_tier, TIER_COUNT]
	_tier_btn.text = info["name"]
	_tier_btn.add_theme_color_override("font_color", info["color"])
	_tier_desc.text = info["desc"]


func _launch(endless: bool) -> void:
	launch_requested.emit(_stage, clampi(_tier, 1, TIER_COUNT), endless)
