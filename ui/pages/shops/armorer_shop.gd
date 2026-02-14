# armorer_shop.gd — Displays Normal quality armor filtered by player class
# Headgear, Body Armor, Boots, Rings, Necklaces
extends MarginContainer

const InventorySlotScene = preload("res://ui/components/InventorySlot.tscn")

@onready var gold_label: Label = $ScrollContent/ContentVBox/ShopHeader/Margin/VBox/GoldRow/GoldValue
@onready var item_grid: GridContainer = $ScrollContent/ContentVBox/ShopHeader/Margin/VBox/ItemGrid

# Class-specific body armor types
const ARMOR_BODY: Dictionary = {
	"Marksman": "Coat", "Twin-Soul": "Armor", "Wuxia": "Vestment",
	"Juggernaut": "Armor", "Spiritmender": "Vestment", "Emberlord": "Vestment"
}

# Class-specific headgear types
const ARMOR_HEAD: Dictionary = {
	"Marksman": "Hat", "Twin-Soul": "Crown", "Wuxia": "Hat",
	"Juggernaut": "Helmet", "Spiritmender": "Hat", "Emberlord": "Hat"
}

# Universal armor types (all classes can use)
const UNIVERSAL_TYPES: Array = ["Boots", "Ring", "Necklace"]

var _shop_items: Array = []
var _purchase_in_flight: bool = false  # Prevents rapid-fire purchases

func _ready() -> void:
	_adapt_for_desktop()
	_refresh_gold()
	_populate_shop()

func _adapt_for_desktop() -> void:
	if item_grid:
		item_grid.columns = ScreenHelper.grid_columns(4, 5)

func _refresh_gold() -> void:
	var gold = int(GameManager.active_user_currencies.get("GD", 0))
	gold_label.text = GameManager.format_gold(gold)

func _populate_shop() -> void:
	# Clear existing items
	for child in item_grid.get_children():
		child.queue_free()
	_shop_items.clear()

	var loot_mgr = get_node_or_null("/root/LootManager")
	if not loot_mgr:
		return

	var player_class = GameManager.active_character_class
	var body_type = ARMOR_BODY.get(player_class, "Armor")
	var head_type = ARMOR_HEAD.get(player_class, "Hat")
	var allowed_types = [body_type, head_type] + UNIVERSAL_TYPES

	# Filter catalog: Normal quality, matching armor types
	for item in loot_mgr._all_items:
		var cd = item.get("CustomData", {})
		var quality = cd.get("Quality", "")
		var item_type = cd.get("Type", "")

		if quality != "Normal":
			continue
		if item_type not in allowed_types:
			continue

		# For class-specific armor, check ItemClass matches
		if item_type == body_type or item_type == head_type:
			var item_class = item.get("ItemClass", "")
			if item_class != player_class and item_class != "" and item_class != "Jewelry" and item_class != "Boots":
				if not (player_class == "Wuxia" and item_class == "Wuxie"):
					continue

		_shop_items.append(item)

	# Sort by level requirement
	_shop_items.sort_custom(func(a, b):
		var a_lvl = int(a.get("CustomData", {}).get("LevelReq", 0))
		var b_lvl = int(b.get("CustomData", {}).get("LevelReq", 0))
		return a_lvl < b_lvl
	)

	# Group by type and create entries with subheadings
	var groups: Dictionary = {}  # Type -> Array of items
	for item in _shop_items:
		var t = item.get("CustomData", {}).get("Type", "Other")
		if not groups.has(t):
			groups[t] = []
		groups[t].append(item)

	# Display order for armor types
	var type_order = [head_type, body_type, "Boots", "Ring", "Necklace"]
	for type_name in type_order:
		if not groups.has(type_name):
			continue
		_create_type_heading(type_name)
		for item in groups[type_name]:
			_create_shop_slot(item)
		# Pad to fill the row so next heading starts on a new line
		var remainder = item_grid.get_child_count() % item_grid.columns
		if remainder != 0:
			for _p in range(item_grid.columns - remainder):
				var pad = Control.new()
				pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
				item_grid.add_child(pad)

