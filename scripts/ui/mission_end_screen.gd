extends CanvasLayer

# Ports gameOverPlayer() + missionDonePlayer() from globalFunctions.lua.
# Listens to GameManager and shows the Mission Failed / Mission Complete
# panels (scenes/ui/panels/game_over_panel.tscn, game_win_panel.tscn).

const EXPLOSION := preload("res://assets/art/characters/explosion.png")

@onready var _game_over: GameOverPanel = $GameOverPanel
@onready var _game_win: GameWinPanel   = $GameWinPanel


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS

	GameManager.game_over_triggered.connect(_show_game_over)
	GameManager.mission_complete.connect(_show_mission_complete)

	_game_over.restart_pressed.connect(func(): GameManager.goto_battle())
	_game_over.menu_pressed.connect(func(): GameManager.goto_main_menu())
	_game_win.continue_pressed.connect(func(): GameManager.goto_main_menu())

	# Hook the player's death signal into GameManager
	call_deferred("_connect_player")


func _connect_player() -> void:
	var players := get_tree().get_nodes_in_group("friendlies")
	if players.is_empty():
		return
	var player = players[0]
	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	# explosion at the hero, then the failed screen (gameOverPlayer)
	var players := get_tree().get_nodes_in_group("friendlies")
	if not players.is_empty():
		_spawn_explosion(players[0].global_position)
	AudioManager.play_sfx("gameOverSound")
	GameManager.trigger_game_over()


func _spawn_explosion(pos: Vector2) -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("idle1")
	frames.set_animation_speed("idle1", 12.0)
	frames.set_animation_loop("idle1", false)
	var tex: Texture2D = EXPLOSION
	var fw := 64
	var cols := maxi(1, int(tex.get_width() / fw))
	var total := maxi(1, cols * int(tex.get_height() / fw))
	for i in mini(total, 8):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		@warning_ignore("integer_division")
		atlas.region = Rect2((i % cols) * fw, (i / cols) * fw, fw, fw)
		frames.add_frame("idle1", atlas)

	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = frames
	fx.scale = Vector2(3, 3)
	fx.global_position = pos
	fx.play("idle1")
	get_tree().current_scene.add_child(fx)
	fx.animation_finished.connect(fx.queue_free)
	AudioManager.play_sfx("explosionSound")


# ── Mission Failed (gameOverPlayer) ────────────────────────────────────────────

func _show_game_over() -> void:
	AudioManager.play_music("gameOverMusic")
	await get_tree().create_timer(1.5).timeout
	GameManager.pause_game()
	_game_over.open()


# ── Mission Complete (missionDonePlayer) ───────────────────────────────────────

func _show_mission_complete() -> void:
	AudioManager.stop_music()
	AudioManager.play_sfx("missionComplete")
	AudioManager.play_music("missionCompleteMusic")
	GameManager.pause_game()

	var rewards_text: String
	if GameManager.difficulty == "expert":
		rewards_text = "Collected:\n +50 Cosmic Gems\n +%d Cosmic Shards\n +%d Central Currency" \
			% [GameManager.gathered_shards + 150, GameManager.gathered_currency + 250]
	else:
		rewards_text = "Collected:\n +15 Cosmic Gems\n +%d Cosmic Shards\n +%d Central Currency" \
			% [GameManager.gathered_shards + 50, GameManager.gathered_currency + 150]

	_game_win.open(rewards_text)
