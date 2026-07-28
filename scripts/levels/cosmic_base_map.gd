extends Node2D
class_name CosmicBaseMap

# Ports createBase() from platform.lua — the hub village map:
# floor + wall images, the full cosmicBaseBorder() collision polygons (g = 64),
# floating citadel backdrops, the spawn pad, and the station boards/tables.

const G := 64.0

const FLOOR_TEX   := preload("res://assets/art/environment/cosmicBase1F.png")
const WALLS_TEX   := preload("res://assets/art/environment/cosmicBase1W.png")
const CITADEL_TEX := preload("res://assets/art/environment/cosmicCitadel.png")
const SPAWNER_TEX := preload("res://assets/art/environment/Spawner.png")
const BEAM_TEX    := preload("res://assets/art/ui/LightSpawn.png")
const BOARD1_TEX  := preload("res://assets/art/environment/cccStationBoard1.png")
const BOARD2_TEX  := preload("res://assets/art/environment/cccStationBoard2.png")
const TABLE1_TEX  := preload("res://assets/art/environment/traderTable.png")
const TABLE2_TEX  := preload("res://assets/art/environment/blacksmithTable.png")

# cosmicBaseBorder() shapes — verbatim from platform.lua, in g units
const WALL_POLYGONS := [
	# Base walls
	[-36, -12,  -36, 17,  -34, 17,  -34, -12],       # left wall
	[36, -12,  36, 17,  34, 17,  34, -12],           # right wall
	[-35, 6,  -10, 6,  -10, 8,  -35, 8],             # bottom-left wall
	[35, 6,  10, 6,  10, 8,  35, 8],                 # bottom-right wall
	# Top walls
	[-35, -14,  -15, -14,  -15, -12,  -35, -12],     # top wall left
	[-8, -12,  8, -12,  8, -10,  -8, -10],           # top wall middle
	[35, -14,  15, -14,  15, -12,  35, -12],         # top wall right
	[-35, -5,  -22, -5,  -22, -13,  -35, -13],       # top wall left 1
	[35, -5,  22, -5,  22, -13,  35, -13],           # top wall right 1
	# Boxes
	[-6, -17,  -6, -9,  -8, -9,  -8, -17],           # box 3
	[6, -17,  6, -9,  8, -9,  8, -17],               # box 4
	[-15, -17,  -15, -10,  -16, -10,  -16, -17],     # left box 1
	[-16, -17,  -16, -15,  -7, -15,  -7, -17],       # left box 2
	[15, -17,  15, -10,  16, -10,  16, -17],         # right box 1
	[16, -17,  16, -15,  7, -15,  7, -17],           # right box 2
	# Balcony walls
	[-11, 6,  -11, 14,  -13, 14,  -13, 6],           # balcony left
	[-12, 12,  -3, 12,  -3, 14,  -12, 14],           # balcony left 1
	[11, 6,  11, 14,  13, 14,  13, 6],               # balcony right
	[12, 12,  3, 12,  3, 14,  12, 14],               # balcony right 1
	[-35, -12,  -35, -9,  -33, -9,  -33, -12],       # box 1
	[35, -12,  35, -9,  33, -9,  33, -12],           # box 2
	[-4, 13,  4, 13,  4, 15,  -4, 15],               # endless pad
]

# Accessory shapes (boardShape / tableShape), in g units relative to each object
const BOARD_SHAPE := [1.5, 0,  1.5, 1.5,  -1.5, 1.5,  -1.5, 0]
const TABLE_SHAPE := [1.5, -1,  1.5, 2,  -1.5, 2,  -1.5, -1]


func _ready() -> void:
	_build_floor_and_walls()
	_build_citadels()
	_build_accessories()
	_build_spawn_pad()


# ── Village floor / walls / borders (cosmicVillage) ────────────────────────────

func _build_floor_and_walls() -> void:
	var floor_sprite := Sprite2D.new()
	floor_sprite.texture = FLOOR_TEX
	floor_sprite.scale = Vector2(2, 2)
	floor_sprite.z_index = -1
	add_child(floor_sprite)

	var walls_sprite := Sprite2D.new()
	walls_sprite.texture = WALLS_TEX
	walls_sprite.scale = Vector2(2, 2)
	walls_sprite.z_index = 1
	add_child(walls_sprite)

	var body := StaticBody2D.new()
	body.name = "BaseWalls"
	body.collision_layer = 64   # "walls" layer — blocks the player, not bullets
	add_child(body)
	for poly in WALL_POLYGONS:
		body.add_child(_make_polygon(poly))


