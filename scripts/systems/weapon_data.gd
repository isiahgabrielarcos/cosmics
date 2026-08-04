extends Resource
class_name WeaponData

## Base stats for one weapon archetype. WeaponSystem scales base_damage by
## the player's stat block at fire time — these are the *base* numbers
## before that scaling, so tuning a weapon's feel means editing one resource
## instead of hunting through code.

@export var base_damage: int = 20
@export var fire_rate: float = 0.25     # seconds between shots (lower = faster)
@export var visual_scale: float = 1.0   # "size"
@export var hit_radius: float = 14.0
@export var lifetime: float = 1.0
@export var speed: float = 800.0        # 0 for melee archetypes that ride the ship
@export var pierce: int = 2

## Shots the weapon holds before it has to reload. Per-weapon, so a slow
## heavy swing doesn't carry as many rounds as the starter laser.
@export var ammo_capacity: int = 18

## Ceiling on pierce once upgrades start stacking on top of `pierce`.
## -1 means uncapped — the melee sweeps cut through everything.
@export var pierce_cap: int = -1

enum Archetype { BOLT, SWEEP, THRUST, SHIELD }
@export var archetype: Archetype = Archetype.BOLT

## SWEEP (slash / wide) — spins in front of the ship.
@export var spin_speed: float = 0.0

## THRUST (pierce) — how far the ship lunges forward while the hitbox
## rides with it; damage is front-loaded since the ship leads the thrust.
@export var thrust_distance: float = 150.0

## SHIELD — knocks enemies back and grants brief invulnerability.
@export var knockback_force: float = 400.0
@export var invuln_duration: float = 0.0
