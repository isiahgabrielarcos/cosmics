extends AnimatedSprite2D

# The star burning behind the battlefield. Which one you see is the solar
# system you took the contract in; how big it looms is the difficulty you took
# it at. The Citadel has no star of its own, so there the structure itself
# stands in the sky instead.
#
# The four animations live on the sprite_frames in scenes/ui/background.tscn
# and are named after their systems.

const SYSTEM_ANIMATIONS := {
	1: "flaschbourn",
	2: "strogghold",
	3: "frokenvinter",
	4: "squilltrant",
}

## Authored scale, treated as the Normal-difficulty size.
@onready var _base_scale: Vector2 = scale


func _ready() -> void:
	var citadel := get_parent().get_node_or_null("CosmicCitadel") as Node2D

	# The Citadel stage is fought at the structure, not around a sun. Swap the
	# two over rather than leaving a star from whichever system happened to be
	# authored into the scene.
	if GameManager.is_citadel():
		visible = false
		if citadel:
			citadel.visible = true
		return

	if citadel:
		citadel.visible = false

	var system: int = GameManager.get_system_index()
	if system == 0:
		return

	var anim: String = SYSTEM_ANIMATIONS[system]
	if sprite_frames and sprite_frames.has_animation(anim):
		# Both, and deferred: the node carries an `autoplay` from the scene,
		# which AnimatedSprite2D applies during its own ready and which would
		# otherwise start the authored animation right back over this one.
		animation = anim
		visible = true
		call_deferred("play", anim)

	var tier: int = clampi(GameManager.difficulty_tier, 1, GameManager.MAX_TIER)
	scale = _base_scale * float(GameManager.TIER_STAR_SCALE.get(tier, 1.0))
