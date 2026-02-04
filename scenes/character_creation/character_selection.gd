extends Control

@onready var grid = $GridContainer # Adjust path if needed
var reorder_mode_enabled: bool = false

func _ready() -> void:
	# 1. Initialize slots with IDs
	var i = 0
	for slot in grid.get_children():
		slot.slot_index = i
		i += 1
	
	# 2. Fetch from PlayFab
	load_slots_from_playfab()

func load_slots_from_playfab():
	# For now, we'll just simulate empty slots
	for slot in grid.get_children():
		slot.update_slot_display({})

# Called by your Toggle Button
func _on_reorder_toggle_toggled(button_pressed: bool) -> void:
	reorder_mode_enabled = button_pressed
	if not reorder_mode_enabled:
		save_new_order_to_playfab()

func save_new_order_to_playfab():
	print("Saving new slot sequence to PlayFab...")
	# Here we would loop through children and save their names to Slot_0, Slot_1, etc.
