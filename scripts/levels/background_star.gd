extends AnimatedSprite2D

# The star burning behind the battlefield. Which one you see is the solar
# system you took the contract in; how big it looms is the difficulty you
# took it at. Outside a system (the hub, the odd mission stage) it keeps
# whatever the scene was authored with.
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
	var system: int = GameManager.get_system_index()
	if system == 0:
		return

	var anim: String = SYSTEM_ANIMATIONS[system]
	if sprite_frames and sprite_frames.has_animation(anim):
		play(anim)

	var tier: int = clampi(GameManager.difficulty_tier, 1, GameManager.MAX_TIER)
	scale = _base_scale * float(GameManager.TIER_STAR_SCALE.get(tier, 1.0))
