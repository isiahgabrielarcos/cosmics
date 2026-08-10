extends Node2D
class_name MainMenu

# Title screen — a port of mainMenu.lua, with one deliberate change: the old
# cosmicFiendsMenuBG.png painting is gone and the live Godot background
# (scenes/ui/background.tscn — parallax nebula + burning star) sits behind
# everything instead.
#
# Everything you'd want to nudge is authored in main_menu.tscn, not in here:
#   · Where the UFO ends up, and how big it is — just move/scale the Ufo node.
#     Its authored transform IS the landing spot; this script only flies it in
#     from off-screen and puts it back.
#   · The dash trail and Toby's animations — SpriteFrames on their nodes,
#     editable in the SpriteFrames panel.
#   · Every label, button and the credits roll — plain text properties.
#   · The spawner's rates, sizes, speeds and enemy roster — the exported
#     values below, all in the inspector.
#
# The enemies streaming right-to-left are pure decoration, the way Mindustry
# flies ships past behind its menu. They're bare AnimatedSprite2Ds built from
# EnemyFactory.DEFS: no archetype scene, no physics body, no AI, no collision
# layer, nothing that can touch a save. This script moves them itself in
# _process and frees each one the moment it clears the left edge, so the menu
# can idle for an hour without piling up nodes.


@export_group("Drifting enemies")

## One spawn every quarter second, as in globalFunctions.lua's
## mainMenuEnemySpawner.
@export var drift_interval := 0.25

## The cap the Lua never needed — it just leaked. Raise for a busier sky.
@export var max_drifters := 48

## How many are already in flight when the menu opens, so it doesn't start on
## an empty sky and take ten seconds to fill.
@export var seeded_drifters := 14

@export var drift_scale_min := 0.5
@export var drift_scale_max := 3.0

## Speed is tied to size: the small ones read as far away, so they're slower,
## dimmer, and drawn behind the big ones.
@export var drift_speed_min := 110.0   # px/s, the far/small ones
@export var drift_speed_max := 260.0   # px/s, the near/big ones

## Bosses, and Toby's own ship, cross the menu now and then as well. They're
## rarer and bigger than the rank and file, so each sighting reads as an event
## rather than as more traffic.
@export var drifters_boss: Array[String] = [
	"boss_flaschbourn", "boss_strogghold", "boss_frokenvinter", "boss_squilltrant",
]
@export var drifters_hero: Array[String] = ["player_ship"]

## Sheets that aren't enemy data. The player's ship is sliced exactly like an
## enemy sheet — it just isn't something EnemyFactory has a def for. Frames and
## speed match the idle loop in toby_ship_1.tscn, so it reads as the same ship.
const EXTRA_SHEETS := {
	"player_ship": {
		"sheet": "res://assets/art/characters/cosmicUFOSprite1.png",
		"fw": 32, "fh": 32, "count": 8, "fps": 48.0,
	},
}

## Share of spawns each kind gets. Whatever is left over after these three is
## the ordinary upright rabble.
@export_range(0.0, 1.0) var facing_chance := 0.4
@export_range(0.0, 1.0) var boss_chance := 0.05
@export_range(0.0, 1.0) var hero_chance := 0.04

## Bosses and the hero ship ignore the general size range — a boss shrunk to
## half size stops reading as a boss.
@export var boss_scale_min := 1.2
@export var boss_scale_max := 2.4
@export var hero_scale_min := 1.5
@export var hero_scale_max := 2.8

## Enemy ids, straight out of EnemyFactory.DEFS. Split by whether the art is
## directional: ships and slashers are drawn nose-up (enemy_unit aims them
## with a +PI/2 offset), so they get turned to face the way they travel — the
## same rotation = -90 mainMenuEnemy3/4 applied. The blobs, bombers and
## shooters read the same at any angle and stay upright.
@export var drifters_upright: Array[String] = [
	"fb_chaser", "fv_chaser", "sh_chaser", "st_mama", "baby_slime",
	"fb_bomber", "sh_bomber", "fv_bomber", "st_bomber",
	"fb_shooter", "sh_shooter", "fv_shooter", "st_shooter",
]
@export var drifters_facing: Array[String] = [
	"fb_ship", "sh_ship", "fv_ship", "st_ship",
	"fb_slasher", "sh_slasher", "fv_slasher", "st_slasher",
]

