extends Area2D
class_name NpcBase

# Ports the cosmicNPCs() characters — an idle-animated NPC with an
# "E to interact" prompt when the player is near. Solid NPCs (guards, trader,
# blacksmith) also block the ship like the original static bodies.

signal interacted

const NPC_SHEET := preload("res://assets/art/characters/allNPCSprite.png")
const PROMPT_TEX := preload("res://assets/art/ui/interacting.png")

const FRAME := 96
const COLS := 7   # 672 / 96

var start_frame: int = 0       # 0-based index into the sheet
var frame_count: int = 3
var fps: float = 3.75          # ~800 ms for 3 frames
var solid: bool = false
var interact_radius: float = 160.0

var _prompt: Sprite2D
var _player_in_range: bool = false


static func create(cfg: Dictionary) -> NpcBase:
	var npc := NpcBase.new()
	npc.start_frame = cfg.get("start_frame", 0)
	npc.frame_count = cfg.get("frame_count", 3)
	npc.fps = cfg.get("fps", 3.75)
	npc.solid = cfg.get("solid", false)
	npc.interact_radius = cfg.get("interact_radius", 160.0)
	npc.position = cfg.get("position", Vector2.ZERO)
	npc.name = cfg.get("name", "NPC")
	return npc


func _ready() -> void:
	# idle animation
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", fps)
	frames.set_animation_loop("idle", true)
	for i in frame_count:
		var idx := start_frame + i
		var atlas := AtlasTexture.new()
		atlas.atlas = NPC_SHEET
		@warning_ignore("integer_division")
		atlas.region = Rect2((idx % COLS) * FRAME, (idx / COLS) * FRAME, FRAME, FRAME)
		frames.add_frame("idle", atlas)

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.scale = Vector2(1.5, 1.5)
	sprite.play("idle")
	add_child(sprite)

	# interact detection zone
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = interact_radius
	shape.shape = circle
	add_child(shape)
	collision_layer = 0
	collision_mask = 1   # detects the player body

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# solid NPCs block the ship (guards / trader / blacksmith in the Lua)
	if solid:
		var body := StaticBody2D.new()
		body.collision_layer = 64   # walls layer
		var solid_shape := CollisionShape2D.new()
		var solid_circle := CircleShape2D.new()
		solid_circle.radius = 60.0
		solid_shape.shape = solid_circle
		body.add_child(solid_shape)
		add_child(body)

	# "E" prompt above the head
	_prompt = Sprite2D.new()
	_prompt.texture = PROMPT_TEX
	_prompt.position = Vector2(0, -110)
	_prompt.visible = false
	add_child(_prompt)


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact") and not GameManager.ui_open:
		get_viewport().set_input_as_handled()
		AudioManager.play_sfx("interacting")
		interacted.emit()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("friendlies"):
		_player_in_range = true
		_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("friendlies"):
		_player_in_range = false
		_prompt.visible = false
