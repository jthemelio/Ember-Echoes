# res://scenes/pages/hero_tab.gd
# Updated: use safer child lookup and wait one frame before accessing nodes
extends Control

var hero_name_label: Label
var hero_level_label: Label
var hero_class_label: Label

func _ready():
	# Wait for the scene to be fully ready
	await get_tree().process_frame
	setup_references()
	update_hero_display()

func setup_references():
	# Use safer node finding with error handling
	hero_name_label = find_child("HeroName", true, false) as Label
	hero_level_label = find_child("HeroLevel", true, false) as Label
	hero_class_label = find_child("HeroClass", true, false) as Label
	
	if not hero_name_label:
		print("HeroName label not found!")
	if not hero_level_label:
		print("HeroLevel label not found!")
	if not hero_class_label:
		print("HeroClass label not found!")

func update_hero_display():
	if hero_name_label and hero_level_label and hero_class_label:
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			hero_name_label.text = game_manager.active_character_name
			hero_level_label.text = "Level: 1"
			hero_class_label.text = game_manager.active_character_class
			
			if hero_name_label.text.is_empty():
				hero_name_label.text = "Unnamed Hero"
		else:
			# Fallback for testing
			hero_name_label.text = "Test Hero"
			hero_level_label.text = "Level: 1"
			hero_class_label.text = "Adventurer"
