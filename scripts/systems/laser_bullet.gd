extends RigidBody2D

@export var speed: float    = 800.0
@export var damage: int     = 25
@export var lifetime: float = 3
@export var pierce: int = 3


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = pierce
	self.body_entered.connect(_on_area_2d_body_shape_entered)

	gravity_scale = 0.0  # RigidBody2D.gravity_scale multiplies default gravity; 0 disables it :contentReference[oaicite:0]{index=0}

	# fire
	linear_velocity = Vector2.UP.rotated(rotation) * speed

	# auto-destroy
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _on_area_2d_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	pierce -= 1
	print("should")
	print("Body: ", body)
	if body.is_in_group("enemies"):
		print("ASDASD")
		if body.has_method("apply_damage"):
			body.apply_damage(damage)
		if pierce == 0:
			queue_free()
	pass # Replace with function body.
