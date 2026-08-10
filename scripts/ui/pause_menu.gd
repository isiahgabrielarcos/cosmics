extends CanvasLayer
class_name PauseMenu

# Ports pauseTheGame() from globalFunctions.lua. Esc toggles the pause menu.
# Resume / Settings / leave; Settings swaps in a resolution/fullscreen/volume
# sub-page (settings_panel.tscn), which is also where master volume lives —
# this menu used to carry a second slider for the same value.
#
# The leave button means different things in the two places the pause menu
# appears, so it re-labels itself each time it opens: in the hub there's no
# run to give up, so it walks all the way out to the title screen; mid-run it
# abandons the run and drops you back at the hub, which is the Solar2D
# behaviour and keeps your session.

@onready var _pause_panel: Control          = $Root/PausePanel
@onready var _settings_panel: SettingsPanel = $Root/SettingsPanel
@onready var _resume_btn: Button            = $Root/PausePanel/VBox/ResumeButton
@onready var _settings_btn: Button          = $Root/PausePanel/VBox/SettingsButton
@onready var _leave_btn: Button             = $Root/PausePanel/VBox/LeaveButton


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_resume_btn.pressed.connect(_resume)
	_settings_btn.pressed.connect(_open_settings)
	_leave_btn.pressed.connect(_leave)
	_settings_panel.back_pressed.connect(_close_settings)


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
	# Re-read each time rather than once in _ready: the pause menu is built
	# with its scene, and nothing guarantees the stage was already set then.
	_leave_btn.text = "Return to Main Menu" if GameManager.is_hub() else "Abandon"
	visible = true
	_pause_panel.visible = true
	_settings_panel.visible = false


func _resume() -> void:
	GameManager.resume_game()
	visible = false


func _leave() -> void:
	_resume()
	if GameManager.is_hub():
		GameManager.goto_title_screen()
	else:
		GameManager.goto_main_menu()   # back to the hub, run abandoned


func _open_settings() -> void:
	_pause_panel.visible = false
	_settings_panel.visible = true
	_settings_panel.refresh()


func _close_settings() -> void:
	_settings_panel.visible = false
	_pause_panel.visible = true
