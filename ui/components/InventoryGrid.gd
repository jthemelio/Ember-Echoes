extends GridContainer

# Path to your slot scene
@export var slot_scene: PackedScene = preload("res://ui/components/InventorySlot.tscn")

# How many slots this grid should create (40 for bag, 40 for warehouse, etc.)
@export var slot_count: int = 40

# If true, reads from GameManager.active_user_warehouse instead of active_user_inventory
@export var is_warehouse_grid: bool = false

# Quality filter: "" = show all, "Normal" = show only Normal, etc.
var quality_filter: String = ""

func _ready():
	# Clear editor placeholders and fill grid
	refresh_grid()
	# Keep slots square when the grid resizes (desktop responsive)
	resized.connect(_enforce_square_slots)
	call_deferred("_enforce_square_slots")

func _enforce_square_slots() -> void:
	if columns <= 0:
		return
	var grid_w := size.x
	# Cap to content width minus card padding
	var max_w := ScreenHelper.get_content_width() - 48.0
	if grid_w <= 0.0 or grid_w > max_w:
		grid_w = max_w
	if grid_w <= 0.0:
		return
	var sep := get_theme_constant("h_separation")
	var cell_w := (grid_w - sep * (columns - 1)) / float(columns)
	if cell_w <= 0.0:
		return
	for slot in get_children():
		slot.custom_minimum_size = Vector2(cell_w, cell_w)

func _get_source_array() -> Array:
	if is_warehouse_grid:
		return GameManager.active_user_warehouse
	return GameManager.active_user_inventory

func refresh_grid():
	# 1. Ensure we have exactly slot_count slots in the tree
	var current_slots = get_children()
	if current_slots.size() < slot_count:
		for i in range(slot_count - current_slots.size()):
			var new_slot = slot_scene.instantiate()
			new_slot.is_warehouse = is_warehouse_grid
			add_child(new_slot)
	else:
		# Update warehouse flag on existing slots
		for slot in current_slots:
			slot.is_warehouse = is_warehouse_grid

	# 1b. Safety: remove zero/negative amount ghost entries
	var source = _get_source_array()
	for i in range(source.size() - 1, -1, -1):
		var e = source[i]
		if e is Dictionary and e.has("amt") and int(e.get("amt", 0)) <= 0:
			source.remove_at(i)

	# 2. Map items to slots
	var all_slots = get_children()
	var slot_idx := 0
	for inv_idx in range(mini(source.size(), slot_count)):
		if slot_idx >= all_slots.size():
			break
		var entry = source[inv_idx]
		var item_data: ItemData = null

		# Handle null entries
		if entry == null:
			all_slots[slot_idx].set_item(null)
			slot_idx += 1
			continue

		if entry is Dictionary and entry.has("uid"):
			item_data = ItemDatabase.resolve_instance(entry)
		elif entry is ItemData:
			item_data = entry

		# Apply quality filter
		if quality_filter != "" and item_data != null:
			if item_data.quality != quality_filter:
				all_slots[slot_idx].set_item(null)
				slot_idx += 1
				continue

		all_slots[slot_idx].set_item(item_data)
		slot_idx += 1

	# 3. Clear remaining slots
	for i in range(slot_idx, min(slot_count, all_slots.size())):
		all_slots[i].set_item(null)
