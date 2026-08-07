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

	# Several of the burst scenes are saved with emitting off (it's the sane
	# default to author with, otherwise they fire in the editor). Turning it
	# on here means a scene can't silently never play — and since `finished`
	# only fires after a burst actually runs, it's also what lets these free
	# themselves instead of piling up in the scene.
	emitting = true

	# Belt and braces: if `finished` never arrives, don't leak the node.
	# Runs on its own regardless of pause, since bursts fired on the frame a
	# menu opens would otherwise sit around until it closes.
	get_tree().create_timer(lifetime * 1.5 + 0.3, true, false, true)\
		.timeout.connect(func():
			if is_instance_valid(self):
				queue_free())
