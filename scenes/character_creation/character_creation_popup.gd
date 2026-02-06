extends Control

signal character_confirmed(data)

@onready var name_input = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/InsertName
var target_slot_index: int = 0
var main_loading_overlay: ColorRect

func _on_class_button_pressed(c_name: String):
	var character_name = name_input.text
	if character_name.length() < 3:
		print("Name too short!")
		return

	# 1. Update and show overlay immediately
	if main_loading_overlay:
		var label = main_loading_overlay.get_node_or_null("CenterContainer/Label")
		if label:
			label.text = "Creating " + c_name + "..."
		main_loading_overlay.show()
	
	# 2. HIDE THIS POPUP IMMEDIATELY so the main screen overlay is visible
	self.visible = false 
	
	var params = {
		"CharacterName": character_name,
		"CharacterType": c_name
	}
	
	PlayFabManager.client.execute_cloud_script("createNewCharacter", params, 
		func(result):
			var response = result.data
			if response.has("FunctionResult") and response.FunctionResult.has("CharacterId"):
				var new_char_id = response.FunctionResult.CharacterId
				var d = {
					"CharacterName": character_name, 
					"Class": c_name, 
					"CharacterId": new_char_id,
					"Level": 1
				}
				character_confirmed.emit(d)
				queue_free() # Clean up the hidden popup
			else:
				print("CloudScript Error: ", response)
				# If it fails, you might want to show the popup again
				self.visible = true
				if main_loading_overlay: main_loading_overlay.hide()
	)

func _on_playfab_error(error):
	print("PlayFab Error: ", error.message)

# Button Hooks
func _on_marksman_pressed(): _on_class_button_pressed("Marksman")
func _on_twin_soul_pressed(): _on_class_button_pressed("Twin-Soul")
func _on_wuxia_pressed(): _on_class_button_pressed("Wuxia")
func _on_juggernaut_pressed(): _on_class_button_pressed("Juggernaut")
