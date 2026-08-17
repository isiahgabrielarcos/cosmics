extends Node2D

# The delivery point for a haul contract. Spawned a very long way off when the
# contract is taken, and the cargo's arrow points at it for the whole trip.
#
# It is a destination and nothing else: no collision with the ship, no combat.
# Arrival is a plain distance check from here, so nothing about the flight
# depends on a body actually touching a shape at speed.

signal reached

## How close the ship has to get to count as delivered. Generous, because the
## citadel art is enormous and clipping the edge of it should be enough.
@export var arrival_radius := 700.0

## Pulse of the structure, purely so it reads as active from far away.
@export var pulse_time := 1.6

## What it fades to once the delivery has landed. It is never removed: a
## structure that size vanishing the moment you touch it looks like a bug, and
## leaving it in place gives the sector a landmark. Dimming is enough to stop
## it competing with everything else for attention.
@export var delivered_tint := Color(0.45, 0.48, 0.58, 0.55)
@export var dim_time := 1.2

var _player: Node2D = null
var _done := false
var _pulse: Tween = null


func _ready() -> void:
	add_to_group("cosmic_citadel")
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "modulate:a", 0.75, pulse_time)\
		.set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(self, "modulate:a", 1.0, pulse_time)\
		.set_trans(Tween.TRANS_SINE)


## Cargo handed over. Stops the pulse and fades the whole structure back so it
## reads as done rather than still waiting for you.
func mark_delivered() -> void:
	_done = true
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	create_tween().tween_property(self, "modulate", delivered_tint, dim_time)\
		.set_trans(Tween.TRANS_SINE)


func _physics_process(_delta: float) -> void:
	if _done:
		return
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("friendlies")
		if players.is_empty():
			return
		_player = players[0]

	if global_position.distance_to(_player.global_position) <= arrival_radius:
		_done = true
		reached.emit()
