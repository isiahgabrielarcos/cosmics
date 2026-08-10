extends Area2D
class_name ExperienceShard

# Ports the experience-shard drops (demoExperienceShard / dropShard logic).
# Rarities and worth from the Lua: common 5 · rare 10 · epic 20 · godly 50.
# Shards magnet toward the player when close, grant XP on pickup.

const SHARD_SHEET := preload("res://assets/art/characters/experienceShards.png")

# Frame coords in the 64x64 sheet (from the Lua sequence mapping:
# common=frame1, rare=frame2, godly=frame3, epic=frame4)
## `worth` is experience. `shards` is the shard currency the pickup also pays
## into the run's haul — a rarer shard is worth more of both.
const RARITY_DATA := {
	"common": { "region": Rect2(0, 0, 32, 32),   "worth": 5,  "shards": 1  },
	"rare":   { "region": Rect2(32, 0, 32, 32),  "worth": 10, "shards": 3  },
	"godly":  { "region": Rect2(0, 32, 32, 32),  "worth": 50, "shards": 20 },
	"epic":   { "region": Rect2(32, 32, 32, 32), "worth": 20, "shards": 8  },
}

const MAGNET_RANGE := 180.0
const MAGNET_SPEED := 500.0
const LIFETIME := 20.0

var rarity: String = "common"
var worth: int = 5
var _age: float = 0.0


static func roll_rarity() -> String:
	var roll := randi_range(1, 100)
	if roll <= 70:
		return "common"
	elif roll <= 90:
		return "rare"
	elif roll <= 98:
		return "epic"
	return "godly"


static func spawn(parent: Node, pos: Vector2, forced_rarity: String = "") -> ExperienceShard:
	var shard := ExperienceShard.new()
	shard.rarity = forced_rarity if forced_rarity != "" else roll_rarity()
	shard.worth = RARITY_DATA[shard.rarity]["worth"]
	shard.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	parent.add_child(shard)
	return shard


func _ready() -> void:
	var spr := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = SHARD_SHEET
	atlas.region = RARITY_DATA[rarity]["region"]
	spr.texture = atlas
	add_child(spr)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)

	# little pop-out animation
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return

	var players := get_tree().get_nodes_in_group("friendlies")
	if players.is_empty():
		return
	var player := players[0] as Node2D
	if not player:
		return

	var offset := player.global_position - global_position
	if offset.length() < MAGNET_RANGE:
		global_position += offset.normalized() * MAGNET_SPEED * delta


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("friendlies"):
		return
	if body.has_method("add_experience"):
		body.add_experience(worth)
	GameManager.collect_shards(int(RARITY_DATA[rarity]["shards"]))
	AudioManager.play_sfx("cosmicShards")
	queue_free()
