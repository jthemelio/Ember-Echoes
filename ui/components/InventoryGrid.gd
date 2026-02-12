extends GridContainer

# Path to your slot scene
@export var slot_scene: PackedScene = preload("res://ui/components/InventorySlot.tscn")

# How many slots this grid should create (40 for bag, 40 for warehouse, etc.)
@export var slot_count: int = 40

# Offset into the inventory array (0 = bag shows items 0-39, 40 = warehouse shows items 40-79)
@export var inventory_offset: int = 0

# Quality filter: "" = show all, "Normal" = show only Normal, etc.
var quality_filter: String = ""

func _ready():
	# Clear editor placeholders and fill grid
	refresh_grid()

func refresh_grid():
	# 1. Ensure we have exactly slot_count slots in the tree
	var current_slots = get_children()
	if current_slots.size() < slot_count:
		for i in range(slot_count - current_slots.size()):
			var new_slot = slot_scene.instantiate()
			new_slot.is_warehouse = (inventory_offset >= 40)
			add_child(new_slot)
	else:
		# Update warehouse flag on existing slots
		for slot in current_slots:
			slot.is_warehouse = (inventory_offset >= 40)

	# 1b. Safety: remove zero/negative amount ghost entries from inventory
	var inv = GameManager.active_user_inventory
	for i in range(inv.size() - 1, -1, -1):
		var e = inv[i]
		if e is Dictionary and e.has("amt") and int(e.get("amt", 0)) <= 0:
			inv.remove_at(i)

	# 2. Get the slice of inventory for this grid
	var inventory = GameManager.active_user_inventory
	var slice_start = inventory_offset
	var slice_end = min(inventory_offset + slot_count, inventory.size())
	var all_slots = get_children()

	# 3. Map items to slots
	var slot_idx := 0
	for inv_idx in range(slice_start, slice_end):
		if slot_idx >= all_slots.size():
			break
		var entry = inventory[inv_idx]
		var item_data: ItemData = null

		if entry is Dictionary and entry.has("uid"):
			item_data = ItemDatabase.resolve_instance(entry)
		elif entry is ItemData:
			item_data = entry

		# Apply quality filter
		if quality_filter != "" and item_data != null:
			if item_data.quality != quality_filter:
				# Still show slot but as empty (item hidden by filter)
				all_slots[slot_idx].set_item(null)
				slot_idx += 1
				continue

		all_slots[slot_idx].set_item(item_data)
		slot_idx += 1

	# 4. Clear remaining slots
	for i in range(slot_idx, min(slot_count, all_slots.size())):
		all_slots[i].set_item(null)
