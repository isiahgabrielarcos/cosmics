extends Control
class_name AvatarFloat

# Gives a portrait a little life: it rises into frame from below and then
# breathes in place.
#
# Everything moves DOWNWARD-to-UPWARD only. These portraits are cropped at the
# waist, so any motion that carries them down past their resting spot exposes
# the cut edge — the idle therefore oscillates between "rest" and "a little
# above rest" rather than around rest.
#
# The squish is pivoted at the BOTTOM CENTRE of the image, so compressing the
# height pulls the top down and leaves the base planted. Scaling from the
# default top-left pivot instead lifts the feet off the chat box, which is
# what makes a squish look like the whole picture is being pumped.

## Pixels the idle lifts off the resting position.
@export var bob_height: float = 5.0
## Seconds for one full breath.
@export var bob_period: float = 3.2
## Fraction of height traded on the squish. Barely perceptible by design —
## you should read it as breathing, not as the image deforming.
@export var squish: float = 0.01

## How far below rest the entrance starts, and how long it takes.
@export var intro_rise: float = 90.0
@export var intro_time: float = 0.34

## Randomise the starting phase so several portraits on screen don't breathe
## in lockstep.
@export var random_phase: bool = true

var _rest_y: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _phase: float = 0.0
var _time: float = 0.0
var _intro: Tween = null


func _ready() -> void:
	_rest_y = position.y
	_base_scale = scale
	if random_phase:
		_phase = randf() * TAU
	_anchor_to_bottom()
	resized.connect(_anchor_to_bottom)


## Scaling pivots from the bottom centre of the image. Without this a
## TextureRect scales from its top-left corner, so squishing the height drags
## the portrait's base upward and it reads as bouncing rather than breathing.
func _anchor_to_bottom() -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y)


func _process(delta: float) -> void:
	if not visible:
		return
	# An intro is a one-off move to the resting spot; let it own the position.
	if _intro and _intro.is_valid():
		return

	_time += delta
	# 0 at rest, 1 at the top of the lift — never negative, so the portrait
	# never dips below where its crop is hidden.
	var lift := (1.0 - cos(_time * TAU / bob_period + _phase)) * 0.5

	position.y = _rest_y - lift * bob_height
	scale = Vector2(
		_base_scale.x,
		_base_scale.y * (1.0 - squish * (1.0 - lift)))


## Rises into frame. Call whenever the portrait (re)appears.
func play_intro() -> void:
	if _intro and _intro.is_valid():
		_intro.kill()

	position.y = _rest_y + intro_rise
	modulate.a = 0.0
	scale = Vector2(_base_scale.x, _base_scale.y * (1.0 - squish))

	_time = 0.0
	_intro = create_tween()
	_intro.set_parallel(true)
	_intro.tween_property(self, "position:y", _rest_y, intro_time)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_intro.tween_property(self, "scale", _base_scale, intro_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro.tween_property(self, "modulate:a", 1.0, intro_time * 0.7)


## Re-reads the resting position — call if the node is moved in the editor at
## runtime, or after a layout change.
func recapture_rest() -> void:
	_rest_y = position.y
	_base_scale = scale
