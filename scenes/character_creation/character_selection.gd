extends Control

@onready var grid = %GridContainer

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
	print("--- DEBUG END ---")

func load_slots_from_playfab():
	print("Fetching character entities from PlayFab...")
	# Note: SDK uses snake_case 'get_all_users_characters'
	PlayFabManager.client.get_all_users_characters({}, func(result):
		var characters = result.data.Characters #
		
		# 1. Clear slots visually
		for child in grid.get_children():
			child.update_slot_display({})
		
		# 2. For each character found, fetch its specific SlotIndex
		for char_entity in characters:
			_fetch_character_slot_and_display(char_entity)
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
	var target_slot = grid.get_child(slot_index)
	
	if is_empty:
		print("Opening character creation for slot: ", slot_index)
		open_creation_popup(slot_index)
	else:
		var data = target_slot.char_data # Assuming char_data is stored in the slot
		print("Selected: ", data.CharacterName, " ID: ", data.CharacterId)
		
		# GLOBAL DATA: Store the selected ID so the game scene knows who to load
		# (You might want a Global script called 'GameManager' for this)
		# GameManager.current_character_id = data.CharacterId
		
		# scene_to_game_world()

func open_creation_popup(slot_index: int):
	var path = "res://scenes/character_creation/character_creation_popup.tscn"
	var popup_scene = load(path)
	
	if popup_scene:
		var popup = popup_scene.instantiate()
		add_child(popup)
		
		# We pass slot_index here so the receiver knows which one to update
		popup.character_confirmed.connect(_on_character_data_received.bind(slot_index))
	else:
		print("CRITICAL ERROR: Could not find popup scene at: ", path)

func _on_character_data_received(data: Dictionary, slot_index: int):
	var char_id = data.CharacterId
	# Character Data requires a Dictionary of Strings
	var slot_bundle = {"SlotIndex": str(slot_index)}
	
	print("Saving SlotIndex to character...")
	PlayFabManager.client.update_character_data(char_id, slot_bundle, func(result):
		print("Slot assigned! Refreshing...")
		load_slots_from_playfab()
	)
	

func _fetch_character_slot_and_display(char_entity):
	var char_id = char_entity.CharacterId
	
	# Use the new bridge we added to PlayFabClient.gd
	PlayFabManager.client.get_character_data(char_id, func(result):
		var char_data = result.data.Data #
		var slot_idx = 0 
		
		# Look for our saved SlotIndex string and convert back to int
		if char_data.has("SlotIndex"):
			slot_idx = char_data.SlotIndex.Value.to_int()
		
		# Safety check: make sure the index is within our 6 slots
		if slot_idx < grid.get_child_count():
			var target_slot = grid.get_child(slot_idx)
			target_slot.update_slot_display({
				"CharacterName": char_entity.CharacterName,
				"Class": char_entity.CharacterType,
				"CharacterId": char_id,
				"Level": 1
			})
	)
