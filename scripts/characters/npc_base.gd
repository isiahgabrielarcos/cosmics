extends Area2D
class_name NpcBase

# An idle-animated NPC with an "E to interact" prompt when the player is
# near. Solid NPCs (guards, trader, blacksmith) block the ship via a
# StaticBody2D child baked into the scene. Sprite frames, the interact
# radius, and the prompt are all real scene nodes — see scenes/npcs/*.tscn.

signal interacted

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _prompt: Sprite2D = $Prompt

var _player_in_range: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1   # detects the player body
	_prompt.visible = false
	_sprite.play("idle")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


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