@export_group("UFO")

## Seconds for the drop-in. The UFO flies from off the top of the screen to
## wherever the Ufo node is placed in the scene, spinning twice on the way.
@export var entrance_time := 1.5
@export var entrance_spin := -360.0

## The float() bob it settles into, in pixels and seconds per half-cycle.
@export var bob_distance := 10.0
@export var bob_time := 1.0

@export_group("Background")

## universeMove() in the Lua: the sky breathes a few pixels up and down so a
## static menu never sits perfectly still.
@export var sky_drift := 6.0
@export var sky_drift_time := 3.0

@export_group("Routing")

## Where Play goes. The hub is where a session actually starts.
@export_file("*.tscn") var play_scene := "res://scenes/levels/cosmic_hub.tscn"

## Plays on loop behind the menu — a key from AudioManager.MUSIC.
@export var menu_music := "cosmicEntrance"


@onready var _background: CanvasLayer    = $Background
@onready var _drifter_root: Node2D       = $Drifters
@onready var _ufo: Node2D                = $Ufo
@onready var _ufo_dash: AnimatedSprite2D = $Ufo/Dash
@onready var _ufo_body: Node2D           = $Ufo/Body
@onready var _toby: AnimatedSprite2D     = $Ufo/Body/Toby

@onready var _play_btn: Button     = $MenuUI/Root/Menu/PlayButton
@onready var _settings_btn: Button = $MenuUI/Root/Menu/SettingsButton
@onready var _quit_btn: Button     = $MenuUI/Root/Menu/QuitButton
@onready var _credits_btn: Button  = $MenuUI/Root/CreditsButton

@onready var _overlay: Control         = $MenuUI/Root/Overlay
@onready var _credits_page: Control    = $MenuUI/Root/Overlay/CreditsPage
@onready var _credits_scroll: ScrollContainer = $MenuUI/Root/Overlay/CreditsPage/Scroll
@onready var _close_btn: TextureButton = $MenuUI/Root/Overlay/CloseButton
@onready var _settings_page: Control   = $MenuUI/Root/Overlay/SettingsPage
@onready var _settings_panel: SettingsPanel = $MenuUI/Root/Overlay/SettingsPage/SettingsPanel

## Live drifters as { "node": AnimatedSprite2D, "speed": float }. Kept in a
## plain array and stepped from here rather than giving 48 sprites a script
## and a _process each.
var _drifters: Array[Dictionary] = []
var _spawn_clock := 0.0

## SpriteFrames are shared between every drifter of the same kind — slicing
## one atlas per sprite would rebuild the same 3-9 regions forty times over.
var _frames: Dictionary = {}

## The Lua's `loading` flag: once we're on our way out, stop spawning and
## refuse any further button presses.
var _leaving := false


func _enter_tree() -> void:
	# Stage 100 is the hub/menu in GameManager's numbering. Set before the
	# background instance readies so background_star keeps the animation the
	# scene was authored with instead of picking a solar system's.
	GameManager.current_stage = 100


func _ready() -> void:
	randomize()
	AudioManager.play_music(menu_music)

	_play_btn.pressed.connect(_on_play)
	_settings_btn.pressed.connect(_on_settings)
	_quit_btn.pressed.connect(_on_quit)
	_credits_btn.pressed.connect(_on_credits)
	_close_btn.pressed.connect(_close_overlay)
	_settings_panel.back_pressed.connect(_close_overlay)

	_toby.animation_finished.connect(func():
		if _toby.animation == "start":
			_toby.play("idle"))

	_fly_ufo_in()
	_drift_sky()

	for i in seeded_drifters:
		_spawn_drifter(true)


