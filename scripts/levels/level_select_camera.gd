extends Node3D

# Orbit rig for the level-selection cluster. This script goes on the
# "camera pointer" Node3D; the Camera3D is a child pushed back on +Z, so
# rotating this node swings the camera around the citadel at the centre.
#
# Hold left OR right mouse and drag to rotate. Horizontal drag yaws, vertical
# drag pitches (clamped so the view never flips over the poles). Releasing
# keeps a little momentum, and an idle drift keeps the scene alive when the
# player isn't touching it.

@export var drag_sensitivity: float = 0.006
@export var pitch_min_deg: float = -60.0
@export var pitch_max_deg: float = 60.0

@export var momentum_damping: float = 4.0   # higher = spin settles sooner
@export var idle_drift_speed: float = 0.04  # radians/sec when untouched
@export var idle_delay: float = 2.5         # seconds before drift resumes

var _dragging: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _idle_timer: float = 0.0
var _enabled: bool = true


func set_input_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
			if mb.pressed:
				_velocity = Vector2.ZERO
				_idle_timer = 0.0

	elif event is InputEventMouseMotion and _dragging:
		var rel := (event as InputEventMouseMotion).relative
		_apply_rotation(-rel.x * drag_sensitivity, -rel.y * drag_sensitivity)
		_velocity = -rel * drag_sensitivity
		_idle_timer = 0.0


func _process(delta: float) -> void:
	if _dragging:
		return

	# coast to a stop after the drag is released
	if _velocity.length() > 0.0001:
		_apply_rotation(_velocity.x, _velocity.y)
		_velocity = _velocity.lerp(Vector2.ZERO, clampf(momentum_damping * delta, 0.0, 1.0))
		_idle_timer = 0.0
		return

	# slow ambient spin once the player has been hands-off for a moment
	_idle_timer += delta
	if _idle_timer >= idle_delay:
		_apply_rotation(idle_drift_speed * delta, 0.0)


func _apply_rotation(yaw: float, pitch: float) -> void:
	rotation.y = wrapf(rotation.y + yaw, -PI, PI)
	rotation.x = clampf(rotation.x + pitch,
		deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
