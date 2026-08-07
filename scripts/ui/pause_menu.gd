extends CanvasLayer
class_name PauseMenu

# Ports pauseTheGame() from globalFunctions.lua. Esc toggles the pause menu.
# Resume / Settings / Abandon + master volume; Settings swaps in a
# resolution/fullscreen/music/ambient/sfx sub-page (settings_panel.tscn).

@onready var _pause_panel: Control          = $Root/PausePanel
@onready var _settings_panel: SettingsPanel = $Root/SettingsPanel
@onready var _resume_btn: Button            = $Root/PausePanel/VBox/ResumeButton
@onready var _settings_btn: Button          = $Root/PausePanel/VBox/SettingsButton
@onready var _abandon_btn: Button           = $Root/PausePanel/VBox/AbandonButton
@onready var _master_slider: HSlider        = $Root/PausePanel/VBox/MasterVolumeSlider
@onready var _master_label: Label           = $Root/PausePanel/VBox/MasterVolumeLabel


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_resume_btn.pressed.connect(_resume)
	_settings_btn.pressed.connect(_open_settings)
	_abandon_btn.pressed.connect(_abandon)
	_master_slider.value_changed.connect(_on_master_volume_changed)
	_settings_panel.back_pressed.connect(_close_settings)

	_master_slider.value = AudioManager.master_volume * 100
	_master_label.text = "Master Volume: %02d" % int(AudioManager.master_volume * 100)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	toggle_pause()


## Same effect as pressing Esc — shared by the key binding and the on-screen
## pause button in the HUD, so the two can never fall out of sync with each
## other's rules about when pausing is (and isn't) allowed.
func toggle_pause() -> void:
	if GameManager.game_done or GameManager.ui_open:
		return
	if GameManager.game_paused:
		if _settings_panel.visible:
			_close_settings()
		else:
			_resume()
	else:
		_open()


func _open() -> void:
	AudioManager.play_sfx("pauseSoundEffect")
	GameManager.pause_game()
	visible = true
	_pause_panel.visible = true
	_settings_panel.visible = false


func _resume() -> void:
	GameManager.resume_game()
	visible = false


func _abandon() -> void:
	_resume()
	GameManager.goto_main_menu()


func _open_settings() -> void:
	_pause_panel.visible = false
	_settings_panel.visible = true
	_settings_panel.refresh()


func _close_settings() -> void:
	_settings_panel.visible = false
	_pause_panel.visible = true


func _on_master_volume_changed(value: float) -> void:
	AudioManager.set_master_volume(value / 100.0)
	_master_label.text = "Master Volume: %02d" % int(value)
