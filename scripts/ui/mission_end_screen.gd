extends CanvasLayer

# Ports gameOverPlayer() + missionDonePlayer() from globalFunctions.lua.
# Listens to GameManager and shows Mission Failed / Mission Complete screens.

const RETRO_FONT := preload("res://assets/fonts/RetroGaming.ttf")
const TOBY_AVATAR := preload("res://assets/art/ui/tobyAvatar.png")
const EXPLOSION := preload("res://assets/art/characters/explosion.png")

var _root: Control


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.game_over_triggered.connect(_show_game_over)
	GameManager.mission_complete.connect(_show_mission_complete)

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

	_build_screen(
		"Mission Failed!",
		"You Have Failed to Defend the Cosmos\nCome back stronger space boy",
		[
			["Restart", func(): GameManager.goto_battle()],
			["Menu",    func(): GameManager.goto_main_menu()],
		],
		""
	)


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

	_build_screen(
		"Mission Complete!",
		"The cosmos are grateful for your work!\nGlad to see you again space cowboy~",
		[
			["Head to Base", func(): GameManager.goto_main_menu()],
		],
		rewards_text
	)


# ── UI builder ─────────────────────────────────────────────────────────────────

func _build_screen(title_text: String, subtitle_text: String,
		buttons: Array, rewards_text: String) -> void:
	if _root:
		_root.queue_free()

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)
	create_tween().tween_property(overlay, "color:a", 0.7, 0.5)

	# Toby avatar floating on the left (like the escape-pod avatar)
	var avatar := TextureRect.new()
	avatar.texture = TOBY_AVATAR
	avatar.custom_minimum_size = Vector2(400, 400)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.position = Vector2(-450, 550)
	_root.add_child(avatar)
	var slide := create_tween()
	slide.tween_property(avatar, "position:x", 120.0, 1.0)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide.tween_callback(func(): _float_avatar(avatar))

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position += Vector2(200, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 30)
	_root.add_child(panel)

	var title := _make_label(title_text, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var subtitle := _make_label(subtitle_text, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(subtitle)

	if rewards_text != "":
		var rewards := _make_label(rewards_text, 25)
		rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(rewards)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 100)
	panel.add_child(button_row)

	for b in buttons:
		button_row.add_child(_make_button(b[0], b[1]))


func _float_avatar(avatar: TextureRect) -> void:
	if not is_instance_valid(avatar):
		return
	var tw := create_tween().set_loops()
	tw.tween_property(avatar, "position:y", avatar.position.y + 10, 1.0)
	tw.tween_property(avatar, "position:y", avatar.position.y - 10, 1.0)


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
