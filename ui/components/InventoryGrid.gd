extends GridContainer

# Path to your slot scene
@export var slot_scene: PackedScene = preload("res://ui/components/InventorySlot.tscn")

# How many slots this grid should create (40 for bag, 40 for warehouse, etc.)
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

	# 2. Get the updated inventory (array of compact instance dicts)
	var inventory = GameManager.active_user_inventory
	var all_slots = get_children()

	# 3. Map items to slots
	for i in range(min(slot_count, all_slots.size())):
		var slot = all_slots[i]
		if i < inventory.size():
			var entry = inventory[i]
			# Compact instance dicts have a "uid" key
			if entry is Dictionary and entry.has("uid"):
				slot.set_item(ItemDatabase.resolve_instance(entry))
			elif entry is ItemData:
				# Legacy: already resolved ItemData
				slot.set_item(entry)
			else:
				slot.set_item(null)
		else:
			# This slot should be empty
			slot.set_item(null)
