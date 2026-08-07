extends Node2D
class_name EnvironmentSpawner

# Drops the scenery from scenes/environment/ in around the player: junk
# drifting past, the occasional wreck to fly around, and rarely a shrine.
#
# Everything spawns off-camera and drifts in. Direction is *biased* toward the
# player rather than aimed at them — a cone rather than a line — because props
# that all converge on the ship read as an attack, and props with no bias at
# all mostly never come into view. The bias is what makes the field feel
# inhabited without feeling aimed.
#
# Frequency is per-category rather than one shared roll, so the common junk
# can be genuinely common while shrines stay a find.

const TRASH_SCENES := [
	preload("res://scenes/environment/space_trash_1.tscn"),
	preload("res://scenes/environment/space_trash_2.tscn"),
	preload("res://scenes/environment/space_trash_3.tscn"),
	preload("res://scenes/environment/space_trash_4.tscn"),
]
const SCRAP_SCENES := [
	preload("res://scenes/environment/space_scraps_1.tscn"),
	preload("res://scenes/environment/space_scraps_2.tscn"),
	preload("res://scenes/environment/space_scraps_3.tscn"),
]
const ASTEROID_SCENES := [
	preload("res://scenes/environment/asteroid_big_1.tscn"),
	preload("res://scenes/environment/asteroid_big_2.tscn"),
	preload("res://scenes/environment/asteroid_big_3.tscn"),
]
const SHRINE_SCENES := [
	preload("res://scenes/environment/shrine_1.tscn"),
	preload("res://scenes/environment/shrine_2.tscn"),
	preload("res://scenes/environment/shrine_3.tscn"),
]

# category -> how often it's rolled, how many may exist at once, and how it
# moves. `chance` is percent per tick.
const CATEGORIES := {
	"trash":    { "chance": 55, "cap": 14, "speed": Vector2(35.0, 90.0),  "spin": 0.5 },
	"scrap":    { "chance": 22, "cap": 7,  "speed": Vector2(25.0, 70.0),  "spin": 0.35 },
	"asteroid": { "chance": 5,  "cap": 3,  "speed": Vector2(18.0, 45.0),  "spin": 0.18 },
	"shrine":   { "chance": 2,  "cap": 2,  "speed": Vector2(0.0, 0.0),    "spin": 0.0 },
}

const TICK_INTERVAL := 1.5

## How far off the camera edge things appear. Comfortably outside the view so
## nothing is ever seen popping in.
const SPAWN_MARGIN := 900.0

## Half-angle of the cone a prop's drift is allowed to deviate from "straight
## at the player". Wide enough that most things cross the play area at an
## angle instead of bearing down on the ship.
const DRIFT_CONE := deg_to_rad(62.0)

## Shrines hold still, so they're placed nearer than the drifting props —
## otherwise the player would rarely stumble across one at all.
const SHRINE_MARGIN := 500.0

@export var player_path: NodePath
@export var camera_path: NodePath

var rng := RandomNumberGenerator.new()
var _player: Node2D
var _camera: Camera2D
var _timer: Timer


func _ready() -> void:
	rng.randomize()
	_player = get_node_or_null(player_path)
	_camera = get_node_or_null(camera_path)
	if _player == null or _camera == null:
		push_warning("EnvironmentSpawner: player or camera not assigned.")
		return

	_timer = Timer.new()
	_timer.wait_time = TICK_INTERVAL
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	_timer.start()


func _on_tick() -> void:
	if GameManager.game_done or GameManager.is_hub():
		return
	for category in CATEGORIES:
		var cfg: Dictionary = CATEGORIES[category]
		if _count(category) >= int(cfg["cap"]):
			continue
		if rng.randi_range(1, 100) <= int(cfg["chance"]):
			_spawn(category, cfg)


func _count(category: String) -> int:
	var n := 0
	for prop in get_tree().get_nodes_in_group("space_props"):
		if prop.get_meta("prop_category", "") == category:
			n += 1
	return n


func _spawn(category: String, cfg: Dictionary) -> void:
	var scene: PackedScene = _scene_for(category)
	if scene == null:
		return

	var prop: Node2D = scene.instantiate()
	prop.set_script(preload("res://scripts/systems/space_prop.gd"))
	prop.set_meta("prop_category", category)

	var margin: float = SHRINE_MARGIN if category == "shrine" else SPAWN_MARGIN
	var at := _outside_camera(margin)
	prop.global_position = at

	var speed_band: Vector2 = cfg["speed"]
	if speed_band.y > 0.0:
		prop.drift = _drift_from(at) * rng.randf_range(speed_band.x, speed_band.y)
		prop.spin = rng.randf_range(-float(cfg["spin"]), float(cfg["spin"]))
		# Only tumbling debris starts at a random angle. Shrines are built
		# structures — they stay upright the way they were authored.
		prop.rotation = rng.randf() * TAU

	get_tree().current_scene.add_child(prop)
	_populate(prop, category)


func _scene_for(category: String) -> PackedScene:
	match category:
		"trash":    return TRASH_SCENES[rng.randi_range(0, TRASH_SCENES.size() - 1)]
		"scrap":    return SCRAP_SCENES[rng.randi_range(0, SCRAP_SCENES.size() - 1)]
		"asteroid": return ASTEROID_SCENES[rng.randi_range(0, ASTEROID_SCENES.size() - 1)]
		"shrine":   return SHRINE_SCENES[rng.randi_range(0, SHRINE_SCENES.size() - 1)]
	return null


## Toward the player, rotated by a random amount inside DRIFT_CONE. The result
## crosses the play area near the ship without heading straight for it.
func _drift_from(spawn_point: Vector2) -> Vector2:
	var toward := (_player.global_position - spawn_point).normalized()
	return toward.rotated(rng.randf_range(-DRIFT_CONE, DRIFT_CONE))


## Shrines carry their own contents: a chest to find, and on shrine_3 a few
## shooters already dug in around it.
func _populate(prop: Node2D, category: String) -> void:
	if category != "shrine":
		return

	var chest_spot := prop.get_node_or_null("SpawnChest") as Node2D
	if chest_spot:
		ModuleChest.spawn(get_tree().current_scene, chest_spot.global_position)

	var faction := _faction()
	if faction == 0:
		return
	for child in prop.get_children():
		if child is Node2D and child.name.begins_with("enemySpawn"):
			EnemyFactory.spawn_kind(get_tree().current_scene, faction, "shooter",
				(child as Node2D).global_position)


func _faction() -> int:
	var system := GameManager.get_system_index()
	return system if system > 0 else rng.randi_range(1, 4)


func _outside_camera(margin: float) -> Vector2:
	var screen := get_viewport().get_visible_rect().size
	var rect := Rect2(_camera.global_position - screen * 0.5, screen)
	match rng.randi_range(0, 3):
		0:
			return Vector2(rect.position.x - margin,
				rng.randf_range(rect.position.y, rect.position.y + rect.size.y))
		1:
			return Vector2(rect.position.x + rect.size.x + margin,
				rng.randf_range(rect.position.y, rect.position.y + rect.size.y))
		2:
			return Vector2(rng.randf_range(rect.position.x, rect.position.x + rect.size.x),
				rect.position.y - margin)
	return Vector2(rng.randf_range(rect.position.x, rect.position.x + rect.size.x),
		rect.position.y + rect.size.y + margin)
