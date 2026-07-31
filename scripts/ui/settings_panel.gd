extends Control
class_name SettingsPanel

# Resolution / fullscreen / per-category volume. Nested inside pause_menu.tscn
# as a sub-page — PauseMenu toggles this panel's visibility against its own.

signal back_pressed

const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

@onready var _resolution_option: OptionButton = $Content/ResolutionRow/ResolutionOption
@onready var _fullscreen_check: CheckBox      = $Content/FullscreenRow/FullscreenCheck
@onready var _music_slider: HSlider           = $Content/MusicRow/MusicSlider
@onready var _music_label: Label              = $Content/MusicRow/MusicLabel
@onready var _ambient_slider: HSlider         = $Content/AmbientRow/AmbientSlider
@onready var _ambient_label: Label            = $Content/AmbientRow/AmbientLabel
@onready var _sfx_slider: HSlider             = $Content/SfxRow/SfxSlider
@onready var _sfx_label: Label                = $Content/SfxRow/SfxLabel
@onready var _back_btn: Button                = $Content/BackButton


func _ready() -> void:
	for res in RESOLUTIONS:
		_resolution_option.add_item("%d x %d" % [res.x, res.y])

	_resolution_option.item_selected.connect(_on_resolution_selected)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_music_slider.value_changed.connect(_on_music_changed)
	_ambient_slider.value_changed.connect(_on_ambient_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_back_btn.pressed.connect(func(): back_pressed.emit())


## Called by PauseMenu each time this page is shown, to reflect current state.
func refresh() -> void:
	_fullscreen_check.button_pressed = get_window().mode == Window.MODE_FULLSCREEN
	_resolution_option.disabled = _fullscreen_check.button_pressed

	var idx := RESOLUTIONS.find(get_window().size)
	_resolution_option.selected = idx

	_music_slider.value = AudioManager.music_volume * 100
	_music_label.text = "Music: %02d" % int(AudioManager.music_volume * 100)
	_ambient_slider.value = AudioManager.ambient_volume * 100
	_ambient_label.text = "Ambient: %02d" % int(AudioManager.ambient_volume * 100)
	_sfx_slider.value = AudioManager.sfx_volume * 100
	_sfx_label.text = "Sound Effects: %02d" % int(AudioManager.sfx_volume * 100)


func _on_resolution_selected(idx: int) -> void:
	get_window().size = RESOLUTIONS[idx]


func _on_fullscreen_toggled(pressed: bool) -> void:
	get_window().mode = Window.MODE_FULLSCREEN if pressed else Window.MODE_WINDOWED
	_resolution_option.disabled = pressed


func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume(value / 100.0)
	_music_label.text = "Music: %02d" % int(value)


func _on_ambient_changed(value: float) -> void:
	AudioManager.set_ambient_volume(value / 100.0)
	_ambient_label.text = "Ambient: %02d" % int(value)


func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value / 100.0)
	_sfx_label.text = "Sound Effects: %02d" % int(value)
