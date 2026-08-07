extends Area2D
class_name ModuleChest

# Ports dropModuleChests() — a chest that floats in the world; flying into it
# opens the module pick screen. The chest's rarity decides how many hands you
# get dealt, not what's in them (the Lua's howManyModuleUpgrade).

const CHEST_SHEET := preload("res://assets/art/environment/moduleChests.png")

const RARITY_REGIONS := {
	"common":    Rect2(0, 0, 128, 128),
	"rare":      Rect2(128, 0, 128, 128),
	"epic":      Rect2(0, 128, 128, 128),
	"legendary": Rect2(128, 128, 128, 128),
}

## Rounds of modules the chest is worth. The run resumes only once every
## round has been picked.
const ROUNDS := { "common": 1, "rare": 2, "epic": 3, "legendary": 4 }

var rarity: String = "common"


static func spawn(parent: Node, pos: Vector2) -> ModuleChest:
	var chest := ModuleChest.new()
	# common 66% · rare 25% · epic 7% · legendary 2%. A legendary chest is four
	# whole rounds of picks, so it has to stay a genuine event.
	var roll := randi_range(1, 100)
	if roll <= 66:
		chest.rarity = "common"
	elif roll <= 91:
		chest.rarity = "rare"
	elif roll <= 98:
		chest.rarity = "epic"
	else:
		chest.rarity = "legendary"
	chest.global_position = pos
	parent.add_child(chest)
	return chest


func _ready() -> void:
	var spr := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = CHEST_SHEET
	atlas.region = RARITY_REGIONS[rarity]
	spr.texture = atlas
	add_child(spr)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 60.0
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("friendlies"):
		return

	var panel := _find_pick_panel()
	if panel == null:
		return   # no pick screen in this scene — leave the chest be

	# One round opens the panel; the rest queue behind it.
	GameManager.pending_module_picks += maxi(0, int(ROUNDS.get(rarity, 1)) - 1)
	AudioManager.play_sfx("moduleChest")
	queue_free()
	panel.open()


func _find_pick_panel() -> ModulePickPanel:
	for node in get_tree().current_scene.get_children():
		if node is ModulePickPanel:
			return node
	return null
