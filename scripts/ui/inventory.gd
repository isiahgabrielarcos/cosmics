extends Control

@onready var open_close: TextureButton = $"Frame/Open-Close"
@onready var inventory: Control = $Inventory

var isInventoryOpen : bool = false


func _ready() -> void:
	pass
	
func _on_open_close_pressed() -> void:
	var tween = create_tween()
	if isInventoryOpen:
		tween.tween_property(inventory, "position", Vector2(inventory.position.x, 504), 0.3)
		isInventoryOpen = false
	else: 
		tween.tween_property(inventory, "position", Vector2(inventory.position.x, 943.0), 0.3)
		isInventoryOpen = true
