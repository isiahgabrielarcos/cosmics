extends Line2D
class_name Trails

@onready var toby_ship_1: CharacterBody2D = $".."

var queue: Array[Vector2] = []
@export var MAX_LENGTH: int = 30

func _ready():
	# Make this Line2D ignore its parent’s transform so it lives in world space
	set_as_top_level(true)            # ↪️ now its own origin is at (0,0) world turn0search4
	z_index = -1                     # draw behind the ship

func _process(_delta: float) -> void:
	# Use the ship’s global_position directly
	var pos = toby_ship_1.global_position

	queue.push_front(pos)
	if queue.size() > MAX_LENGTH:
		queue.pop_back()

	clear_points()
	for point in queue:
		add_point(point)             # points are now in global coords, and because we're top-level they draw correctly