func _create_type_heading(type_name: String) -> void:
	var heading = Label.new()
	heading.text = type_name + "s"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.add_child(heading)
	# Fill remaining columns in the row with empty spacers
	for i in range(item_grid.columns - 1):
		var spacer = Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_grid.add_child(spacer)

func _create_shop_slot(item: Dictionary) -> void:
	var cd = item.get("CustomData", {})
	var display_name = item.get("DisplayName", "Unknown")
	var level_req = int(cd.get("LevelReq", 0))
	var price = int(cd.get("Price", 0))
	var item_id = item.get("ItemId", "")

	# Create an InventorySlot with the item resolved
	var slot = InventorySlotScene.instantiate()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_FILL
	slot.suppress_tooltip = true  # We handle click ourselves

	var instance = ItemDatabase.create_instance_dict(item_id, "Normal")
	var item_data = ItemDatabase.resolve_instance(instance)
	item_grid.add_child(slot)  # Must be in tree before set_item
	slot.set_item(item_data)

	# Dim if player can't use yet
	var player_level = GameManager.active_character_level
	if player_level < level_req:
		slot.modulate = Color(0.6, 0.6, 0.6, 1.0)

	# Overlay a small price label at the bottom
	var price_label = Label.new()
	price_label.text = "%sg" % GameManager.format_gold(price)
	price_label.add_theme_font_size_override("font_size", 9)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	price_label.anchors_preset = Control.PRESET_BOTTOM_WIDE
	price_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(price_label)

	# Connect click for purchase
	slot.gui_input.connect(_on_shop_slot_input.bind(item_id, display_name, price))

func _on_shop_slot_input(event: InputEvent, item_id: String, display_name: String, price: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_buy_pressed(item_id, display_name, price)

func _on_buy_pressed(item_id: String, display_name: String, price: int) -> void:
	if _purchase_in_flight:
		print("Armorer: Purchase already in progress, please wait")
		return
	var gold = GameManager.active_user_currencies.get("GD", 0)
	if gold < price:
		print("Armorer: Not enough gold for %s (need %d, have %d)" % [display_name, price, gold])
		return

	_purchase_in_flight = true
	print("Armorer: Purchasing %s for %d gold" % [display_name, price])
	PlayFabManager.client.execute_cloud_script("purchaseShopItem", {
		"characterId": GameManager.active_character_id,
		"itemId": item_id,
		"price": price
	}, func(result):
		var data = result.get("data", {})
		var fn_result = data.get("FunctionResult", {})

		# Log CloudScript messages
		var logs = data.get("Logs", [])
		for log_entry in logs:
			print("Armorer [CloudScript %s]: %s %s" % [
				log_entry.get("Level", ""),
				log_entry.get("Message", ""),
				log_entry.get("Data", "")
			])

		_purchase_in_flight = false

		if fn_result is Dictionary and fn_result.get("success", false):
			print("Armorer: Purchase successful! Gold remaining: %s" % fn_result.get("goldRemaining", "?"))
			GameManager.active_user_currencies["GD"] = fn_result.get("goldRemaining", gold - price)
			_refresh_gold()
			GlobalUI.show_floating_text("Purchased %s!" % display_name, Color.WHITE)

			# Add the compact instance dict returned by CloudScript to local bag
			var new_item = fn_result.get("item", {})
			if new_item is Dictionary and new_item.has("uid"):
				GameManager.add_to_bag(new_item)
				GameManager.inventory_changed.emit()
			else:
				# Fallback: create locally if server didn't return the item
				var instance = ItemDatabase.create_instance_dict(item_id, "Normal")
				var item_data = ItemDatabase.resolve_instance(instance)
				if instance.get("dura", -1) == -1:
					instance["dura"] = item_data.stats.get("MaxDura", 0)
				GameManager.add_to_bag(instance)
				GameManager.inventory_changed.emit()
		else:
			var error_msg = ""
			if fn_result is Dictionary:
				error_msg = fn_result.get("error", "Unknown")
			else:
				error_msg = "FunctionResult was null/invalid"
			print("Armorer: Purchase failed -- %s" % error_msg)
	)
