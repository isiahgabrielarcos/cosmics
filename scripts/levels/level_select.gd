extends Node3D

# CCC level selection — a Mindustry-style orbit around the cluster. The camera
# rig lives on "camera pointer"; this script owns the picking (which system did
# the player click) and the 2D overlay on top of it.
#
# Picking is done by projecting each system's world position to the screen and
# taking the nearest one inside PICK_RADIUS, rather than by raycasting. The
# systems are billboarded AnimatedSprite3D nodes with no collision shapes, so
# screen-space distance is both simpler and more forgiving to click.

const SolarSystemPanelScene := preload("res://scenes/ui/panels/solar_system_panel.tscn")

const PICK_RADIUS := 90.0     # screen pixels
const DRAG_TOLERANCE := 8.0   # a click that moves further than this is a drag

## Scene node name -> the battle stage id it launches.
const SYSTEM_STAGES := {
	"Flashbourn": 1,
	"Strogghold": 2,
	"Frokenvinter": 3,
	"Squilltrant": 4,
	# The structure in the middle of the cluster. Same picking rules as a
	# system, but it launches the all-factions stage rather than one system's.
	"Citadel": GameManager.CITADEL_STAGE,
}

@onready var _camera: Camera3D = $"camera pointer/Camera3D"
@onready var _rig: Node3D = $"camera pointer"

var _panel: SolarSystemPanel
var _back_btn: Button
var _hint: Label
var _systems: Dictionary = {}      # stage -> Node3D
var _press_at: Vector2 = Vector2.ZERO
var _pressed: bool = false


func _ready() -> void:
	GameManager.start_session(100)
	GameManager.ui_open = false

	for node_name in SYSTEM_STAGES:
		var n := get_node_or_null(NodePath(node_name))
		if n:
			_systems[SYSTEM_STAGES[node_name]] = n
		else:
			push_warning("LevelSelect: no node named '%s' in the scene" % node_name)

	_build_overlay()

	_panel = SolarSystemPanelScene.instantiate()
	add_child(_panel)
	_panel.launch_requested.connect(_on_launch)
	_panel.closed.connect(func(): _set_rig_input(true))


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.name = "Overlay"
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

func _set_rig_input(enabled: bool) -> void:
	if _rig.has_method("set_input_enabled"):
		_rig.set_input_enabled(enabled)


# ── Picking ───────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	if mb.pressed:
		_press_at = mb.position
		_pressed = true
		return

	# release — only treat it as a pick if the pointer barely moved
	if not _pressed:
		return
	_pressed = false
	if mb.position.distance_to(_press_at) > DRAG_TOLERANCE:
		return

	# a click inside the open panel belongs to the panel, not the cluster
	if _panel.contains_point(mb.position):
		return

	var stage := _pick_system(mb.position)
	if stage > 0:
		_open_system(stage)
	elif _panel.is_open():
		_panel.close()


func _pick_system(at: Vector2) -> int:
	var best_stage := -1
	var best_dist := PICK_RADIUS

	for stage in _systems:
		var node: Node3D = _systems[stage]
		if _camera.is_position_behind(node.global_position):
			continue
		var screen := _camera.unproject_position(node.global_position)
		var d := screen.distance_to(at)
		if d < best_dist:
			best_dist = d
			best_stage = stage

	return best_stage


func _open_system(stage: int) -> void:
	_set_rig_input(false)
	_panel.open(stage)


# ── Actions ───────────────────────────────────────────────────────────────────

func _on_launch(stage: int, tier: int, endless: bool) -> void:
	# Endless variants live at stage+20 (21-24) so is_endless_stage() picks
	# up the count-up timer; a timed run keeps the plain stage id.
	if stage == GameManager.CITADEL_STAGE:
		# The Citadel keeps its own endless id: 21-24 are the four systems'.
		if endless:
			GameManager.queue_battle(GameManager.CITADEL_ENDLESS_STAGE, "normal", tier, 0.0)
		else:
			GameManager.queue_battle(GameManager.CITADEL_STAGE, "normal", tier, 15.0)
	elif endless:
		GameManager.queue_battle(stage + 20, "normal", tier, 0.0)
	else:
		GameManager.queue_battle(stage, "normal", tier, 15.0)


func _on_back() -> void:
	AudioManager.play_sfx("switchMode")
	GameManager.goto_main_menu()
	GameManager.last_talked_to = "receptionist"