func _process(delta: float) -> void:
	if not _leaving:
		_spawn_clock += delta
		while _spawn_clock >= drift_interval:
			_spawn_clock -= drift_interval
			_spawn_drifter()

	_move_drifters(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _overlay.visible and event.is_action_pressed("pause"):
		_close_overlay()
		get_viewport().set_input_as_handled()


# ── Drifting enemies ──────────────────────────────────────────────────────────

## `mid_flight` starts the enemy somewhere across the screen instead of just
## off the right edge — only used to prime the scene at load.
func _spawn_drifter(mid_flight: bool = false) -> void:
	if _drifters.size() >= max_drifters:
		return

	var pick := _roll_drifter()
	if pick.is_empty():
		return
	var id: String = pick["id"]
	var facing: bool = pick["facing"]

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _drifter_frames(id)
	if sprite.sprite_frames == null:
		return
	sprite.play("idle")
	# Start each one at a random point in its loop, or a burst of the same
	# enemy crosses the screen flapping in lockstep.
	sprite.frame = randi() % sprite.sprite_frames.get_frame_count("idle")

	var low: float = pick["scale_min"]
	var high: float = pick["scale_max"]
	var size := randf_range(low, high)
	sprite.scale = Vector2(size, size)

	var depth := inverse_lerp(low, high, size)
	sprite.modulate.a = lerpf(0.45, 1.0, depth)
	sprite.z_index = int(depth * 8.0)
	if facing:
		sprite.rotation = -PI / 2.0

	var view := get_viewport_rect().size
	var x := randf_range(view.x + 60.0, view.x + 220.0)
	if mid_flight:
		x = randf_range(-100.0, view.x + 220.0)
	sprite.position = Vector2(x, randf_range(-40.0, view.y + 40.0))

	_drifter_root.add_child(sprite)
	_drifters.append({
		"node": sprite,
		"speed": lerpf(drift_speed_min, drift_speed_max, depth),
	})


## Picks what crosses next: hero ship, boss, nose-up enemy, or upright rabble,
## in that order of rarity. Empty means the chosen roster has nothing in it.
func _roll_drifter() -> Dictionary:
	var roll := randf()
	var hero_cut := hero_chance
	var boss_cut := hero_cut + boss_chance
	var facing_cut := boss_cut + facing_chance

	if roll < hero_cut and not drifters_hero.is_empty():
		return { "id": drifters_hero.pick_random(), "facing": true,
			"scale_min": hero_scale_min, "scale_max": hero_scale_max }
	if roll < boss_cut and not drifters_boss.is_empty():
		return { "id": drifters_boss.pick_random(), "facing": true,
			"scale_min": boss_scale_min, "scale_max": boss_scale_max }
	if roll < facing_cut and not drifters_facing.is_empty():
		return { "id": drifters_facing.pick_random(), "facing": true,
			"scale_min": drift_scale_min, "scale_max": drift_scale_max }
	if drifters_upright.is_empty():
		return {}
	return { "id": drifters_upright.pick_random(), "facing": false,
		"scale_min": drift_scale_min, "scale_max": drift_scale_max }


func _move_drifters(delta: float) -> void:
	for i in range(_drifters.size() - 1, -1, -1):
		var sprite: AnimatedSprite2D = _drifters[i]["node"]
		sprite.position.x -= float(_drifters[i]["speed"]) * delta
		# Gone once its own half-width has cleared the left edge, whatever
		# size it was scaled to.
		if sprite.position.x < -80.0 - sprite.scale.x * 64.0:
			sprite.queue_free()
			_drifters.remove_at(i)


## Slices one enemy's sheet into a looping "idle", reusing the geometry
## EnemyFactory already records for it — so a faction whose art changes there
## changes here too, with nothing to keep in sync by hand.
func _drifter_frames(id: String) -> SpriteFrames:
	if _frames.has(id):
		return _frames[id]

	# Enemy data first, then the handful of sheets that aren't enemies.
	var def: Dictionary = {}
	if EnemyFactory.DEFS.has(id):
		def = EnemyFactory.DEFS[id]
	elif EXTRA_SHEETS.has(id):
		def = EXTRA_SHEETS[id]
	else:
		push_warning("MainMenu: no sheet for drifter '%s'" % id)
		_frames[id] = null
		return null

	var tex: Texture2D = load(def["sheet"])
	var fw: int = int(def["fw"])
	var fh: int = int(def["fh"])
	var cols := maxi(1, tex.get_width() / fw)

	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", float(def["fps"]))
	frames.set_animation_loop("idle", true)
	for i in int(def["count"]):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		@warning_ignore("integer_division")
		atlas.region = Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)
		frames.add_frame("idle", atlas)
	frames.remove_animation("default")

	_frames[id] = frames
	return frames


