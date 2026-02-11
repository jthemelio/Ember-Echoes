extends Control # Or Button, if your root is a Button

signal slot_pressed(index: int, empty: bool)

@onready var name_label = $Button/HBoxContainer/VBoxContainer/NameLabel
@onready var level_label = $Button/HBoxContainer/VBoxContainer/HBoxContainer/LevelLabel
@onready var class_label = $Button/HBoxContainer/VBoxContainer/HBoxContainer/ClassLabel
@onready var delete_button = $Button/HBoxContainer/DeleteButton
@onready var create_label = $Button/CreateLabel
@onready var info_container = $Button/HBoxContainer/VBoxContainer

var slot_index: int = 0
var is_empty: bool = true
var char_data: Dictionary = {}

func update_slot_display(data: Dictionary):
	char_data = data
	
	if data.is_empty():
		is_empty = true
		create_label.show() # Show the centered text
		info_container.hide() # Hide Name, Lv, and Class
		delete_button.hide()
		return

	is_empty = false
	create_label.hide() # Hide the centered text
	info_container.show() # Show character info
	delete_button.show()
	
	name_label.text = data.get("CharacterName", "Hero")
	level_label.text = "Lv. " + str(data.get("Level", 1))
	class_label.text = data.get("Class", "Unknown")

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


func _on_button_pressed() -> void:
	# This 'emits' the signal so the parent (Selection Screen) can hear it
	slot_pressed.emit(slot_index, is_empty)
	print("Slot ", slot_index, " signaled the main screen.")

signal delete_requested(char_id)

func _on_delete_button_pressed():
	if char_data.has("CharacterId"):
		delete_requested.emit(char_data.CharacterId)
