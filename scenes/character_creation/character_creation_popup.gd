extends Control

signal character_confirmed(data)

@onready var name_input = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/InsertName
var target_slot_index: int = 0

func _on_class_button_pressed(c_name: String):
	var character_name = name_input.text
	if character_name.length() < 3:
		print("Name too short!")
		return

	# Define the parameters for the CloudScript
	var params = {
		"CharacterName": character_name,
		"CharacterType": c_name
	}
	
	print("Requesting character creation via CloudScript...")
	
	# We use the snake_case function we added to PlayFabClient.gd
	# This SDK expects the function name and parameters as separate arguments
	PlayFabManager.client.execute_cloud_script("createNewCharacter", params, 
		func(result):
			# Structed's SDK wraps the PlayFab response in a '.data' property
			var response = result.data
			
			# Check if the CloudScript execution was successful
			if response.has("FunctionResult") and response.FunctionResult.has("CharacterId"):
				var new_char_id = response.FunctionResult.CharacterId
				print("Character Created! ID: ", new_char_id)
				_initialize_slot_stats(new_char_id, character_name, c_name)
			else:
				# If it fails, print the response to see what PlayFab said
				print("CloudScript Error or missing ID: ", response)

	)

func _on_grant_success(result, character_name: String, c_name: String):
	var new_char_id = result.CharacterId
	_initialize_slot_stats(new_char_id, character_name, c_name)

func _initialize_slot_stats(char_id: String, n_name: String, c_name: String):
	# 1. Get starting stats from your StatCalculator
	var starting_stats = StatCalculator.get_smart_allocated_stats(c_name, 1)
	
	# 2. Calculate initial vitals (HP/MP)
	var base_vitals = StatCalculator.calculate_base_stats({
		"Strength": starting_stats["Str"],
		"Agility": starting_stats["Agi"],
		"Vitality": starting_stats["Vit"],
		"Spirit": starting_stats["Spi"]
	})
	var final_vitals = StatCalculator.apply_multipliers(base_vitals, c_name, 1)
	
	# 3. Format the stats list as an Array of Dictionaries for PlayFab
	var stats_list = [
		{"StatisticName": "Strength", "Value": starting_stats["Str"]},
		{"StatisticName": "Agility", "Value": starting_stats["Agi"]},
		{"StatisticName": "Vitality", "Value": starting_stats["Vit"]},
		{"StatisticName": "Spirit", "Value": starting_stats["Spi"]},
		{"StatisticName": "Level", "Value": 1}
	]
	
	print("Updating character stats for: ", char_id)
	
	# 4. Use the new snake_case function in PlayFabClient.gd
	# This sends the ID, the Array, and the success callback
	PlayFabManager.client.update_character_statistics(char_id, stats_list, 
		func(result):
			# On success, proceed to sync internal data and close the popup
			_on_stats_updated(char_id, n_name, c_name, final_vitals)
	)

func _on_stats_updated(char_id: String, n_name: String, c_name: String, final_vitals: Dictionary):
	# 1. Sync the HP/MP to Internal Data as before
	StatCalculator.sync_calculated_stats(char_id, final_vitals.MaxHP, final_vitals.MaxMP)
	
	# 2. Save the SlotIndex to Character Data
	# We use a dummy index for now, or you can pass the actual slot_index through
	var slot_data = {"SlotIndex": str(target_slot_index)}
	
	PlayFabManager.client.update_character_data(char_id, slot_data, func(result):
		print("Slot assigned to character data!")
		
		var d = {
			"CharacterName": n_name, 
			"Class": c_name, 
			"CharacterId": char_id,
			"Level": 1
		}
		character_confirmed.emit(d)
		queue_free()
	)

func _on_playfab_error(error):
	print("PlayFab Error: ", error.message)

# Button Hooks
func _on_marksman_pressed(): _on_class_button_pressed("Marksman")
func _on_twin_soul_pressed(): _on_class_button_pressed("Twin-Soul")
func _on_wuxia_pressed(): _on_class_button_pressed("Wuxia")
func _on_juggernaut_pressed(): _on_class_button_pressed("Juggernaut")
