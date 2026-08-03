extends CanvasLayer
class_name DialoguePanel

# The chatBox.png popup used by every simple-talk NPC. Layout lives entirely in
# scenes/ui/panels/dialogue_panel.tscn — this script fills in the avatar/name/
# role/body per line and plays the open/close and speaker-change tweens.
#
# Supports both a single line (open) and a multi-stage, multi-speaker sequence
# (open_sequence), so a conversation can hop between characters (e.g. the
# receptionist and Toby going back and forth) inside one chat box. Clicking
# advances to the next line; clicking on the last line closes the panel.

signal closed

# speaker key -> avatar path, display name, and title. A single record here
# drives every dialogue call, so callers only ever pass a speaker key and text.
const CHARACTERS := {
	"toby":         { "avatar": "res://assets/art/ui/tobyAvatar.png",             "name": "Toby",      "role": "CCC Mercenary" },
	"receptionist": { "avatar": "res://assets/art/ui/receptionistAvatar.png",     "name": "Chesca",    "role": "CCC Guild Receptionist" },
	"guard1":       { "avatar": "res://assets/art/ui/guard1Avatar.png",          "name": "Julie",     "role": "CCC Guild Guard" },
	"guard2":       { "avatar": "res://assets/art/ui/guard2Avatar.png",          "name": "Eveland",   "role": "CCC Guild Guard" },
	"trader":       { "avatar": "res://assets/art/ui/cosmicTraderAvatar.png",    "name": "Princess",  "role": "Central Trader Associate" },
	"blacksmith":   { "avatar": "res://assets/art/ui/cosmicTalyerAvatar.png",    "name": "Gabriel",   "role": "Cosmic Blacksmith" },
	"polaroid":     { "avatar": "res://assets/art/ui/cosmicPolaroidAvatar.png",  "name": "Lorraine",  "role": "Cosmic Polaroid Head" },
	"nurse":        { "avatar": "res://assets/art/ui/nurseAvatar.png",          "name": "Mary Jane", "role": "CCC Nurse" },
	"guildmerc":    { "avatar": "res://assets/art/ui/arthurAvatar.png",         "name": "Cody",      "role": "Mercenary Guild Leader" },
	# the mysterious girl before and after her name is revealed share one avatar
	"girl":         { "avatar": "res://assets/art/ui/mysteriousGirlAvatar.png", "name": "???",       "role": "" },
	"yujin":        { "avatar": "res://assets/art/ui/mysteriousGirlAvatar.png", "name": "Yujin",     "role": "" },
}

@onready var _dim: ColorRect       = $Root/Dim
@onready var _avatar: TextureRect  = $Root/Avatar
@onready var _chatbox: TextureRect = $Root/ChatBox
@onready var _name_label: Label    = $Root/ChatBox/NameLabel
@onready var _role_label: Label    = $Root/ChatBox/RoleLabel
@onready var _body_label: Label    = $Root/ChatBox/BodyLabel
@onready var _bg_decor: TileMap    = $Root/Control2/BackgroundDecor
@onready var _bot_border: TileMap  = $Root/Control2/BottomBorder
@onready var _top_border: TileMap  = $Root/Control2/TopBorder
@onready var _fg_decor: TileMap    = $Control/ForegroundDecor

var _bg_rest: Vector2
var _bot_rest: Vector2
var _top_rest: Vector2
var _fg_rest: Vector2

var _lines: Array = []
var _index: int = 0
var _prev_speaker: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 85
	visible = false
	_dim.gui_input.connect(_on_bg_input)
	_chatbox.gui_input.connect(_on_bg_input)
	_bg_rest  = _bg_decor.position
	_bot_rest = _bot_border.position
	_top_rest = _top_border.position
	_fg_rest  = _fg_decor.position


## Single-line convenience wrapper. speaker must be a key in CHARACTERS.
func open(speaker: String, text: String) -> DialoguePanel:
	return open_sequence([{ "speaker": speaker, "text": text }])


## Multi-stage, multi-speaker conversation. lines is an Array of
## { "speaker": <CHARACTERS key>, "text": <String> } dictionaries, shown one
## at a time in order. Clicking advances; the avatar only re-plays its intro
## tween when the speaker actually changes between lines, so a back-and-forth
## conversation between two or three characters reads as one continuous scene.
func open_sequence(lines: Array) -> DialoguePanel:
	_lines = lines
	_index = 0
	_prev_speaker = ""
	visible = true
	_play_intro_tween()
	_show_line(0)
	return self


func _show_line(i: int) -> void:
	var line: Dictionary = _lines[i]
	var speaker: String = line.get("speaker", "")
	var data: Dictionary = CHARACTERS.get(speaker, { "avatar": "", "name": speaker, "role": "" })

	_name_label.text = data.get("name", speaker)
	var role_text: String = data.get("role", "")
	_role_label.text = role_text
	_role_label.visible = role_text != ""
	_body_label.text = line.get("text", "")

	var avatar_path: String = data.get("avatar", "")
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		_avatar.texture = load(avatar_path)
		_avatar.visible = true
	else:
		_avatar.visible = false

	if speaker != _prev_speaker:
		_avatar.modulate.a = 0.0
		_avatar.position.x = 60.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_avatar, "modulate:a", 1.0, 0.3)
		tw.tween_property(_avatar, "position:x", 100.0, 0.3)

	_prev_speaker = speaker


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		close()
	else:
		_show_line(_index)


func _play_intro_tween() -> void:
	# snap decors to their off-screen start positions
	_bg_decor.position   = _bg_rest  + Vector2(900.0,  0.0)
	_bot_border.position = _bot_rest + Vector2(0.0,    480.0)
	_top_border.position = _top_rest + Vector2(0.0,   -480.0)
	_fg_decor.position   = _fg_rest  + Vector2(1200.0, 0.0)
	_chatbox.modulate.a  = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_bg_decor,   "position", _bg_rest,  0.30).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_bot_border, "position", _bot_rest, 0.38).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_top_border, "position", _top_rest, 0.38).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_fg_decor,   "position", _fg_rest,  0.50).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_chatbox,    "modulate:a", 1.0,     0.15)


func close() -> void:
	visible = false
	_lines = []
	_index = 0
	closed.emit()


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()
