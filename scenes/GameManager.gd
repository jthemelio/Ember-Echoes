extends Node

# Persistent data that survives scene changes
var active_character_stats: Dictionary = {}
var active_character_id: String = ""
var active_character_name: String = ""
var active_character_class: String = ""
var active_character_level: int = 1

func start_game_with_character(data: Dictionary):
	active_character_id = data.get("CharacterId", "")
	active_character_name = data.get("CharacterName", "")
	active_character_class = data.get("Class", "")
	active_character_level = int(data.get("Level", 1))
	active_character_stats = data.get("Statistics", {}) 
	
	get_tree().change_scene_to_file("res://scenes/pages/idleHome.tscn")
