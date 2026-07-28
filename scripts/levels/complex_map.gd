extends Node2D
class_name ComplexMap

# Ports createComplex() from platform.lua — the 9-room complex/dungeon grid.
# Each room = complexMapF (floor) + complexMapW1 (walls) at scale 2 with the
# comUp/comDown collision polygons (g = 64), laid out in the original spiral.

const G := 64.0

const FLOOR_TEX := preload("res://assets/art/environment/complexMapF.png")
const WALLS_TEX := preload("res://assets/art/environment/complexMapW1.png")

# Room offsets in g units — the order from createComplex ("Spiral")
const ROOM_OFFSETS := [
	Vector2(0, 0),
	Vector2(0, 24),
	Vector2(22, 24),
	Vector2(22, 0),
	Vector2(22, -24),
	Vector2(0, -24),
	Vector2(-22, -24),
	Vector2(-22, 0),
	Vector2(-22, 24),
]

# cosmicBaseBorder() shapes for a complex room — verbatim, in g units
const ROOM_POLYGONS := [
	[-11, -11,  -2, -11,  -2, -10,  -11, -10],   # comUpL1
	[-11, -12,  -10, -12,  -10, -2,  -11, -2],   # comUpL2
	[-11, -12,  -9, -12,  -9, -9,  -11, -9],     # comUpL3
	[11, -11,  2, -11,  2, -10,  11, -10],       # comUpR1
	[11, -12,  10, -12,  10, -2,  11, -2],       # comUpR2
	[11, -12,  9, -12,  9, -9,  11, -9],         # comUpR3
	[11, 13,  2, 13,  2, 10,  11, 10],           # comDownR1
	[11, 12,  10, 12,  10, 2,  11, 2],           # comDownR2
	[-11, 13,  -2, 13,  -2, 10,  -11, 10],       # comDownL1
	[-11, 12,  -10, 12,  -10, 2,  -11, 2],       # comDownL2
]


func _ready() -> void:
	for offset in ROOM_OFFSETS:
		_build_room(offset * G)


func _build_room(pos: Vector2) -> void:
	var room := Node2D.new()
	room.position = pos
	add_child(room)

	var floor_sprite := Sprite2D.new()
	floor_sprite.texture = FLOOR_TEX
	floor_sprite.scale = Vector2(2, 2)
	floor_sprite.z_index = -1
	room.add_child(floor_sprite)

	var walls_sprite := Sprite2D.new()
	walls_sprite.texture = WALLS_TEX
	walls_sprite.scale = Vector2(2, 2)
	walls_sprite.z_index = 1
	room.add_child(walls_sprite)

	var body := StaticBody2D.new()
	body.collision_layer = 64   # "walls" layer
	room.add_child(body)
	for poly in ROOM_POLYGONS:
		var shape := CollisionPolygon2D.new()
		var points := PackedVector2Array()
		for i in range(0, poly.size(), 2):
			points.append(Vector2(poly[i] * G, poly[i + 1] * G))
		shape.polygon = points
		body.add_child(shape)
