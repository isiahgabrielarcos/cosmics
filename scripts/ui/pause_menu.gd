extends CanvasLayer

# Ports pauseTheGame() + createVolumeSlider() from globalFunctions.lua.
# Esc toggles the pause menu. Works while the tree is paused.

const RETRO_FONT := preload("res://assets/fonts/RetroGaming.ttf")

var _overlay: ColorRect
var _panel: VBoxContainer
var _volume_label: Label


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameManager.game_done or GameManager.ui_open:
			return
		if GameManager.game_paused:
			_resume()
		else:
			_open()


func _open() -> void:
	AudioManager.play_sfx("pauseSoundEffect")
	GameManager.pause_game()
	visible = true


func _resume() -> void:
	GameManager.resume_game()
	visible = false


func _abandon() -> void:
	_resume()
	GameManager.goto_main_menu()


# ── UI ─────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	_panel = VBoxContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_theme_constant_override("separation", 28)
	add_child(_panel)

	var title := _make_label("Paused", 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 80)
	_panel.add_child(buttons)

	buttons.add_child(_make_button("Resume", _resume))
	buttons.add_child(_make_button("Abandon", _abandon))

	_volume_label = _make_label("Master Volume: %02d" % int(AudioManager.master_volume * 100), 30)
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_volume_label)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = AudioManager.master_volume * 100
	slider.custom_minimum_size = Vector2(600, 30)
	slider.value_changed.connect(_on_volume_changed)
	_panel.add_child(slider)


func _on_volume_changed(value: float) -> void:
	AudioManager.set_master_volume(value / 100.0)
	_volume_label.text = "Master Volume: %02d" % int(value)


func _make_label(text: String, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", RETRO_FONT)
	lbl.add_theme_font_size_override("font_size", size)
	return lbl


func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.add_theme_font_override("font", RETRO_FONT)
	btn.add_theme_font_size_override("font_size", 50)
	btn.pressed.connect(callback)
	return btn