func _make_polygon(coords: Array, unit: float = G) -> CollisionPolygon2D:
	var shape := CollisionPolygon2D.new()
	var points := PackedVector2Array()
	@warning_ignore("integer_division")
	for i in range(0, coords.size(), 2):
		points.append(Vector2(coords[i] * unit, coords[i + 1] * unit))
	shape.polygon = points
	return shape


# ── Floating citadel backdrops ─────────────────────────────────────────────────

func _build_citadels() -> void:
	# (offset_x, scale, alpha, z) mirroring cosmicCitadel()..cosmicCitadel4()
	var configs := [
		[-960.0, 0.5,  0.6, -4],
		[1920.0, 0.5,  0.6, -4],
		[0.0,    0.25, 0.6, -5],
		[1440.0, 0.25, 0.6, -5],
		[0.0,    0.8,  0.7, -3],
	]
	for cfg in configs:
		var citadel := Sprite2D.new()
		citadel.texture = CITADEL_TEX
		citadel.position = Vector2(cfg[0], 0)
		citadel.scale = Vector2.ONE * cfg[1]
		citadel.modulate.a = cfg[2]
		citadel.z_index = cfg[3]
		add_child(citadel)
		_float(citadel)


func _float(node: Node2D) -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(node, "position:y", node.position.y - 3.0, 3.0)
	tw.tween_property(node, "position:y", node.position.y + 3.0, 3.0)


# ── Station boards & tables (createBaseAccessories) ────────────────────────────

func _build_accessories() -> void:
	# board1 at (9g, -3g) anchor(1,1) size 3g — center = pos - 1.5g
	_accessory(BOARD1_TEX, Vector2(G * 9 - G * 1.5, -G * 3 - G * 1.5), Vector2(G * 3, G * 3), BOARD_SHAPE)
	_accessory(BOARD2_TEX, Vector2(-G * 6 - G * 1.5, -G * 3 - G * 1.5), Vector2(G * 3, G * 3), BOARD_SHAPE)
	# tables at (-8.5g, -12g) and (11.5g, -12g) anchor(1,1) size 3g×4g
	_accessory(TABLE1_TEX, Vector2(-G * 8.5 - G * 1.5, -G * 12 - G * 2), Vector2(G * 3, G * 4), TABLE_SHAPE)
	_accessory(TABLE2_TEX, Vector2(G * 11.5 - G * 1.5, -G * 12 - G * 2), Vector2(G * 3, G * 4), TABLE_SHAPE)


func _accessory(tex: Texture2D, center: Vector2, size: Vector2, shape: Array) -> void:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 64
	add_child(body)

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.scale = size / tex.get_size()
	spr.z_index = 1
	body.add_child(spr)

	body.add_child(_make_polygon(shape))


# ── Spawn pad + light beam (spawnPad) ──────────────────────────────────────────

func _build_spawn_pad() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("spawn")
	frames.set_animation_speed("spawn", 13.0)
	frames.set_animation_loop("spawn", true)
	# frames 1,2,3,4,5,6,6,6,5,4,3,2,1 from a 64x72, 3x3 sheet
	var order := [0, 1, 2, 3, 4, 5, 5, 5, 4, 3, 2, 1, 0]
	for idx in order:
		var atlas := AtlasTexture.new()
		atlas.atlas = SPAWNER_TEX
		@warning_ignore("integer_division")
		atlas.region = Rect2((idx % 3) * 64, (idx / 3) * 72, 64, 72)
		frames.add_frame("spawn", atlas)

	var pad := AnimatedSprite2D.new()
	pad.sprite_frames = frames
	pad.scale = Vector2(2, 2)
	pad.position = Vector2(0, -G)
	pad.play("spawn")
	add_child(pad)

	var beam := Sprite2D.new()
	beam.texture = BEAM_TEX
	beam.scale = Vector2(2, 2)
	beam.position = Vector2(0, -G)
	beam.offset = Vector2(0, -BEAM_TEX.get_height() * 0.475)
	beam.z_index = 2
	add_child(beam)
	# beam fades out after the landing (4 s hold, 1 s fade)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(beam, "modulate:a", 0.0, 1.0)
	tw.tween_callback(beam.queue_free)
