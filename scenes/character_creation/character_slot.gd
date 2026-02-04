extends Control # Or Button, if your root is a Button

@onready var name_label = $Button/HBoxContainer/VBoxContainer/NameLabel
@onready var class_label = $Button/HBoxContainer/VBoxContainer/ClassLabel

var slot_index: int = 0
var is_empty: bool = true
var char_data: Dictionary = {}

# 1. Logic to update the look
func update_slot_display(data: Dictionary):
	char_data = data
	if data.is_empty():
		is_empty = true
		name_label.text = "Empty Slot"
		class_label.text = "Tap to Create"
	else:
		is_empty = false
		name_label.text = data.get("CharacterName", "Hero")
		class_label.text = "Level " + str(data.get("Level", 1))

# 2. Drag Logic
func _get_drag_data(_at_position):
	# Check the main scene to see if "Edit Mode" is on
	if not get_tree().current_scene.reorder_mode_enabled:
		return null
		
	# Create a simple preview so the player sees what they are moving
	var preview = Button.new()
	preview.text = name_label.text
	preview.custom_minimum_size = Vector2(200, 50)
	set_drag_preview(preview)
	
	return self # Pass this slot as the data

# 3. Drop Logic
func _can_drop_data(_at_position, data):
	return data is Control # Only allow other UI nodes

func _drop_data(_at_position, data):
	var target_index = get_index()
	var origin_index = data.get_index()
	# Swap them in the GridContainer
	get_parent().move_child(data, target_index)
	get_parent().move_child(self, origin_index)
