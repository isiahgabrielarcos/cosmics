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
#
# ── Layers ────────────────────────────────────────────────────────────────────
# Props go into the Parallax2D decor layers rather than straight into the
# scene. The first one named is the real one — its props have collision, its
# shrines carry chests and guards. Every layer after it is scenery only:
# collision switched off, chests and enemy markers stripped out. Because those
# layers scroll at their own rate they read as depth behind the play area, and
# because nothing in them is solid the player can never bump into or loot
# something that's meant to be a mile away.

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

# category -> how often it's rolled, how many may exist at once (per layer),
# and how it moves. `chance` is percent per tick. `solid` marks the categories
# that hold each other apart instead of drifting through one another.
const CATEGORIES := {
	"trash":    { "chance": 55, "cap": 14, "speed": Vector2(35.0, 90.0), "spin": 0.5,  "solid": false },
	"scrap":    { "chance": 22, "cap": 7,  "speed": Vector2(25.0, 70.0), "spin": 0.35, "solid": false },
	"asteroid": { "chance": 5,  "cap": 3,  "speed": Vector2(18.0, 45.0), "spin": 0.18, "solid": true },
	"shrine":   { "chance": 2,  "cap": 2,  "speed": Vector2(0.0, 0.0),   "spin": 0.0,  "solid": true },
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

# ── Keeping props off each other ──────────────────────────────────────────────
# Two rules, and they do different jobs. The spawn check stops a prop being
# *born* on top of something, which is what produced most of the visible
# overlap. Separation then keeps the solid ones apart as they drift, since two
# rocks on converging courses would otherwise slide straight through each
# other — their collision is static tile geometry, which doesn't push back.

## Breathing room on top of the two footprints merely touching.
const SPAWN_CLEARANCE := 70.0

## Positions tried per spawn before giving up and waiting for the next tick.
## Skipping is the right failure: a crowded field just stays as it is.
const SPAWN_ATTEMPTS := 8

const SEPARATION_INTERVAL := 0.25

## Ceiling on the measured footprint, so one sprawling prop can't claim half
## the field and starve everything else out of a spawn.
const MAX_FOOTPRINT := 700.0

@export var player_path: NodePath
@export var camera_path: NodePath

## Decor layers are found by name rather than wired up, because an exported
## NodePath array does not reliably survive the scene being re-saved in the
## editor — and when it silently emptied, every prop quietly went into the
## scene root instead and the parallax layers looked broken.
##
## Any sibling whose name starts with this, in name order: "Space Decor 1",
## "Space Decor 2", ... Add a "Space Decor 4" in the editor and it fills up
## with no code change.
@export var decor_layer_prefix := "Space Decor"

## Optional explicit override. Leave empty to use the prefix search above.
@export var decor_layer_paths: Array[NodePath] = []

var rng := RandomNumberGenerator.new()
var _player: Node2D
var _camera: Camera2D
var _timer: Timer
var _layers: Array[Node] = []
var _separation_clock := 0.0


func _ready() -> void:
	rng.randomize()
	_player = get_node_or_null(player_path)
	_camera = get_node_or_null(camera_path)
	if _player == null or _camera == null:
		push_warning("EnvironmentSpawner: player or camera not assigned.")
		return

	_resolve_layers()

	_timer = Timer.new()
	_timer.wait_time = TICK_INTERVAL
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	_timer.start()


## Explicit paths win if they're set; otherwise every sibling named with the
## prefix, in name order, so "Space Decor 1" is the solid one and everything
## after it is scenery. Falling back to the scene root keeps a level with no
## decor layers at all working exactly as it did before.
func _resolve_layers() -> void:
	for path in decor_layer_paths:
		var layer := get_node_or_null(path)
		if layer != null:
			_layers.append(layer)
	if not _layers.is_empty():
		return

	var found: Array[Node] = []
	var parent := get_parent()
	if parent != null:
		for sibling in parent.get_children():
			if sibling != self and str(sibling.name).begins_with(decor_layer_prefix):
				found.append(sibling)
	found.sort_custom(func(a, b): return str(a.name) < str(b.name))
	_layers.assign(found)

	if _layers.is_empty():
		_layers.append(get_tree().current_scene)


func _process(delta: float) -> void:
	if GameManager.game_done or GameManager.is_hub():
		return
	_separation_clock -= delta
	if _separation_clock > 0.0:
		return
	_separation_clock = SEPARATION_INTERVAL
	_separate_solids()


func _on_tick() -> void:
	if GameManager.game_done or GameManager.is_hub():
		return
	for layer_index in _layers.size():
		for category in CATEGORIES:
			var cfg: Dictionary = CATEGORIES[category]
			if _count(category, layer_index) >= int(cfg["cap"]):
				continue
			if rng.randi_range(1, 100) <= int(cfg["chance"]):
				_spawn(category, cfg, layer_index)


func _count(category: String, layer_index: int) -> int:
	var n := 0
	for prop in get_tree().get_nodes_in_group("space_props"):
		if prop.get_meta("prop_category", "") == category \
				and int(prop.get_meta("prop_layer", 0)) == layer_index:
			n += 1
	return n


# ── Spawning ──────────────────────────────────────────────────────────────────

func _spawn(category: String, cfg: Dictionary, layer_index: int) -> void:
	var scene: PackedScene = _scene_for(category)
	if scene == null:
		return

	var prop: Node2D = scene.instantiate()
	prop.set_script(preload("res://scripts/systems/space_prop.gd"))
	prop.set_meta("prop_category", category)
	prop.set_meta("prop_layer", layer_index)

	# Only the nearest layer is real. Everything behind it is a picture.
	var decorative := layer_index > 0
	if decorative:
		_strip_to_scenery(prop)

	# Parented FIRST, and only then positioned. The decor layers are scaled
	# Parallax2Ds, and global_position on a node outside the tree is just its
	# local position — set it before parenting and the layer's scale drags the
	# prop somewhere else the moment it's added, which put props on top of each
	# other no matter what the clearance check said.
	_layers[layer_index].add_child(prop)

	# Measured after parenting too, so the radius is the footprint in world
	# space rather than in the layer's shrunken local space.
	var radius := minf(_footprint_radius(prop), MAX_FOOTPRINT)
	prop.set_meta("prop_radius", radius)
	prop.set_meta("prop_solid", bool(cfg["solid"]) and not decorative)

	var margin: float = SHRINE_MARGIN if category == "shrine" else SPAWN_MARGIN
	var spot: Variant = _find_clear_spot(margin, radius, layer_index, prop)
	if spot == null:
		prop.queue_free()   # nowhere to put it this tick; the field is busy
		return
	var at: Vector2 = spot
	prop.global_position = at

	var speed_band: Vector2 = cfg["speed"]
	if speed_band.y > 0.0:
		prop.drift = _drift_from(at) * rng.randf_range(speed_band.x, speed_band.y)
		prop.spin = rng.randf_range(-float(cfg["spin"]), float(cfg["spin"]))
		# Only tumbling debris starts at a random angle. Shrines are built
		# structures — they stay upright the way they were authored.
		prop.rotation = rng.randf() * TAU

	if not decorative:
		_populate(prop, category)


## Tries a few off-camera positions and returns the first that isn't sitting on
## top of something. Null means every attempt was crowded.
func _find_clear_spot(margin: float, radius: float, layer_index: int,
		ignore: Node2D) -> Variant:
	for attempt in SPAWN_ATTEMPTS:
		var at := _outside_camera(margin)
		if _is_clear(at, radius, layer_index, ignore):
			return at
	return null


## Props only crowd others on their own layer — a rock in a distant parallax
## layer isn't anywhere near the play area, whatever the raw coordinates say.
## `ignore` is the prop being placed: it's already in the tree (and so in the
## group) by this point, and it is always zero distance from itself.
func _is_clear(at: Vector2, radius: float, layer_index: int, ignore: Node2D) -> bool:
	for other in get_tree().get_nodes_in_group("space_props"):
		if other == ignore or not is_instance_valid(other):
			continue
		if int(other.get_meta("prop_layer", 0)) != layer_index:
			continue
		var needed: float = radius + float(other.get_meta("prop_radius", 0.0)) + SPAWN_CLEARANCE
		if at.distance_to((other as Node2D).global_position) < needed:
			return false
	return true


## Measured from the prop's own tile layers rather than hard-coded per
## category, so re-drawing an asteroid changes the space it claims for free.
func _footprint_radius(prop: Node2D) -> float:
	var largest := 0.0
	for child in prop.get_children():
		if not (child is TileMapLayer):
			continue
		var layer := child as TileMapLayer
		if layer.tile_set == null:
			continue
		var used := layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var extent := Vector2(used.size) * Vector2(layer.tile_set.tile_size) * 0.5
		largest = maxf(largest, extent.length())
	# global_scale, not scale: a prop in a 0.4x parallax layer really is that
	# much smaller on screen, and claiming its unscaled footprint would starve
	# the far layers of spawns.
	return largest * absf(prop.global_scale.x)


## Turns a prop into pure scenery: nothing solid, nothing to collect, nothing
## to fight. Used for every decor layer behind the first.
func _strip_to_scenery(prop: Node2D) -> void:
	for child in prop.get_children():
		if child is TileMapLayer:
			(child as TileMapLayer).collision_enabled = false
		elif child is Area2D:
			# The trash pickup trigger. Scenery a mile back must not be
			# collectable — SpaceProp already refuses to arm it off the solid
			# layer, and switching it off here means it can't fire at all.
			var area := child as Area2D
			area.monitoring = false
			area.monitorable = false
		elif child.name == "SpawnChest" or child.name.begins_with("enemySpawn"):
			child.queue_free()


func _scene_for(category: String) -> PackedScene:
	match category:
		"trash":    return TRASH_SCENES[rng.randi_range(0, TRASH_SCENES.size() - 1)]
		"scrap":    return SCRAP_SCENES[rng.randi_range(0, SCRAP_SCENES.size() - 1)]
		"asteroid": return ASTEROID_SCENES[rng.randi_range(0, ASTEROID_SCENES.size() - 1)]
		"shrine":   return SHRINE_SCENES[rng.randi_range(0, SHRINE_SCENES.size() - 1)]
	return null


# ── Keeping the solid ones apart ──────────────────────────────────────────────

## Asteroids and shrines carry static tile collision, which stops the *player*
## but does nothing between two props — left alone, two rocks drift straight
## through each other and briefly render as one mangled shape. This pushes any
## overlapping pair apart along the line between them, splitting the correction
## so neither is the one that visibly jumps.
func _separate_solids() -> void:
	var solids: Array[Node2D] = []
	for prop in get_tree().get_nodes_in_group("space_props"):
		if is_instance_valid(prop) and bool(prop.get_meta("prop_solid", false)):
			solids.append(prop)

	for i in solids.size():
		for j in range(i + 1, solids.size()):
			var a := solids[i]
			var b := solids[j]
			if int(a.get_meta("prop_layer", 0)) != int(b.get_meta("prop_layer", 0)):
				continue
			var offset := b.global_position - a.global_position
			var distance := offset.length()
			var minimum: float = float(a.get_meta("prop_radius", 0.0)) \
				+ float(b.get_meta("prop_radius", 0.0))
			if distance >= minimum:
				continue
			# Exactly co-located: pick any axis, or normalized() returns zero
			# and they stay welded together forever.
			var away := offset.normalized() if distance > 0.01 else Vector2.RIGHT
			var push := away * (minimum - distance) * 0.5
			a.global_position -= push
			b.global_position += push


## Toward the player, rotated by a random amount inside DRIFT_CONE. The result
## crosses the play area near the ship without heading straight for it.
func _drift_from(spawn_point: Vector2) -> Vector2:
	var toward := (_player.global_position - spawn_point).normalized()
	return toward.rotated(rng.randf_range(-DRIFT_CONE, DRIFT_CONE))


## Shrines carry their own contents: a chest to find, and on shrine_3 a few
## shooters already dug in around it. Only ever called for the solid layer.
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
