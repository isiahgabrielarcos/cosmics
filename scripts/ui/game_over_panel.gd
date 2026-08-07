extends CanvasLayer
class_name GameOverPanel

# Mission Failed screen — ports gameOverPlayer() from globalFunctions.lua.
# Layout lives in scenes/ui/panels/game_over_panel.tscn.

signal restart_pressed
signal menu_pressed

@onready var _overlay: ColorRect     = $Root/Overlay
@onready var _avatar: TextureRect    = $Root/Avatar
@onready var _restart_btn: Button    = $Root/Panel/Buttons/RestartButton
@onready var _menu_btn: Button       = $Root/Panel/Buttons/MenuButton

var _float_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	visible = false
	_restart_btn.pressed.connect(func(): restart_pressed.emit())
	_menu_btn.pressed.connect(func(): menu_pressed.emit())


func open() -> void:
	# Toby rises into frame with the panel
	var portrait := get_node_or_null("Root/Avatar")
	if portrait is AvatarFloat:
		(portrait as AvatarFloat).play_intro()
	visible = true

	_overlay.color.a = 0.0
	create_tween().tween_property(_overlay, "color:a", 0.7, 0.5)

	if _float_tween:
		_float_tween.kill()
	_avatar.position.x = -450.0
	var slide := create_tween()
	slide.tween_property(_avatar, "position:x", 120.0, 1.0)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide.tween_callback(_float_avatar)


func close() -> void:
	visible = false
	if _float_tween:
		_float_tween.kill()


func _float_avatar() -> void:
	if not is_instance_valid(_avatar):
		return
	_float_tween = create_tween().set_loops()
	_float_tween.tween_property(_avatar, "position:y", _avatar.position.y + 10, 1.0)
	_float_tween.tween_property(_avatar, "position:y", _avatar.position.y - 10, 1.0)
