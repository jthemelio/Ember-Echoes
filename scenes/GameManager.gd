extends Node

# Persistent data that survives scene changes
var active_character_id: String = ""
var active_character_name: String = ""
var active_character_class: String = ""

func start_game_with_character(data: Dictionary):
	# Store the data passed from the selection slot
	active_character_id = data.get("CharacterId", "")
	active_character_name = data.get("CharacterName", "")
	active_character_class = data.get("Class", "")
	
	print("GameManager: Loading world for ", active_character_name)
	
	# Change to your actual game world scene
	# Ensure this path is correct for your project!
	get_tree().change_scene_to_file("res://scenes/world/main_world.tscn")
