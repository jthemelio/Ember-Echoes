extends Control

signal character_confirmed(data)

@onready var name_input = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/InsertName
var target_slot_index: int = 0
var main_loading_overlay: ColorRect

func _get_loading_label() -> Label:
	if not main_loading_overlay:
		return null
	# Try new styled path first, then fall back to old
	var label = main_loading_overlay.get_node_or_null("CenterContainer/Panel/Margin/Label")
	if label == null:
		label = main_loading_overlay.get_node_or_null("CenterContainer/Label")
	return label

func _on_class_button_pressed(c_name: String):
	var character_name = name_input.text
	if character_name.length() < 3:
		print("Name too short!")
		return

	# Show the loading overlay and update text
	var label = _get_loading_label()
	if label:
		label.text = "Creating %s..." % c_name
	if main_loading_overlay:
		main_loading_overlay.show()

	# Hide the popup window immediately so user can't click twice
	self.visible = false

	var params = {"CharacterName": character_name, "CharacterType": c_name}

	# Execute CloudScript to create the character and set Level 1 stats
	PlayFabManager.client.execute_cloud_script("createNewCharacter", params,
		func(result):
			var response = result.data
			if response.has("FunctionResult") and response.FunctionResult.has("CharacterId"):
				var new_char_id = response.FunctionResult.CharacterId

				# Update overlay text
				var lbl = _get_loading_label()
				if lbl:
					lbl.text = "Character Created! Syncing..."

				# Wait for PlayFab to finish indexing
				await get_tree().create_timer(0.5).timeout

				# Prepare the data package for the UI transition
				var d = {
					"CharacterId": new_char_id,
					"CharacterName": character_name,
					"CharacterType": c_name,
					"Level": 1
				}

				print("[DEBUG] Creation success. Emitting data: ", d)

				# Signal the Selection Screen to update and close this popup
				character_confirmed.emit(d)
				queue_free()
			else:
				# Error handling for CloudScript failures
				print("CloudScript Error: ", response)
				self.visible = true
				if main_loading_overlay:
					main_loading_overlay.hide()
	)

func _on_playfab_error(error):
	print("PlayFab Error: ", error.message)

func _on_cancel_pressed():
	queue_free()

# Button Hooks
func _on_marksman_pressed(): _on_class_button_pressed("Marksman")
func _on_twin_soul_pressed(): _on_class_button_pressed("Twin-Soul")
func _on_wuxia_pressed(): _on_class_button_pressed("Wuxia")
func _on_juggernaut_pressed(): _on_class_button_pressed("Juggernaut")
