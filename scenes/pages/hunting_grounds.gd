extends VBoxContainer

@export var mob_slot_scene: PackedScene 
@onready var grid = $GridContainer

# These are your "Unique" primary nodes
@onready var primary_name = $PanelContainer/VBoxContainer/MonsterName
@onready var primary_hp = $PanelContainer/VBoxContainer/MonsterHP
@onready var char_name_label = $Header/VBoxContainer2/HeaderContent/CharNameLabel 
@onready var class_name_label = $Header/VBoxContainer2/HeaderContent/ClassName
@onready var hp_display = $Header/VBoxContainer2/HPDisplay

func _ready() -> void:
	# Load the data from GameManager
	char_name_label.text = GameManager.active_character_name
	class_name_label.text = GameManager.active_character_class
	print("Hunting Grounds UI updated for: ", GameManager.active_character_name)

func spawn_full_encounter():
	# 1. Set up the "King" Chicken (The 25th one)
	primary_name.text = "Chicken 1 (Primary)"
	primary_hp.value = 100
	
	# 2. Clear the grid and spawn the other 24 in the queue
	for child in grid.get_children():
		child.queue_free()
		
	for i in range(2, 26): # Starts at 2 because #1 is the Primary
		var new_mob = mob_slot_scene.instantiate()
		grid.add_child(new_mob)
		new_mob.get_node("HBoxContainer/Label").text = "Chicken " + str(i)

func on_primary_slain():
	if grid.get_child_count() > 0:
		# 1. Get the data from the next Chicken in the queue (Chicken 2)
		var next_mob = grid.get_child(0)
		var next_name = next_mob.get_node("HBoxContainer/Label").text
		
		# 2. Update your "Unique" Primary Slot with the new data
		primary_name.text = next_name + " (Primary)"
		primary_hp.value = 100
		
		# 3. Remove the Chicken from the grid so everyone else slides up
		next_mob.queue_free()
	else:
		primary_name.text = "Victory! Area Cleared"
		primary_hp.value = 0
