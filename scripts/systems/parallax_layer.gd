extends ParallaxLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	motion_scale.x = 0.001
	motion_scale.y = 0.001
	
	motion_mirroring.x = 1920 * 5
	motion_mirroring.y = 1080 * 5
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
