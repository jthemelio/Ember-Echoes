extends GridContainer

# Path to your slot scene
@export var slot_scene: PackedScene = preload("res://ui/components/InventorySlot.tscn")

func _ready():
	# Clear editor placeholders and fill grid
	refresh_grid()

func refresh_grid():
	# 1. Ensure we have exactly 40 slots in the tree first
	var current_slots = get_children()
	if current_slots.size() < 40:
		for i in range(40 - current_slots.size()):
			var new_slot = slot_scene.instantiate()
			add_child(new_slot)
	
	# 2. Get the updated inventory
	var pf_inventory = GameManager.active_user_inventory
	var all_slots = get_children()
	
	# 3. Map items to slots
	for i in range(40):
		var slot = all_slots[i]
		if i < pf_inventory.size():
			# This slot has a real item
			var item_data = ItemDatabase.parse_playfab_item(pf_inventory[i])
			slot.set_item(item_data)
		else:
			# This slot should be empty
			slot.set_item(null)
