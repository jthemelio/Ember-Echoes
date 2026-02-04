extends Control

@onready var grid = $GridContainer # Adjust path if needed
var reorder_mode_enabled: bool = false

func _ready() -> void:
	var i = 0
	for slot in grid.get_children():
		slot.slot_index = i
		# This 'connects' the slot's signal to the logic we wrote earlier
		if not slot.slot_pressed.is_connected(_on_slot_pressed):
			slot.slot_pressed.connect(_on_slot_pressed)
		i += 1
	
	load_slots_from_playfab()

func load_slots_from_playfab():
	print("Fetching characters from PlayFab...")
	PlayFabManager.client.get_user_data([], func(result):
		# Loop through all 6 possible slots
		for i in range(6):
			var key = "Slot_" + str(i)
			var target_slot = grid.get_child(i)
			
			if result.data.has(key):
				# Convert the saved text back into a Dictionary
				var character_data = JSON.parse_string(result.data[key].value)
				target_slot.update_slot_display(character_data)
			else:
				# No character found in this slot
				target_slot.update_slot_display({})
	, func(error):
		print("Load Failed: ", error.message)
	)

# Called by your Toggle Button
func _on_reorder_toggle_toggled(button_pressed: bool) -> void:
	reorder_mode_enabled = button_pressed
	if not reorder_mode_enabled:
		save_new_order_to_playfab()

func save_new_order_to_playfab():
	print("Syncing new character sequence to PlayFab...")
	var new_data_bundle = {}
	
	# 1. Look at the grid and see the new order of children
	var current_slots = grid.get_children()
	
	for i in range(current_slots.size()):
		var slot = current_slots[i]
		var key = "Slot_" + str(i)
		
		# Update the slot's internal index to match its new position
		slot.slot_index = i
		
		# 2. Bundle the character data into our request
		# If the slot is empty, we save an empty string or empty JSON
		new_data_bundle[key] = JSON.stringify(slot.char_data)
	
	# 3. Send the entire updated list to PlayFab in one go
	var request = { "Data": new_data_bundle }
	
	PlayFabManager.client.update_user_data(request, 
		func(result): print("New sequence saved to cloud!"),
		func(error): print("Sequence save failed: ", error.message)
	)
	
func _on_slot_pressed(slot_index: int, is_empty: bool):
	if is_empty:
		print("Opening character creation for slot: ", slot_index)
		open_creation_popup(slot_index) # This is the missing link!
	else:
		print("Character selected at slot: ", slot_index)
		# Future: Load into the game world with this character

func open_creation_popup(slot_index: int):
	# The path must include the sub-folder
	var popup_scene = load("res://scenes/character_creation/character_creation.tscn")
	var popup = popup_scene.instantiate()
	add_child(popup)
	
	# Connect the signal so the popup can talk back to this script
	popup.character_confirmed.connect(_on_character_data_received.bind(slot_index))

func _on_character_data_received(data: Dictionary, slot_index: int):
	# Update the UI slot immediately so the player sees their hero
	var target_slot = grid.get_child(slot_index)
	target_slot.update_slot_display(data)
	
	# Save the new data to PlayFab
	save_single_slot_to_playfab(slot_index, data)
	
func save_single_slot_to_playfab(index: int, data: Dictionary):
	# 1. Create a key like "Slot_0" so PlayFab knows which box to put the data in
	var key = "Slot_" + str(index)
	
	# 2. Convert the dictionary (Name, Class) into a String so PlayFab can store it
	var value = JSON.stringify(data) 
	
	# 3. Format the data for the PlayFab SDK
	var request = {
		"Data": { 
			key: value 
		}
	}
	
	print("Attempting to save to PlayFab: ", key)
	
	# 4. The actual API call to the server
	# Make sure PlayFabManager is an Autoload/Singleton in your Project Settings!
	PlayFabManager.client.update_user_data(request, 
		func(result): 
			print("Successfully saved character to ", key),
		func(error): 
			print("PlayFab Error: ", error.message)
	)
