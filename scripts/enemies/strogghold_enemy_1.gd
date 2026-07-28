extends CharacterBody2D

@export var max_hp: int = 100
@export var damage: int = 10
@export var speed: float = 250.0
@export var experience_value: int = 10 # Added experience value

var hp: int
@onready var area_2d: Area2D = $Area2D

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	area_2d.body_entered.connect(_on_body_entered) # Connect collision

func _physics_process(delta: float) -> void:
	_chase_any()
	move_and_slide()

func _chase_any() -> void:
	var targets = get_tree().get_nodes_in_group("friendlies")
	if targets.size() == 0:
		velocity = Vector2.ZERO
		return

	var target = targets[0]
	if target is Node2D:
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * speed
	else:
		velocity = Vector2.ZERO

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
