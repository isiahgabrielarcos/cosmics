extends Node2D

# The thing you are hauling: a crate or a wounded ship, roped to the back of
# Toby's hull and dragged to a citadel.
#
# It follows rather than being parented, so the rope can go slack and taut and
# the cargo can swing behind you through a turn instead of being welded to the
# ship's rotation. The rope is a Line2D redrawn each frame between the two.
#
# While it is attached the ship is slower. That penalty is the contract: the
# reward is paid for flying a whole run at three quarters speed, not for the
# distance itself.
#
# The arrow above it always points at the citadel, because the delivery point
# is tens of thousands of pixels away and would otherwise be unfindable.

signal delivered

## Frame in escortAssets.png this cargo shows. The sheet is a 3x3 grid of
## 48x48; the top row is the three usable pieces. 0 and 2 are supply crates,
## 1 is the medical ship.
@export var frame: int = 0

## How far behind the ship the cargo trails, and how hard it is pulled back to
## that spot. Lower stiffness means a longer, lazier tether.
@export var tether_length := 70.0
@export var tether_stiffness := 6.0

## How quickly the cargo swings round to face the ship. It turns rather than
## snapping, so being towed reads as something being dragged on a line instead
## of a sprite glued to an angle.
@export var face_turn_rate := 8.0

## What the ship's speed is multiplied by while this is attached.
@export var speed_penalty := 0.75

const SHEET := preload("res://assets/art/characters/escortAssets.png")
const FRAME_SIZE := 48

@onready var _sprite: Sprite2D = $Sprite
@onready var _rope: Line2D = $Rope
@onready var _arrow: Node2D = $Arrow

var _player: Node2D = null
var _target: Node2D = null
var _attached := false


func _ready() -> void:
	add_to_group("escort_cargo")
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	@warning_ignore("integer_division")
	atlas.region = Rect2((frame % 3) * FRAME_SIZE, (frame / 3) * FRAME_SIZE,
		FRAME_SIZE, FRAME_SIZE)
	_sprite.texture = atlas


## Hooks the cargo to the ship and points its arrow at `target`.
func attach(player: Node2D, target: Node2D) -> void:
	_player = player
	_target = target
	_attached = true
	# Start already trailing rather than on top of the ship, so the rope is
	# drawn taut from the first frame.
	global_position = player.global_position - Vector2(0, -tether_length)
	_apply_speed_penalty(speed_penalty)


func release() -> void:
	if not _attached:
		return
	_attached = false
	_apply_speed_penalty(1.0)


## The ship carries a separate haul multiplier rather than reusing
## speed_multiplier, which the Overdrive module already drives — sharing it
## meant an overdrive ending would quietly hand back full speed mid-delivery.
func _apply_speed_penalty(value: float) -> void:
	if _player != null and is_instance_valid(_player) and "haul_multiplier" in _player:
		_player.haul_multiplier = value


func _physics_process(delta: float) -> void:
	if not _attached or _player == null or not is_instance_valid(_player):
		return

	# Chase the point behind the ship. Framerate independent so a slow frame
	# doesn't snap the cargo forward through the rope.
	var anchor: Vector2 = _player.global_position
	var offset := global_position - anchor
	if offset.length() < 1.0:
		offset = Vector2(0, tether_length)
	var goal := anchor + offset.normalized() * tether_length
	global_position = global_position.lerp(goal, clampf(tether_stiffness * delta, 0.0, 1.0))

	_rope.points = PackedVector2Array([Vector2.ZERO, to_local(anchor)])

	# Only the sprite turns. The root stays upright so the arrow above it can
	# keep pointing at the citadel independently of which way the cargo faces.
	# The art is drawn nose-up, hence the quarter turn.
	var toward_ship := (anchor - global_position).angle() + PI / 2.0
	_sprite.rotation = lerp_angle(_sprite.rotation, toward_ship,
		clampf(face_turn_rate * delta, 0.0, 1.0))

	if _target != null and is_instance_valid(_target):
		# Arrow lives above the cargo and is drawn pointing up, so the
		# quarter turn puts its nose on the citadel.
		_arrow.rotation = (_target.global_position - global_position).angle() + PI / 2.0
		_arrow.visible = true
	else:
		_arrow.visible = false


func complete() -> void:
	release()
	delivered.emit()
	queue_free()
