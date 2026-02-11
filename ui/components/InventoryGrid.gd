extends GridContainer

# Path to your slot scene
@export var slot_scene: PackedScene = preload("res://ui/components/InventorySlot.tscn")

# How many slots this grid should create (20 for bag, 40 for warehouse, etc.)
@export var slot_count: int = 40

func _ready():
	# Clear editor placeholders and fill grid
	refresh_grid()

func refresh_grid():
	# 1. Ensure we have exactly slot_count slots in the tree
	var current_slots = get_children()
	if current_slots.size() < slot_count:
		for i in range(slot_count - current_slots.size()):
			var new_slot = slot_scene.instantiate()
			add_child(new_slot)

	# 2. Get the updated inventory
	var pf_inventory = GameManager.active_user_inventory
	var all_slots = get_children()

	# 3. Map items to slots
	for i in range(min(slot_count, all_slots.size())):
		var slot = all_slots[i]
		if i < pf_inventory.size():
			# This slot has a real item
			var item_data = ItemDatabase.parse_playfab_item(pf_inventory[i])
			slot.set_item(item_data)
		else:
			# This slot should be empty
			slot.set_item(null)
