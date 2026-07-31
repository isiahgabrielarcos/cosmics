extends CanvasLayer
class_name DialoguePanel

# The chatBox.png popup used by every simple-talk NPC (guards, polaroid,
# mercenary, nurse). Layout lives entirely in scenes/ui/panels/dialogue_panel.tscn —
# this script only fills in the text/avatar and plays the open/close tween.

signal closed

const AVATARS := {
	"receptionist": "res://assets/art/ui/receptionistAvatar.png",
	"guard1":       "res://assets/art/ui/guard1Avatar.png",
	"guard2":       "res://assets/art/ui/guard2Avatar.png",
	"trader":       "res://assets/art/ui/cosmicTraderAvatar.png",
	"blacksmith":   "res://assets/art/ui/cosmicTalyerAvatar.png",
	"polaroid":     "res://assets/art/ui/cosmicPolaroidAvatar.png",
	"nurse":        "res://assets/art/ui/nurseAvatar.png",
	"girl":         "res://assets/art/ui/mysteriousGirlAvatar.png",
}

@onready var _dim: ColorRect      = $Root/Dim
@onready var _avatar: TextureRect = $Root/Avatar
@onready var _chatbox: TextureRect = $Root/ChatBox
@onready var _name_label: Label   = $Root/ChatBox/NameLabel
@onready var _body_label: Label   = $Root/ChatBox/BodyLabel
@onready var _bg_decor: TileMap   = $Root/Control2/BackgroundDecor
@onready var _bot_border: TileMap = $Root/Control2/BottomBorder
@onready var _top_border: TileMap = $Root/Control2/TopBorder
@onready var _fg_decor: TileMap   = $Control/ForegroundDecor

var _bg_rest: Vector2
var _bot_rest: Vector2
var _top_rest: Vector2
var _fg_rest: Vector2


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


func open(npc_name: String, avatar_key: String, text: String) -> void:
	visible = true
	_name_label.text = npc_name
	_body_label.text = text

	if AVATARS.has(avatar_key) and ResourceLoader.exists(AVATARS[avatar_key]):
		_avatar.texture = load(AVATARS[avatar_key])
		_avatar.visible = true
	else:
		_avatar.visible = false

	# snap decors to their off-screen start positions
	_bg_decor.position   = _bg_rest  + Vector2(900.0,  0.0)
	_bot_border.position = _bot_rest + Vector2(0.0,    480.0)
	_top_border.position = _top_rest + Vector2(0.0,   -480.0)
	_fg_decor.position   = _fg_rest  + Vector2(1200.0, 0.0)

	_avatar.modulate.a = 0.0
	_avatar.position.x = 60.0
	_chatbox.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	# decor slides
	tw.tween_property(_bg_decor,   "position", _bg_rest,  0.30).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_bot_border, "position", _bot_rest, 0.38).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_top_border, "position", _top_rest, 0.38).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_fg_decor,   "position", _fg_rest,  0.50).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# avatar and chatbox fade-in
	tw.tween_property(_avatar,  "modulate:a", 1.0,  0.4)
	tw.tween_property(_avatar,  "position:x", 100.0, 0.4)
	tw.tween_property(_chatbox, "modulate:a", 1.0,  0.15)


func close() -> void:
	visible = false
	closed.emit()


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
