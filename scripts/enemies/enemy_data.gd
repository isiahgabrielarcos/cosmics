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
@export var hp_per_hero_level: int = 14

## Whether killing this drops shards/XP at all. Off for enemies that are
## themselves a drop — baby slimes come out of a mama that already paid out,
## so letting each of the three pay again turned one kill into a shard shower.
@export var drops_loot: bool = true
@export var contact_damage: int = 5
@export var experience_value: int = 5
@export var speed: float = 260.0
@export var turn_rate: float = 5.0
@export var is_boss: bool = false

## Immune to burning and paralysis. Bosses are the fight, not something to be
## locked down by a cheap proc — a chain of electric rounds would otherwise
## hold one still for its entire health bar.
@export var immune_to_status: bool = false

## Ranged attack (shooters, and the FlaschBourn boss chaser+shooter hybrid)
@export var fires_projectiles: bool = false
@export var shoot_interval: float = 3.0
@export var projectile_speed: float = 400.0
@export var projectile_damage: int = 5

## Slasher lunge
## How close a slasher has to get before it commits to a lunge — far enough
## to read as a dive, close enough that it isn't lunging from off-screen.
@export var slash_range: float = 190.0
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

## Physics grouping — which enemy layer this archetype lives on. Each type
## only collides with its own kind, so a crowd interleaves instead of six
## archetypes all shoving each other into one mass. Six groups rather than
## three means bombers, fast ships and bosses each get their own lane too.
enum PhysicsGroup { CHASERS, SHIPS, SHOOTERS, SLASHERS, BOMBERS, BOSSES }
@export var physics_group: PhysicsGroup = PhysicsGroup.CHASERS
