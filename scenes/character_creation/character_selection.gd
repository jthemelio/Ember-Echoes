extends Control

@onready var grid = %GridContainer
@onready var loading_overlay = $LoadingOverlay

var reorder_mode_enabled: bool = false

func _ready() -> void:
	print("--- DEBUG START ---")
	if grid == null:
		print("ERROR: Grid variable is NULL. The path is definitely wrong.")
		# Try to find it manually as a last resort
		grid = find_child("GridContainer", true, false)
		if grid:
			print("SUCCESS: Found GridContainer using find_child!")
	
	if grid:
		var slots = grid.get_children()
		print("SUCCESS: Found ", slots.size(), " slots.")
		for i in range(slots.size()):
			var slot = slots[i]
			slot.slot_index = i
			slot.slot_pressed.connect(_on_slot_pressed)
			print("Connected Slot: ", i)
			slot.delete_requested.connect(_on_character_delete_requested)
			print("Connected Slot and Delete for: ", i)
	print("--- DEBUG END ---")
	load_slots_from_playfab()
	PlayFabManager.client.api_error.connect(_on_playfab_error)

func load_slots_from_playfab():
	var label = loading_overlay.get_node_or_null("CenterContainer/Label")
	if label and label.text == "":
		label.text = "Loading characters..."
	
	loading_overlay.show()
	
	# --- ADD THIS LOOP HERE ---
	# This clears the local UI so deleted characters actually disappear
	for child in grid.get_children():
		child.update_slot_display({})
	
	PlayFabManager.client.get_all_users_characters({}, func(result):
		var characters = result.data.Characters
		
		# If account is empty, we already cleared the slots above, so just finish
		if characters.size() == 0:
			_finish_loading()
			return

		var expected = characters.size()
		var tracker = {"count": 0}
		
		for char_entity in characters:
			_fetch_character_slot_and_display_with_callback(char_entity, func():
				tracker.count += 1
				if tracker.count >= expected:
					_finish_loading()
			)
	)

func _finish_loading():
	loading_overlay.hide()
	# Reset text so the next operation can set it fresh
	var label = loading_overlay.get_node_or_null("CenterContainer/Label")
	if label:
		label.text = ""
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
	var target_slot = grid.get_child(slot_index)
	
	if is_empty:
		print("Opening character creation for slot: ", slot_index)
		open_creation_popup(slot_index)
	else:
		# Use the data stored in the slot from PlayFab 
		var data = target_slot.char_data 
		# Hand off to GameManager to store Name, ID, and Class [cite: 13]
		GameManager.start_game_with_character(data)

func open_creation_popup(slot_index: int):
	var path = "res://scenes/character_creation/character_creation_popup.tscn"
	var popup_scene = load(path)
	
	if popup_scene:
		var popup = popup_scene.instantiate()
		popup.target_slot_index = slot_index 
		
		# Pass a reference to the loading overlay so the popup can show it
		popup.main_loading_overlay = loading_overlay 
		
		add_child(popup)
		popup.character_confirmed.connect(_on_character_data_received.bind(slot_index))

func _on_character_data_received(data: Dictionary, slot_index: int):
	loading_overlay.show()
	var char_id = data.CharacterId
	var slot_bundle = {"SlotIndex": str(slot_index)}
	
	PlayFabManager.client.update_character_data(char_id, slot_bundle, func(result):
		print("Slot assigned! Waiting for PlayFab indexing...")
		# A small 0.3s delay ensures the next fetch sees the updated data
		await get_tree().create_timer(0.3).timeout 
		load_slots_from_playfab()
	)
	

func _fetch_character_slot_and_display_with_callback(char_entity, on_complete: Callable):
	var char_id = char_entity.CharacterId
	
	PlayFabManager.client.get_character_data(char_id, func(result):
		var char_data = result.data.Data 
		if char_data.has("SlotIndex"):
			var slot_idx = char_data.SlotIndex.Value.to_int()
			if slot_idx < grid.get_child_count():
				var target_slot = grid.get_child(slot_idx)
				target_slot.update_slot_display({
					"CharacterName": char_entity.CharacterName,
					"Class": char_entity.CharacterType,
					"CharacterId": char_id,
					"Level": 1
				})
		
		# Important: Notify the loop that this request is done
		on_complete.call()
	)
	
func _on_character_delete_requested(char_id: String):
	var path = "res://scenes/character_creation/character_delete_confirmation.tscn"
	var delete_scene = load(path)
	
	if delete_scene:
		var popup = delete_scene.instantiate()
		popup.character_id_to_delete = char_id # Pass the ID
		add_child(popup)
		
		# Connect the custom signal
		popup.deletion_confirmed.connect(_execute_actual_deletion)
	else:
		print("Error loading delete confirmation scene")

# Move your actual deletion logic into this helper function
func _execute_actual_deletion(char_id: String):
	var label = loading_overlay.get_node_or_null("CenterContainer/Label")
	if label:
		label.text = "Deleting Character..."
	
	loading_overlay.show()
	
	PlayFabManager.client.execute_cloud_script(
		"DeleteCharacter", 
		{"CharacterId": char_id}, 
		func(result):
			print("Delete command sent. Waiting for cloud sync...")
			# 1. Add a 0.5s delay to let the PlayFab database catch up
			await get_tree().create_timer(0.5).timeout 
			
			# 2. Now refresh the slots
			load_slots_from_playfab()
	)

func _on_playfab_error(error):
	# This will print the exact reason (e.g., "AccountDeletionDisabled")
	print("!!! PLAYFAB ERROR !!!")
	print("Error: ", error.error)
	print("Message: ", error.errorMessage)
