extends Area2D
class_name ModuleChest

# Ports dropModuleChests() — a chest that floats in the world; flying into it
# grants a random module upgrade (turns on a ModuleSystem flag or buffs one).

const CHEST_SHEET := preload("res://assets/art/environment/moduleChests.png")

const RARITY_REGIONS := {
	"common": Rect2(0, 0, 128, 128),
	"rare":   Rect2(128, 0, 128, 128),
	"epic":   Rect2(0, 128, 128, 128),
	"godly":  Rect2(128, 128, 128, 128),
}

# Module flags a chest can unlock, weighted by rarity tier
const COMMON_MODULES := ["got_shockwave_module", "got_electric_aura_module"]
const RARE_MODULES   := ["got_comet_module", "got_electro_bubbles_module", "got_energy_outburst_module"]
const EPIC_MODULES   := ["got_force_field_module", "got_dash_shockwave_module"]

var rarity: String = "common"


static func spawn(parent: Node, pos: Vector2) -> ModuleChest:
	var chest := ModuleChest.new()
	var roll := randi_range(1, 100)
	if roll <= 55:
		chest.rarity = "common"
	elif roll <= 85:
		chest.rarity = "rare"
	elif roll <= 97:
		chest.rarity = "epic"
	else:
		chest.rarity = "godly"
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
	var module_system = body.get_node_or_null("ModuleSystem")
	if module_system:
		_grant_upgrade(module_system)
	AudioManager.play_sfx("moduleChest")
	queue_free()


func _grant_upgrade(ms: Node) -> void:
	var pool: Array
	match rarity:
		"common": pool = COMMON_MODULES
		"rare":   pool = COMMON_MODULES + RARE_MODULES
		"epic":   pool = RARE_MODULES + EPIC_MODULES
		_:        pool = COMMON_MODULES + RARE_MODULES + EPIC_MODULES  # godly

	# Prefer a module the player doesn't own yet
	pool.shuffle()
	for flag in pool:
		if flag in ms and not ms.get(flag):
			ms.set(flag, true)
			GameManager.module_upgrade_count += 1
			print("Module unlocked: ", flag)
			return

	# Already owns everything in the pool — buff an owned module instead
	ms.shockwave_damage += 5
	ms.electric_aura_damage += 1
	print("Modules maxed — damage buffed")
