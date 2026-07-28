extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

const SPEED := 250.0


func _ready() -> void:
	add_to_group("friendlies")
	sprite.play("down")


func _physics_process(_delta: float) -> void:
	var dir := Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down")  - Input.get_action_strength("up")
	)

	if dir != Vector2.ZERO:
		velocity = dir.normalized() * SPEED
		_update_animation(dir)
	else:
		velocity = Vector2.ZERO

	move_and_slide()


func _update_animation(dir: Vector2) -> void:
	# Up/down override left/right
	if dir.y < 0:
		sprite.play("up")
	elif dir.y > 0:
		sprite.play("down")
	elif dir.x < 0:
		sprite.play("left")
	else:
		sprite.play("right")
