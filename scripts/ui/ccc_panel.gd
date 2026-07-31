extends CanvasLayer
class_name CccPanel

# Central Cosmic Commission — mission board. Chrome (backdrop, close button,
# title, scroll list, bottom bar) lives in scenes/ui/panels/ccc_panel.tscn;
# this script only duplicates RowTemplate per mission and wires callbacks.

signal closed

const MISSIONS := [
	{ "stage": 0,  "icon": 4, "name": "Random Solar System",
		"desc": "Randomly picks a solar system for you to invade" },
	{ "stage": 1,  "icon": 0, "name": "FlaschBourn Feiry Solar System",
		"desc": "A fairly normal solar system filled with space soaring aliens" },
	{ "stage": 2,  "icon": 1, "name": "Stroggholl C137 Solar System",
		"desc": "An abandoned dyson sphere. Rogue aliens, high bounty criminals. Pure anarchy" },
	{ "stage": 3,  "icon": 2, "name": "Frokenvinter Glazing Solar System",
		"desc": "A blazing solar system filled with rogue comets and heavy aliens" },
	{ "stage": 4,  "icon": 3, "name": "Squilltrant Slime Solar System",
		"desc": "A dwarf solar system filled with both heavy and fast aliens" },
	{ "stage": 21, "icon": 5, "name": "The Endless Void",
		"desc": "Survive as long as you can. The fiends never stop coming" },
]

const SYSTEM_SHEET := preload("res://assets/art/ui/enemySystems.png")

@onready var _list: VBoxContainer   = $Root/Frame/Margin/Content/Scroll/MissionList
@onready var _row_template: PanelContainer = $Root/Frame/Margin/Content/Scroll/MissionList/RowTemplate
@onready var _close_btn: TextureButton = $Root/Frame/CloseButton
@onready var _difficulty_btn: Button = $Root/Frame/Margin/Content/BottomBar/DifficultyButton
@onready var _accept_btn: TextureButton = $Root/Frame/Margin/Content/BottomBar/AcceptButton
@onready var _reject_btn: TextureButton = $Root/Frame/Margin/Content/BottomBar/RejectButton

var _selected_stage: int = 1
var _selected_difficulty: String = "normal"
var _rows: Dictionary = {}   # stage -> Button (select button)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	visible = false
	_row_template.visible = false

	_close_btn.pressed.connect(close)
	_reject_btn.pressed.connect(close)
	_accept_btn.pressed.connect(_on_accept)
	_difficulty_btn.pressed.connect(_on_toggle_difficulty)


func open() -> void:
	visible = true
	AudioManager.play_sfx("pickedMode1")
	_rebuild_list()
	_difficulty_btn.text = _selected_difficulty.to_upper()


func close() -> void:
	visible = false
	closed.emit()


func _rebuild_list() -> void:
	for child in _rows.values():
		child.get_parent().queue_free()
	_rows.clear()

	for m in MISSIONS:
		var row: PanelContainer = _row_template.duplicate()
		row.visible = true
		row.name = "row_%d" % int(m["stage"])
		_list.add_child(row)

		var icon: TextureRect = row.get_node("HBox/Icon")
		var atlas := AtlasTexture.new()
		atlas.atlas = SYSTEM_SHEET
		@warning_ignore("integer_division")
		atlas.region = Rect2((int(m["icon"]) % 3) * 128, (int(m["icon"]) / 3) * 128, 128, 128)
		icon.texture = atlas

		row.get_node("HBox/TextCol/NameLabel").text = m["name"]
		row.get_node("HBox/TextCol/DescLabel").text = m["desc"]

		var select_btn: Button = row.get_node("HBox/SelectButton")
		var stage := int(m["stage"])
		select_btn.text = "* Picked *" if _selected_stage == stage else "Select"
		select_btn.pressed.connect(_on_select_stage.bind(stage))
		_rows[stage] = select_btn


func _on_select_stage(stage: int) -> void:
	_selected_stage = stage
	AudioManager.play_sfx("pickedMode2")
	for s in _rows:
		_rows[s].text = "* Picked *" if s == stage else "Select"


func _on_toggle_difficulty() -> void:
	_selected_difficulty = "expert" if _selected_difficulty == "normal" else "normal"
	_difficulty_btn.text = _selected_difficulty.to_upper()
	AudioManager.play_sfx("switchMode")


func _on_accept() -> void:
	var stage := _selected_stage
	if stage == 0:
		stage = randi_range(1, 4)
	GameManager.queue_battle(stage, _selected_difficulty)