# ── The UFO ───────────────────────────────────────────────────────────────────

## Takes the Ufo node's authored transform as the landing spot, drops it off
## the top of the screen, and flies it back — so re-positioning the UFO in the
## editor is all it takes to change where the entrance ends.
func _fly_ufo_in() -> void:
	var home := _ufo.position
	var home_scale := _ufo.scale
	var view := get_viewport_rect().size

	_ufo.position = Vector2(view.x * 0.9, -view.y * 0.5)
	_ufo.scale = home_scale * 0.1
	_ufo.rotation = 0.0
	_ufo_dash.scale = Vector2(0.1, 0.1)

	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(_ufo, "position", home, entrance_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	entrance.tween_property(_ufo, "scale", home_scale, entrance_time)
	entrance.tween_property(_ufo, "rotation_degrees", entrance_spin, entrance_time)
	entrance.tween_property(_ufo_dash, "scale", Vector2.ONE, entrance_time)
	entrance.chain().tween_callback(_float_ufo)


func _float_ufo() -> void:
	_ufo.rotation = 0.0   # -720° and 0° look identical; keep the number sane
	var bob := create_tween().set_loops()
	bob.tween_property(_ufo_body, "position:y", bob_distance, bob_time)\
		.as_relative().set_trans(Tween.TRANS_SINE)
	bob.tween_property(_ufo_body, "position:y", -bob_distance, bob_time)\
		.as_relative().set_trans(Tween.TRANS_SINE)


func _drift_sky() -> void:
	var sky := create_tween().set_loops()
	sky.tween_property(_background, "offset:y", sky_drift, sky_drift_time)\
		.as_relative().set_trans(Tween.TRANS_SINE)
	sky.tween_property(_background, "offset:y", -sky_drift, sky_drift_time)\
		.as_relative().set_trans(Tween.TRANS_SINE)


# ── Buttons ───────────────────────────────────────────────────────────────────

func _on_play() -> void:
	if _leaving or _overlay.visible:
		return
	_leaving = true
	AudioManager.play_sfx("playGame")
	GameManager.goto_scene(play_scene)


func _on_settings() -> void:
	if _leaving or _overlay.visible:
		return
	AudioManager.play_sfx("interacting")
	_settings_panel.refresh()
	_settings_page.visible = true
	_credits_page.visible = false
	_close_btn.visible = false     # the panel has its own Back
	_overlay.visible = true


func _on_credits() -> void:
	if _leaving or _overlay.visible:
		return
	AudioManager.play_sfx("interacting")
	_credits_scroll.scroll_vertical = 0
	_settings_page.visible = false
	_credits_page.visible = true
	_close_btn.visible = true
	_overlay.visible = true


func _on_quit() -> void:
	if _leaving or _overlay.visible:
		return
	_leaving = true
	SaveManager.save_all()
	get_tree().quit()


func _close_overlay() -> void:
	_overlay.visible = false
	_credits_page.visible = false
	_settings_page.visible = false
