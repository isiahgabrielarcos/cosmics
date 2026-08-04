extends Resource
class_name EnemyData

## Per-faction/per-archetype stat block. One archetype scene (chaser / bomber /
## shooter / slasher) gets reused across every solar system by swapping this
## resource — factions differ only in sprite sheet + numbers, not behaviour.

## Visuals — a plain grid spritesheet, sliced into a single "idle" loop.
@export var sprite_sheet: Texture2D
@export var frame_width: int = 32
@export var frame_height: int = 32
@export var frame_count: int = 3
@export var fps: float = 6.0

## Sizing — random range unless fixed_scale > 0 (bosses / babies use a fixed size)
@export var scale_min: float = 2.0
@export var scale_max: float = 3.0
@export var fixed_scale: float = 0.0

## Stats. `max_hp` is the base only — EnemyUnit adds `hp_per_hero_level` for
## every hero level and then applies the difficulty multiplier at spawn.
@export var max_hp: int = 50
@export var hp_per_hero_level: int = 20
@export var contact_damage: int = 5
@export var experience_value: int = 5
@export var speed: float = 260.0
@export var turn_rate: float = 5.0
@export var is_boss: bool = false

## Ranged attack (shooters, and the FlaschBourn boss chaser+shooter hybrid)
@export var fires_projectiles: bool = false
@export var shoot_interval: float = 3.0
@export var projectile_speed: float = 400.0
@export var projectile_damage: int = 5

## Slasher lunge
@export var slash_range: float = 100.0
@export var slash_speed: float = 1400.0
@export var slash_cooldown: float = 1.5

## Death — spawn a different enemy (mama slime -> babies)
@export var death_spawn_data: EnemyData
@export var death_spawn_count: int = 0

## Death — split into smaller copies of self (Squilltrant boss: 1 -> 2 -> 4)
@export var self_split_count: int = 0
@export var self_split_max_depth: int = 0
@export var self_split_scale_mult: float = 0.6
@export var self_split_hp_mult: float = 0.5

## Physics grouping — which of the 3 enemy layers this archetype lives on,
## so different groups can overlap instead of everything clumping together.
enum PhysicsGroup { CHASERS, SHIPS, SHOOTERS }
@export var physics_group: PhysicsGroup = PhysicsGroup.CHASERS
