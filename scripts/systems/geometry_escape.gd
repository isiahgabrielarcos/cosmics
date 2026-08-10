extends RefCounted

# Gets a kinematic body out of solid geometry it should never have been inside.
#
# Deliberately NOT a `class_name` global: global classes only exist once the
# editor has rescanned and written them into .godot/global_script_class_cache,
# so a brand new one fails to resolve for anybody who pulls the project and
# runs it before opening the editor — and a parse error here takes every
# script that references it down with it. Callers preload it instead.
#
# Asteroid and shrine walls are static tile collision. Anything that moves a
# body without asking physics can plant it in there — the pierce lunge used to
# tween the ship's position outright, a rock can drift onto a stationary
# enemy, and a knockback can shove one through a wall. Once inside,
# move_and_slide's own depenetration only nudges a body a little per frame,
# which never climbs out of rock several tiles thick, so it sits there stuck
# for the rest of the run.
#
# The test is the body's CENTRE POINT, not its shape. Touching a wall overlaps
# the shape constantly and is completely normal; the origin being inside solid
# geometry only ever means genuinely stuck. That distinction is what keeps
# this from teleporting things that are merely flying along a rock's surface.

## How far out to look for open space, and in how many steps. 640 clears the
## thickest wall on the big asteroids.
const MAX_DISTANCE := 640.0
const STEPS := 8
const DIRECTIONS := 8

## Walls (physics layer 7) — the asteroid and shrine tile geometry, and the
## ONLY thing that counts as being stuck inside something.
##
## Deliberately not the body's own collision_mask: an enemy's mask also covers
## other enemies and the player, so standing next to another enemy read as
## "inside geometry" and the poor thing teleported itself across the field
## every single physics frame.
const WALLS_MASK := 64


## Returns true if `body` was inside wall geometry and has been moved out.
## Cheap when it isn't: one point query, which is the overwhelmingly common
## case.
static func eject(body: CollisionObject2D, mask: int = WALLS_MASK) -> bool:
	var space := body.get_world_2d().direct_space_state
	if not is_solid(space, body.global_position, mask):
		return false

	# Straight out along the shortest escape: rings of increasing radius, and
	# the first free direction on the nearest ring wins.
	for step in range(1, STEPS + 1):
		var radius := MAX_DISTANCE * float(step) / float(STEPS)
		for i in DIRECTIONS:
			var candidate := body.global_position \
				+ Vector2.RIGHT.rotated(TAU * float(i) / float(DIRECTIONS)) * radius
			if not is_solid(space, candidate, mask):
				body.global_position = candidate
				return true
	return false


static func is_solid(space: PhysicsDirectSpaceState2D, at: Vector2, mask: int) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collision_mask = mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not space.intersect_point(query, 1).is_empty()
