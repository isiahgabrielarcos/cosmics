extends CharacterBody2D

@export var max_hp: int       = 100
@export var damage: int       = 10
@export var speed: float      = 400.0
@export var turn_rate: float  = 50.0
@export var experience_value: int = 15 # Added experience value

var hp: int
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D    = $AnimatedSprite2D
@onready var area_2d: Area2D = $Area2D

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	area_2d.body_entered.connect(_on_body_entered) # Connect collision

func _physics_process(delta: float) -> void:
	_chase_smooth(delta)
	move_and_slide()
	_rotate_to_velocity()

func _chase_smooth(delta: float) -> void:
	var targets = get_tree().get_nodes_in_group("friendlies")
	if targets.size() == 0:
		velocity = Vector2.ZERO
		return

	var target = targets[0] as Node2D
	if not target:
		velocity = Vector2.ZERO
		return

	var desired_dir = (target.global_position - global_position).normalized()
	if desired_dir == Vector2.ZERO:
		velocity = Vector2.ZERO
		return

	var cur_dir: Vector2
	if velocity.length() > 0.001:
		cur_dir = velocity.normalized()
	else:
		cur_dir = desired_dir

	var new_dir = cur_dir.lerp(desired_dir, turn_rate * delta).normalized()
	velocity = new_dir * speed

func _rotate_to_velocity() -> void:
	if velocity.length() > 0.001:
		sprite.rotation = velocity.angle() + deg_to_rad(90)

func apply_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		# Drop an experience shard (the original drops shards, not direct XP)
		ExperienceShard.spawn(get_tree().current_scene, global_position)
		AudioManager.play_sfx("enemyDeath")
		GameManager.on_enemy_killed(experience_value)
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("friendlies") and body.has_method("take_damage"):
		body.take_damage(damage)
