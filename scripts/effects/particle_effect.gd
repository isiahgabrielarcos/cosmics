extends GPUParticles2D
class_name ParticleEffect

# Shared runtime for every one-shot particle burst scene (enemy death, boss
# death, player hit/death, level up, projectile pop). Each scene bakes its
# own ParticleProcessMaterial, amount and lifetime — this script only fires
# the burst at the given position and frees itself once it finishes playing,
# so it's safe to fire-and-forget from any gameplay script.

static func spawn(scene: PackedScene, parent: Node, pos: Vector2, scale_mult: float = 1.0) -> ParticleEffect:
	var fx: ParticleEffect = scene.instantiate()
	fx.global_position = pos
	if scale_mult != 1.0:
		fx.scale = Vector2.ONE * scale_mult
	parent.add_child(fx)
	return fx


func _ready() -> void:
	finished.connect(queue_free)
